import Foundation
import Testing
@testable import PadelCore

struct MotionStatisticsTests {
    private func metadata() throws -> RecordingMetadata {
        try RecordingMetadata(recordingID: UUID(),
            clock: RecordingClock(domainID: UUID(), monotonicAnchorSeconds: 100, wallAnchorUnixSeconds: 1_792_300_000),
            appBuild: "synthetic", protocolVersion: "test", deviceModel: "Synthetic fixture",
            operatingSystem: "Test", handedness: .right, playingArm: .right, watchWrist: .right,
            watchOrientation: "test", playingArmConfirmed: true, drill: "forehand",
            capabilityReport: "Synthetic; no sensor evidence",
            streams: RecordingStream.allCases.map {
                try RecordingStreamConfiguration(stream: $0, supported: true, requestedRateHz: nil, knownSensorLimit: nil)
            })
    }

    private func chunk(_ metadata: RecordingMetadata, stream: RecordingStream = .accelerometer,
                       sequence: Int = 0, _ samples: [(Double, [Double])]) throws -> RecordingChunk {
        try RecordingChunk(recordingID: metadata.recordingID, clockDomainID: metadata.clock.domainID,
            stream: stream, sequence: sequence,
            samples: samples.map { RecordingSample(timestamp: $0.0, values: $0.1) })
    }

    private func reducer(_ metadata: RecordingMetadata, buckets: Int = 256) throws -> MotionStatisticsAccumulator {
        try .init(metadata: metadata, segments: [.init(id: 0, start: 100, end: 200)], chartBucketBudget: buckets)
    }

    @Test func vectorUnitsAndSampleWeightedRMS() throws {
        let m = try metadata()
        var r = try reducer(m)
        try r.consume(chunk(m, [(101, [3, 0, 0]), (102, [0, 4, 0])]))
        try r.consume(chunk(m, stream: .deviceMotion, [
            (101.5, [0, 0, .pi, 0, 0, 1, 0, 0, 0.5, 0, 0, 0, 1])
        ]))
        let result = try r.result()
        let raw = result.summary(for: .rawAcceleration)
        #expect(raw.sampleCount == 2 && raw.peak == 4)
        #expect(abs(try #require(raw.sampleRMS) - sqrt(12.5)) < 1e-12)
        #expect(result.summary(for: .userAcceleration).peak == 0.5)
        #expect(result.summary(for: .rotationRate).peak == .pi)
        #expect(MotionStatisticMetric.rotationRate.displayValue(.pi) == 180)
        var other = try reducer(m)
        try other.consume(chunk(m, [(101, [3, 4, 0])]))
        #expect(try other.result().summary(for: .rawAcceleration).peak == 5)
    }

    @Test func chunkPartitionDoesNotChangeResultsOrPoints() throws {
        let m = try metadata()
        let samples = (0..<200).map { (100 + Double($0) / 10, [Double(($0 * 17) % 31), 0, 0]) }
        var whole = try reducer(m, buckets: 7)
        try whole.consume(chunk(m, samples))
        var split = try reducer(m, buckets: 7)
        try split.consume(chunk(m, Array(samples[..<73])))
        try split.consume(chunk(m, sequence: 1, Array(samples[73...])))
        #expect(try whole.result() == split.result())
    }

    @Test func activeSegmentsExcludePausesAndCountSharedBoundaryOnce() throws {
        let m = try metadata()
        var r = try MotionStatisticsAccumulator(metadata: m, segments: [
            .init(id: 0, start: 100, end: 102), .init(id: 1, start: 102, end: 103),
            .init(id: 2, start: 110, end: 112)
        ], chartBucketBudget: 3)
        try r.consume(chunk(m, [(99, [9, 0, 0]), (100, [1, 0, 0]), (102, [2, 0, 0]),
            (104, [99, 0, 0]), (110, [3, 0, 0]), (112, [4, 0, 0]), (113, [99, 0, 0])]))
        let summary = try r.result().summary(for: .rawAcceleration)
        #expect(summary.sampleCount == 4 && summary.peak == 4)
        #expect(summary.points.map(\.timestamp) == [100, 102, 110, 112])
        #expect(summary.points.map(\.segmentID) == [0, 0, 2, 2])
    }

    @Test func absentAndSingleSampleHaveTruthfulOptionality() throws {
        let m = try metadata()
        var r = try reducer(m)
        #expect(try r.result().summaries.allSatisfy { $0.sampleCount == 0 && $0.peak == nil && $0.sampleRMS == nil })
        try r.consume(chunk(m, [(101, [0, 0, 0])]))
        let result = try r.result()
        #expect(result.summary(for: .rawAcceleration).sampleRMS == 0)
        #expect(result.summary(for: .rotationRate).peak == nil)
    }

    @Test func extremaAndActualTimesSurviveBoundedReduction() throws {
        let m = try metadata()
        var r = try reducer(m, buckets: 1)
        try r.consume(chunk(m, [(100, [2, 0, 0]), (101, [9, 0, 0]), (102, [9, 0, 0]),
            (150, [1, 0, 0]), (199, [3, 0, 0])]))
        let summary = try r.result().summary(for: .rawAcceleration)
        #expect(summary.points.map(\.timestamp) == [100, 101, 150, 199])
        #expect(summary.points.map(\.value) == [2, 9, 1, 3])
        #expect(summary.peak == 9)
    }

    @Test func largeInputRemainsBoundedAndKeepsBoundaryPeak() throws {
        let m = try metadata()
        var r = try reducer(m)
        for sequence in 0..<10 {
            let samples = (0..<5_000).map { offset -> (Double, [Double]) in
                let index = sequence * 5_000 + offset
                return (100 + Double(index) / 500, [index == 25_000 ? 500 : Double(index % 13), 0, 0])
            }
            try r.consume(chunk(m, sequence: sequence, samples))
        }
        let summary = try r.result().summary(for: .rawAcceleration)
        #expect(summary.sampleCount == 50_000 && summary.peak == 500)
        #expect(summary.points.count <= 1_024)
        #expect(summary.points.contains { $0.timestamp == 150 && $0.value == 500 })
    }

    @Test func stableLargeNumbersAndUnrepresentableAffectedMetric() throws {
        let m = try metadata()
        var r = try reducer(m)
        try r.consume(chunk(m, [(101, [1e200, 1e200, 0]), (102, [1e200, 1e200, 0])]))
        let valid = try r.result().summary(for: .rawAcceleration)
        #expect(try #require(valid.sampleRMS).isFinite)
        #expect(abs(try #require(valid.sampleRMS) / 1e200 - sqrt(2)) < 1e-12)
        try r.consume(chunk(m, sequence: 1, [(103, [.greatestFiniteMagnitude, .greatestFiniteMagnitude, 0])]))
        let invalid = try r.result().summary(for: .rawAcceleration)
        #expect(invalid.sampleCount == 3 && invalid.peak == nil && invalid.sampleRMS == nil)
        #expect(invalid.points.isEmpty && invalid.unavailableReason != nil)
        try r.consume(chunk(m, stream: .deviceMotion, [(101, [0, 0, 1, 0, 0, 1, 0, 0, 2, 0, 0, 0, 1])]))
        #expect(try r.result().summary(for: .userAcceleration).peak == 2)
    }

    @Test func invalidChunkEvenOutsideSegmentsPoisonsCompletion() throws {
        let m = try metadata()
        var r = try reducer(m)
        let foreign = try metadata()
        #expect(throws: (any Error).self) {
            try r.consume(chunk(foreign, [(300, [1, 0, 0])]))
        }
        #expect(throws: (any Error).self) { try r.result() }
        var order = try reducer(m)
        try order.consume(chunk(m, [(300, [1, 0, 0])]))
        #expect(throws: (any Error).self) { try order.consume(chunk(m, sequence: 1, [(299, [1, 0, 0])])) }
        #expect(throws: (any Error).self) { try order.result() }
    }

    @Test func invalidSegmentsAndWrongClockAreRejected() throws {
        let m = try metadata()
        for segments in [
            [MotionStatisticsSegment(id: 0, start: 102, end: 101)],
            [.init(id: 0, start: 100, end: .infinity)],
            [.init(id: 0, start: 100, end: 103), .init(id: 1, start: 102, end: 104)],
            (0..<257).map { .init(id: $0, start: 100 + Double($0), end: 100 + Double($0)) }
        ] {
            #expect(throws: (any Error).self) { try MotionStatisticsAccumulator(metadata: m, segments: segments) }
        }
        var r = try reducer(m)
        let wrong = try RecordingChunk(recordingID: m.recordingID, clockDomainID: UUID(), stream: .accelerometer,
            sequence: 0, samples: [RecordingSample(timestamp: 300, values: [1, 0, 0])])
        #expect(throws: (any Error).self) { try r.consume(wrong) }
    }

    @Test func cancellationIsDeterministicAndCannotProducePartialSuccess() throws {
        let m = try metadata()
        var r = try reducer(m)
        var checks = 0
        let input = try chunk(m, (0..<1_000).map { (100 + Double($0) / 100, [1, 0, 0]) })
        #expect(throws: CancellationError.self) {
            try r.consume(input) {
                checks += 1
                if checks == 3 { throw CancellationError() }
            }
        }
        #expect(checks == 3)
        #expect(throws: (any Error).self) { try r.result() }
    }
}
