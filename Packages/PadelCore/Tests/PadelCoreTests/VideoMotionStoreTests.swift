import Darwin
import Foundation
import Testing
@testable import PadelCore

func videoTestBinding(sessionID: UUID = UUID(), recordingID: UUID = UUID(),
                      practiceID: UUID = ownerTestPractice) throws -> VideoMotionBinding {
    let draft = try PracticeSetupDraft(originInstallationEpoch: ownerTestPhone,
        preparationID: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!, revision: 1,
        preferences: .init(currentRacketArm: .right, usualHand: .right, intendedDrill: .otherUnclassified,
                           captureMode: .videoMotionMixedReferenceV1))
    return try VideoMotionBinding(sessionID: sessionID, recordingID: recordingID,
        preparation: OwnerPreparation(authority: ownerTestIdentity(), practiceID: practiceID, draft: draft),
        createdAtUnixSeconds: 1_800_000_000, appBuild: "synthetic-8")
}

@Suite struct VideoMotionStoreTests {
    @Test func exactBindingAndCanonicalRevisionSurviveReopen() throws {
        let fixture = try RecordingDirectoryFixture(), binding = try videoTestBinding()
        let store = try VideoMotionStore(base: fixture.root)
        let initial = try store.create(binding, authority: ownerTestIdentity())
        #expect(initial.revision == 1 && initial.previousDigest == nil)
        #expect(initial.retention == .reserved && initial.annotations.isEmpty)
        #expect(try VideoMotionSession.decode(initial.encoded()) == initial)
        let partial = try initial.next(retention: .partial, interruptionReason: "Phone stopped unexpectedly.")
        try store.publish(partial, expectedDigest: initial.digest, authority: ownerTestIdentity())
        #expect(try store.read(binding) == partial)
        store.close()
        let reopened = try VideoMotionStore(base: fixture.root)
        defer { reopened.close() }
        #expect(try reopened.read(binding) == partial)
        #expect(try FileManager.default.contentsOfDirectory(atPath: reopened.sessionDirectoryURL(binding).path)
            .filter { $0.hasPrefix("revision-") }.count == 2)
    }

    @Test func compareAndPublishRejectsLostUpdatesAndChangedBinding() throws {
        let fixture = try RecordingDirectoryFixture(), binding = try videoTestBinding()
        let store = try VideoMotionStore(base: fixture.root)
        defer { store.close() }
        let initial = try store.create(binding, authority: ownerTestIdentity())
        let first = try initial.next(retention: .partial, interruptionReason: "Interrupted")
        try store.publish(first, expectedDigest: initial.digest, authority: ownerTestIdentity())
        #expect(throws: (any Error).self) {
            try store.publish(initial.next(retention: .closed), expectedDigest: initial.digest,
                              authority: ownerTestIdentity())
        }
        let foreign = try videoTestBinding(sessionID: binding.sessionID, recordingID: UUID())
        #expect(throws: (any Error).self) { try store.read(foreign) }
        #expect(throws: (any Error).self) { try store.create(foreign, authority: ownerTestIdentity()) }
        let reusedRecording = try videoTestBinding(recordingID: binding.recordingID)
        #expect(throws: (any Error).self) { try store.create(reusedRecording, authority: ownerTestIdentity()) }
        let changed = try ownerTestIdentity().advancingRevision(expectedRevision: 1)
        #expect(throws: (any Error).self) {
            try store.publish(first.next(retention: .closed), expectedDigest: first.digest, authority: changed)
        }
        #expect(try store.read(binding) == first)
    }

    @Test func namespaceHasOneWriterAndDetectsDetachedLease() throws {
        let fixture = try RecordingDirectoryFixture()
        let store = try VideoMotionStore(base: fixture.root)
        defer { store.close() }
        #expect(throws: (any Error).self) { try VideoMotionStore(base: fixture.root) }
        let binding = try videoTestBinding()
        _ = try store.create(binding, authority: ownerTestIdentity())
        let lease = store.directoryURL.appendingPathComponent(".lease")
        try FileManager.default.moveItem(at: lease, to: store.directoryURL.appendingPathComponent("detached-lease"))
        try Data("replacement".utf8).write(to: lease)
        #expect(throws: (any Error).self) { try store.read(binding) }
        #expect(throws: (any Error).self) { try VideoMotionStore(base: fixture.root) }
    }

    @Test(arguments: [VideoMotionStoreStage.temporarySynced, .revisionPublished, .directorySynced])
    func interruptedPublicationRetainsOnlyCompleteCanonicalRevisions(stage: VideoMotionStoreStage) throws {
        struct InjectedFailure: Error {}
        let fixture = try RecordingDirectoryFixture(), binding = try videoTestBinding()
        let store = try VideoMotionStore(base: fixture.root)
        let initial = try store.create(binding, authority: ownerTestIdentity())
        let next = try initial.next(retention: .partial, interruptionReason: "Retained partial capture")
        store.failureInjector = { if $0 == stage { throw InjectedFailure() } }
        #expect(throws: (any Error).self) {
            try store.publish(next, expectedDigest: initial.digest, authority: ownerTestIdentity())
        }
        #expect(throws: (any Error).self) { try store.read(binding) }
        store.close()
        let reopened = try VideoMotionStore(base: fixture.root)
        defer { reopened.close() }
        let recovered = try reopened.read(binding)
        #expect(recovered == (stage == .temporarySynced ? initial : next))
        // Temporary bytes are retained for explicit later cleanup, never silently promoted.
        let files = try FileManager.default.contentsOfDirectory(atPath: reopened.sessionDirectoryURL(binding).path)
        if stage == .temporarySynced { #expect(files.contains { $0.hasPrefix(".pending-") }) }
    }

    @Test func corruptUnknownOrNoncanonicalHistoryIsNotSkipped() throws {
        let fixture = try RecordingDirectoryFixture(), binding = try videoTestBinding()
        let store = try VideoMotionStore(base: fixture.root)
        let initial = try store.create(binding, authority: ownerTestIdentity())
        let file = try store.sessionDirectoryURL(binding).appendingPathComponent("revision-000001.json")
        store.close()
        let malformed = try ownerTestResealed(initial.encoded(), domain: "PSLVideoMotionSession1") {
            $0["schemaVersion"] = 99
        }
        for bytes in [malformed, Data([32]) + (try initial.encoded()),
                      Data(repeating: 32, count: VideoMotionSession.maximumBytes + 1)] {
            try bytes.write(to: file)
            let reopened = try VideoMotionStore(base: fixture.root)
            #expect(throws: (any Error).self) { try reopened.read(binding) }
            reopened.close()
        }
    }

    @Test func publicationNeverOverwritesARevisionThatAppearsAfterComparison() throws {
        let fixture = try RecordingDirectoryFixture(), binding = try videoTestBinding()
        let store = try VideoMotionStore(base: fixture.root)
        let initial = try store.create(binding, authority: ownerTestIdentity())
        let attempted = try initial.next(retention: .partial, interruptionReason: "Interrupted writer")
        let conflict = try initial.next(retention: .closed), conflictBytes = try conflict.encoded()
        let file = try store.sessionDirectoryURL(binding).appendingPathComponent("revision-000002.json")
        // A fault seam creates a conflicting filesystem entry after the production CAS read.
        // The publishing operation must preserve it and report failure, never replace it.
        store.failureInjector = { stage in
            if stage == .temporarySynced { try conflictBytes.write(to: file) }
        }
        #expect(throws: (any Error).self) {
            try store.publish(attempted, expectedDigest: initial.digest, authority: ownerTestIdentity())
        }
        #expect(try Data(contentsOf: file) == conflictBytes)
        store.close()
        let reopened = try VideoMotionStore(base: fixture.root)
        defer { reopened.close() }
        #expect(try reopened.read(binding) == conflict)
        let retained = try FileManager.default.contentsOfDirectory(atPath: reopened.sessionDirectoryURL(binding).path)
        #expect(retained.contains { $0.hasPrefix(".pending-") })
    }

    @Test func noFollowAndHardLinkChecksProtectNamespaceAndRevisions() throws {
        let fixture = try RecordingDirectoryFixture(), outside = try RecordingDirectoryFixture()
        let namespace = fixture.root.appendingPathComponent(VideoMotionStore.directoryName)
        try FileManager.default.createSymbolicLink(at: namespace, withDestinationURL: outside.root)
        #expect(throws: (any Error).self) { try VideoMotionStore(base: fixture.root) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.root.path).isEmpty)
        try FileManager.default.removeItem(at: namespace)
        // A failed bootstrap is fenced; use a clean fixture for the revision attack.
        let clean = try RecordingDirectoryFixture(), binding = try videoTestBinding()
        let store = try VideoMotionStore(base: clean.root)
        _ = try store.create(binding, authority: ownerTestIdentity())
        let file = try store.sessionDirectoryURL(binding).appendingPathComponent("revision-000001.json")
        try FileManager.default.linkItem(at: file, to: outside.root.appendingPathComponent("linked.json"))
        #expect(throws: (any Error).self) { try store.read(binding) }
        store.close()
    }

    @Test func sessionDirectoryCannotBeSubstitutedOrIdentityReused() throws {
        let fixture = try RecordingDirectoryFixture(), binding = try videoTestBinding()
        let store = try VideoMotionStore(base: fixture.root)
        _ = try store.create(binding, authority: ownerTestIdentity())
        let directory = try store.sessionDirectoryURL(binding)
        try FileManager.default.moveItem(at: directory, to: directory.appendingPathExtension("retained"))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try store.read(binding) }
        #expect(throws: (any Error).self) { try store.create(binding, authority: ownerTestIdentity()) }
        store.close()
    }

    @Test func practiceTombstoneBlocksLatePublicationAndNewSessionAfterReopen() throws {
        let fixture = try RecordingDirectoryFixture(), binding = try videoTestBinding()
        let store = try VideoMotionStore(base: fixture.root)
        let initial = try store.create(binding, authority: ownerTestIdentity())
        let operation = UUID()
        try store.retirePractice(binding, authority: ownerTestIdentity(), operationID: operation)
        try store.retirePractice(binding, authority: ownerTestIdentity(), operationID: operation)
        #expect(throws: (any Error).self) { try store.read(binding) }
        #expect(throws: (any Error).self) {
            try store.publish(initial.next(retention: .closed), expectedDigest: initial.digest,
                              authority: ownerTestIdentity())
        }
        store.close()
        let reopened = try VideoMotionStore(base: fixture.root)
        defer { reopened.close() }
        #expect(throws: (any Error).self) { try reopened.create(videoTestBinding(), authority: ownerTestIdentity()) }
        let otherPractice = try videoTestBinding(practiceID: UUID())
        #expect(try reopened.create(otherPractice, authority: ownerTestIdentity()).binding == otherPractice)
    }

    @Test func bindingRejectsNormalModeAndInvalidIdentityMetadata() throws {
        #expect(throws: (any Error).self) {
            try VideoMotionBinding(sessionID: UUID(), recordingID: recordingTestID,
                preparation: OwnerPreparation(authority: ownerTestIdentity(), practiceID: ownerTestPractice,
                    draft: ownerTestDraft()), createdAtUnixSeconds: 1, appBuild: "test")
        }
        let binding = try videoTestBinding()
        #expect(try VideoMotionBinding.decode(binding.encoded()) == binding)
        let unknown = try ownerTestResealed(binding.encoded(), domain: "PSLVideoMotionBinding1") {
            $0["schemaVersion"] = 99
        }
        #expect(throws: (any Error).self) { try VideoMotionBinding.decode(unknown) }
    }
}
