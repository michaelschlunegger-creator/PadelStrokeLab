import Darwin
import Foundation
import Testing
@testable import PadelCore

private struct ChannelFixture {
    let root: URL
    let phone: URL
    let watch: URL
    init() throws {
        root = URL(fileURLWithPath: "/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/O3b/Fixtures/" + UUID().uuidString)
        phone = root.appendingPathComponent("phone"); watch = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: phone, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: watch, withIntermediateDirectories: true)
    }
    func open(_ device: OwnerPracticeDevice, _ intent: OwnerPracticeStoreIntent) throws -> PracticeSetupChannel {
        try PracticeSetupChannel(base: device == .phone ? phone : watch,
            localInstallationEpoch: device == .phone ? ownerTestPhone : ownerTestWatch, device: device, intent: intent)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}

private enum ChannelTestFailure: Error { case injected }

// The accepted pre-O4q journal shape, used through the real canonical round-trip decoder.
private struct LegacyChannelJournal: Codable {
let version: Int
let localEpoch: UUID
let device: OwnerPracticeDevice
let anchor: Data?
let acknowledged: OwnerAuthorityAcknowledgement?
let entries: [LegacyChannelEntry]
let intent: LegacyChannelIntent?
let fence: OwnerLocalRestriction
}
private struct LegacyChannelEntry: Codable {
let transition: OwnerAuthorityTransition
let reserve: String?
}
private struct LegacyChannelIntent: Codable {
let mutation: OwnerAuthorityMutation
let dispatched: Bool
let originalDigest: String?
}
private extension ChannelFixture {
func limitedPhone(_ intent: OwnerPracticeStoreIntent, bytes: Int) throws -> PracticeSetupChannel {
try PracticeSetupChannel(base: phone, localInstallationEpoch: ownerTestPhone, device: .phone,
intent: intent, recoveryFault: nil, maximumJournalBytes: bytes)
}
var phoneJournal: URL { phone.appendingPathComponent(PracticeSetupChannel.directoryName).appendingPathComponent("journal.json") }
}

private func enrollChannels(_ phone: PracticeSetupChannel, _ watch: PracticeSetupChannel) throws {
    let command = try OwnerAuthorityMutation.enrollment(ownerTestIdentity())
    try phone.request(command)
    let sent = try phone.dispatchPending()
    let transition = try watch.sequence(sent)
    let ack = try phone.mirror(transition)
    try watch.acknowledge(ack)
}

@Suite struct PracticeSetupChannelTests {
    @Test func soleSequencerMirrorAckAndCleanReopen() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch!)
        #expect(try phone!.readSnapshot().authority == ownerTestIdentity())
        #expect(try watch!.readSnapshot().retainedTransitionCount == 0)
        #expect(throws: (any Error).self) { try phone!.sequence(.advance(from: ownerTestIdentity(), mutationID: UUID())) }
        #expect(throws: (any Error).self) { try watch!.request(.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 2)) }
        let command = try OwnerAuthorityMutation.advance(from: ownerTestIdentity(), mutationID: UUID())
        let next = try watch!.sequence(command)
        #expect(try watch!.sequence(command) == next)
        let ack = try phone!.mirror(next)
        #expect(try phone!.mirror(next) == ack)
        try watch!.acknowledge(ack)
        try watch!.acknowledge(ack)
        phone = nil; watch = nil
        phone = try f.open(.phone, .openExisting); watch = try f.open(.watch, .openExisting)
        #expect(try phone!.readSnapshot().authority == watch!.readSnapshot().authority)
        #expect(try watch!.readSnapshot().acknowledged?.sequence == 2)
    }

    @Test func offlineEndThenPendingWithdrawalConvergesThroughExactRevisionOnlyChain() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        let phone = try f.open(.phone, .createNew), watch = try f.open(.watch, .createNew)
        try enrollChannels(phone, watch)
        let original = try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 1)
        try phone.request(original)
        let end = try watch.sequence(.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: UUID()))
        _ = try phone.mirror(end)
        let sent = try phone.dispatchPending()
        #expect(sent.id == original.id)
        #expect(sent.beforeRevision == 2)
        let withdrawn = try watch.sequence(sent)
        let ack = try phone.mirror(withdrawn)
        try watch.acknowledge(ack)
        #expect(try phone.readSnapshot().authority == watch.readSnapshot().authority)
        #expect(try phone.readSnapshot().authority?.revision == 3)
        #expect(try phone.readSnapshot().pending == nil)
        #expect(try phone.readSnapshot().motionAccessBlocked)
    }

    @Test func conflictingRestrictionIsDurableLocalFenceAndNeverASecondQueuedIntent() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let grant = try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone!.request(grant); _ = try phone!.dispatchPending()
        let restriction = try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 3)
        #expect(throws: OwnerChannelError.intentOutstanding) { try phone!.request(restriction) }
        #expect(try phone!.readSnapshot().pending?.mutation.id == grant.id)
        #expect(try phone!.readSnapshot().unqueuedRestriction == .all)
        #expect(try phone!.readSnapshot().motionAccessBlocked)
        phone = nil; phone = try f.open(.phone, .openExisting)
        #expect(throws: OwnerChannelError.sentIntentCannotCancel) { try phone!.cancelPending() }
        _ = try phone!.mirror(watch.sequence(grant))
        #expect(try phone!.readSnapshot().pending == nil)
        #expect(try phone!.readSnapshot().unqueuedRestriction == .all)
        #expect(try phone!.readSnapshot().motionAccessBlocked)
        let current = try #require(phone!.readSnapshot().authority)
        let actualWithdrawal = try OwnerAuthorityMutation.withdraw(from: current, decisionID: UUID(), confirmedAtUnixSeconds: 4)
        try phone!.request(actualWithdrawal)
        _ = try phone!.mirror(watch.sequence(phone!.dispatchPending()))
        #expect(try phone!.readSnapshot().unqueuedRestriction == .none)
        #expect(try phone!.readSnapshot().authority?.isCollectionAllowed == false)
    }

    @Test func unsentCancellationAndSentLostReplyHaveDifferentDurableOutcomes() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let command = try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone!.request(command); try phone!.cancelPending()
        #expect(try phone!.readSnapshot().pending == nil)
        try phone!.request(command); let sent = try phone!.dispatchPending()
        let applied = try watch.sequence(sent)
        phone = nil; phone = try f.open(.phone, .openExisting)
        #expect(try phone!.readSnapshot().heartRateAccessBlocked)
        #expect(try phone!.dispatchPending() == sent)
        #expect(throws: OwnerChannelError.sentIntentCannotCancel) { try phone!.cancelPending() }
        #expect(try watch.sequence(sent) == applied)
        _ = try phone!.mirror(applied)
        #expect(try phone!.readSnapshot().pending == nil)
    }

    @Test func endAckDoesNotClearRefusedGlobalWithdrawal() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let end = try OwnerAuthorityMutation.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: UUID())
        try phone!.request(end); _ = try phone!.dispatchPending()
        #expect(throws: OwnerChannelError.intentOutstanding) {
            try phone!.request(.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 2))
        }
        _ = try phone!.mirror(watch.sequence(end))
        #expect(try phone!.readSnapshot().pending == nil)
        #expect(try phone!.readSnapshot().authority?.isCollectionAllowed == true)
        #expect(try phone!.readSnapshot().unqueuedRestriction == .all)
        #expect(try phone!.readSnapshot().motionAccessBlocked)
        phone = nil; phone = try f.open(.phone, .openExisting)
        #expect(try phone!.readSnapshot().motionAccessBlocked)
    }

    @Test func unrelatedAcknowledgementCannotReleaseHeartRateFence() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let grant = try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone!.request(grant); _ = try phone!.dispatchPending()
        #expect(throws: OwnerChannelError.intentOutstanding) {
            try phone!.request(.heartRate(from: ownerTestIdentity(), allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 3))
        }
        _ = try phone!.mirror(watch.sequence(grant))
        phone = nil; phone = try f.open(.phone, .openExisting)
        let fenced = try phone!.readSnapshot()
        #expect(fenced.pending == nil)
        #expect(fenced.authority?.heartRateConsent == true)
        #expect(fenced.unqueuedRestriction == .heartRate)
        #expect(fenced.admissionBlocked && fenced.heartRateAccessBlocked)
        let disable = try OwnerAuthorityMutation.heartRate(from: #require(fenced.authority), allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 4)
        try phone!.request(disable)
        _ = try phone!.mirror(watch.sequence(phone!.dispatchPending()))
        #expect(try phone!.readSnapshot().unqueuedRestriction == .none)
        #expect(try !phone!.readSnapshot().admissionBlocked)
        #expect(try phone!.readSnapshot().heartRateAccessBlocked)
    }

    @Test func refusedEndCreatesNoPrivacyFenceOrSecondIntent() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let grant = try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone!.request(grant); _ = try phone!.dispatchPending()
        #expect(throws: OwnerChannelError.intentOutstanding) {
            try phone!.request(.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: UUID()))
        }
        #expect(try phone!.readSnapshot().pending?.mutation == grant)
        #expect(try phone!.readSnapshot().admissionBlocked)
        #expect(try phone!.readSnapshot().unqueuedRestriction == .none)
        _ = try phone!.mirror(watch.sequence(grant))
        phone = nil; phone = try f.open(.phone, .openExisting)
        #expect(try phone!.readSnapshot().pending == nil)
        #expect(try phone!.readSnapshot().unqueuedRestriction == .none)
        #expect(try !phone!.readSnapshot().admissionBlocked)
        #expect(try !watch.hasReplayGuard(scope: .practice, id: ownerTestPractice))
    }

    @Test func retryOriginalRestrictionAfterVerifiedRebaseIsIdempotent() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        let phone = try f.open(.phone, .createNew), watch = try f.open(.watch, .createNew)
        try enrollChannels(phone, watch)
        let original = try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone.request(original); _ = try phone.dispatchPending()
        _ = try phone.mirror(watch.sequence(.advance(from: ownerTestIdentity(), mutationID: UUID())))
        let before = try phone.readSnapshot()
        try phone.request(original)
        #expect(try phone.readSnapshot() == before)
        #expect(try phone.dispatchPending().beforeRevision == 2)
    }

    @Test func staleGrantNeedsExplicitResolutionAndCannotRebaseAcrossWithdrawal() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        let phone = try f.open(.phone, .createNew), watch = try f.open(.watch, .createNew)
        try enrollChannels(phone, watch)
        let grant = try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone.request(grant); _ = try phone.dispatchPending()
        let withdrawal = try watch.sequence(.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 3))
        _ = try phone.mirror(withdrawal)
        #expect(try phone.readSnapshot().pending?.requiresResolution == true)
        #expect(throws: (any Error).self) { try phone.dispatchPending() }
        #expect(throws: OwnerChannelError.sentIntentCannotCancel) { try phone.cancelPending() }
        try phone.resolveObsoleteIntent(replacement: nil)
        #expect(try phone.readSnapshot().pending == nil)
        #expect(try phone.readSnapshot().motionAccessBlocked)
        let current = try #require(phone.readSnapshot().authority)
        let renewal = try OwnerAuthorityMutation.reconsent(from: current, includesHeartRate: false,
            acknowledgesWithdrawal: true, decisionID: UUID(), confirmedAtUnixSeconds: 4)
        try phone.request(renewal)
        _ = try phone.mirror(watch.sequence(phone.dispatchPending()))
        #expect(try phone.readSnapshot().authority?.isCollectionAllowed == true)
    }

    @Test func reorderedConflictingForeignTransitionsAndAcksNeverAdvanceOrPrune() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        let phone = try f.open(.phone, .createNew), watch = try f.open(.watch, .createNew)
        try enrollChannels(phone, watch)
        let second = try watch.sequence(.advance(from: ownerTestIdentity(), mutationID: UUID()))
        let third = try watch.sequence(.advance(from: second.mutation.resolve(from: ownerTestIdentity()), mutationID: UUID()))
        #expect(throws: (any Error).self) { try phone.mirror(third) }
        let conflicting = try OwnerAuthorityTransition(sequence: 2, mutation: .advance(from: ownerTestIdentity(), mutationID: UUID()))
        #expect(throws: (any Error).self) { try watch.acknowledge(OwnerAuthorityAcknowledgement(transition: conflicting)) }
        #expect(try watch.readSnapshot().retainedTransitionCount == 2)
        _ = try phone.mirror(second)
        #expect(throws: (any Error).self) { try phone.mirror(conflicting) }
        let ack = try phone.mirror(third); try watch.acknowledge(ack)
        #expect(try watch.readSnapshot().retainedTransitionCount == 0)
        let cursor = try OwnerAuthorityReplayCursor(ownerID: ownerTestSubject, phoneEpoch: ownerTestPhone, watchEpoch: ownerTestWatch, after: ack)
        #expect(try watch.nextTransition(after: cursor) == nil)
        #expect(throws: (any Error).self) { try watch.nextTransition(after: OwnerAuthorityReplayCursor(ownerID: ownerTestSubject, phoneEpoch: ownerTestPhone, watchEpoch: UUID())) }
        #expect(throws: (any Error).self) { try watch.nextTransition(after: OwnerAuthorityReplayCursor(ownerID: ownerTestSubject, phoneEpoch: ownerTestPhone, watchEpoch: ownerTestWatch)) }
    }

    @Test(arguments: [OwnerChannelStage.temporarySynced, .published, .directorySynced, .commandCommitted, .ownerApplied])
    func crashBoundaryNeverAcknowledgesOrGuessesAuthority(stage: OwnerChannelStage) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
        _ = try watch!.sequence(.enrollment(ownerTestIdentity()))
        let command = try OwnerAuthorityMutation.advance(from: ownerTestIdentity(), mutationID: UUID())
        watch!.writeFault = { if $0 == stage { throw ChannelTestFailure.injected } }
        #expect(throws: (any Error).self) { try watch!.sequence(command) }
        #expect(watch!.isPoisoned)
        #expect(throws: (any Error).self) { try watch!.readSnapshot() }
        watch = nil
        if stage == .temporarySynced {
            #expect(throws: (any Error).self) { try f.open(.watch, .openExisting) }
        } else {
            watch = try f.open(.watch, .openExisting)
            #expect(try watch!.readSnapshot().authority?.revision == 2)
            #expect(try watch!.sequence(command).sequence == 2)
        }
    }

    @Test func guardPresentBeforeAuthorityRecoversExactlyOnceButFreshRepeatedEndDoesNot() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
        _ = try watch!.sequence(.enrollment(ownerTestIdentity()))
        let command = try OwnerAuthorityMutation.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: UUID())
        watch!.ownerWriteFault = { if $0 == .guardDirectorySynced { throw ChannelTestFailure.injected } }
        #expect(throws: (any Error).self) { try watch!.sequence(command) }
        watch = nil; watch = try f.open(.watch, .openExisting)
        let before = try watch!.readSnapshot()
        #expect(before.authority?.revision == 2)
        #expect(try watch!.hasReplayGuard(scope: .practice, id: ownerTestPractice))
        #expect(try watch!.sequence(command).sequence == 2)
        let freshRepeated = try OwnerAuthorityMutation.retirePractice(from: #require(before.authority), practiceID: ownerTestPractice, mutationID: UUID())
        #expect(throws: (any Error).self) { try watch!.sequence(freshRepeated) }
        #expect(try watch!.readSnapshot() == before)
        watch = nil; watch = try f.open(.watch, .openExisting)
        #expect(try watch!.readSnapshot().authority?.revision == 2)
    }

    @Test(arguments: [["end", "disable", "withdraw"], ["disable", "end", "withdraw"], ["disable", "withdraw", "end"]])
    func exact256BoundaryKeepsThreeDistinctReserves(order: [String]) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        let watch = try f.open(.watch, .createNew)
        _ = try watch.sequence(.enrollment(ownerTestIdentity()))
        for _ in 1..<253 {
            _ = try watch.sequence(.advance(from: #require(watch.readSnapshot().authority), mutationID: UUID()))
        }
        #expect(try watch.readSnapshot().retainedTransitionCount == 253)
        #expect(try watch.readSnapshot().admissionBlocked)
        #expect(throws: (any Error).self) { try watch.sequence(.advance(from: #require(watch.readSnapshot().authority), mutationID: UUID())) }
        for operation in order {
            let current = try #require(watch.readSnapshot().authority)
            let command: OwnerAuthorityMutation
            switch operation {
            case "end": command = try .retirePractice(from: current, practiceID: ownerTestPractice, mutationID: UUID())
            case "disable": command = try .heartRate(from: current, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 3)
            default: command = try .withdraw(from: current, decisionID: UUID(), confirmedAtUnixSeconds: 2)
            }
            _ = try watch.sequence(command)
            if operation == "disable" {
                #expect(throws: (any Error).self) {
                    try watch.sequence(.heartRate(from: #require(watch.readSnapshot().authority), allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 3))
                }
            }
        }
        #expect(try watch.readSnapshot().retainedTransitionCount == 256)
        #expect(try watch.readSnapshot().journalByteCount <= PracticeSetupChannel.maximumBytes)
        #expect(throws: (any Error).self) { try watch.sequence(.advance(from: #require(watch.readSnapshot().authority), mutationID: UUID())) }
    }

    @Test func locksMissingCorruptAndUncommittedNamespacesFailClosed() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
        _ = try watch!.sequence(.enrollment(ownerTestIdentity()))
        #expect(throws: (any Error).self) { try f.open(.watch, .openExisting) }
        #expect(throws: (any Error).self) { try f.open(.watch, .createNew) }
        watch = nil
        let journal = f.watch.appendingPathComponent(PracticeSetupChannel.directoryName).appendingPathComponent("journal.json")
        let original = try Data(contentsOf: journal)
        for corrupted in [Data(), Data("{}".utf8), Data(repeating: 32, count: PracticeSetupChannel.maximumBytes + 1), original + Data(" ".utf8)] {
            try corrupted.write(to: journal)
            #expect(throws: (any Error).self) { try f.open(.watch, .openExisting) }
        }
        try FileManager.default.removeItem(at: journal)
        #expect(throws: (any Error).self) { try f.open(.watch, .openExisting) }
    }

    @Test(arguments: ["temporary", "committed"])
    func replacementDuringPublicationCannotOverwriteAnotherFile(target: String) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        let watch = try f.open(.watch, .createNew)
        _ = try watch.sequence(.enrollment(ownerTestIdentity()))
        let directory = f.watch.appendingPathComponent(PracticeSetupChannel.directoryName)
        let committed = directory.appendingPathComponent("journal.json")
        let original = try Data(contentsOf: committed)
        watch.writeFault = { stage in
            guard stage == .temporarySynced else { return }
            let url = directory.appendingPathComponent(target == "temporary" ? "journal.pending" : "journal.json")
            let bytes = target == "temporary" ? try Data(contentsOf: url) : Data("replaced externally".utf8)
            try FileManager.default.removeItem(at: url)
            try bytes.write(to: url)
        }
        #expect(throws: (any Error).self) { try watch.sequence(.advance(from: ownerTestIdentity(), mutationID: UUID())) }
        #expect(watch.isPoisoned)
        #expect(try Data(contentsOf: committed) == (target == "temporary" ? original : Data("replaced externally".utf8)))
    }

    @Test func pendingEnrollmentMustMatchLocalEpochEvenBeforeAnyAuthorityExists() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        try phone!.request(.enrollment(ownerTestIdentity())); phone = nil
        let foreign = try OwnerPracticeIdentity.enrolled(ownerID: ownerTestSubject,
            phoneInstallationEpoch: UUID(), watchInstallationEpoch: ownerTestWatch,
            attestsWatchAccountOwner: true, acceptsMotionStudy: true, includesHeartRate: true,
            decisionID: ownerTestDecision, confirmedAtUnixSeconds: 1_800_000_000, policyDigest: OwnerPracticePolicy.digest)
        let mutation = try JSONSerialization.jsonObject(with: PracticeSetupJSON.encode(OwnerAuthorityMutation.enrollment(foreign)))
        let url = f.phone.appendingPathComponent(PracticeSetupChannel.directoryName).appendingPathComponent("journal.json")
        try ownerTestResealed(Data(contentsOf: url), domain: "PSLOwnerChannel2") {
            $0["intent"] = ["mutation": mutation, "dispatched": false]
        }.write(to: url)
        #expect(throws: (any Error).self) { try f.open(.phone, .openExisting) }
    }

    @Test(arguments: [OwnerChannelStage.temporarySynced, .published, .directorySynced],
          ["request", "dispatch", "fence", "prune", "mirror", "checkpoint"])
    func durableMutationFailuresRemainExplicitAcrossReopen(stage: OwnerChannelStage, operation: String) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch!)
        let grant = try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        if operation == "dispatch" || operation == "fence" { try phone!.request(grant) }
        if operation == "fence" { _ = try phone!.dispatchPending() }
        let transition = operation == "prune" || operation == "mirror" || operation == "checkpoint" ? try watch!.sequence(grant) : nil
        var hits = 0
        let fault: (OwnerChannelStage) throws -> Void = {
            if $0 == stage { hits += 1; if hits == (operation == "checkpoint" ? 2 : 1) { throw ChannelTestFailure.injected } }
        }
        if operation == "prune" { watch!.writeFault = fault } else { phone!.writeFault = fault }
        #expect(throws: (any Error).self) {
            switch operation {
            case "request": try phone!.request(grant)
            case "dispatch": _ = try phone!.dispatchPending()
            case "fence": try phone!.request(.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 3))
            case "prune": try watch!.acknowledge(OwnerAuthorityAcknowledgement(transition: #require(transition)))
            default: _ = try phone!.mirror(#require(transition))
            }
        }
        #expect(operation == "prune" ? watch!.isPoisoned : phone!.isPoisoned)
        phone = nil; watch = nil
        let device: OwnerPracticeDevice = operation == "prune" ? .watch : .phone
        if stage == .temporarySynced {
            #expect(throws: (any Error).self) { try f.open(device, .openExisting) }
        } else {
            let reopened = try f.open(device, .openExisting), state = try reopened.readSnapshot()
            switch operation {
            case "request": #expect(state.pending?.mutation == grant && state.pending?.dispatched == false)
            case "dispatch": #expect(state.pending?.mutation == grant && state.pending?.dispatched == true)
            case "fence": #expect(state.pending?.mutation == grant && state.unqueuedRestriction == .all && state.motionAccessBlocked)
            case "prune": #expect(state.retainedTransitionCount == 0 && state.acknowledged?.sequence == 2)
            default: #expect(state.authority?.revision == 2 && state.latest?.sequence == 2 && state.retainedTransitionCount == 0)
            }
        }
    }

    @Test(arguments: [OwnerChannelStage.commandCommitted, .ownerApplied])
    func phoneApplicationFailureReplaysOnlyCommittedTransition(stage: OwnerChannelStage) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let transition = try watch.sequence(.advance(from: ownerTestIdentity(), mutationID: UUID()))
        phone!.writeFault = { if $0 == stage { throw ChannelTestFailure.injected } }
        #expect(throws: (any Error).self) { try phone!.mirror(transition) }
        phone = nil; phone = try f.open(.phone, .openExisting)
        #expect(try phone!.readSnapshot().authority?.revision == 2)
        #expect(try phone!.mirror(transition).matches(transition))
    }

    @Test(arguments: ["role", "epoch", "sequence", "digest", "duplicate", "reserve"])
    func resealedSemanticCorruptionCannotReconstructAuthority(change: String) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
        _ = try watch!.sequence(.enrollment(ownerTestIdentity()))
        _ = try watch!.sequence(.advance(from: ownerTestIdentity(), mutationID: UUID())); watch = nil
        let url = f.watch.appendingPathComponent(PracticeSetupChannel.directoryName).appendingPathComponent("journal.json")
        let changed = try ownerTestResealed(Data(contentsOf: url), domain: "PSLOwnerChannel2") { body in
            if change == "role" { body["device"] = "phone" }
            else if change == "epoch" { body["localEpoch"] = UUID().uuidString }
            else {
                var entries = body["entries"] as! [[String: Any]]
                if change == "duplicate" { entries.append(entries[1]) }
                else if change == "reserve" { entries[1]["reserve"] = "disable" }
                else {
                    var transition = entries[1]["transition"] as! [String: Any]
                    if change == "sequence" { transition["sequence"] = 9 }
                    else {
                        var mutation = transition["mutation"] as! [String: Any]
                        mutation["afterDigest"] = String(repeating: "0", count: 64); transition["mutation"] = mutation
                    }
                    entries[1]["transition"] = transition
                }
                body["entries"] = entries
            }
        }
        try changed.write(to: url)
        #expect(throws: (any Error).self) { try f.open(.watch, .openExisting) }
    }

    @Test(arguments: ["symlink", "hardlink", "detached-root", "detached-base", "lock"])
    func journalFilesystemIdentityCannotChange(change: String) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
        _ = try watch!.sequence(.enrollment(ownerTestIdentity()))
        let root = f.watch.appendingPathComponent(PracticeSetupChannel.directoryName), url = root.appendingPathComponent("journal.json")
        let outside = f.root.appendingPathComponent("outside")
        if change == "symlink" || change == "hardlink" {
            try FileManager.default.moveItem(at: url, to: outside)
            if change == "symlink" { try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outside) }
            else { try FileManager.default.linkItem(at: outside, to: url) }
        } else if change == "lock" {
            try FileManager.default.removeItem(at: root.appendingPathComponent(".lock"))
            try Data().write(to: root.appendingPathComponent(".lock"))
        } else {
            let target = change == "detached-root" ? root : f.watch
            try FileManager.default.moveItem(at: target, to: outside)
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        }
        #expect(throws: (any Error).self) { try watch!.readSnapshot() }
        #expect(watch!.isPoisoned)
        watch = nil
        if change != "lock" { #expect(throws: (any Error).self) { try f.open(.watch, .openExisting) } }
    }

    @Test(arguments: [OwnerChannelStage.recoveryFileSynced, .recoveryDirectorySynced])
    func reopenSynchronizesJournalBeforeRecoveringO2(stage: OwnerChannelStage) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
        _ = try watch!.sequence(.enrollment(ownerTestIdentity()))
        let command = try OwnerAuthorityMutation.advance(from: ownerTestIdentity(), mutationID: UUID())
        watch!.writeFault = { if $0 == .published { throw ChannelTestFailure.injected } }
        #expect(throws: (any Error).self) { try watch!.sequence(command) }; watch = nil
        var boundaries: [OwnerChannelStage] = []
        #expect(throws: (any Error).self) {
            try PracticeSetupChannel(base: f.watch, localInstallationEpoch: ownerTestWatch, device: .watch,
                intent: .openExisting, recoveryFault: {
                    boundaries.append($0); if $0 == stage { throw ChannelTestFailure.injected }
                })
        }
        #expect(boundaries == (stage == .recoveryFileSynced ? [.recoveryFileSynced] : [.recoveryFileSynced, .recoveryDirectorySynced]))
        do {
            let store = try OwnerPracticeStore(base: f.watch, localInstallationEpoch: ownerTestWatch, device: .watch, intent: .openExisting)
            #expect(store.snapshot.authority?.revision == 1)
        }
        watch = try f.open(.watch, .openExisting)
        #expect(try watch!.sequence(command).sequence == 2)
        #expect(try watch!.readSnapshot().authority?.revision == 2)
    }

    @Test(arguments: [true, false], [true, false])
    func explicitSatisfiedFenceResolutionRequiresExactReconciledDenial(full: Bool, obsolete: Bool) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let grant = try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone!.request(grant); _ = try phone!.dispatchPending()
        let refused = full ? try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 3)
            : try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 3)
        #expect(throws: OwnerChannelError.intentOutstanding) { try phone!.request(refused) }
        if !obsolete { _ = try phone!.mirror(watch.sequence(grant)) }
        let before = try #require(phone!.readSnapshot().latest)
        #expect(throws: (any Error).self) { try phone!.resolveSatisfiedRestriction(expected: before) }
        let current = try #require(watch.readSnapshot().authority)
        let actual = full ? try OwnerAuthorityMutation.withdraw(from: current, decisionID: UUID(), confirmedAtUnixSeconds: 4)
            : try OwnerAuthorityMutation.heartRate(from: current, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 4)
        _ = try phone!.mirror(watch.sequence(actual))
        let exact = try #require(phone!.readSnapshot().latest)
        if obsolete {
            #expect(throws: (any Error).self) { try phone!.resolveSatisfiedRestriction(expected: exact) }
            try phone!.resolveObsoleteIntent(replacement: nil)
        }
        phone = nil; phone = try f.open(.phone, .openExisting)
        #expect(try phone!.readSnapshot().unqueuedRestriction == (full ? .all : .heartRate))
        #expect(throws: (any Error).self) { try phone!.resolveSatisfiedRestriction(expected: before) }
        #expect(throws: (any Error).self) { try watch.resolveSatisfiedRestriction(expected: exact) }
        try phone!.resolveSatisfiedRestriction(expected: exact)
        phone = nil; phone = try f.open(.phone, .openExisting)
        #expect(try phone!.readSnapshot().unqueuedRestriction == .none)
        #expect(try phone!.readSnapshot().heartRateAccessBlocked)
        #expect(try phone!.readSnapshot().motionAccessBlocked == full)
    }

    @Test func revisionLimitIndependentlyReservesEndDisableAndWithdrawal() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
        let enrolled = try watch!.sequence(.enrollment(ownerTestIdentity()))
        try watch!.acknowledge(OwnerAuthorityAcknowledgement(transition: enrolled)); watch = nil
        // A semantically valid synthetic near-limit anchor avoids trillions of unrelated advances.
        let before = try OwnerPracticeIdentity.decode(ownerTestResealed(ownerTestIdentity().encoded(), domain: "PSLOwnerIdentity1") {
            $0["revision"] = OwnerPracticeIdentity.maximumRevision - 4
        })
        let transition = try OwnerAuthorityTransition(sequence: before.revision + 1, mutation: .advance(from: before, mutationID: UUID()))
        let anchor = try transition.mutation.resolve(from: before)
        let ack = try JSONSerialization.jsonObject(with: PracticeSetupJSON.encode(OwnerAuthorityAcknowledgement(transition: transition)))
        let journalURL = f.watch.appendingPathComponent(PracticeSetupChannel.directoryName).appendingPathComponent("journal.json")
        let anchorBytes = try anchor.encoded()
        try ownerTestResealed(Data(contentsOf: journalURL), domain: "PSLOwnerChannel2") {
            $0["anchor"] = anchorBytes.base64EncodedString(); $0["acknowledged"] = ack
        }.write(to: journalURL)
        let ownerURL = f.watch.appendingPathComponent(OwnerPracticeStore.directoryName).appendingPathComponent("state.json")
        try ownerTestResealed(Data(contentsOf: ownerURL), domain: "PSLOwnerStore1") {
            $0["authorityBytes"] = anchorBytes.base64EncodedString()
        }.write(to: ownerURL)
        watch = try f.open(.watch, .openExisting)
        #expect(try watch!.readSnapshot().retainedTransitionCount == 0)
        #expect(try watch!.readSnapshot().admissionBlocked)
        #expect(throws: (any Error).self) { try watch!.sequence(.advance(from: anchor, mutationID: UUID())) }
        _ = try watch!.sequence(.retirePractice(from: anchor, practiceID: ownerTestPractice, mutationID: UUID()))
        _ = try watch!.sequence(.heartRate(from: #require(watch!.readSnapshot().authority), allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 2))
        _ = try watch!.sequence(.withdraw(from: #require(watch!.readSnapshot().authority), decisionID: UUID(), confirmedAtUnixSeconds: 3))
        #expect(try watch!.readSnapshot().authority?.revision == OwnerPracticeIdentity.maximumRevision)
        #expect(try watch!.readSnapshot().motionAccessBlocked)
        #expect(throws: (any Error).self) { try watch!.sequence(.advance(from: #require(watch!.readSnapshot().authority), mutationID: UUID())) }
    }

    @Test func contextWrapperSharesAuthorityAndPreservesRawLegacySiblings() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        let raw = f.watch.appendingPathComponent("Recordings"), legacy = f.watch.appendingPathComponent("legacy.json")
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: false)
        let rawFile = raw.appendingPathComponent("samples.bin"), bytes = Data([0, 255, 13, 17, 7])
        try bytes.write(to: rawFile); try bytes.write(to: legacy)
        let watch = try f.open(.watch, .createNew)
        _ = try watch.sequence(.enrollment(ownerTestIdentity()))
        let binding = try OwnerRecordingContext.bind(rawMetadataBytes: ownerTestRaw(), authority: ownerTestIdentity(),
            practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
        let published = try watch.publish(binding, expectedRevision: 1)
        #expect(published.validatedRevision == 1)
        _ = try watch.sequence(.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: UUID()))
        #expect(throws: (any Error).self) { try watch.publish(binding, expectedRevision: 1) }
        #expect(try watch.hasReplayGuard(scope: .practice, id: ownerTestPractice))
        #expect(try Data(contentsOf: rawFile) == bytes && Data(contentsOf: legacy) == bytes)
    }

    @Test func publicationMustMatchTheCurrentlyCheckedStoreInstanceAfterReopen() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
        _ = try watch!.sequence(.enrollment(ownerTestIdentity()))
        let binding = try OwnerRecordingContext.bind(rawMetadataBytes: ownerTestRaw(), authority: ownerTestIdentity(),
            practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
        let old = try watch!.publish(binding, expectedRevision: 1)
        #expect(try watch!.readSnapshot().storeInstanceID == old.storeInstanceID)
        watch = nil; watch = try f.open(.watch, .openExisting)
        let current = try watch!.readSnapshot()
        #expect(current.storeInstanceID != old.storeInstanceID)
        let checked = try watch!.publish(binding, expectedRevision: 1)
        #expect(checked.storeInstanceID == current.storeInstanceID)
        #expect(checked.disposition == .alreadyExisting)
    }

    @Test func contextPublicationPoisonPropagatesToChannel() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        let watch = try f.open(.watch, .createNew)
        _ = try watch.sequence(.enrollment(ownerTestIdentity()))
        let binding = try OwnerRecordingContext.bind(rawMetadataBytes: ownerTestRaw(), authority: ownerTestIdentity(),
            practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
        watch.ownerWriteFault = { if $0 == .contextReserved { throw ChannelTestFailure.injected } }
        #expect(throws: (any Error).self) { try watch.publish(binding, expectedRevision: 1) }
        #expect(watch.isPoisoned)
        #expect(throws: (any Error).self) { try watch.readSnapshot() }
    }

    @Test(arguments: [OwnerPracticeStoreStage.stateTemporarySynced, .statePublished, .stateDirectorySynced])
    func phoneO2InterruptedConsentApplyRecoversExactCommittedTransition(stage: OwnerPracticeStoreStage) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let withdrawal = try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone!.request(withdrawal); _ = try phone!.dispatchPending()
        let transition = try watch.sequence(withdrawal)
        phone!.ownerWriteFault = { if $0 == stage { throw ChannelTestFailure.injected } }
        #expect(throws: (any Error).self) { try phone!.mirror(transition) }
        #expect(phone!.isPoisoned)
        phone = nil; phone = try f.open(.phone, .openExisting)
        #expect(try phone!.readSnapshot().pending == nil)
        #expect(try phone!.readSnapshot().authority == watch.readSnapshot().authority)
        #expect(try phone!.mirror(transition).matches(transition))
    }

    @Test(arguments: [OwnerChannelStage.temporarySynced, .published, .directorySynced], ["cancel", "obsolete", "satisfied"])
    func explicitResolutionPublicationFailuresStayClosed(stage: OwnerChannelStage, operation: String) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let grant = try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone!.request(grant)
        if operation != "cancel" {
            _ = try phone!.dispatchPending()
            #expect(throws: OwnerChannelError.intentOutstanding) {
                try phone!.request(.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 3))
            }
            _ = try phone!.mirror(watch.sequence(.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 4)))
            if operation == "satisfied" { try phone!.resolveObsoleteIntent(replacement: nil) }
        }
        let exact = try #require(phone!.readSnapshot().latest)
        phone!.writeFault = { if $0 == stage { throw ChannelTestFailure.injected } }
        #expect(throws: (any Error).self) {
            if operation == "cancel" { try phone!.cancelPending() }
            else if operation == "obsolete" { try phone!.resolveObsoleteIntent(replacement: nil) }
            else { try phone!.resolveSatisfiedRestriction(expected: exact) }
        }
        #expect(phone!.isPoisoned); phone = nil
        if stage == .temporarySynced {
            #expect(throws: (any Error).self) { try f.open(.phone, .openExisting) }
        } else {
            phone = try f.open(.phone, .openExisting)
            let state = try phone!.readSnapshot()
            #expect(state.pending == nil)
            #expect(state.unqueuedRestriction == (operation == "obsolete" ? .all : .none))
            #expect(state.motionAccessBlocked == (operation != "cancel"))
        }
    }

    @Test(arguments: [true, false])
    func sentEnrollmentCanRetainAConflictingPrivacyFenceWithoutAnotherIntent(full: Bool) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        let enrollment = try OwnerAuthorityMutation.enrollment(ownerTestIdentity())
        try phone!.request(enrollment); _ = try phone!.dispatchPending()
        let restriction = full ? try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 2)
            : try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        #expect(throws: OwnerChannelError.intentOutstanding) { try phone!.request(restriction) }
        #expect(try phone!.readSnapshot().authority == nil)
        #expect(try phone!.readSnapshot().pending?.mutation == enrollment)
        #expect(try phone!.readSnapshot().pending?.dispatched == true)
        #expect(try phone!.readSnapshot().unqueuedRestriction == (full ? .all : .heartRate))
        phone = nil; phone = try f.open(.phone, .openExisting)
        _ = try phone!.mirror(watch.sequence(enrollment))
        phone = nil; phone = try f.open(.phone, .openExisting)
        #expect(try phone!.readSnapshot().authority?.heartRateConsent == true)
        #expect(try phone!.readSnapshot().pending == nil)
        #expect(try phone!.readSnapshot().unqueuedRestriction == (full ? .all : .heartRate))
        #expect(try phone!.readSnapshot().admissionBlocked)
        #expect(try phone!.readSnapshot().heartRateAccessBlocked)
        try phone!.request(restriction)
        _ = try phone!.mirror(watch.sequence(phone!.dispatchPending()))
        #expect(try phone!.readSnapshot().unqueuedRestriction == .none)
    }

    @Test func enrollmentProposedStateCannotAuthorizeOtherPeersOrUnsentConflicts() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        let phone = try f.open(.phone, .createNew)
        try phone.request(.enrollment(ownerTestIdentity()))
        let withdrawal = try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 2)
        #expect(throws: (any Error).self) { try phone.request(withdrawal) }
        #expect(try phone.readSnapshot().unqueuedRestriction == .none)
        _ = try phone.dispatchPending()
        let foreign = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: ownerTestPhone,
            watchInstallationEpoch: ownerTestWatch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
            includesHeartRate: true, decisionID: UUID(), confirmedAtUnixSeconds: 1, policyDigest: OwnerPracticePolicy.digest)
        let before = try phone.readSnapshot()
        #expect(throws: (any Error).self) { try phone.request(.withdraw(from: foreign, decisionID: UUID(), confirmedAtUnixSeconds: 2)) }
        #expect(throws: (any Error).self) { try phone.request(.heartRate(from: ownerTestIdentity(), allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)) }
        #expect(try phone.readSnapshot() == before)
    }

    @Test func pendingWithdrawalStillCompletesAfter256VerifiedRevisionOnlyMirrors() throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let original = try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone!.request(original); _ = try phone!.dispatchPending()
        for _ in 0..<256 {
            let transition = try watch.sequence(.advance(from: #require(watch.readSnapshot().authority), mutationID: UUID()))
            try watch.acknowledge(phone!.mirror(transition))
        }
        phone = nil; phone = try f.open(.phone, .openExisting)
        #expect(try phone!.readSnapshot().motionAccessBlocked)
        let beforeRetry = try phone!.readSnapshot()
        let altered = try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: original.id, confirmedAtUnixSeconds: 3)
        #expect(throws: (any Error).self) { try phone!.request(altered) }
        try phone!.request(original)
        #expect(try phone!.readSnapshot() == beforeRetry)
        let current = try phone!.dispatchPending()
        #expect(current.id == original.id)
        let result = try watch.sequence(current)
        try watch.acknowledge(phone!.mirror(result))
        #expect(try phone!.readSnapshot().pending == nil)
        #expect(try phone!.readSnapshot().authority == watch.readSnapshot().authority)
        #expect(try phone!.readSnapshot().authority?.isCollectionAllowed == false)
    }

    @Test(arguments: [OwnerChannelStage.temporarySynced, .published, .directorySynced])
    func verifiedRestrictionCheckpointIsAtomicAndPreservesOriginalRetry(stage: OwnerChannelStage) throws {
        let f = try ChannelFixture(); defer { f.remove() }
        var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
        let watch = try f.open(.watch, .createNew)
        try enrollChannels(phone!, watch)
        let original = try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 2)
        try phone!.request(original); _ = try phone!.dispatchPending()
        let transition = try watch.sequence(.advance(from: ownerTestIdentity(), mutationID: UUID()))
        var hits = 0
        phone!.writeFault = { if $0 == stage { hits += 1; if hits == 2 { throw ChannelTestFailure.injected } } }
        #expect(throws: (any Error).self) { try phone!.mirror(transition) }
        #expect(phone!.isPoisoned); phone = nil
        if stage == .temporarySynced {
            #expect(throws: (any Error).self) { try f.open(.phone, .openExisting) }
        } else {
            phone = try f.open(.phone, .openExisting)
            let beforeRetry = try phone!.readSnapshot()
            #expect(beforeRetry.authority?.revision == 2 && beforeRetry.retainedTransitionCount == 0)
            #expect(beforeRetry.pending?.mutation.beforeRevision == 2 && beforeRetry.pending?.dispatched == true)
            try phone!.request(original)
            #expect(try phone!.readSnapshot() == beforeRetry)
            #expect(try phone!.mirror(transition).matches(transition))
        }
    }
}

@Suite struct OwnerPhoneLifecycleChannelTests {
@Test(arguments: [false, true])
func localEndIDCannotAliasMirroredRetirement(occupiedIntent: Bool) throws {
let f = try ChannelFixture(); defer { f.remove() }
let phone = try f.open(.phone, .createNew), watch = try f.open(.watch, .createNew)
try enrollChannels(phone, watch)
try phone.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let endID = UUID()
try phone.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
if occupiedIntent {
try phone.request(.heartRate(from: ownerTestIdentity(), allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 2))
_ = try phone.dispatchPending()
}
let before = try phone.readSnapshot(), bytes = try Data(contentsOf: f.phoneJournal)
let transition = try watch.sequence(.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: endID))
#expect(throws: (any Error).self) { try phone.mirror(transition) }
#expect(!phone.isPoisoned)
#expect(try phone.readSnapshot() == before)
#expect(try Data(contentsOf: f.phoneJournal) == bytes)
#expect(try !phone.hasReplayGuard(scope: .practice, id: ownerTestPractice))
}

@Test func localEndIDPersistedVerifiedEntryAliasCannotReplayIntoO2() throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
try enrollChannels(phone!, watch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let endID = UUID()
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
let transition = try watch.sequence(.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: endID))
let transitionObject = try JSONSerialization.jsonObject(with: PracticeSetupJSON.encode(transition))
phone = nil
let ownerURL = f.phone.appendingPathComponent(OwnerPracticeStore.directoryName).appendingPathComponent("state.json")
let ownerBytes = try Data(contentsOf: ownerURL)
let invalid = try ownerTestResealed(Data(contentsOf: f.phoneJournal), domain: "PSLOwnerChannel2") {
$0["entries"] = [["transition": transitionObject]]
}
try invalid.write(to: f.phoneJournal)
#expect(throws: (any Error).self) { try f.open(.phone, .openExisting) }
#expect(try Data(contentsOf: f.phoneJournal) == invalid)
#expect(try Data(contentsOf: ownerURL) == ownerBytes)
}

@Test func localEndIDCannotBeDirectRetirementID() throws {
let f = try ChannelFixture(); defer { f.remove() }
let phone = try f.open(.phone, .createNew), watch = try f.open(.watch, .createNew)
try enrollChannels(phone, watch)
try phone.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let endID = UUID()
try phone.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
let before = try phone.readSnapshot(), bytes = try Data(contentsOf: f.phoneJournal)
let aliased = try OwnerAuthorityMutation.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: endID)
#expect(throws: (any Error).self) { try phone.request(aliased) }
#expect(!phone.isPoisoned)
#expect(try phone.readSnapshot() == before)
#expect(try Data(contentsOf: f.phoneJournal) == bytes)
let valid = try phone.queueRequestedEnd()
#expect(valid.id != endID)
#expect(try phone.queueRequestedEnd() == valid)
}

@Test func localEndIDCannotBeObsoleteReplacementID() throws {
let f = try ChannelFixture(); defer { f.remove() }
let phone = try f.open(.phone, .createNew), watch = try f.open(.watch, .createNew)
try enrollChannels(phone, watch)
try phone.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let endID = UUID()
try phone.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
let original = try phone.queueRequestedEnd(); _ = try phone.dispatchPending()
_ = try phone.mirror(watch.sequence(.advance(from: ownerTestIdentity(), mutationID: UUID())))
let before = try phone.readSnapshot(), bytes = try Data(contentsOf: f.phoneJournal)
#expect(before.pending?.mutation == original && before.pending?.requiresResolution == true)
let aliased = try OwnerAuthorityMutation.retirePractice(from: #require(before.authority), practiceID: ownerTestPractice, mutationID: endID)
#expect(throws: (any Error).self) { try phone.resolveObsoleteIntent(replacement: aliased) }
#expect(!phone.isPoisoned)
#expect(try phone.readSnapshot() == before)
#expect(try Data(contentsOf: f.phoneJournal) == bytes)
}

@Test(arguments: [false, true])
func localEndIDCannotAliasRetirementBeforeLatch(dispatched: Bool) throws {
let f = try ChannelFixture(); defer { f.remove() }
let phone = try f.open(.phone, .createNew), watch = try f.open(.watch, .createNew)
try enrollChannels(phone, watch)
try phone.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let wire = try OwnerAuthorityMutation.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: UUID())
try phone.request(wire)
if dispatched { _ = try phone.dispatchPending() }
let before = try phone.readSnapshot(), bytes = try Data(contentsOf: f.phoneJournal)
#expect(throws: (any Error).self) { try phone.requestPhoneEnd(practiceID: ownerTestPractice, requestID: wire.id) }
#expect(!phone.isPoisoned)
#expect(try phone.readSnapshot() == before)
#expect(try Data(contentsOf: f.phoneJournal) == bytes)
}

@Test(arguments: [false, true], ["localEnd", "wire"])
func localEndIDPersistedAliasCannotReopen(dispatched: Bool, altered: String) throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
try enrollChannels(phone!, watch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let endID = UUID()
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
let wire = try phone!.queueRequestedEnd()
#expect(wire.id != endID)
if dispatched { _ = try phone!.dispatchPending() }
phone = nil
let aliasedWire = try OwnerAuthorityMutation.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: endID)
let wireObject = try JSONSerialization.jsonObject(with: PracticeSetupJSON.encode(aliasedWire))
let invalid = try ownerTestResealed(Data(contentsOf: f.phoneJournal), domain: "PSLOwnerChannel2") { body in
if altered == "localEnd" {
var lifecycle = body["phonePractice"] as! [String: Any]
lifecycle["endRequestID"] = wire.id.uuidString
body["phonePractice"] = lifecycle
} else {
var intent = body["intent"] as! [String: Any]
intent["mutation"] = wireObject
body["intent"] = intent
}
}
try invalid.write(to: f.phoneJournal)
#expect(throws: (any Error).self) { try f.open(.phone, .openExisting) }
#expect(try Data(contentsOf: f.phoneJournal) == invalid)
}

@Test(arguments: [false, true])
func localEndIDDistinctFromRetainedRetirementRemainsIdempotent(dispatched: Bool) throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
try enrollChannels(phone!, watch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let wire = try OwnerAuthorityMutation.retirePractice(from: ownerTestIdentity(), practiceID: ownerTestPractice, mutationID: UUID())
try phone!.request(wire)
if dispatched { _ = try phone!.dispatchPending() }
let before = try phone!.readSnapshot(), endID = UUID()
#expect(endID != wire.id)
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
let bytes = try Data(contentsOf: f.phoneJournal)
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
#expect(try phone!.queueRequestedEnd() == wire)
#expect(try phone!.readSnapshot().pending == before.pending)
#expect(try Data(contentsOf: f.phoneJournal) == bytes)
phone = nil; phone = try f.open(.phone, .openExisting)
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
#expect(try phone!.queueRequestedEnd() == wire)
#expect(try phone!.readSnapshot().pending == before.pending)
#expect(try Data(contentsOf: f.phoneJournal) == bytes)
}

@Test func exhaustedAuthorityCanSaveEndWithoutClaimingRetirement() throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
try enrollChannels(phone!, watch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
phone = nil
let withdrawal = try OwnerAuthorityMutation.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 2)
let denied = try withdrawal.resolve(from: ownerTestIdentity())
let before = try OwnerPracticeIdentity.decode(ownerTestResealed(denied.encoded(), domain: "PSLOwnerIdentity1") {
$0["revision"] = OwnerPracticeIdentity.maximumRevision - 1
})
let transition = try OwnerAuthorityTransition(sequence: OwnerPracticeIdentity.maximumRevision, mutation: .advance(from: before, mutationID: UUID()))
let exhausted = try transition.mutation.resolve(from: before), bytes = try exhausted.encoded()
let ack = try JSONSerialization.jsonObject(with: PracticeSetupJSON.encode(OwnerAuthorityAcknowledgement(transition: transition)))
try ownerTestResealed(Data(contentsOf: f.phoneJournal), domain: "PSLOwnerChannel2") {
$0["anchor"] = bytes.base64EncodedString(); $0["acknowledged"] = ack
}.write(to: f.phoneJournal)
let ownerURL = f.phone.appendingPathComponent(OwnerPracticeStore.directoryName).appendingPathComponent("state.json")
try ownerTestResealed(Data(contentsOf: ownerURL), domain: "PSLOwnerStore1") {
$0["authorityBytes"] = bytes.base64EncodedString()
}.write(to: ownerURL)
phone = try f.open(.phone, .openExisting)
let endID = UUID()
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
#expect(throws: (any Error).self) { try phone!.queueRequestedEnd() }
#expect(!phone!.isPoisoned)
phone = nil; phone = try f.open(.phone, .openExisting)
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
#expect(try phone!.readSnapshot().authority == exhausted && phone!.readSnapshot().pending == nil)
#expect(try !phone!.hasReplayGuard(scope: .practice, id: ownerTestPractice))
}

@Test(arguments: ["null", "unknown", "alias", "ownerID", "phoneEpoch", "watchEpoch", "noBasis", "oversize"])
func malformedLifecycleNeverReopensOrRecreatesAuthority(change: String) throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
try phone!.request(.enrollment(ownerTestIdentity()))
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
phone = nil
let bytes = try Data(contentsOf: f.phoneJournal)
let corrupt = try ownerTestResealed(bytes, domain: "PSLOwnerChannel2") { body in
var record = body["phonePractice"] as! [String: Any]
switch change {
case "null": body["phonePractice"] = NSNull(); return
case "unknown": record["unrecognised"] = true
case "alias": record["preparationID"] = record["practiceID"]
case "noBasis": body.removeValue(forKey: "intent")
case "oversize": record["endRequestID"] = String(repeating: "x", count: 513)
default: record[change] = UUID().uuidString
}
body["phonePractice"] = record
}
try corrupt.write(to: f.phoneJournal)
#expect(throws: (any Error).self) { try f.open(.phone, .openExisting) }
#expect(try Data(contentsOf: f.phoneJournal) == corrupt)
}

@Test func watchJournalCannotContainAPhoneLifecycle() throws {
let f = try ChannelFixture(); defer { f.remove() }
let phone = try f.open(.phone, .createNew)
var watch: PracticeSetupChannel? = try f.open(.watch, .createNew)
try enrollChannels(phone, watch!)
try phone.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let envelope = try JSONSerialization.jsonObject(with: Data(contentsOf: f.phoneJournal)) as! [String: Any]
let body = envelope["body"] as! [String: Any]
watch = nil
let url = f.watch.appendingPathComponent(PracticeSetupChannel.directoryName).appendingPathComponent("journal.json")
try ownerTestResealed(Data(contentsOf: url), domain: "PSLOwnerChannel2") { $0["phonePractice"] = body["phonePractice"] }.write(to: url)
#expect(throws: (any Error).self) { try f.open(.watch, .openExisting) }
}

@Test(arguments: [false, true])
func lifecyclePrecedesP1DraftAndNoPreparationIsRestored(saveDraft: Bool) throws {
let f = try ChannelFixture(); defer { f.remove() }
var setup: PracticeSetupStore? = try PracticeSetupStore(base: f.phone)
let epoch = try #require(setup).checkedSnapshot().localInstallationEpoch
let owner = try OwnerPracticeIdentity.enrolled(ownerID: ownerTestSubject, phoneInstallationEpoch: epoch,
watchInstallationEpoch: ownerTestWatch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
includesHeartRate: false, decisionID: UUID(), confirmedAtUnixSeconds: 1, policyDigest: OwnerPracticePolicy.digest)
var phone: PracticeSetupChannel? = try PracticeSetupChannel(base: f.phone, localInstallationEpoch: epoch, device: .phone, intent: .createNew)
try phone!.request(.enrollment(owner))
let draft = try ownerTestDraft(origin: epoch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: draft.identity.preparationID, owner: owner)
if saveDraft { try setup!.saveSuggestion(draft) }
phone = nil; setup = nil
setup = try PracticeSetupStore(base: f.phone)
phone = try PracticeSetupChannel(base: f.phone, localInstallationEpoch: epoch, device: .phone, intent: .openExisting)
#expect(try phone!.readSnapshot().phonePractice?.practiceID == ownerTestPractice)
#expect(try phone!.readSnapshot().phonePractice?.preparationID == draft.identity.preparationID)
#expect(try phone!.readSnapshot().authority == nil && phone!.readSnapshot().admissionBlocked)
#expect(try phone!.readSnapshot().pending?.dispatched == false)
#expect(try setup!.checkedSnapshot().latestDraft == (saveDraft ? draft : nil))
#expect(try setup!.checkedSnapshot().highWater == nil)
}

@Test(arguments: [OwnerChannelStage.temporarySynced, .published, .directorySynced],
["begin", "end", "queue", "dispatch", "clear", "priorMirror"])
func lifecycleDurabilityFaultsNeverClaimSavedOrApplied(stage: OwnerChannelStage, operation: String) throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
try enrollChannels(phone!, watch)
let preparation = UUID(), endID = UUID()
if operation != "begin" { try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: preparation, owner: ownerTestIdentity()) }
var transition: OwnerAuthorityTransition?
if operation == "priorMirror" {
try phone!.request(.heartRate(from: ownerTestIdentity(), allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 2))
_ = try phone!.dispatchPending()
}
if !["begin", "end"].contains(operation) { try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID) }
if operation == "dispatch" || operation == "clear" { _ = try phone!.queueRequestedEnd() }
if operation == "clear" || operation == "priorMirror" { transition = try watch.sequence(phone!.dispatchPending()) }
var hits = 0
phone!.writeFault = { observed in
if observed == stage { hits += 1; if hits == (operation == "clear" ? 2 : 1) { throw ChannelTestFailure.injected } }
}
#expect(throws: (any Error).self) {
switch operation {
case "begin": try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: preparation, owner: ownerTestIdentity())
case "end": try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
case "queue": _ = try phone!.queueRequestedEnd()
case "dispatch": _ = try phone!.dispatchPending()
default: _ = try phone!.mirror(#require(transition))
}
}
#expect(phone!.isPoisoned)
#expect(throws: (any Error).self) { try phone!.readSnapshot() }
phone = nil
if stage == .temporarySynced {
#expect(throws: (any Error).self) { try f.open(.phone, .openExisting) }
} else {
phone = try f.open(.phone, .openExisting)
let restored = try phone!.readSnapshot()
if operation == "clear" {
#expect(restored.phonePractice == nil && restored.pending == nil)
#expect(try phone!.hasReplayGuard(scope: .practice, id: ownerTestPractice))
} else {
#expect(restored.phonePractice?.practiceID == ownerTestPractice)
#expect(restored.phonePractice?.endRequestID == (operation == "begin" ? nil : endID))
if operation == "dispatch" { #expect(restored.pending?.dispatched == true) }
if operation == "queue" { #expect(restored.pending?.mutation.retiredPracticeID == ownerTestPractice) }
if operation == "priorMirror" { #expect(restored.pending == nil && restored.authority?.heartRateConsent == false) }
}
}
}

@Test(arguments: [OwnerPracticeStoreStage.guardDirectorySynced, .statePublished, .stateDirectorySynced])
func retirementO2InterruptionRetainsExactRecoveryAndClearsOnce(stage: OwnerPracticeStoreStage) throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
try enrollChannels(phone!, watch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: UUID())
_ = try phone!.queueRequestedEnd()
let transition = try watch.sequence(phone!.dispatchPending())
phone!.ownerWriteFault = { if $0 == stage { throw ChannelTestFailure.injected } }
#expect(throws: (any Error).self) { try phone!.mirror(transition) }
#expect(phone!.isPoisoned); phone = nil
phone = try f.open(.phone, .openExisting)
#expect(try phone!.readSnapshot().phonePractice == nil)
#expect(try phone!.readSnapshot().authority?.revision == 2)
#expect(try phone!.hasReplayGuard(scope: .practice, id: ownerTestPractice))
_ = try phone!.mirror(transition)
#expect(try phone!.readSnapshot().authority?.revision == 2)
}

@Test func retirementClearsOnlyItsLifecycleAndPreservesObsoleteIntentAndPrivacyFence() throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
try enrollChannels(phone!, watch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let grant = try OwnerAuthorityMutation.heartRate(from: ownerTestIdentity(), allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)
try phone!.request(grant); _ = try phone!.dispatchPending()
#expect(throws: OwnerChannelError.intentOutstanding) {
try phone!.request(.withdraw(from: ownerTestIdentity(), decisionID: UUID(), confirmedAtUnixSeconds: 3))
}
let endID = UUID()
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
let unrelated = try watch.sequence(.retirePractice(from: ownerTestIdentity(), practiceID: UUID(), mutationID: UUID()))
_ = try phone!.mirror(unrelated)
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
let withdrawn = try watch.sequence(.withdraw(from: #require(watch.readSnapshot().authority), decisionID: UUID(), confirmedAtUnixSeconds: 4))
_ = try phone!.mirror(withdrawn)
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
let exact = try watch.sequence(.retirePractice(from: #require(watch.readSnapshot().authority), practiceID: ownerTestPractice, mutationID: UUID()))
_ = try phone!.mirror(exact)
let after = try phone!.readSnapshot()
#expect(after.phonePractice == nil)
#expect(after.pending?.mutation == grant && after.pending?.requiresResolution == true)
#expect(after.retainedTransitionCount == 3 && after.unqueuedRestriction == .all && after.motionAccessBlocked)
phone = nil; phone = try f.open(.phone, .openExisting)
let reopened = try phone!.readSnapshot()
#expect(reopened.phonePractice == nil && reopened.pending == after.pending)
#expect(reopened.retainedTransitionCount == after.retainedTransitionCount && reopened.unqueuedRestriction == .all)
}

@Test func aReplayGuardAloneCannotClearTheRetainedEnd() throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
try enrollChannels(phone!, watch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let endID = UUID()
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
phone = nil
var direct: OwnerPracticeStore? = try OwnerPracticeStore(base: f.phone, localInstallationEpoch: ownerTestPhone, device: .phone, intent: .openExisting)
direct!.writeFault = { if $0 == .guardDirectorySynced { throw ChannelTestFailure.injected } }
#expect(throws: (any Error).self) { try direct!.retire(scope: .practice, id: ownerTestPractice, expectedRevision: 1) }
direct = nil
phone = try f.open(.phone, .openExisting)
#expect(try phone!.hasReplayGuard(scope: .practice, id: ownerTestPractice))
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
#expect(try phone!.readSnapshot().admissionBlocked && phone!.readSnapshot().authority?.revision == 1)
}

@Test func reservedEndBytesSurviveRealJournalGrowthRefusalAndExactInsufficientLimit() throws {
let f = try ChannelFixture(); defer { f.remove() }
let limit = 45_000
var phone: PracticeSetupChannel? = try f.limitedPhone(.createNew, bytes: limit)
let watch = try f.open(.watch, .createNew)
try enrollChannels(phone!, watch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
try phone!.request(.heartRate(from: ownerTestIdentity(), allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2))
_ = try phone!.dispatchPending()
var refused = false
for _ in 0..<PracticeSetupChannel.maximumTransitions {
let transition = try watch.sequence(.advance(from: #require(watch.readSnapshot().authority), mutationID: UUID()))
do { _ = try phone!.mirror(transition) }
catch OwnerPracticeError.capacity { refused = true; break }
}
#expect(refused && !phone!.isPoisoned)
let before = try Data(contentsOf: f.phoneJournal)
let endID = UUID()
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
let after = try Data(contentsOf: f.phoneJournal)
#expect(after.count > before.count && after.count - before.count <= 64 && after.count <= limit)
#expect(try phone!.readSnapshot().admissionBlocked)
phone = nil; phone = try f.limitedPhone(.openExisting, bytes: limit)
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
phone = nil
#expect(throws: (any Error).self) { try f.limitedPhone(.openExisting, bytes: after.count - 1) }
#expect(try Data(contentsOf: f.phoneJournal) == after)
phone = try f.limitedPhone(.openExisting, bytes: limit)
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
}

@Test(arguments: [0, -1, PracticeSetupChannel.maximumBytes + 1])
func invalidInternalByteLimitFailsBeforeCreatingStorage(limit: Int) throws {
let f = try ChannelFixture(); defer { f.remove() }
#expect(throws: (any Error).self) { try f.limitedPhone(.createNew, bytes: limit) }
#expect(try FileManager.default.contentsOfDirectory(atPath: f.phone.path).isEmpty)
}

@Test(arguments: ["empty", "pending", "anchored"])
func settledLegacyBytesRemainExactAndOldReadersRejectLifecycle(state: String) throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
if state == "anchored" { try enrollChannels(phone!, watch) }
else if state == "pending" { try phone!.request(.enrollment(ownerTestIdentity())) }
let original = try Data(contentsOf: f.phoneJournal)
let legacy: LegacyChannelJournal = try OwnerCanonical.decode(original, domain: "PSLOwnerChannel2", limit: PracticeSetupChannel.maximumBytes)
#expect(try OwnerCanonical.encode(legacy, domain: "PSLOwnerChannel2", limit: PracticeSetupChannel.maximumBytes) == original)
phone = nil; phone = try f.open(.phone, .openExisting)
#expect(try Data(contentsOf: f.phoneJournal) == original)
#expect(try phone!.readSnapshot().phonePractice == nil)
if state == "empty" { try phone!.request(.enrollment(ownerTestIdentity())) }
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: ownerTestDraft().identity.preparationID, owner: ownerTestIdentity())
let expanded = try Data(contentsOf: f.phoneJournal)
#expect(throws: (any Error).self) {
let _: LegacyChannelJournal = try OwnerCanonical.decode(expanded, domain: "PSLOwnerChannel2", limit: PracticeSetupChannel.maximumBytes)
}
phone = nil; phone = try f.open(.phone, .openExisting)
#expect(try Data(contentsOf: f.phoneJournal) == expanded)
#expect(try phone!.readSnapshot().phonePractice?.practiceID == ownerTestPractice)
}

@Test func exactIndependentMappingCannotReplaceAPracticeOrRestoreAcceptance() throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
let owner = try ownerTestIdentity(), preparation = try ownerTestDraft().identity.preparationID
#expect(throws: (any Error).self) { try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: preparation, owner: owner) }
try enrollChannels(phone!, watch)
#expect(throws: OwnerChannelError.wrongRole) { try watch.beginPhonePractice(practiceID: ownerTestPractice, preparationID: preparation, owner: owner) }
#expect(throws: (any Error).self) { try phone!.beginPhonePractice(practiceID: preparation, preparationID: preparation, owner: owner) }
let before = try phone!.readSnapshot()
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: preparation, owner: owner)
let saved = try phone!.readSnapshot(), bytes = try Data(contentsOf: f.phoneJournal)
#expect(saved.authority == before.authority && saved.pending == nil)
#expect(saved.phonePractice?.practiceID != saved.phonePractice?.preparationID)
#expect(saved.phonePractice?.ownerID == owner.ownerID && saved.phonePractice?.phoneEpoch == ownerTestPhone)
#expect(saved.phonePractice?.watchEpoch == ownerTestWatch && saved.phonePractice?.endRequestID == nil)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: preparation, owner: owner)
#expect(try Data(contentsOf: f.phoneJournal) == bytes)
#expect(throws: (any Error).self) { try phone!.beginPhonePractice(practiceID: UUID(), preparationID: UUID(), owner: owner) }
#expect(throws: (any Error).self) { try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: owner) }
let pending = try OwnerAuthorityMutation.heartRate(from: owner, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 2)
try phone!.request(pending)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: preparation, owner: owner)
phone = nil; phone = try f.open(.phone, .openExisting)
#expect(try phone!.readSnapshot().phonePractice == saved.phonePractice)
#expect(try phone!.readSnapshot().pending?.mutation == pending)
#expect(try phone!.readSnapshot().admissionBlocked)
let endID = UUID()
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
let ended = try Data(contentsOf: f.phoneJournal)
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
#expect(try Data(contentsOf: f.phoneJournal) == ended)
#expect(throws: (any Error).self) { try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: UUID()) }
#expect(throws: (any Error).self) { try phone!.requestPhoneEnd(practiceID: UUID(), requestID: endID) }
#expect(throws: (any Error).self) { try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: preparation, owner: owner) }
}

@Test func newPracticeWaitsForNonEnrollmentIntentAndRefusesStaleOrForeignOwner() throws {
let f = try ChannelFixture(); defer { f.remove() }
let phone = try f.open(.phone, .createNew), watch = try f.open(.watch, .createNew)
try enrollChannels(phone, watch)
let initial = try ownerTestIdentity()
let change = try OwnerAuthorityMutation.heartRate(from: initial, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 2)
try phone.request(change)
#expect(throws: (any Error).self) { try phone.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: initial) }
try phone.cancelPending()
let foreign = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: ownerTestPhone,
watchInstallationEpoch: ownerTestWatch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
includesHeartRate: true, decisionID: UUID(), confirmedAtUnixSeconds: 1, policyDigest: OwnerPracticePolicy.digest)
#expect(throws: (any Error).self) { try phone.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: foreign) }
_ = try phone.mirror(watch.sequence(.advance(from: initial, mutationID: UUID())))
#expect(throws: (any Error).self) { try phone.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: initial) }
let retired = try watch.sequence(.retirePractice(from: #require(watch.readSnapshot().authority), practiceID: ownerTestPractice, mutationID: UUID()))
_ = try phone.mirror(retired)
#expect(throws: (any Error).self) { try phone.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: #require(phone.readSnapshot().authority)) }
#expect(try phone.readSnapshot().phonePractice == nil)
}

@Test(arguments: ["enrollment", "heartRate"], [false, true])
func endSurvivesOccupiedIntentRelaunchAndLostReply(kind: String, dispatched: Bool) throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew), owner = try ownerTestIdentity()
let original: OwnerAuthorityMutation
if kind == "enrollment" {
original = try .enrollment(owner)
try phone!.request(original)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: owner)
} else {
try enrollChannels(phone!, watch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: owner)
original = try .heartRate(from: owner, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 2)
try phone!.request(original)
}
if dispatched { _ = try phone!.dispatchPending() }
let before = try phone!.readSnapshot(), endID = UUID()
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
let latched = try phone!.readSnapshot()
#expect(latched.pending == before.pending && latched.authority == before.authority)
#expect(latched.motionAccessBlocked == before.motionAccessBlocked && latched.heartRateAccessBlocked == before.heartRateAccessBlocked)
#expect(latched.unqueuedRestriction == before.unqueuedRestriction && latched.admissionBlocked)
#expect(throws: (any Error).self) { try phone!.queueRequestedEnd() }
if kind == "enrollment" {
#expect(throws: (any Error).self) { try phone!.cancelPending() }
#expect(throws: (any Error).self) { try phone!.resolveObsoleteIntent(replacement: nil) }
#expect(try phone!.readSnapshot().pending == before.pending)
}
phone = nil; phone = try f.open(.phone, .openExisting)
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
let exact = try phone!.dispatchPending()
#expect(exact == original)
let applied = try watch.sequence(exact)
try watch.acknowledge(phone!.mirror(applied))
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
let beforeRetirement = try phone!.readSnapshot().authority
let wire = try phone!.queueRequestedEnd()
#expect(wire.id != endID && wire.retiredPracticeID == ownerTestPractice)
#expect(try phone!.queueRequestedEnd() == wire)
_ = try phone!.dispatchPending()
let retirement = try watch.sequence(wire)
// The Watch applied End, but the reply was lost. The phone only has its durable intent.
phone = nil; phone = try f.open(.phone, .openExisting)
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
#expect(try phone!.dispatchPending() == wire)
#expect(try watch.sequence(wire) == retirement)
let ack = try phone!.mirror(retirement)
#expect(try phone!.readSnapshot().phonePractice == nil)
#expect(try phone!.hasReplayGuard(scope: .practice, id: ownerTestPractice))
#expect(try phone!.readSnapshot().authority?.isCollectionAllowed == beforeRetirement?.isCollectionAllowed)
#expect(try phone!.readSnapshot().authority?.heartRateConsent == beforeRetirement?.heartRateConsent)
try watch.acknowledge(ack)
let newPractice = UUID(), newPreparation = UUID()
try phone!.beginPhonePractice(practiceID: newPractice, preparationID: newPreparation, owner: #require(phone!.readSnapshot().authority))
_ = try phone!.mirror(retirement)
#expect(try phone!.readSnapshot().phonePractice?.practiceID == newPractice)
#expect(try phone!.readSnapshot().phonePractice?.preparationID == newPreparation)
}

@Test func obsoleteEndNeedsExplicitNewWireIdentityWhileLocalEndStaysStable() throws {
let f = try ChannelFixture(); defer { f.remove() }
var phone: PracticeSetupChannel? = try f.open(.phone, .createNew)
let watch = try f.open(.watch, .createNew)
try enrollChannels(phone!, watch)
try phone!.beginPhonePractice(practiceID: ownerTestPractice, preparationID: UUID(), owner: ownerTestIdentity())
let endID = UUID()
try phone!.requestPhoneEnd(practiceID: ownerTestPractice, requestID: endID)
let oldWire = try phone!.queueRequestedEnd(); _ = try phone!.dispatchPending()
_ = try phone!.mirror(watch.sequence(.advance(from: ownerTestIdentity(), mutationID: UUID())))
#expect(try phone!.readSnapshot().pending?.requiresResolution == true)
#expect(throws: OwnerChannelError.resolutionRequired) { try phone!.queueRequestedEnd() }
#expect(throws: (any Error).self) { try phone!.resolveObsoleteIntent(replacement: nil) }
phone = nil; phone = try f.open(.phone, .openExisting)
let replacement = try OwnerAuthorityMutation.retirePractice(from: #require(phone!.readSnapshot().authority), practiceID: ownerTestPractice, mutationID: UUID())
#expect(replacement.id != oldWire.id && replacement.id != endID)
try phone!.resolveObsoleteIntent(replacement: replacement)
#expect(try phone!.readSnapshot().phonePractice?.endRequestID == endID)
#expect(try phone!.queueRequestedEnd() == replacement)
_ = try phone!.mirror(watch.sequence(phone!.dispatchPending()))
#expect(try phone!.readSnapshot().phonePractice == nil)
}
}
