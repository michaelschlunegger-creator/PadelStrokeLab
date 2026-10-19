import Foundation
import Testing
@testable import PadelCore

let recordingTestID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
let recordingTestClockID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

func recordingMetadata(appBuild: String = "synthetic-build") throws -> RecordingMetadata {
    try RecordingMetadata(recordingID: recordingTestID,
                          clock: RecordingClock(domainID: recordingTestClockID, monotonicAnchorSeconds: 10,
                                                wallAnchorUnixSeconds: 1_800_000_000.125),
                          appBuild: appBuild, protocolVersion: "synthetic-protocol-1", deviceModel: "synthetic-watch",
                          operatingSystem: "synthetic-os", handedness: .right, playingArm: .right, watchWrist: .right,
                          watchOrientation: "synthetic-crown-left", playingArmConfirmed: true,
                          drill: "forehandGroundstroke", capabilityReport: "synthetic-test-capability",
                          streams: RecordingStream.allCases.map {
                              try RecordingStreamConfiguration(stream: $0, supported: true, requestedRateHz: nil, knownSensorLimit: nil)
                          })
}

func recordingChunk(stream: RecordingStream = .accelerometer, sequence: Int = 0,
                    times: [Double] = [10.125, 10.25]) throws -> RecordingChunk {
    try RecordingChunk(recordingID: recordingTestID, clockDomainID: recordingTestClockID, stream: stream,
                       sequence: sequence, samples: times.map {
                           RecordingSample(timestamp: $0, values: (0..<stream.componentCount).map { Double($0) - 2.25 })
                       })
}

struct RecordingModelsTests {
    @Test func suppliedMetadataAndClockRemainDistinct() throws {
        let metadata = try recordingMetadata()
        let decoded = try RecordingChunkCodec.decodeMetadata(RecordingChunkCodec.encodeMetadata(metadata))
        #expect(decoded == metadata)
        #expect(decoded.clock.monotonicAnchorSeconds == 10)
        #expect(decoded.clock.wallAnchorUnixSeconds == 1_800_000_000.125)
        #expect(decoded.streams.allSatisfy { $0.requestedRateHz == nil && $0.knownSensorLimit == nil })
        #expect(decoded.streams[1].units == ["rad/s", "rad/s", "rad/s", "g", "g", "g", "g", "g", "g", "unitless", "unitless", "unitless", "unitless"])
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity, -1])
    func invalidClockAnchors(_ value: Double) {
        #expect(throws: (any Error).self) {
            try RecordingClock(domainID: recordingTestClockID, monotonicAnchorSeconds: value, wallAnchorUnixSeconds: 0)
        }
    }

    @Test func invalidWallAnchor() {
        #expect(throws: (any Error).self) {
            try RecordingClock(domainID: recordingTestClockID, monotonicAnchorSeconds: 0, wallAnchorUnixSeconds: .nan)
        }
    }

    @Test func textBoundaryUsesUTF8WithoutTrimming() throws {
        #expect(try recordingMetadata(appBuild: String(repeating: "é", count: 64)).appBuild.utf8.count == 128)
        #expect(throws: (any Error).self) { try recordingMetadata(appBuild: String(repeating: "é", count: 65)) }
        #expect(throws: (any Error).self) { try recordingMetadata(appBuild: "") }
        #expect(throws: (any Error).self) { try recordingMetadata(appBuild: "build\n") }
        #expect(try recordingMetadata(appBuild: " build ").appBuild == " build ")
    }

    @Test(arguments: [Double.nan, .infinity, 0, -1])
    func invalidRateAndLimit(_ value: Double) {
        #expect(throws: (any Error).self) {
            try RecordingStreamConfiguration(stream: .accelerometer, supported: true, requestedRateHz: value, knownSensorLimit: nil)
        }
        #expect(throws: (any Error).self) {
            try RecordingStreamConfiguration(stream: .deviceMotion, supported: true, requestedRateHz: nil, knownSensorLimit: value)
        }
    }

    @Test func inspectionBudgetsAreBounded() throws {
        _ = try RecordingInspectionBudget(maximumEntries: 272, maximumBytes: 268_976_128)
        for value in [0, 273] {
            #expect(throws: (any Error).self) { try RecordingInspectionBudget(maximumEntries: value) }
        }
        for value in [0, 268_976_129] {
            #expect(throws: (any Error).self) { try RecordingInspectionBudget(maximumBytes: value) }
        }
    }
}
