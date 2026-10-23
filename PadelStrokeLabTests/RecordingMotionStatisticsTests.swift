import Foundation
import Testing
import PadelCore
@testable import PadelStrokeLab

@MainActor
struct RecordingMotionStatisticsTests {
    @Test func fixtureRequiresAnExplicitSupportedArgument() throws {
        #expect(try RecordingMotionUIFixture.make(arguments: []) == nil)
        #expect(try RecordingMotionUIFixture.make(arguments: ["--motion-statistics-fixture=/tmp/arbitrary"]) == nil)
    }
    private func fixture(paths supplied: RecordingPaths? = nil, interrupted: Bool = false,
                         userAcceleration: Double = 0.5) throws -> (RecordingPaths, UUID) {
        let paths = try supplied ?? RecordingPaths(base: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let id = UUID()
        let metadata = try RecordingMetadata(recordingID: id,
            clock: RecordingClock(domainID: UUID(), monotonicAnchorSeconds: 100, wallAnchorUnixSeconds: 1_792_300_000),
            appBuild: "SYNTHETIC UI REVIEW", protocolVersion: "test", deviceModel: "Synthetic fixture",
            operatingSystem: "Test", handedness: .right, playingArm: .right, watchWrist: .right,
            watchOrientation: "test", playingArmConfirmed: true, drill: "forehand",
            capabilityReport: "No physical sensor evidence",
            streams: RecordingStream.allCases.map {
                try RecordingStreamConfiguration(stream: $0, supported: true, requestedRateHz: nil, knownSensorLimit: nil)
            })
        let store = try RecordingStore.create(root: paths.rawRoot, metadata: metadata)
        for stream in RecordingStream.allCases {
            let values: [Double] = stream == .accelerometer ? [3, 4, 0] : [0, 0, .pi, 0, 0, 1, 0, 0, userAcceleration, 0, 0, 0, 1]
            try store.append(RecordingChunk(recordingID: id, clockDomainID: metadata.clock.domainID,
                stream: stream, sequence: 0,
                samples: [100.1, 100.2, 110.1, 110.2].map { RecordingSample(timestamp: $0, values: values) }))
        }
        if !interrupted { try store.finalize(stopRequestTimestamp: 111, reason: .userStopped) }
        var timeline = CaptureTimeline(recordingID: id, clockDomainID: metadata.clock.domainID)
        timeline.events = try [
            .init(kind: .start, timestamp: 100), .init(kind: .pauseRequested, timestamp: 101),
            .init(kind: .paused, timestamp: 101), .init(kind: .resumeRequested, timestamp: 109),
            .init(kind: .resumed, timestamp: 110), .init(kind: interrupted ? .interruption : .stopped, timestamp: 111)
        ]
        try SessionAnnotationsStore(root: paths.notesRoot).saveTimeline(timeline)
        return (paths, id)
    }

    private func snapshot(_ paths: RecordingPaths, _ id: UUID) throws -> [String: Data] {
        var result: [String: Data] = [:]
        for (prefix, root) in [("raw", paths.rawRoot), ("notes", paths.notesRoot)] {
            let directory = root.appendingPathComponent(id.uuidString)
            for name in try FileManager.default.contentsOfDirectory(atPath: directory.path) {
                result["\(prefix)/\(name)"] = try Data(contentsOf: directory.appendingPathComponent(name))
            }
        }
        return result
    }

    private func cleanup(_ paths: RecordingPaths) {
        try? FileManager.default.removeItem(at: paths.rawRoot.deletingLastPathComponent().deletingLastPathComponent())
    }

    @Test func realRepositoryAddsMotionWithoutChangingCoverageOrFiles() async throws {
        let (paths, id) = try fixture(); defer { cleanup(paths) }
        let before = try snapshot(paths, id)
        let repository = RecordingLibraryRepository(paths: paths)
        let review = try await repository.review(id)
        let motion = try #require(review.motionStatistics)
        #expect(motion.summary(for: .rawAcceleration).peak == 5)
        #expect(motion.summary(for: .userAcceleration).peak == 0.5)
        #expect(motion.summary(for: .rotationRate).peak == .pi)
        #expect(review.segments.count == 2 && review.streams.allSatisfy { $0.count == 4 })
        #expect(review.streams.allSatisfy { $0.segments.allSatisfy { abs(($0.rate ?? 0) - 10) < 1e-8 } })
        #expect(motion.summary(for: .rawAcceleration).points.map(\.timestamp) == [100.1, 100.2, 110.1, 110.2])
        #expect(try await repository.review(id).motionStatistics == motion)
        #expect(try await repository.list().allSatisfy { $0.motionStatistics == nil })
        #expect(try snapshot(paths, id) == before)
        let exported = try await repository.export(id)
        #expect(FileManager.default.fileExists(atPath: exported.path))
        #expect(try snapshot(paths, id) == before)
    }

    @Test func interruptedAndCorruptDataRemainTruthful() async throws {
        let (paths, id) = try fixture(interrupted: true); defer { cleanup(paths) }
        let repository = RecordingLibraryRepository(paths: paths)
        let interrupted = try await repository.review(id)
        #expect(interrupted.status == "Interrupted")
        #expect(interrupted.motionStatistics?.summary(for: .rawAcceleration).peak == 5)
        try Data("corrupt".utf8).write(to: paths.rawRoot.appendingPathComponent(id.uuidString).appendingPathComponent("chunk-1-0.bin"))
        let damaged = try await repository.review(id)
        #expect(damaged.report.status == .corrupt)
        #expect(damaged.motionStatistics == nil && damaged.motionStatisticsUnavailableReason != nil)
    }

    @Test func missingTimelineWithholdsStatistics() async throws {
        let (paths, id) = try fixture(); defer { cleanup(paths) }
        try FileManager.default.removeItem(at: paths.notesRoot.appendingPathComponent(id.uuidString).appendingPathComponent("capture-events.json"))
        let result = try await RecordingLibraryRepository(paths: paths).review(id)
        #expect(result.motionStatistics == nil && result.motionStatisticsUnavailableReason != nil)
    }

    @Test(.timeLimit(.minutes(1))) func changedSelectionRejectsOlderUncancelledResult() async throws {
        let (paths, firstID) = try fixture(); defer { cleanup(paths) }
        let (_, secondID) = try fixture(paths: paths, userAcceleration: 1.5)
        let barrier = DetailReviewBarrier(recordingID: firstID)
        let model = RecordingLibraryModel(paths: paths, activateConnectivity: false)
        model.detailReviewDidComplete = { id in await barrier.hold(id) }
        let firstOpen = Task { await model.open(firstID) }
        await barrier.waitForArrival()
        #expect(model.selected == nil && model.loading)
        await model.open(secondID)
        #expect(model.selected?.id == secondID)
        #expect(model.selected?.motionStatistics?.summary(for: .userAcceleration).peak == 1.5)
        #expect(!model.loading)
        await barrier.release()
        await firstOpen.value
        #expect(!firstOpen.isCancelled)
        #expect(model.selected?.id == secondID)
        #expect(model.selected?.motionStatistics?.summary(for: .userAcceleration).peak == 1.5)
        #expect(!model.loading && model.error == nil)
    }

    @Test(.timeLimit(.minutes(1))) func cancelledInFlightReviewCannotPublish() async throws {
        let (paths, id) = try fixture(); defer { cleanup(paths) }
        let barrier = DetailReviewBarrier(recordingID: id)
        let model = RecordingLibraryModel(paths: paths, activateConnectivity: false)
        model.detailReviewDidComplete = { id in await barrier.hold(id) }
        let open = Task { await model.open(id) }
        await barrier.waitForArrival()
        #expect(model.selected == nil && model.loading)
        open.cancel()
        await barrier.release()
        await open.value
        #expect(open.isCancelled)
        #expect(model.selected == nil && !model.loading && model.error == nil)
    }
}

private actor DetailReviewBarrier {
    let recordingID: UUID
    private var arrived = false
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    private var held: CheckedContinuation<Void, Never>?

    init(recordingID: UUID) { self.recordingID = recordingID }

    func hold(_ id: UUID) async {
        guard id == recordingID else { return }
        await withCheckedContinuation { continuation in
            held = continuation
            arrived = true
            let waiters = arrivalWaiters
            arrivalWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
        }
    }

    func waitForArrival() async {
        guard !arrived else { return }
        await withCheckedContinuation { arrivalWaiters.append($0) }
    }

    func release() {
        held?.resume()
        held = nil
    }
}
