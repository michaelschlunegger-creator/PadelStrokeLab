import Darwin
import Foundation
import Testing
@testable import PadelCore

private enum OwnerStoreInjectedFailure: Error { case boundary }

private func ownerStore(_ base: URL, intent: OwnerPracticeStoreIntent = .createNew) throws -> OwnerPracticeStore {
    try OwnerPracticeStore(base: base, localInstallationEpoch: ownerTestWatch, device: .watch, intent: intent)
}

private func ownerStoreBinding(authority: OwnerPracticeIdentity, recordingID: UUID = recordingTestID,
                               practiceID: UUID = ownerTestPractice) throws -> OwnerContextBinding {
    let bytes = try ownerTestRaw()
    let changed = Data(String(decoding: bytes, as: UTF8.self)
        .replacingOccurrences(of: recordingTestID.uuidString, with: recordingID.uuidString).utf8)
    return try OwnerRecordingContext.bind(rawMetadataBytes: changed, authority: authority,
        practiceID: practiceID, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
}

@Suite struct OwnerPracticeStoreTests {
    @Test func freshNamespaceHasNoAuthorityAndEnrollmentSurvivesReopen() throws {
        let fixture = try RecordingDirectoryFixture()
        do {
            let store = try ownerStore(fixture.root)
            #expect(store.snapshot.authority == nil)
            #expect(store.snapshot.localInstallationEpoch == ownerTestWatch)
            try store.enroll(ownerTestIdentity())
            #expect(try store.snapshot.authority == ownerTestIdentity())
            #expect(throws: (any Error).self) { try store.enroll(ownerTestIdentity()) }
        }
        do {
            let reopened = try ownerStore(fixture.root, intent: .openExisting)
            #expect(try reopened.snapshot.authority == ownerTestIdentity())
        }
        #expect(throws: (any Error).self) {
            try OwnerPracticeStore(base: fixture.root, localInstallationEpoch: UUID(), device: .watch, intent: .openExisting)
        }
        #expect(throws: (any Error).self) {
            try OwnerPracticeStore(base: fixture.root, localInstallationEpoch: ownerTestWatch, device: .phone, intent: .openExisting)
        }
        #expect(try ownerStore(fixture.root, intent: .openExisting).snapshot.authority == ownerTestIdentity())
    }

    @Test func publicationReceiptSeparatesNewFromExistingAndRechecksCurrentConsent() throws {
        let fixture = try RecordingDirectoryFixture()
        let owner = try ownerTestIdentity(), binding = try ownerStoreBinding(authority: owner)
        var first: OwnerContextPublication!
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(owner)
            first = try store.publish(binding, expectedRevision: 1)
            #expect(first.disposition == .newlyPublished && first.validatedRevision == 1)
            #expect(first.recordingID == recordingTestID)
            let repeatReceipt = try store.publish(binding, expectedRevision: 1)
            #expect(repeatReceipt.disposition == .alreadyExisting)
            #expect(repeatReceipt.contextSHA256 == first.contextSHA256)
            #expect(try store.inspectContext(recordingID: recordingTestID) == .valid(binding.context))
            let withdrawn = try store.apply(OwnerConsentDecision.withdraw(for: owner, decisionID: UUID(),
                confirmedAtUnixSeconds: 1_799_999_000))
            #expect(!withdrawn.isCollectionAllowed)
            #expect(throws: (any Error).self) { try store.publish(binding, expectedRevision: 1) }
        }
        let reopened = try ownerStore(fixture.root, intent: .openExisting)
        #expect(reopened.snapshot.authority?.isCollectionAllowed == false)
        #expect(throws: (any Error).self) { try reopened.publish(binding, expectedRevision: 1) }
        #expect(try reopened.inspectContext(recordingID: recordingTestID) == .valid(binding.context))
    }

    @Test func staleBindingAndConflictingContextNeverReplaceOriginal() throws {
        let fixture = try RecordingDirectoryFixture(), store = try ownerStore(fixture.root)
        let owner = try ownerTestIdentity(), original = try ownerStoreBinding(authority: owner)
        try store.enroll(owner)
        _ = try store.publish(original, expectedRevision: 1)
        let alternate = try ownerStoreBinding(authority: owner, practiceID: UUID())
        #expect(throws: (any Error).self) { try store.publish(alternate, expectedRevision: 1) }
        let advanced = try store.advanceAuthority(expectedRevision: 1)
        #expect(advanced.revision == 2)
        #expect(throws: (any Error).self) { try store.publish(original, expectedRevision: 2) }
        #expect(try store.inspectContext(recordingID: recordingTestID) == .valid(original.context))
    }

    @Test(arguments: [OwnerPracticeStoreStage.stateTemporarySynced, .statePublished, .stateDirectorySynced])
    func failedAuthorityWritePoisonsOwnerAndReopenReconcilesActualBytes(stage: OwnerPracticeStoreStage) throws {
        let fixture = try RecordingDirectoryFixture(), original = try ownerTestIdentity()
        let decision = try OwnerConsentDecision.withdraw(for: original, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_700_000_000)
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(original)
            store.writeFault = { if $0 == stage { throw OwnerStoreInjectedFailure.boundary } }
            #expect(throws: OwnerStoreInjectedFailure.boundary) { try store.apply(decision) }
            #expect(store.snapshot.authority == original)
            #expect(throws: (any Error).self) { try store.advanceAuthority(expectedRevision: 1) }
        }
        let reopened = try ownerStore(fixture.root, intent: .openExisting)
        #expect(reopened.snapshot.authority?.isCollectionAllowed == (stage == .stateTemporarySynced))
        let applied = try reopened.apply(decision)
        #expect(!applied.isCollectionAllowed)
    }

    @Test(arguments: [OwnerPracticeStoreStage.contextReserved, .metadataPublished,
        .contextTemporarySynced, .contextPublished, .contextDirectorySynced])
    func failedContextIDCanNeverBecomeFreshCapture(stage: OwnerPracticeStoreStage) throws {
        let fixture = try RecordingDirectoryFixture(), owner = try ownerTestIdentity()
        let binding = try ownerStoreBinding(authority: owner)
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(owner)
            store.writeFault = { if $0 == stage { throw OwnerStoreInjectedFailure.boundary } }
            #expect(throws: OwnerStoreInjectedFailure.boundary) { try store.publish(binding, expectedRevision: 1) }
            #expect(throws: (any Error).self) { try store.publish(binding, expectedRevision: 1) }
        }
        let reopened = try ownerStore(fixture.root, intent: .openExisting)
        if stage == .contextPublished || stage == .contextDirectorySynced {
            #expect(try reopened.publish(binding, expectedRevision: 1).disposition == .alreadyExisting)
        } else {
            #expect(try reopened.inspectContext(recordingID: recordingTestID) == .partial)
            #expect(throws: (any Error).self) { try reopened.publish(binding, expectedRevision: 1) }
        }
    }

    @Test func tombstonesAreDurableIdempotentAndBlockRecordingOrPracticeReplay() throws {
        let fixture = try RecordingDirectoryFixture(), owner = try ownerTestIdentity()
        var next: OwnerPracticeIdentity!
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(owner)
            next = try store.retire(scope: .recording, id: recordingTestID, expectedRevision: 1)
            #expect(next.revision == 2)
            #expect(try store.retire(scope: .recording, id: recordingTestID, expectedRevision: 2) == next)
            #expect(try store.hasReplayGuard(scope: .recording, id: recordingTestID))
            #expect(throws: (any Error).self) { try store.publish(ownerStoreBinding(authority: next), expectedRevision: 2) }
            next = try store.retire(scope: .practice, id: ownerTestPractice, expectedRevision: 2)
            #expect(throws: (any Error).self) {
                try store.publish(ownerStoreBinding(authority: next, recordingID: UUID()), expectedRevision: 3)
            }
        }
        let reopened = try ownerStore(fixture.root, intent: .openExisting)
        #expect(try reopened.hasReplayGuard(scope: .recording, id: recordingTestID))
        #expect(try reopened.hasReplayGuard(scope: .practice, id: ownerTestPractice))
    }

    @Test func missingCorruptOrUninitializedStateIsNeverSilentlyReplaced() throws {
        for corrupt in [Data(), Data("{}".utf8), Data(repeating: 32, count: 16_385)] {
            let fixture = try RecordingDirectoryFixture()
            var file: URL!
            do { file = try ownerStore(fixture.root).directoryURL.appendingPathComponent("state.json") }
            try corrupt.write(to: file)
            #expect(throws: (any Error).self) { try ownerStore(fixture.root, intent: .openExisting) }
            #expect(try Data(contentsOf: file) == corrupt)
        }
        let empty = try RecordingDirectoryFixture()
        try FileManager.default.createDirectory(at: empty.root.appendingPathComponent("OwnerPractice-v1"),
            withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try ownerStore(empty.root) }
    }

    @Test func noFollowCompetingOwnerAndHardLinksFailWithoutTouchingOutsideData() throws {
        let fixture = try RecordingDirectoryFixture(), outside = try RecordingDirectoryFixture()
        let link = fixture.root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside.root)
        #expect(throws: (any Error).self) { try ownerStore(link) }
        let store = try ownerStore(fixture.root)
        #expect(throws: OwnerPracticeStorageError.busy) { try ownerStore(fixture.root, intent: .openExisting) }
        let state = store.directoryURL.appendingPathComponent("state.json")
        try FileManager.default.linkItem(at: state, to: outside.root.appendingPathComponent("hardlink"))
        #expect(throws: (any Error).self) { try store.enroll(ownerTestIdentity()) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.root.path) == ["hardlink"])
    }

    @Test(arguments: [".lock", "state.json", "contexts", "guards"])
    func deletedOrReplacedOwnershipEntriesPoisonLiveOwner(name: String) throws {
        let fixture = try RecordingDirectoryFixture(), store = try ownerStore(fixture.root)
        let entry = store.directoryURL.appendingPathComponent(name)
        try FileManager.default.removeItem(at: entry)
        #expect(throws: (any Error).self) { try store.enroll(ownerTestIdentity()) }
        #expect(store.snapshot.authority == nil)
    }

    @Test func baseAndNamespaceReplacementAreDetected() throws {
        let parent = try RecordingDirectoryFixture()
        let base = parent.root.appendingPathComponent("app")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
        let store = try ownerStore(base)
        try FileManager.default.moveItem(at: base, to: parent.root.appendingPathComponent("old-app"))
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try store.enroll(ownerTestIdentity()) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: base.path).isEmpty)
        let other = try RecordingDirectoryFixture(), second = try ownerStore(other.root)
        try FileManager.default.moveItem(at: second.directoryURL,
            to: other.root.appendingPathComponent("old-owner"))
        #expect(throws: (any Error).self) { try second.enroll(ownerTestIdentity()) }
    }

    @Test func rawSiblingBytesRemainUntouched() throws {
        let fixture = try RecordingDirectoryFixture()
        let raw = fixture.root.appendingPathComponent("Recordings")
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: false)
        let sample = raw.appendingPathComponent("retained")
        let bytes = Data([0, 255, 10, 1]); try bytes.write(to: sample)
        let store = try ownerStore(fixture.root)
        try store.enroll(ownerTestIdentity())
        _ = try store.publish(ownerStoreBinding(authority: ownerTestIdentity()), expectedRevision: 1)
        #expect(try Data(contentsOf: sample) == bytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: raw.path) == ["retained"])
        #expect(throws: (any Error).self) { try ownerStore(raw) }
    }

    @Test(arguments: [false, true])
    func removingReservedContextNeverMakesRecordingFresh(failed: Bool) throws {
        let fixture = try RecordingDirectoryFixture(), owner = try ownerTestIdentity()
        let binding = try ownerStoreBinding(authority: owner)
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(owner)
            if failed {
                store.writeFault = { if $0 == .contextReserved { throw OwnerStoreInjectedFailure.boundary } }
                #expect(throws: OwnerStoreInjectedFailure.boundary) { try store.publish(binding, expectedRevision: 1) }
            } else {
                _ = try store.publish(binding, expectedRevision: 1)
            }
            try FileManager.default.removeItem(at: store.directoryURL
                .appendingPathComponent("contexts/" + recordingTestID.uuidString))
            #expect(throws: (any Error).self) { try store.inspectContext(recordingID: recordingTestID) }
        }
        #expect(throws: (any Error).self) { try ownerStore(fixture.root, intent: .openExisting) }
    }

    @Test(arguments: [OwnerReplayScope.recording, .practice])
    func missingCommittedGuardFailsClosedLiveAndOnReopen(scope: OwnerReplayScope) throws {
        let fixture = try RecordingDirectoryFixture(), id = UUID()
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(ownerTestIdentity())
            _ = try store.retire(scope: scope, id: id, expectedRevision: 1)
            try FileManager.default.removeItem(at: store.directoryURL
                .appendingPathComponent("guards/" + scope.rawValue + "-" + id.uuidString))
            #expect(throws: (any Error).self) { try store.hasReplayGuard(scope: scope, id: id) }
        }
        #expect(throws: (any Error).self) { try ownerStore(fixture.root, intent: .openExisting) }
    }

    @Test func explicitCreationCannotResetAnExistingInstallation() throws {
        let fixture = try RecordingDirectoryFixture()
        #expect(throws: (any Error).self) { try ownerStore(fixture.root, intent: .openExisting) }
        var namespace: URL!
        do {
            let store = try ownerStore(fixture.root)
            namespace = store.directoryURL
            try store.enroll(ownerTestIdentity())
            #expect(throws: (any Error).self) { try ownerStore(fixture.root, intent: .createNew) }
        }
        try FileManager.default.removeItem(at: namespace)
        #expect(throws: (any Error).self) { try ownerStore(fixture.root, intent: .openExisting) }
        #expect(!FileManager.default.fileExists(atPath: namespace.path))
    }

    @Test(arguments: [OwnerPracticeStoreStage.stateTemporarySynced, .statePublished, .stateDirectorySynced,
        .reservationCommitted, .reservationStubSynced])
    func interruptedReservationRecoversOnlyAnUnusableStub(stage: OwnerPracticeStoreStage) throws {
        for guardOnly in [false, true] {
            let fixture = try RecordingDirectoryFixture(), owner = try ownerTestIdentity()
            let binding = try ownerStoreBinding(authority: owner)
            do {
                let store = try ownerStore(fixture.root)
                try store.enroll(owner)
                store.writeFault = { if $0 == stage { throw OwnerStoreInjectedFailure.boundary } }
                #expect(throws: OwnerStoreInjectedFailure.boundary) {
                    if guardOnly { _ = try store.retire(scope: .recording, id: recordingTestID, expectedRevision: 1) }
                    else { _ = try store.publish(binding, expectedRevision: 1) }
                }
                #expect(throws: OwnerPracticeStorageError.poisoned) { try store.inspectContext(recordingID: recordingTestID) }
            }
            let reopened = try ownerStore(fixture.root, intent: .openExisting)
            #expect(reopened.snapshot.authority == owner)
            if guardOnly {
                #expect(try reopened.hasReplayGuard(scope: .recording, id: recordingTestID))
                #expect(try reopened.retire(scope: .recording, id: recordingTestID, expectedRevision: 1) == owner)
            } else {
                #expect(try reopened.inspectContext(recordingID: recordingTestID) == .partial)
            }
            #expect(throws: (any Error).self) { try reopened.publish(binding, expectedRevision: 1) }
        }
    }

    @Test(arguments: [OwnerPracticeStoreStage.guardReserved, .guardDirectorySynced])
    func interruptedGuardRetainsProtectionBeforeAuthorityAcknowledgement(stage: OwnerPracticeStoreStage) throws {
        let fixture = try RecordingDirectoryFixture(), owner = try ownerTestIdentity()
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(owner)
            store.writeFault = { if $0 == stage { throw OwnerStoreInjectedFailure.boundary } }
            #expect(throws: OwnerStoreInjectedFailure.boundary) {
                try store.retire(scope: .practice, id: ownerTestPractice, expectedRevision: 1)
            }
        }
        let reopened = try ownerStore(fixture.root, intent: .openExisting)
        #expect(reopened.snapshot.authority == owner)
        #expect(try reopened.hasReplayGuard(scope: .practice, id: ownerTestPractice))
        #expect(try reopened.retire(scope: .practice, id: ownerTestPractice, expectedRevision: 1) == owner)
        #expect(throws: (any Error).self) { try reopened.publish(ownerStoreBinding(authority: owner), expectedRevision: 1) }
    }

    @Test func pendingReservationCannotLegitimizePayloadOrLinks() throws {
        for contents in ["payload", "symlink", "hardlink"] {
            let fixture = try RecordingDirectoryFixture(), outside = try RecordingDirectoryFixture()
            let target = outside.root.appendingPathComponent("sentinel")
            let bytes = Data("retained".utf8); try bytes.write(to: target)
            var namespace: URL!
            do {
                let store = try ownerStore(fixture.root)
                namespace = store.directoryURL
                try store.enroll(ownerTestIdentity())
                store.writeFault = { if $0 == .reservationCommitted { throw OwnerStoreInjectedFailure.boundary } }
                #expect(throws: OwnerStoreInjectedFailure.boundary) {
                    if contents == "hardlink" { _ = try store.retire(scope: .recording, id: recordingTestID, expectedRevision: 1) }
                    else { _ = try store.publish(ownerStoreBinding(authority: ownerTestIdentity()), expectedRevision: 1) }
                }
            }
            if contents == "hardlink" {
                try FileManager.default.linkItem(at: target, to: namespace.appendingPathComponent("guards/recording-" + recordingTestID.uuidString))
            } else {
                let directory = namespace.appendingPathComponent("contexts/" + recordingTestID.uuidString)
                if contents == "symlink" {
                    try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: outside.root)
                } else {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
                    try bytes.write(to: directory.appendingPathComponent("context.json"))
                }
            }
            #expect(throws: (any Error).self) { try ownerStore(fixture.root, intent: .openExisting) }
            #expect(try Data(contentsOf: target) == bytes)
        }
    }

    @Test(arguments: [false, true])
    func fullBoundedInventoryKeepsFailedFinalSlotAndNeverEvicts(guards: Bool) throws {
        let fixture = try RecordingDirectoryFixture(), owner = try ownerTestIdentity()
        let maximum = guards ? OwnerPracticeStore.maximumReplayGuards : OwnerPracticeStore.maximumContexts
        let first = UUID(), failed = UUID()
        var authority = owner
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(owner)
            for index in 0..<(maximum - 1) {
                let id = index == 0 ? first : UUID()
                if guards {
                    authority = try store.retire(scope: .recording, id: id, expectedRevision: authority.revision)
                } else {
                    _ = try store.publish(ownerStoreBinding(authority: owner, recordingID: id), expectedRevision: 1)
                }
            }
            store.writeFault = {
                if $0 == (guards ? .guardReserved : .contextReserved) { throw OwnerStoreInjectedFailure.boundary }
            }
            #expect(throws: OwnerStoreInjectedFailure.boundary) {
                if guards { _ = try store.retire(scope: .recording, id: failed, expectedRevision: authority.revision) }
                else { _ = try store.publish(ownerStoreBinding(authority: owner, recordingID: failed), expectedRevision: 1) }
            }
        }
        let reopened = try ownerStore(fixture.root, intent: .openExisting)
        if guards {
            #expect(try reopened.hasReplayGuard(scope: .recording, id: first))
            #expect(try reopened.hasReplayGuard(scope: .recording, id: failed))
            #expect(throws: OwnerPracticeStorageError.capacity) {
                try reopened.retire(scope: .practice, id: UUID(), expectedRevision: authority.revision)
            }
        } else {
            #expect(try reopened.inspectContext(recordingID: failed) == .partial)
            #expect(try reopened.publish(ownerStoreBinding(authority: owner, recordingID: first), expectedRevision: 1)
                .disposition == .alreadyExisting)
            #expect(throws: OwnerPracticeStorageError.capacity) {
                try reopened.publish(ownerStoreBinding(authority: owner, recordingID: UUID()), expectedRevision: 1)
            }
        }
        let stateBytes = try Data(contentsOf: reopened.directoryURL.appendingPathComponent("state.json"))
        #expect(stateBytes.count <= 16_384)
    }

    @Test func maximumConsentHistoryRemainsDurableInsideStateBound() throws {
        let fixture = try RecordingDirectoryFixture()
        var owner = try ownerTestIdentity()
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(owner)
            for _ in 1..<126 {
                owner = try store.apply(OwnerConsentDecision.heartRate(for: owner, allowed: true,
                    decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000, policyDigest: OwnerPracticePolicy.digest))
            }
            owner = try store.apply(OwnerConsentDecision.heartRate(for: owner, allowed: false,
                decisionID: UUID(), confirmedAtUnixSeconds: 1_700_000_000, policyDigest: OwnerPracticePolicy.digest))
            owner = try store.apply(OwnerConsentDecision.withdraw(for: owner, decisionID: UUID(),
                confirmedAtUnixSeconds: 1_600_000_000))
            #expect(owner.consentGeneration == 128 && !owner.isCollectionAllowed)
            #expect(try Data(contentsOf: store.directoryURL.appendingPathComponent("state.json")).count <= 16_384)
        }
        let reopened = try ownerStore(fixture.root, intent: .openExisting)
        #expect(reopened.snapshot.authority == owner)
    }

    @Test(arguments: [OwnerPracticeStoreStage.stateTemporarySynced, .statePublished, .stateDirectorySynced])
    func reservationFinalizationFailureRetainsItsID(stage: OwnerPracticeStoreStage) throws {
        let fixture = try RecordingDirectoryFixture(), owner = try ownerTestIdentity()
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(owner)
            var hits = 0
            store.writeFault = {
                if $0 == stage {
                    hits += 1
                    if hits == 2 { throw OwnerStoreInjectedFailure.boundary }
                }
            }
            #expect(throws: OwnerStoreInjectedFailure.boundary) {
                try store.publish(ownerStoreBinding(authority: owner), expectedRevision: 1)
            }
        }
        let reopened = try ownerStore(fixture.root, intent: .openExisting)
        #expect(try reopened.inspectContext(recordingID: recordingTestID) == .partial)
        #expect(throws: (any Error).self) { try reopened.publish(ownerStoreBinding(authority: owner), expectedRevision: 1) }
    }

    @Test(arguments: ["symlink", "hardlink", "oversized", "truncated", "unknown"])
    func corruptedContextRemainsUnreadableAndCannotBeRepublished(change: String) throws {
        let fixture = try RecordingDirectoryFixture(), outside = try RecordingDirectoryFixture()
        let owner = try ownerTestIdentity(), binding = try ownerStoreBinding(authority: owner)
        let store = try ownerStore(fixture.root)
        try store.enroll(owner)
        _ = try store.publish(binding, expectedRevision: 1)
        let directory = store.directoryURL.appendingPathComponent("contexts/" + recordingTestID.uuidString)
        let file = directory.appendingPathComponent("context.json")
        let sentinel = outside.root.appendingPathComponent("retained")
        let retained = Data("outside data".utf8); try retained.write(to: sentinel)
        switch change {
        case "symlink":
            try FileManager.default.removeItem(at: file)
            try FileManager.default.createSymbolicLink(at: file, withDestinationURL: sentinel)
        case "hardlink":
            try FileManager.default.linkItem(at: file, to: outside.root.appendingPathComponent("linked-context"))
        case "oversized": try Data(repeating: 0, count: OwnerRecordingContext.maximumBytes + 1).write(to: file)
        case "truncated": try Data("{".utf8).write(to: file)
        default: try Data().write(to: directory.appendingPathComponent("unknown"))
        }
        #expect(try store.inspectContext(recordingID: recordingTestID) == .corrupt)
        #expect(throws: OwnerPracticeStorageError.failedRecordingID) { try store.publish(binding, expectedRevision: 1) }
        #expect(try Data(contentsOf: sentinel) == retained)
    }

    @Test func malformedUncommittedStateIsPreservedWithoutOpeningAuthority() throws {
        let fixture = try RecordingDirectoryFixture()
        var temporary: URL!
        do {
            let store = try ownerStore(fixture.root)
            try store.enroll(ownerTestIdentity())
            temporary = store.directoryURL.appendingPathComponent("state.pending")
        }
        let bytes = Data("incomplete candidate".utf8)
        try bytes.write(to: temporary)
        #expect(throws: (any Error).self) { try ownerStore(fixture.root, intent: .openExisting) }
        #expect(try Data(contentsOf: temporary) == bytes)
    }
}
