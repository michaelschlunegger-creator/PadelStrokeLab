import Foundation
import Testing
import PadelCore
@testable import PadelStrokeLab

@MainActor
struct RecordingLibraryTests {
    private func paths() throws -> RecordingPaths {
        try RecordingPaths(base: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private func makeRecording(_ paths: RecordingPaths, finalized: Bool = true) throws -> UUID {
        let id = UUID()
        let clock = try RecordingClock(domainID: UUID(), monotonicAnchorSeconds: 100, wallAnchorUnixSeconds: 1_792_300_000)
        let metadata = try RecordingMetadata(recordingID: id, clock: clock, appBuild: "test-only",
            protocolVersion: "1", deviceModel: "Synthetic fixture", operatingSystem: "Test OS",
            handedness: .right, playingArm: .right, watchWrist: .right, watchOrientation: "test",
            playingArmConfirmed: true, drill: "forehand", capabilityReport: "Synthetic test fixture, no hardware",
            streams: [try RecordingStreamConfiguration(stream: .accelerometer, supported: true, requestedRateHz: nil, knownSensorLimit: nil)])
        let store = try RecordingStore.create(root: paths.rawRoot, metadata: metadata)
        for (sequence, times) in [[100.1, 100.2, 100.4], [110.1, 110.3, 110.5]].enumerated() {
            try store.append(RecordingChunk(recordingID: id, clockDomainID: clock.domainID,
                stream: .accelerometer, sequence: sequence,
                samples: times.map { RecordingSample(timestamp: $0, values: [0.1, 0.2, 0.3]) }))
        }
        if finalized { try store.finalize(stopRequestTimestamp: 111, reason: .userStopped) }
        let timeline = CaptureTimeline(recordingID: id, clockDomainID: clock.domainID, events: [
            try RecordingCaptureEvent(kind: .start, timestamp: 100),
            try RecordingCaptureEvent(kind: .pauseRequested, timestamp: 101),
            try RecordingCaptureEvent(kind: .paused, timestamp: 101),
            try RecordingCaptureEvent(kind: .resumeRequested, timestamp: 109),
            try RecordingCaptureEvent(kind: .resumed, timestamp: 110),
            try RecordingCaptureEvent(kind: finalized ? .stopRequested : .interruption, timestamp: 111)
        ])
        try SessionAnnotationsStore(root: paths.notesRoot).saveTimeline(timeline)
        return id
    }

    private func cleanup(_ paths: RecordingPaths) {
        try? FileManager.default.removeItem(at: paths.rawRoot.deletingLastPathComponent().deletingLastPathComponent())
    }

    private func rawSnapshot(_ paths: RecordingPaths, id: UUID) throws -> [String: Data] {
        let directory = paths.rawRoot.appendingPathComponent(id.uuidString)
        return try Dictionary(uniqueKeysWithValues: FileManager.default.contentsOfDirectory(atPath: directory.path).map {
            ($0, try Data(contentsOf: directory.appendingPathComponent($0)))
        })
    }

    @Test func emptyLibraryAndRecoveryStatuses() async throws {
        let roots = try paths(); defer { cleanup(roots) }
        let repository = RecordingLibraryRepository(paths: roots)
        #expect(try await repository.list().isEmpty)
        let complete = try makeRecording(roots)
        let interrupted = try makeRecording(roots, finalized: false)
        #expect(try await repository.review(complete).status == "Finalized")
        #expect(try await repository.review(interrupted).status == "Interrupted")
        let chunk = roots.rawRoot.appendingPathComponent(complete.uuidString).appendingPathComponent("chunk-1-0.bin")
        try Data("corrupt".utf8).write(to: chunk)
        let damaged = try await repository.review(complete)
        #expect(damaged.report.status == .corrupt)
        #expect(damaged.streams.first?.count == 3)
        #expect(!damaged.receiptVerified)
    }

    @Test func observedStatisticsExcludePause() async throws {
        let roots = try paths(); defer { cleanup(roots) }
        let id = try makeRecording(roots)
        let review = try await RecordingLibraryRepository(paths: roots).review(id)
        #expect(review.segments.count == 2)
        #expect(review.streams[0].count == 6)
        #expect(review.streams[1].count == 0)
        #expect(review.bytes > 0)
        #expect(abs((review.streams[0].segments[0].rate ?? 0) - 6.6666666667) < 0.001)
        #expect(abs((review.streams[0].segments[1].maximumInterval ?? 0) - 0.2) < 0.00001)
        #expect(review.streams[0].segments.allSatisfy { ($0.maximumInterval ?? 999) < 1 })
    }

    @Test func appendEditUnmatchedAndRawImmutability() async throws {
        let roots = try paths(); defer { cleanup(roots) }
        let id = try makeRecording(roots)
        let before = try rawSnapshot(roots, id: id)
        let repository = RecordingLibraryRepository(paths: roots)
        var draft = RecordingLabelDraft(); draft.category = .cleanContact; draft.note = "Owner felt a clean contact"
        let first = try await repository.saveLabel(recordingID: id, draft: draft)
        let attempt = try #require(first.latestLabels.first)
        #expect(attempt.startTimestamp == nil && attempt.clockDomainID == nil)
        #expect(attempt.author == .ownerSelf && attempt.category == .cleanContact)
        draft.attemptID = attempt.attemptID; draft.category = .uncertain; draft.confidence = .low
        let edited = try await repository.saveLabel(recordingID: id, draft: draft)
        #expect(edited.labels.count == 2 && edited.latestLabels.count == 1)
        #expect(edited.latestLabels[0].revision == 2 && edited.latestLabels[0].ordinal == 1)
        #expect(edited.labels[0].category == .cleanContact)
        #expect(try rawSnapshot(roots, id: id) == before)
        #expect(try SessionAnnotationsStore(root: roots.notesRoot).loadLabels(recordingID: id) == edited.labels)
    }

    @Test func explicitClockMatchAndRejectedAmbiguousIntervals() async throws {
        let roots = try paths(); defer { cleanup(roots) }
        let id = try makeRecording(roots)
        let repository = RecordingLibraryRepository(paths: roots)
        var valid = RecordingLabelDraft(); valid.relativeStart = "0.1"; valid.relativeEnd = "0.4"
        let matched = try await repository.saveLabel(recordingID: id, draft: valid)
        #expect(matched.latestLabels[0].startTimestamp == 100.1)
        #expect(matched.latestLabels[0].endTimestamp == 100.4)
        #expect(matched.latestLabels[0].clockDomainID == matched.report.metadata?.clock.domainID)
        for (start, end) in [("0.2", "10.2"), ("-1", "0.2"), ("nan", "1"), ("0.2", ""), ("0.4", "0.1"), ("10", "999")] {
            var draft = RecordingLabelDraft(); draft.relativeStart = start; draft.relativeEnd = end
            await #expect(throws: (any Error).self) { try await repository.saveLabel(recordingID: id, draft: draft) }
        }
        var tooLong = RecordingLabelDraft(); tooLong.note = String(repeating: "é", count: 513)
        await #expect(throws: (any Error).self) { try await repository.saveLabel(recordingID: id, draft: tooLong) }
        #expect(try await repository.review(id).labels.count == 1)
    }

    @Test func exportPreservesHistoryAndDeletionRequiresConfirmation() async throws {
        let roots = try paths(); defer { cleanup(roots) }
        let destination = try paths(); defer { cleanup(destination) }
        let id = try makeRecording(roots)
        let repository = RecordingLibraryRepository(paths: roots)
        var draft = RecordingLabelDraft()
        let first = try await repository.saveLabel(recordingID: id, draft: draft)
        draft.attemptID = first.latestLabels[0].attemptID; draft.category = .mishit
        let revised = try await repository.saveLabel(recordingID: id, draft: draft)
        let exported = try await repository.export(id)
        let receipt = try RecordingArchive.importBundle(from: exported, rawRoot: destination.rawRoot, notesRoot: destination.notesRoot)
        #expect(receipt.recordingID == id)
        #expect(try SessionAnnotationsStore(root: destination.notesRoot).loadLabels(recordingID: id) == revised.labels)
        #expect(try rawSnapshot(roots, id: id) == rawSnapshot(destination, id: id))
        let model = RecordingLibraryModel(paths: roots, activateConnectivity: false)
        #expect(await model.confirmDeletion(id) == false)
        model.requestDeletion(id); model.cancelDeletion()
        #expect(await model.confirmDeletion(id) == false)
        #expect(FileManager.default.fileExists(atPath: roots.rawRoot.appendingPathComponent(id.uuidString).path))
        model.requestDeletion(id)
        #expect(await model.confirmDeletion(UUID()) == false)
        #expect(await model.confirmDeletion(id))
        #expect(!FileManager.default.fileExists(atPath: roots.rawRoot.appendingPathComponent(id.uuidString).path))
        #expect(!FileManager.default.fileExists(atPath: roots.notesRoot.appendingPathComponent(id.uuidString).path))
        #expect(FileManager.default.fileExists(atPath: exported.path))
        #expect(try RecordingStore.inspect(root: destination.rawRoot, recordingID: id).status == .finalized)
    }

    @Test func defaultAppContainerCanWriteInspectAndAnnotate() throws {
        // App-host execution exercises the real sandbox. Only this unique synthetic UUID is removed.
        let roots = try RecordingPaths()
        let id = try makeRecording(roots)
        defer {
            try? FileManager.default.removeItem(at: roots.rawRoot.appendingPathComponent(id.uuidString))
            try? FileManager.default.removeItem(at: roots.notesRoot.appendingPathComponent(id.uuidString))
        }
        let report = try RecordingStore.inspect(root: roots.rawRoot, recordingID: id)
        #expect(report.status == .finalized)
        #expect(report.chunks.reduce(0) { $0 + $1.sampleCount } == 6)
        let timeline = try SessionAnnotationsStore(root: roots.notesRoot).loadTimeline(recordingID: id)
        #expect(timeline?.recordingID == id && timeline?.events.count == 6)
    }
}
