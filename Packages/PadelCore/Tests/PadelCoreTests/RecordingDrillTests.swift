import Foundation
import Testing
@testable import PadelCore

struct RecordingDrillTests {
    @Test func stableManualVocabularyAndHistoricalDisplay() {
        let expected = [
            "forehandGroundstroke": "Forehand groundstroke", "backhandGroundstroke": "Backhand groundstroke",
            "forehandVolley": "Forehand volley", "backhandVolley": "Backhand volley", "serve": "Serve",
            "lob": "Lob", "bandeja": "Bandeja", "vibora": "Víbora", "smash": "Smash",
            "otherUnclassified": "Other / unclassified"
        ]
        #expect(RecordingDrill.allCases.count == 10)
        #expect(Set(RecordingDrill.allCases.map(\.id)).count == 10)
        #expect(Dictionary(uniqueKeysWithValues: RecordingDrill.allCases.map { ($0.rawValue, $0.title) }) == expected)
        #expect(RecordingDrill.protocolVersion == "owner-manual-training-logger-1")
        #expect(RecordingDrill(rawValue: "") == nil)
        #expect(RecordingDrill(rawValue: "futureDrill") == nil)
        #expect(RecordingDrill.recordedTitle(for: "forehandGroundstroke") == "Forehand groundstroke")
        #expect(RecordingDrill.recordedTitle(for: "futureDrill") == "Unrecognized recorded value: futureDrill")
        #expect(RecordingDrill.recordedTitle(for: "forehand") == "Unrecognized recorded value: forehand")
        #expect(PracticeDrill.forehandGroundstroke.rawValue == "forehandGroundstroke")
    }

    @Test(arguments: RecordingDrill.allCases)
    func syntheticBothStreamStoreArchiveImportPreservesEveryOriginalByte(_ drill: RecordingDrill) throws {
        let source = try RecordingDirectoryFixture(), target = try RecordingDirectoryFixture()
        let paths = try RecordingPaths(base: source.root), importedPaths = try RecordingPaths(base: target.root)
        let metadata = try RecordingMetadata(recordingID: recordingTestID,
            clock: RecordingClock(domainID: recordingTestClockID, monotonicAnchorSeconds: 10, wallAnchorUnixSeconds: 1_800_000_000),
            appBuild: "synthetic-test", protocolVersion: RecordingDrill.protocolVersion,
            deviceModel: "Synthetic fixture", operatingSystem: "Synthetic OS", handedness: .right,
            playingArm: .right, watchWrist: .right, watchOrientation: "Synthetic orientation",
            playingArmConfirmed: true, drill: drill.rawValue, capabilityReport: "Synthetic data; no sensor evidence",
            streams: RecordingStream.allCases.map {
                try RecordingStreamConfiguration(stream: $0, supported: true, requestedRateHz: nil, knownSensorLimit: nil)
            })
        let store = try RecordingStore.create(root: paths.rawRoot, metadata: metadata)
        for stream in RecordingStream.allCases { try store.append(recordingChunk(stream: stream)) }
        try store.finalize(stopRequestTimestamp: 11, reason: .userStopped)
        let timeline = CaptureTimeline(recordingID: recordingTestID, clockDomainID: recordingTestClockID,
            events: [try RecordingCaptureEvent(kind: .start, timestamp: 10),
                     try RecordingCaptureEvent(kind: .stopped, timestamp: 11)])
        let original = try RecordingStore.inspect(root: paths.rawRoot, recordingID: recordingTestID)
        #expect(original.metadata == metadata && original.status == .finalized)
        #expect(original.chunks.map(\.sampleCount) == [2, 2])
        let bundle = paths.outboxRoot.appendingPathComponent("synthetic.pslrecording")
        let receipt = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot,
            timeline: timeline, destination: bundle)
        #expect(receipt.recordingID == recordingTestID && receipt.streams.map(\.sampleCount) == [2, 2])
        #expect(try RecordingArchive.importBundle(from: bundle, rawRoot: importedPaths.rawRoot,
            notesRoot: importedPaths.notesRoot) == receipt)
        let imported = try RecordingStore.inspect(root: importedPaths.rawRoot, recordingID: recordingTestID)
        #expect(imported.metadata == metadata && imported.status == .finalized)
        #expect(imported.chunks.map(\.sampleCount) == [2, 2])
        let originalDirectory = paths.rawRoot.appendingPathComponent(recordingTestID.uuidString)
        let importedDirectory = importedPaths.rawRoot.appendingPathComponent(recordingTestID.uuidString)
        let names = try FileManager.default.contentsOfDirectory(atPath: originalDirectory.path)
        #expect(Set(names) == Set(try FileManager.default.contentsOfDirectory(atPath: importedDirectory.path)))
        for name in names {
            #expect(try Data(contentsOf: originalDirectory.appendingPathComponent(name)) ==
                Data(contentsOf: importedDirectory.appendingPathComponent(name)))
        }
        #expect(try SessionAnnotationsStore(root: importedPaths.notesRoot).loadTimeline(recordingID: recordingTestID) == timeline)
    }
}
