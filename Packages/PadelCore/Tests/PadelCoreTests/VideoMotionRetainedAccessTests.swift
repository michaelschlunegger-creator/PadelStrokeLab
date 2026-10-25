import Foundation
import Testing
@testable import PadelCore

@Suite struct VideoMotionRetainedAccessTests {
    private func snapshot(_ owner: OwnerPracticeIdentity?, admissionBlocked: Bool = false,
                          motionBlocked: Bool = false, heartRateBlocked: Bool = false) -> OwnerChannelSnapshot {
        OwnerChannelSnapshot(storeInstanceID: UUID(), authority: owner, acknowledged: nil, latest: nil,
            retainedTransitionCount: 0, journalByteCount: 0, pending: nil, phonePractice: nil,
            unqueuedRestriction: .none, admissionBlocked: admissionBlocked,
            motionAccessBlocked: motionBlocked, heartRateAccessBlocked: heartRateBlocked)
    }
    private func annotation(_ binding: VideoMotionBinding) throws -> VideoMotionAnnotation {
        try VideoMotionAnnotation(binding: binding, stroke: .forehand, contact: .clean,
                                  changedAtUnixSeconds: 1_800_000_050)
    }
    private func binding(for owner: OwnerPracticeIdentity) throws -> VideoMotionBinding {
        let original = try videoTestBinding()
        return try VideoMotionBinding(sessionID: original.sessionID, recordingID: original.recordingID,
            preparation: OwnerPreparation(authority: owner, practiceID: original.practiceID, draft: original.preparation.draft),
            createdAtUnixSeconds: original.createdAtUnixSeconds, appBuild: original.appBuild)
    }

    @Test func genuineEndAdvanceAndHeartRateChangePermitRetainedLabelsButNotLivePublication() throws {
        let original = try ownerTestIdentity(), capture = try videoTestBinding()
        let end = try OwnerAuthorityMutation.retirePractice(from: original, practiceID: capture.practiceID, mutationID: UUID())
        let advance = try OwnerAuthorityMutation.advance(from: original, mutationID: UUID())
        let heartRate = try OwnerAuthorityMutation.heartRate(from: original, allowed: false,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_020)
        for mutation in [end, advance, heartRate] {
            let fixture = try RecordingDirectoryFixture(), store = try VideoMotionStore(base: fixture.root)
            defer { store.close() }
            let reserved = try store.create(capture, authority: original), closed = try reserved.next(retention: .closed)
            try store.publish(closed, expectedDigest: reserved.digest, authority: original)
            let originalBytes = try closed.encoded(), advanced = try mutation.resolve(from: original)
            // Admission/replay restrictions and HR choice govern new capture, not motion/video labels.
            let current = snapshot(advanced, admissionBlocked: true, heartRateBlocked: true)
            #expect(try store.readRetained(capture, current: current) == closed)
            let labelled = try closed.next(annotations: [annotation(capture)])
            #expect(throws: (any Error).self) {
                try store.publish(labelled, expectedDigest: closed.digest, authority: advanced)
            }
            #expect(throws: (any Error).self) { try store.create(videoTestBinding(), authority: advanced) }
            try store.publishRetained(labelled, expectedDigest: closed.digest, current: current)
            #expect(try store.readRetained(capture, current: current) == labelled)
            let historical = try store.sessionDirectoryURL(capture).appendingPathComponent("revision-000002.json")
            #expect(try Data(contentsOf: historical) == originalBytes)
        }
    }

    @Test func withdrawalReconsentAndLocalMotionFencesCannotReopenOldEvidence() throws {
        let fixture = try RecordingDirectoryFixture(), capture = try videoTestBinding(), original = try ownerTestIdentity()
        let store = try VideoMotionStore(base: fixture.root); defer { store.close() }
        let initial = try store.create(capture, authority: original), edited = try initial.next(annotations: [annotation(capture)])
        let withdrawn = try OwnerAuthorityMutation.withdraw(from: original, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_800_000_020).resolve(from: original)
        let reconsented = try OwnerAuthorityMutation.reconsent(from: withdrawn, includesHeartRate: false,
            acknowledgesWithdrawal: true, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_030).resolve(from: withdrawn)
        #expect(reconsented.isCollectionAllowed && reconsented.withdrawalBarrier != original.withdrawalBarrier)
        for denied in [snapshot(nil), snapshot(withdrawn), snapshot(reconsented), snapshot(original, motionBlocked: true)] {
            #expect(throws: (any Error).self) { try store.readRetained(capture, current: denied) }
            #expect(throws: (any Error).self) {
                try store.publishRetained(edited, expectedDigest: initial.digest, current: denied)
            }
        }
        #expect(try store.read(capture) == initial)
    }

    @Test func foreignOwnerInstallationsAndEarlierAuthorityCannotAuthorizeRetainedAccess() throws {
        let original = try ownerTestIdentity()
        let later = try OwnerAuthorityMutation.heartRate(from: original, allowed: false, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_800_000_020).resolve(from: original)
        let capture = try binding(for: later), fixture = try RecordingDirectoryFixture()
        let store = try VideoMotionStore(base: fixture.root); defer { store.close() }
        let initial = try store.create(capture, authority: later), edited = try initial.next(annotations: [annotation(capture)])
        let revisionOnly = try original.advancingRevision(expectedRevision: 1).advancingRevision(expectedRevision: 2)
        var owners = [original, revisionOnly]
        for (owner, phone, watch) in [(UUID(), ownerTestPhone, ownerTestWatch),
                                      (ownerTestSubject, UUID(), ownerTestWatch), (ownerTestSubject, ownerTestPhone, UUID())] {
            owners.append(try OwnerPracticeIdentity.enrolled(ownerID: owner, phoneInstallationEpoch: phone,
                watchInstallationEpoch: watch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
                includesHeartRate: true, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000,
                policyDigest: OwnerPracticePolicy.digest))
        }
        for owner in owners {
            #expect(throws: (any Error).self) { try store.readRetained(capture, current: snapshot(owner)) }
            #expect(throws: (any Error).self) {
                try store.publishRetained(edited, expectedDigest: initial.digest, current: snapshot(owner))
            }
        }
        #expect(try store.readRetained(capture, current: snapshot(later)) == initial)
    }

    @Test func retainedUpdatesPreserveCompareAndPublishAndDeletionTombstones() throws {
        let fixture = try RecordingDirectoryFixture(), capture = try videoTestBinding(), original = try ownerTestIdentity()
        let store = try VideoMotionStore(base: fixture.root); defer { store.close() }
        let initial = try store.create(capture, authority: original)
        let advanced = try OwnerAuthorityMutation.retirePractice(from: original, practiceID: capture.practiceID,
            mutationID: UUID()).resolve(from: original), current = snapshot(advanced)
        let edited = try initial.next(annotations: [annotation(capture)])
        try store.publishRetained(edited, expectedDigest: initial.digest, current: current)
        #expect(throws: (any Error).self) {
            try store.publishRetained(initial.next(retention: .closed), expectedDigest: initial.digest, current: current)
        }
        try store.retirePractice(capture, authority: advanced, operationID: UUID())
        #expect(throws: (any Error).self) { try store.readRetained(capture, current: current) }
        #expect(throws: (any Error).self) {
            try store.publishRetained(edited.next(retention: .closed), expectedDigest: edited.digest, current: current)
        }
    }

    @Test func realPendingHeartRateRestrictionAllowsLabelsButPendingWithdrawalImmediatelyBlocksThem() throws {
        let phoneRoot = try RecordingDirectoryFixture(), watchRoot = try RecordingDirectoryFixture()
        let phone = try PracticeSetupChannel(base: phoneRoot.root, localInstallationEpoch: ownerTestPhone,
            device: .phone, intent: .createNew)
        let watch = try PracticeSetupChannel(base: watchRoot.root, localInstallationEpoch: ownerTestWatch,
            device: .watch, intent: .createNew)
        let original = try ownerTestIdentity()
        try phone.request(.enrollment(original))
        let enrolled = try watch.sequence(phone.dispatchPending())
        try watch.acknowledge(phone.mirror(enrolled))
        let capture = try videoTestBinding(), store = try VideoMotionStore(base: phoneRoot.root)
        defer { store.close() }
        let initial = try store.create(capture, authority: original)
        try phone.request(.heartRate(from: original, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_020))
        let heartRateOnly = try phone.readSnapshot()
        #expect(heartRateOnly.admissionBlocked && heartRateOnly.heartRateAccessBlocked && !heartRateOnly.motionAccessBlocked)
        #expect(try store.readRetained(capture, current: heartRateOnly) == initial)
        let edited = try initial.next(annotations: [annotation(capture)])
        try store.publishRetained(edited, expectedDigest: initial.digest, current: heartRateOnly)
        try phone.cancelPending()
        try phone.request(.withdraw(from: original, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_030))
        let pendingWithdrawal = try phone.readSnapshot()
        #expect(pendingWithdrawal.authority == original && pendingWithdrawal.motionAccessBlocked)
        #expect(throws: (any Error).self) { try store.readRetained(capture, current: pendingWithdrawal) }
        #expect(throws: (any Error).self) {
            try store.publishRetained(edited.next(retention: .closed), expectedDigest: edited.digest, current: pendingWithdrawal)
        }
        #expect(try store.read(capture) == edited)
    }
}
