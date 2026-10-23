import Darwin
import Foundation

public enum OwnerChannelError: Error, Equatable, Sendable {
    case invalid(String), integrity(String), wrongRole, capacity, poisoned, busy, stale, conflict
    case intentOutstanding, sentIntentCannotCancel, resolutionRequired, localRestriction
}

/// A local access fence, never another queued command or proof of remote application.
public enum OwnerLocalRestriction: Int, Codable, Sendable { case none = 0, heartRate = 1, all = 2 }

public struct OwnerPendingIntent: Equatable, Sendable {
    public let mutation: OwnerAuthorityMutation
    public let dispatched: Bool
    public let requiresResolution: Bool
}

/// Durable phone bookkeeping only. This value cannot restore consent, preparation acceptance or Start.
public struct OwnerPhonePracticeLifecycle: Codable, Equatable, Sendable {
public let practiceID: UUID
public let preparationID: UUID
public let ownerID: UUID
public let phoneEpoch: UUID
public let watchEpoch: UUID
public let endRequestID: UUID?

fileprivate func matches(_ owner: OwnerPracticeIdentity) -> Bool {
ownerID == owner.ownerID && phoneEpoch == owner.phoneInstallationEpoch && watchEpoch == owner.watchInstallationEpoch
}
}

public struct OwnerChannelSnapshot: Equatable, Sendable {
    public let storeInstanceID: UUID
    public let authority: OwnerPracticeIdentity?
    public let acknowledged: OwnerAuthorityAcknowledgement?
    public let latest: OwnerAuthorityAcknowledgement?
    public let retainedTransitionCount: Int
    public let journalByteCount: Int
    public let pending: OwnerPendingIntent?
public let phonePractice: OwnerPhonePracticeLifecycle?
    public let unqueuedRestriction: OwnerLocalRestriction
    public let admissionBlocked: Bool
    public let motionAccessBlocked: Bool
    public let heartRateAccessBlocked: Bool
}

enum OwnerChannelStage: Sendable, Equatable {
    case temporarySynced, published, directorySynced, commandCommitted, ownerApplied
    case recoveryFileSynced, recoveryDirectorySynced
}

/// One synchronous serial owner of the journal AND O2. Intentionally not Sendable.
/// Resource shutdown is the caller's independent obligation, including when any method throws.
public final class PracticeSetupChannel {
    public static let directoryName = "OwnerChannel-v2"
    public static let maximumTransitions = 256
    public static let maximumBytes = 1_048_576
    private static let reservedEntryBytes = OwnerAuthorityTransition.maximumBytes + 256
    private static let anchorAllowance = 24_576
    private let files: OwnerJournalFiles
    private let store: OwnerPracticeStore
private let maximumJournalBytes: Int
    private var journal: OwnerChannelJournal
    private var expectedBytes: Data
    public private(set) var isPoisoned = false
    // Nil in production; inject at the actual publication/apply boundaries, never substitute a fake store.
    var writeFault: ((OwnerChannelStage) throws -> Void)?
    var ownerWriteFault: ((OwnerPracticeStoreStage) throws -> Void)? {
        get { store.writeFault }
        set { store.writeFault = newValue }
    }

    /// The application must retain first-use evidence outside both namespaces. Known installs always openExisting.
    public convenience init(base: URL, localInstallationEpoch: UUID, device: OwnerPracticeDevice, intent: OwnerPracticeStoreIntent) throws {
        try self.init(base: base, localInstallationEpoch: localInstallationEpoch, device: device, intent: intent, recoveryFault: nil)
    }

    // Tests observe actual reopen synchronization; production always uses the nil hook above.
    init(base: URL, localInstallationEpoch: UUID, device: OwnerPracticeDevice, intent: OwnerPracticeStoreIntent,
recoveryFault: ((OwnerChannelStage) throws -> Void)?, maximumJournalBytes: Int = PracticeSetupChannel.maximumBytes) throws {
guard (1...Self.maximumBytes).contains(maximumJournalBytes) else { throw OwnerChannelError.invalid("journal byte limit") }
self.maximumJournalBytes = maximumJournalBytes
        let ownedFiles = try OwnerJournalFiles(base: base, intent: intent)
        let ownedStore = try OwnerPracticeStore(base: base, localInstallationEpoch: localInstallationEpoch, device: device, intent: intent)
        let existing = try ownedFiles.read(allowsMissing: intent == .createNew)
        let state: OwnerChannelJournal
        if intent == .createNew {
            guard existing == nil, ownedStore.snapshot.authority == nil else { throw OwnerChannelError.integrity("fresh channel required") }
            state = OwnerChannelJournal(version: 2, localEpoch: localInstallationEpoch, device: device,
                anchor: nil, acknowledged: nil, entries: [], intent: nil, fence: .none)
        } else {
            guard let existing else { throw OwnerChannelError.integrity("missing initialized journal") }
state = try OwnerCanonical.decode(existing, domain: "PSLOwnerChannel2", limit: maximumJournalBytes)
        }
        guard state.localEpoch == localInstallationEpoch, state.device == device else { throw OwnerChannelError.integrity("channel role or installation") }
        _ = try Self.derive(state)
        files = ownedFiles; store = ownedStore; journal = state; expectedBytes = existing ?? Data()
_ = try encode(state)
        if existing == nil { try commit(state) }
        else { try files.synchronize(expected: expectedBytes, fault: recoveryFault) }
        // Committed journal entries are the only authority for recovery. A temporary never reaches this point.
        try reconcileOwner()
        if device == .phone { try checkpointPhone() }
        _ = try checkLive()
    }

    public func readSnapshot() throws -> OwnerChannelSnapshot {
        let view = try checkLive()
        let requested = view.pending.map { Self.restriction($0.mutation) } ?? .none
        let restriction = Self.stronger(journal.fence, requested)
        let available = normalCapacity(journal, bytes: expectedBytes.count, authority: view.tip, prospective: true)
        return OwnerChannelSnapshot(storeInstanceID: store.storeInstanceID, authority: view.tip,
            acknowledged: journal.acknowledged, latest: view.latest,
            retainedTransitionCount: journal.entries.count, journalByteCount: expectedBytes.count, pending: view.pending,
phonePractice: journal.phonePractice,
            unqueuedRestriction: journal.fence,
admissionBlocked: view.tip?.isCollectionAllowed != true || view.pending != nil || restriction != .none || !available || journal.phonePractice?.endRequestID != nil,
            motionAccessBlocked: view.tip?.isCollectionAllowed != true || restriction == .all,
            heartRateAccessBlocked: view.tip?.heartRateConsent != true || restriction != .none)
    }

    /// Watch alone can sequence. Exact retained duplicates do not create a new transition or acknowledgement.
    @discardableResult
    public func sequence(_ mutation: OwnerAuthorityMutation) throws -> OwnerAuthorityTransition {
        let view = try checkLive(); try require(.watch)
        if let existing = journal.entries.first(where: { $0.transition.mutation.id == mutation.id }) {
            guard existing.transition.mutation == mutation else { throw OwnerChannelError.conflict }
            return existing.transition
        }
        let next = try mutation.resolve(from: view.tip)
        try validateLocal(next)
        if let practice = mutation.retiredPracticeID, try store.hasReplayGuard(scope: .practice, id: practice) {
            // A new End cannot reuse an old guard. Only reconcileOwner may finish this journal's committed retirement.
            throw OwnerPracticeStorageError.retired
        }
        let transition = try OwnerAuthorityTransition(sequence: next.revision, mutation: mutation)
        var candidate = journal
        candidate.entries.append(OwnerChannelEntry(transition: transition, reserve: nil))
let ordinaryBytes = try encode(candidate).count
        if !normalCapacity(candidate, bytes: ordinaryBytes, authority: next) {
            guard let reserve = Self.eligibleReserve(mutation, before: view.tip),
                  !journal.entries.contains(where: { $0.reserve == reserve }) else { throw OwnerChannelError.capacity }
            candidate.entries[candidate.entries.count - 1].reserve = reserve
            let remaining = 3 - Set(candidate.entries.compactMap(\.reserve)).count
            guard candidate.entries.count + remaining <= Self.maximumTransitions,
ordinaryBytes + remaining * Self.reservedEntryBytes + Self.anchorAllowance <= maximumJournalBytes else {
                throw OwnerChannelError.capacity
            }
        }
        try commit(candidate)
        do {
            try writeFault?(.commandCommitted)
            try reconcileOwner()
            try writeFault?(.ownerApplied)
            _ = try checkLive()
            return transition
        } catch { isPoisoned = true; throw error }
    }

    /// Phone durably records the next explicit transition before O2 application and returns an ACK only afterwards.
    @discardableResult
    public func mirror(_ transition: OwnerAuthorityTransition) throws -> OwnerAuthorityAcknowledgement {
        let view = try checkLive(); try require(.phone)
        let ack = try OwnerAuthorityAcknowledgement(transition: transition)
        if transition.sequence <= (view.tip?.revision ?? 0) {
            guard journal.acknowledged == ack || journal.entries.contains(where: { $0.transition == transition }) else {
                throw OwnerChannelError.conflict
            }
            return ack
        }
        guard transition.sequence == (view.tip?.revision ?? 0) + 1 else { throw OwnerChannelError.stale }
        let next = try transition.mutation.resolve(from: view.tip)
        try validateLocal(next)
        var candidate = journal
        candidate.entries.append(OwnerChannelEntry(transition: transition, reserve: nil))
        try commit(candidate)
        do {
            try writeFault?(.commandCommitted)
            try reconcileOwner()
            try writeFault?(.ownerApplied)
            try checkpointPhone()
            _ = try checkLive()
            return ack
        } catch { isPoisoned = true; throw error }
    }

    /// Prunes only a locally retained, exact contiguous prefix. No missing entry is interpreted as an empty queue.
    public func acknowledge(_ acknowledgement: OwnerAuthorityAcknowledgement) throws {
        let view = try checkLive(); try require(.watch)
        if acknowledgement == journal.acknowledged { return }
        guard let index = journal.entries.firstIndex(where: { acknowledgement.matches($0.transition) }) else {
            throw OwnerChannelError.conflict
        }
        var candidate = journal
        candidate.anchor = try view.nodes[index + 1]?.encoded()
        candidate.acknowledged = acknowledgement
        candidate.entries.removeFirst(index + 1)
        try commit(candidate)
        _ = try checkLive()
    }

    public func nextTransition(after cursor: OwnerAuthorityReplayCursor) throws -> OwnerAuthorityTransition? {
        let view = try checkLive(); try require(.watch)
        guard let tip = view.tip, cursor.ownerID == tip.ownerID,
              cursor.phoneEpoch == tip.phoneInstallationEpoch, cursor.watchEpoch == tip.watchInstallationEpoch else {
            throw OwnerChannelError.stale
        }
        if cursor.after == journal.acknowledged { return journal.entries.first?.transition }
        guard let ack = cursor.after,
              let index = journal.entries.firstIndex(where: { ack.matches($0.transition) }) else { throw OwnerChannelError.stale }
        return index + 1 < journal.entries.count ? journal.entries[index + 1].transition : nil
    }

/// Persist before the corresponding P1 draft or preparation dispatch. Reopening is bookkeeping only.
public func beginPhonePractice(practiceID: UUID, preparationID: UUID, owner: OwnerPracticeIdentity) throws {
let view = try checkLive(); try require(.phone)
var expected = view.tip
if expected == nil, let pending = view.pending, pending.mutation.kind == .enroll {
expected = try pending.mutation.resolve(from: nil)
}
guard expected == owner else { throw OwnerChannelError.stale }
guard practiceID != preparationID else { throw OwnerChannelError.invalid("distinct practice and preparation identities") }
if let retained = journal.phonePractice {
guard retained.practiceID == practiceID, retained.preparationID == preparationID,
retained.matches(owner) else { throw OwnerChannelError.conflict }
guard retained.endRequestID == nil else { throw OwnerChannelError.localRestriction }
return
}
guard owner.isCollectionAllowed, view.pending == nil || view.pending?.mutation.kind == .enroll else {
throw OwnerChannelError.localRestriction
}
guard try !store.hasReplayGuard(scope: .practice, id: practiceID) else { throw OwnerPracticeStorageError.retired }
var candidate = journal
candidate.phonePractice = OwnerPhonePracticeLifecycle(practiceID: practiceID, preparationID: preparationID,
ownerID: owner.ownerID, phoneEpoch: owner.phoneInstallationEpoch, watchEpoch: owner.watchInstallationEpoch, endRequestID: nil)
guard normalCapacity(candidate, bytes: try encode(candidate).count, authority: owner) else { throw OwnerChannelError.capacity }
try commit(candidate)
}

/// A local End survives an occupied authority intent without withdrawing consent or claiming a remote stop.
public func requestPhoneEnd(practiceID: UUID, requestID: UUID) throws {
_ = try checkLive(); try require(.phone)
guard let retained = journal.phonePractice, retained.practiceID == practiceID else { throw OwnerChannelError.conflict }
if let previous = retained.endRequestID {
guard previous == requestID else { throw OwnerChannelError.conflict }
return
}
var candidate = journal
candidate.phonePractice = OwnerPhonePracticeLifecycle(practiceID: retained.practiceID, preparationID: retained.preparationID,
ownerID: retained.ownerID, phoneEpoch: retained.phoneEpoch, watchEpoch: retained.watchEpoch, endRequestID: requestID)
try commit(candidate)
}

/// Each concrete wire command has its own ID; explicit obsolete-intent resolution preserves the local End ID.
@discardableResult
public func queueRequestedEnd() throws -> OwnerAuthorityMutation {
let view = try checkLive(); try require(.phone)
guard let retained = journal.phonePractice, let endID = retained.endRequestID else { throw OwnerChannelError.localRestriction }
if let pending = view.pending {
guard pending.mutation.retiredPracticeID == retained.practiceID else { throw OwnerChannelError.intentOutstanding }
guard !pending.requiresResolution else { throw OwnerChannelError.resolutionRequired }
return pending.mutation
}
guard let owner = view.tip, retained.matches(owner) else { throw OwnerChannelError.resolutionRequired }
var wireID = UUID()
while wireID == endID { wireID = UUID() }
let command = try OwnerAuthorityMutation.retirePractice(from: owner, practiceID: retained.practiceID, mutationID: wireID)
try request(command)
return command
}

/// A rejected second narrowing request raises a durable LOCAL fence but saves no second command.
    public func request(_ mutation: OwnerAuthorityMutation) throws {
        let view = try checkLive(); try require(.phone)
        if let pending = view.pending {
            if mutation == pending.mutation || mutation == journal.intent?.mutation { return }
            if let original = journal.intent?.originalDigest, mutation.id == pending.mutation.id,
               try mutation.canonicalDigest == original { return }
        }
        var before = view.tip
        if before == nil, let pending = view.pending, pending.dispatched,
           pending.mutation.kind == .enroll, mutation.isRestrictive {
            // A sent enrollment can still be narrowed locally. Its proposed state never authorizes a second command.
            before = try pending.mutation.resolve(from: nil)
        }
        let next = try mutation.resolve(from: before)
        try validateLocal(next)
        if view.pending != nil {
            var candidate = journal
            candidate.fence = Self.stronger(candidate.fence, Self.restriction(mutation))
            if candidate != journal { try commit(candidate) }
            throw OwnerChannelError.intentOutstanding
        }
        guard journal.entries.isEmpty else { throw OwnerChannelError.integrity("uncheckpointed phone history") }
        var candidate = journal
        candidate.intent = OwnerChannelIntent(mutation: mutation, dispatched: false)
        try commit(candidate)
    }

    /// Durable dispatch precedes transport submission. A retry preserves both the human decision and sent status.
    public func dispatchPending() throws -> OwnerAuthorityMutation {
        let view = try checkLive(); try require(.phone)
        guard let pending = view.pending, !pending.requiresResolution else { throw OwnerChannelError.resolutionRequired }
        if !pending.dispatched {
            var candidate = journal; candidate.intent?.dispatched = true
            try commit(candidate)
        }
        return pending.mutation
    }

    public func cancelPending() throws {
        let view = try checkLive(); try require(.phone)
        guard let pending = view.pending else { return }
        guard !pending.dispatched else { throw OwnerChannelError.sentIntentCannotCancel }
guard view.tip != nil || journal.phonePractice == nil else { throw OwnerChannelError.localRestriction }
        try replaceIntent(nil, view: view, preserveRestriction: false)
    }

    /// Requires an explicit new human decision. Verified intervening transitions, never status/timeout, prove obsolescence.
    public func resolveObsoleteIntent(replacement: OwnerAuthorityMutation?) throws {
        let view = try checkLive(); try require(.phone)
        guard let pending = view.pending, pending.requiresResolution, !journal.entries.isEmpty else {
            throw OwnerChannelError.resolutionRequired
        }
        if let replacement {
            guard replacement.id != pending.mutation.id else { throw OwnerChannelError.conflict }
            let result = try replacement.resolve(from: view.tip); try validateLocal(result)
            guard Self.restriction(replacement).rawValue >= Self.restriction(pending.mutation).rawValue,
                  !pending.mutation.isFullWithdrawal || replacement.isFullWithdrawal else { throw OwnerChannelError.localRestriction }
            try replaceIntent(OwnerChannelIntent(mutation: replacement, dispatched: false), view: view, preserveRestriction: true)
        } else {
            let command = pending.mutation
            let satisfied: Bool
            if command.isFullWithdrawal { satisfied = view.tip?.isCollectionAllowed == false }
            else if command.isRestrictive { satisfied = view.tip?.heartRateConsent == false }
            else if let practice = command.retiredPracticeID { satisfied = try store.hasReplayGuard(scope: .practice, id: practice) }
            else { satisfied = true }
            guard satisfied else { throw OwnerChannelError.localRestriction }
            try replaceIntent(nil, view: view, preserveRestriction: false)
        }
    }

    /// Explicit human resolution of a local privacy fence already satisfied by the exact verified chain.
    /// No authority or consent is granted. An obsolete pending intent must be separately resolved first.
    public func resolveSatisfiedRestriction(expected: OwnerAuthorityAcknowledgement) throws {
        let view = try checkLive(); try require(.phone)
        guard view.pending == nil else { throw OwnerChannelError.intentOutstanding }
        guard expected == view.latest, let authority = view.tip else { throw OwnerChannelError.stale }
        let satisfied = journal.fence == .none
            || (journal.fence == .all && !authority.isCollectionAllowed)
            || (journal.fence == .heartRate && !authority.heartRateConsent)
        guard satisfied else { throw OwnerChannelError.localRestriction }
        var candidate = journal; candidate.fence = .none
        try commit(candidate)
    }

    /// Capture/context operations share the same serial owner; application code never receives the mutable O2 store.
    public func publish(_ binding: OwnerContextBinding, expectedRevision: Int64) throws -> OwnerContextPublication {
        try require(.watch)
        guard try !readSnapshot().admissionBlocked else { throw OwnerChannelError.localRestriction }
        do {
            let receipt = try store.publish(binding, expectedRevision: expectedRevision)
            _ = try checkLive()
            return receipt
        } catch {
            // A validation rejection may leave O2 healthy; ambiguous persistence poisons its owner too.
            _ = try? checkLive()
            throw error
        }
    }
    public func inspectContext(recordingID: UUID) throws -> OwnerStoredContext {
        _ = try checkLive(); return try store.inspectContext(recordingID: recordingID)
    }
    public func hasReplayGuard(scope: OwnerReplayScope, id: UUID) throws -> Bool {
        _ = try checkLive(); return try store.hasReplayGuard(scope: scope, id: id)
    }

    private func replaceIntent(_ intent: OwnerChannelIntent?, view: OwnerChannelView, preserveRestriction: Bool) throws {
        var candidate = journal
        if preserveRestriction, let pending = view.pending {
            candidate.fence = Self.stronger(candidate.fence, Self.restriction(pending.mutation))
        }
        candidate.anchor = try view.tip?.encoded(); candidate.acknowledged = view.latest
        candidate.entries = []; candidate.intent = intent
        try commit(candidate)
    }

    private func checkpointPhone() throws {
        let view = try Self.derive(journal)
        guard journal.device == .phone else { return }
        var candidate = journal
if let retained = journal.phonePractice,
journal.entries.contains(where: { $0.transition.mutation.retiredPracticeID == retained.practiceID }),
try store.hasReplayGuard(scope: .practice, id: retained.practiceID) {
candidate.phonePractice = nil
}
        if let fulfilled = view.fulfilled {
            // Only an exact mirrored restriction that covers this fence can release it. Grants never do so.
            let command = fulfilled.mutation
            if command.isFullWithdrawal || (candidate.fence == .heartRate && command.isRestrictive) { candidate.fence = .none }
            candidate.intent = nil
        } else if let pending = view.pending {
            guard pending.mutation.isRestrictive, !pending.requiresResolution, !journal.entries.isEmpty,
let retained = journal.intent else {
if candidate != journal { try commit(candidate) }
return
}
            // derive verified every consumed step as revision-only. Persist that verified new base, not an imported status.
            let original = try retained.originalDigest ?? retained.mutation.canonicalDigest
            candidate.intent = OwnerChannelIntent(mutation: pending.mutation, dispatched: pending.dispatched, originalDigest: original)
        }
        candidate.anchor = try view.tip?.encoded(); candidate.acknowledged = view.latest; candidate.entries = []
        if candidate != journal { try commit(candidate) }
    }

    private func reconcileOwner() throws {
        let view = try Self.derive(journal)
        // A public bounded O2 read also verifies its live namespace/membership; snapshot alone would miss disk replacement.
        _ = try store.hasReplayGuard(scope: .practice, id: journal.localEpoch)
        guard let node = view.nodes.firstIndex(where: { $0 == store.snapshot.authority }) else {
            throw OwnerChannelError.integrity("O2 authority is not an exact committed chain node")
        }
        for index in node..<journal.entries.count {
            let mutation = journal.entries[index].transition.mutation
            let before = view.nodes[index], expected = view.nodes[index + 1]
            guard store.snapshot.authority == before else { throw OwnerChannelError.integrity("authority changed during replay") }
            switch mutation.kind {
            case .enroll: try store.enroll(mutation.resolve(from: nil))
            case .advance:
                _ = try store.advanceAuthority(expectedRevision: mutation.beforeRevision)
            case .retirePractice:
                guard let practice = mutation.retiredPracticeID else { throw OwnerChannelError.integrity("missing retirement identity") }
                if try store.hasReplayGuard(scope: .practice, id: practice) {
                    // The committed command and EXACT before-state justify precisely this one recovery advancement.
                    _ = try store.advanceAuthority(expectedRevision: mutation.beforeRevision)
                } else {
                    _ = try store.retire(scope: .practice, id: practice, expectedRevision: mutation.beforeRevision)
                }
            default:
                guard let before else { throw OwnerChannelError.integrity("consent without authority") }
                _ = try store.apply(mutation.consentDecision(for: before))
            }
            guard store.snapshot.authority == expected else { throw OwnerChannelError.integrity("O2 returned without exact application") }
        }
        _ = try store.hasReplayGuard(scope: .practice, id: journal.localEpoch)
        guard store.snapshot.authority == view.tip else { throw OwnerChannelError.integrity("recovery tip mismatch") }
    }

    private func checkLive() throws -> OwnerChannelView {
        guard !isPoisoned else { throw OwnerChannelError.poisoned }
        do {
            guard try files.read() == expectedBytes else { throw OwnerChannelError.integrity("journal changed or missing") }
            _ = try store.hasReplayGuard(scope: .practice, id: journal.localEpoch)
            let view = try Self.derive(journal)
            guard store.snapshot.authority == view.tip else { throw OwnerChannelError.integrity("unsequenced O2 authority") }
            return view
        } catch { isPoisoned = true; throw error }
    }

    private func commit(_ candidate: OwnerChannelJournal) throws {
        _ = try Self.derive(candidate)
let bytes = try encode(candidate)
        guard bytes != expectedBytes else { return }
        do {
            try files.replace(bytes, expected: expectedBytes.isEmpty ? nil : expectedBytes, fault: writeFault)
            journal = candidate; expectedBytes = bytes
        } catch { isPoisoned = true; throw error }
    }

    private func require(_ device: OwnerPracticeDevice) throws {
        guard journal.device == device else { throw OwnerChannelError.wrongRole }
    }
    private func validateLocal(_ authority: OwnerPracticeIdentity) throws {
        let local = journal.device == .phone ? authority.phoneInstallationEpoch : authority.watchInstallationEpoch
        guard local == journal.localEpoch else { throw OwnerChannelError.stale }
    }
    private func normalCapacity(_ state: OwnerChannelJournal, bytes: Int, authority: OwnerPracticeIdentity?, prospective: Bool = false) -> Bool {
        let revisionReserve: Int64 = authority?.isCollectionAllowed == true ? (authority?.heartRateConsent == true ? 3 : 2) : 0
        let additional = prospective ? 1 : 0
        return state.entries.count + additional <= Self.maximumTransitions - 3
&& bytes + Self.endReserve(state) + (3 + additional) * Self.reservedEntryBytes + Self.anchorAllowance <= maximumJournalBytes
            && (authority?.revision ?? 0) + Int64(additional) <= OwnerPracticeIdentity.maximumRevision - revisionReserve
    }
    private static func restriction(_ command: OwnerAuthorityMutation) -> OwnerLocalRestriction {
        if command.isFullWithdrawal { return .all }
        return command.isRestrictive ? .heartRate : .none
    }
    private static func stronger(_ lhs: OwnerLocalRestriction, _ rhs: OwnerLocalRestriction) -> OwnerLocalRestriction {
        lhs.rawValue >= rhs.rawValue ? lhs : rhs
    }
    private static func eligibleReserve(_ command: OwnerAuthorityMutation, before: OwnerPracticeIdentity?) -> OwnerChannelReserve? {
        if command.retiredPracticeID != nil { return .end }
        if command.isFullWithdrawal, before?.isCollectionAllowed == true { return .withdraw }
        if command.isRestrictive, before?.heartRateConsent == true { return .disable }
        return nil
    }
private static func endReserve(_ state: OwnerChannelJournal) -> Int {
state.phonePractice != nil && state.phonePractice?.endRequestID == nil ? 64 : 0
}
private func encode(_ state: OwnerChannelJournal) throws -> Data {
try OwnerCanonical.encode(state, domain: "PSLOwnerChannel2", limit: maximumJournalBytes - Self.endReserve(state))
    }

    private static func derive(_ state: OwnerChannelJournal) throws -> OwnerChannelView {
        guard state.version == 2, state.entries.count <= maximumTransitions,
              state.device == .phone || (state.intent == nil && state.fence == .none) else { throw OwnerChannelError.integrity("journal shape") }
        let anchor = try state.anchor.map(OwnerPracticeIdentity.decode)
        if let anchor, let ack = state.acknowledged {
            try ack.validate()
            guard ack.ownerID == anchor.ownerID, ack.phoneEpoch == anchor.phoneInstallationEpoch,
                  ack.watchEpoch == anchor.watchInstallationEpoch, ack.sequence == anchor.revision,
                  try ack.authorityDigest == OwnerAuthorityMutation.digest(anchor) else { throw OwnerChannelError.integrity("anchor acknowledgement") }
        } else if anchor != nil || state.acknowledged != nil { throw OwnerChannelError.integrity("missing anchor/high-water") }
        var current = anchor, nodes: [OwnerPracticeIdentity?] = [anchor]
        var effective = state.intent?.mutation, stale = false, fulfilled: OwnerAuthorityTransition?
        if let effective {
            let pendingOwner = try effective.resolve(from: anchor)
            let local = state.device == .phone ? pendingOwner.phoneInstallationEpoch : pendingOwner.watchInstallationEpoch
            guard local == state.localEpoch else { throw OwnerChannelError.integrity("foreign pending enrollment") }
            if let original = state.intent?.originalDigest {
                guard effective.isRestrictive, original.utf8.count == 64,
                      original.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
                    throw OwnerChannelError.integrity("invalid original restriction fingerprint")
                }
            }
        }
        var ids = Set<UUID>(), reserves = Set<OwnerChannelReserve>()
        for (index, entry) in state.entries.enumerated() {
            let transition = entry.transition, mutation = transition.mutation
            _ = try transition.encoded()
            guard ids.insert(mutation.id).inserted, transition.sequence == (current?.revision ?? 0) + 1 else {
                throw OwnerChannelError.integrity("duplicate or skipped transition")
            }
            if let reserve = entry.reserve {
                guard state.device == .watch, reserves.insert(reserve).inserted,
                      eligibleReserve(mutation, before: current) == reserve else { throw OwnerChannelError.integrity("reserved operation") }
            }
            let result = try mutation.resolve(from: current)
            if let pending = effective {
                if pending.id == mutation.id {
                    guard !stale, pending == mutation, index == state.entries.count - 1 else { throw OwnerChannelError.conflict }
                    fulfilled = transition
                } else if !stale, pending.isRestrictive, mutation.isRevisionOnly {
                    effective = try pending.rebasingRestriction(afterVerifiedRevisionOnlyChangesTo: result)
                } else { stale = true }
            }
            current = result; nodes.append(result)
        }
        if let current {
            let local = state.device == .phone ? current.phoneInstallationEpoch : current.watchInstallationEpoch
            guard local == state.localEpoch else { throw OwnerChannelError.integrity("foreign journal owner") }
        }
if let retained = state.phonePractice {
var scope = current
if scope == nil, state.intent?.mutation.kind == .enroll { scope = try state.intent?.mutation.resolve(from: nil) }
guard state.device == .phone, retained.phoneEpoch == state.localEpoch,
retained.practiceID != retained.preparationID, let scope, retained.matches(scope),
try PracticeSetupJSON.encode(retained).count <= 512 else { throw OwnerChannelError.integrity("phone lifecycle scope or shape") }
if let endID = retained.endRequestID {
let aliasesLocalEnd: (OwnerAuthorityMutation) -> Bool = { mutation in
mutation.retiredPracticeID == retained.practiceID && mutation.id == endID
}
guard state.intent.map({ !aliasesLocalEnd($0.mutation) }) ?? true,
!state.entries.contains(where: { aliasesLocalEnd($0.transition.mutation) }) else {
throw OwnerChannelError.conflict
}
}
}
        if state.device == .watch, state.entries.count + 3 - reserves.count > maximumTransitions { throw OwnerChannelError.capacity }
        let pending = effective.map { OwnerPendingIntent(mutation: $0, dispatched: state.intent?.dispatched == true, requiresResolution: stale) }
        let latest = try state.entries.last.map { try OwnerAuthorityAcknowledgement(transition: $0.transition) } ?? state.acknowledged
        return OwnerChannelView(nodes: nodes, pending: pending, fulfilled: fulfilled, latest: latest)
    }
}

private enum OwnerChannelReserve: String, Codable { case end, disable, withdraw }
private struct OwnerChannelEntry: Codable, Equatable {
    let transition: OwnerAuthorityTransition
    var reserve: OwnerChannelReserve?
}
private struct OwnerChannelIntent: Codable, Equatable {
    let mutation: OwnerAuthorityMutation
    var dispatched: Bool
    var originalDigest: String? = nil
}
private struct OwnerChannelJournal: Codable, Equatable {
    let version: Int
    let localEpoch: UUID
    let device: OwnerPracticeDevice
    var anchor: Data?
    var acknowledged: OwnerAuthorityAcknowledgement?
    var entries: [OwnerChannelEntry]
    var intent: OwnerChannelIntent?
    var fence: OwnerLocalRestriction
var phonePractice: OwnerPhonePracticeLifecycle? = nil
}
private struct OwnerChannelView {
    let nodes: [OwnerPracticeIdentity?]
    let pending: OwnerPendingIntent?
    let fulfilled: OwnerAuthorityTransition?
    let latest: OwnerAuthorityAcknowledgement?
    var tip: OwnerPracticeIdentity? { nodes.last ?? nil }
}

/// Descriptor-relative, bounded, exclusive journal file. Uncommitted temporaries are preserved and block reopening.
private final class OwnerJournalFiles {
    private let base: URL
    private let baseFD: Int32
    private let rootFD: Int32
    private let lockFD: Int32
    init(base: URL, intent: OwnerPracticeStoreIntent) throws {
        guard base.isFileURL, !base.pathComponents.contains("Recordings"),
              !base.pathComponents.contains(PracticeSetupChannel.directoryName),
              !base.pathComponents.contains(OwnerPracticeStore.directoryName) else { throw OwnerChannelError.invalid("separate channel namespace") }
        let baseDescriptor = try AnnotationFiles.root(base)
        var root: Int32 = -1, lock: Int32 = -1
        do {
            let create = intent == .createNew
            if create, mkdirat(baseDescriptor, PracticeSetupChannel.directoryName, 0o700) != 0 { throw AnnotationFiles.error("create channel") }
            root = try AnnotationFiles.directory(PracticeSetupChannel.directoryName, parent: baseDescriptor, create: false)
            lock = openat(root, ".lock", O_RDWR | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | (create ? O_CREAT | O_EXCL : 0), 0o600)
            guard lock >= 0 else { throw AnnotationFiles.error("open channel lock") }
            try Self.lockFile(lock)
            guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw OwnerChannelError.busy }
            if create { try AnnotationFiles.sync(baseDescriptor) }
            // Transfer descriptor ownership only after every throwing initializer operation.
            self.base = base; baseFD = baseDescriptor; rootFD = root; lockFD = lock
        } catch {
            if lock >= 0 { flock(lock, LOCK_UN); close(lock) }
            if root >= 0 { close(root) }
            close(baseDescriptor); throw error
        }
    }
    deinit { flock(lockFD, LOCK_UN); close(lockFD); close(rootFD); close(baseFD) }

    func read(allowsMissing: Bool = false) throws -> Data? {
        try ownership()
        let names = Set(try AnnotationFiles.names(rootFD, limit: 3))
        guard names.isSubset(of: [".lock", "journal.json", "journal.pending"]), names.contains(".lock"),
              allowsMissing || names.contains("journal.json") else { throw OwnerChannelError.integrity("journal entries") }
        if names.contains("journal.pending") {
            _ = try AnnotationFiles.read("journal.pending", directory: rootFD, limit: PracticeSetupChannel.maximumBytes)
            throw OwnerChannelError.integrity("uncommitted journal preserved; admission blocked")
        }
        let result = try AnnotationFiles.read("journal.json", directory: rootFD, limit: PracticeSetupChannel.maximumBytes)
        try ownership()
        return result
    }

    func replace(_ bytes: Data, expected: Data?, fault: ((OwnerChannelStage) throws -> Void)?) throws {
        guard try read(allowsMissing: expected == nil) == expected else { throw OwnerChannelError.integrity("journal changed before write") }
        let descriptor = openat(rootFD, "journal.pending", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw AnnotationFiles.error("create journal temporary") }
        defer { close(descriptor) }
        try AnnotationFiles.write(bytes, fd: descriptor)
        try AnnotationFiles.sync(descriptor)
        try fault?(.temporarySynced)
        try ownership()
        let (namedTemporary, _) = try AnnotationFiles.openFile("journal.pending", directory: rootFD)
        defer { close(namedTemporary) }
        try Self.same(descriptor, namedTemporary, kind: S_IFREG)
        guard try AnnotationFiles.read("journal.pending", directory: rootFD, limit: PracticeSetupChannel.maximumBytes) == bytes,
              try AnnotationFiles.read("journal.json", directory: rootFD, limit: PracticeSetupChannel.maximumBytes) == expected else {
            throw OwnerChannelError.integrity("journal replaced during publication")
        }
        guard renameat(rootFD, "journal.pending", rootFD, "journal.json") == 0 else { throw AnnotationFiles.error("publish journal") }
        try fault?(.published)
        try AnnotationFiles.sync(rootFD)
        try fault?(.directorySynced)
        guard try read() == bytes else { throw OwnerChannelError.integrity("journal changed before acknowledgement") }
    }

    func synchronize(expected: Data, fault: ((OwnerChannelStage) throws -> Void)?) throws {
        guard try read() == expected else { throw OwnerChannelError.integrity("journal changed before recovery") }
        let (descriptor, _) = try AnnotationFiles.openFile("journal.json", directory: rootFD)
        defer { close(descriptor) }
        try AnnotationFiles.sync(descriptor)
        try fault?(.recoveryFileSynced)
        try AnnotationFiles.sync(rootFD)
        try fault?(.recoveryDirectorySynced)
        let (named, _) = try AnnotationFiles.openFile("journal.json", directory: rootFD)
        defer { close(named) }
        try Self.same(descriptor, named, kind: S_IFREG)
        guard try read() == expected else { throw OwnerChannelError.integrity("journal changed during recovery") }
    }

    private func ownership() throws {
        let namedBase = try AnnotationFiles.root(base)
        defer { close(namedBase) }
        try Self.same(baseFD, namedBase, kind: S_IFDIR)
        let namedRoot = try AnnotationFiles.directory(PracticeSetupChannel.directoryName, parent: baseFD, create: false)
        defer { close(namedRoot) }
        try Self.same(rootFD, namedRoot, kind: S_IFDIR)
        let (namedLock, size) = try AnnotationFiles.openFile(".lock", directory: rootFD)
        defer { close(namedLock) }
        guard size == 0 else { throw OwnerChannelError.integrity("channel lock contents") }
        try Self.lockFile(lockFD)
        try Self.same(lockFD, namedLock, kind: S_IFREG)
    }
    private static func same(_ held: Int32, _ named: Int32, kind: mode_t) throws {
        var first = stat(), second = stat()
        guard fstat(held, &first) == 0, fstat(named, &second) == 0,
              first.st_mode & S_IFMT == kind, second.st_mode & S_IFMT == kind,
              first.st_dev == second.st_dev, first.st_ino == second.st_ino else { throw OwnerChannelError.integrity("channel filesystem identity") }
    }
    private static func lockFile(_ fd: Int32) throws {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1, info.st_size == 0 else {
            throw OwnerChannelError.integrity("channel lock type")
        }
    }
}
