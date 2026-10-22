import Foundation
import Observation
import PadelCore

@MainActor @Observable
final class PracticeSetupModel {
    enum Status { case reviewRequired, saved, pending, offline, acceptedCurrent, acceptedNext, endPending, withdrawn, failed }
    private(set) var status = Status.reviewRequired
    private(set) var choices = PracticeSetupPreferences(currentRacketArm: .right, usualHand: .right, intendedDrill: .forehandGroundstroke)
    private(set) var ownerConfirmed = false
    private(set) var motionConsent = false
    private(set) var heartRateConsent = false
    private(set) var stored: PracticeSetupPersistentState?
    private(set) var channel: OwnerChannelSnapshot?
    private(set) var observation: OwnerPreparationObservation?
    private(set) var acceptedCurrent: OwnerPreparation?
    private(set) var acceptedNext: OwnerPreparation?
    private(set) var lastError: String?
    private(set) var busy = false
    private let worker: PhoneSetupWorker
    private let base: URL
    private let connectivity: RecordingConnectivity?
    private let fence: PhoneSetupFence
    private let beforeReplyCommit: (@Sendable (OwnerPreparationMessage) async -> Void)?
    var beforeConsentPersistence: (@Sendable () async -> Void)?
    var beforePracticeRename: (@Sendable () -> Void)?
    var afterPracticeRename: (@Sendable () -> Void)?
    var beforePracticeDeletion: (@MainActor () async -> Void)?
    var practiceDeletionFault: (@Sendable (OwnerPracticeDeletionStage) throws -> Void)?
    private var input = UUID()
    private var published: UInt64 = 0
    private var loaded = false
    private var loading = false
    private var endRequested = false
    private var withdrawalRequested = false
    private var mutationInFlight = false
    private var statusRequest: UUID?
    private var requests: [UUID: PhoneSetupRequest] = [:]

    init(base: URL, connectivity: RecordingConnectivity?,
         beforeReplyCommit: (@Sendable (OwnerPreparationMessage) async -> Void)? = nil) {
        self.base = base; worker = PhoneSetupWorker(base: base)
        self.connectivity = connectivity
        fence = PhoneSetupFence(ingress: connectivity?.practiceDeletionIngress)
        self.beforeReplyCommit = beforeReplyCommit
        // The library registers this before activating its sole WCSession delegate.
        connectivity?.onOwnerPreparation = { [weak self] message, work in
            guard let self else { throw OwnerTransportFailure.cancelled }
            return try await self.receive(message, work: work)
        }
    }

    var canPrepare: Bool { loaded && !busy && ownerConfirmed && motionConsent && !endRequested && !withdrawalRequested }
    var canEnd: Bool { channel?.phonePractice != nil && !endRequested }
    var needsResolution: Bool { channel?.pending?.requiresResolution == true || (channel?.unqueuedRestriction ?? .none) != .none }
    var statusText: String {
        switch status {
        case .reviewRequired: "Review your choices, then prepare on Watch."
        case .saved: "Choices saved on iPhone. Review them before preparing on Watch."
        case .pending: "Setup pending. Waiting for a verified Watch reply."
        case .offline: stored?.preferences == nil
            ? "Watch unavailable. Review your choices and retry when connected."
            : "Watch unavailable. Your choices are saved on iPhone; preparation is still pending."
        case .acceptedCurrent: "Watch accepted this setup. Complete the physical check and Start on Watch."
        case .acceptedNext: "Watch accepted the next set. The current set keeps its original selection."
        case .endPending: "End pending. Watch may still be recording until it confirms End."
        case .withdrawn: "Motion consent withdrawn. Watch shutdown may still be pending while disconnected."
        case .failed: endRequested
            ? "End could not be saved. Watch may still be recording. Use its local stop control."
            : "Setup could not be completed. Review the error before retrying."
        }
    }

    func load() async {
        guard !loaded && !loading else { return }
        loading = true; defer { loading = false }
        let initialInput = input
        do {
            let value = try await worker.read()
            publish(value); loaded = true
            if initialInput == input { choices = value.stores.preferences ?? value.stores.latestDraft?.preferences ?? choices }
            endRequested = value.channel.phonePractice?.endRequestID != nil
            withdrawalRequested = value.channel.unqueuedRestriction == .all
            status = endRequested ? .endPending : withdrawalRequested ? .pending : .reviewRequired
            connectivity?.resumePracticeDeletions()
        } catch { fail(error) }
    }

    func updateChoices(_ value: PracticeSetupPreferences) {
        guard [.forehandGroundstroke, .backhandGroundstroke].contains(value.intendedDrill), value != choices else { return }
        choices = value; invalidate(keepRunning: true)
        let token = input
        let expected = fence.current, liveFence = fence
        Task {
            do {
                let snapshot = try await worker.run { setup, channel in
                    if liveFence.matches(expected) { try setup.savePreferences(value) }
                    return try PhoneSetupStores(setup, channel)
                }
                publish(snapshot)
                if token == input && !endRequested && !withdrawalRequested { status = .saved }
            } catch { if token == input { fail(error) } }
        }
    }

    func setConsent(ownerConfirmed: Bool, motion: Bool, heartRate: Bool) {
        guard self.ownerConfirmed != ownerConfirmed || motionConsent != motion || heartRateConsent != heartRate else { return }
        let narrowMotion = (self.ownerConfirmed && !ownerConfirmed) || (motionConsent && !motion)
        let narrowHeartRate = heartRateConsent && !heartRate
        self.ownerConfirmed = ownerConfirmed; motionConsent = motion; heartRateConsent = heartRate
        invalidate(keepRunning: false)
        if narrowMotion, channel?.authority != nil || channel?.pending != nil { _ = withdrawMotionConsent() }
        else if narrowHeartRate, channel?.authority != nil || channel?.pending != nil {
            let restriction = fence.restrict(.heartRate, owner: channel?.authority)
            Task { await restrictCollection(motion: false, token: restriction) }
        }
    }

    func refreshWatch() async {
        if !loaded { await load() }
        guard let epoch = stored?.localInstallationEpoch else { return }
        let id = UUID(), requestInput = input; statusRequest = id
        do { try await send(.statusRequest(requestID: id, phoneEpoch: epoch)) }
        catch {
            guard id == statusRequest else { return }
            do { publish(try await worker.read()) }
            catch {
                guard id == statusRequest, requestInput == input else { return }
                observation = nil
                if !endRequested && !withdrawalRequested { fail(error) }
                else { handle(error) }
                return
            }
            guard id == statusRequest, requestInput == input else { return }
            observation = nil; fence.advance(); acceptedCurrent = nil; acceptedNext = nil
            lastError = error.localizedDescription
            if !endRequested && !withdrawalRequested { status = .offline }
        }
    }

    func reviewAndPrepare() async {
        guard canPrepare else { return }
        busy = true; defer { busy = false }
        let reviewed = input, reviewedChoices = choices, includesHR = heartRateConsent
        lastError = nil; status = .pending
        do {
            await refreshWatch()
            guard reviewed == input, ownerConfirmed, motionConsent else { return }
            guard let peer = observation, peer.state != .unavailable,
                  peer.capability == .supported, peer.storage == .available else { throw PhoneSetupFailure.watchUnavailable }
            let staged = try await worker.stage(choices: reviewedChoices, heartRate: includesHR, peer: peer,
                fence: fence, expected: fence.current)
            publish(staged)
            if reviewed != input {
                if !ownerConfirmed || !motionConsent { await withdrawMotionConsent().value }
                else if includesHR && !heartRateConsent { await restrictCollection(motion: false) }
                else { try await drivePending() }
                return
            }
            // A durably dispatched earlier human decision still needs reconciliation after an edit or End.
            try await drivePending()
            guard reviewed == input, !endRequested, !withdrawalRequested else { return }
            await refreshWatch()
            guard reviewed == input, let observed = observation else { return }
            let prepared = try await worker.preparation(choices: reviewedChoices)
            publish(prepared.snapshot)
            guard reviewed == input, !endRequested, !withdrawalRequested else { return }
            let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: observed.generations,
                preparation: prepared.value.identity)
            status = .pending
            try await send(.prepare(correlation: correlation, preparation: prepared.value))
        } catch {
            // A capacity failure can follow durable lifecycle creation without poisoning the stores.
            do { publish(try await worker.read()) }
            catch {
                if reviewed == input { fail(error) }
                return
            }
            if reviewed == input { handle(error) }
        }
    }

    /// The visible denial precedes both the serial executor hop and any persistence failure.
    @discardableResult func endPractice() -> Task<Void, Never> {
        endRequested = true; invalidate(keepRunning: false); status = .endPending
        return Task {
            do {
                publish(try await worker.run { setup, channel in
                    guard let life = try channel.readSnapshot().phonePractice else { throw PhoneSetupFailure.noPractice }
                    try channel.requestPhoneEnd(practiceID: life.practiceID, requestID: life.endRequestID ?? UUID())
                    return try PhoneSetupStores(setup, channel)
                })
                if !mutationInFlight { try await drivePending() }
                finishRestriction()
            } catch { handle(error, persistence: channel?.phonePractice?.endRequestID == nil) }
        }
    }

    @discardableResult func withdrawMotionConsent() -> Task<Void, Never> {
        motionConsent = false; withdrawalRequested = true
        invalidate(keepRunning: false); status = .pending
        let restriction = fence.restrict(.all, owner: channel?.authority)
        return Task { await restrictCollection(motion: true, token: restriction) }
    }

    func retryPending() async {
        guard loaded, !mutationInFlight else { return }
        do {
            await refreshWatch()
            try await replayVerifiedTransitions()
            try await drivePending()
            if let ack = channel?.latest { try await sendAcknowledgement(ack) }
            finishRestriction()
        } catch { handle(error) }
    }

    /// This button is a new explicit decision; retries and status cannot drop obsolete intent.
    func resolveObsoleteIntent() async {
        invalidate(keepRunning: false)
        do {
            publish(try await worker.run { setup, channel in
                let state = try channel.readSnapshot()
                if let pending = state.pending, pending.requiresResolution {
                    let replacement: OwnerAuthorityMutation?
                    if let owner = state.authority, pending.mutation.isFullWithdrawal && owner.isCollectionAllowed {
                        replacement = try .withdraw(from: owner, decisionID: UUID(), confirmedAtUnixSeconds: Date().timeIntervalSince1970)
                    } else if let owner = state.authority, pending.mutation.isRestrictive && owner.heartRateConsent {
                        replacement = try .heartRate(from: owner, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: Date().timeIntervalSince1970)
                    } else if let practice = pending.mutation.retiredPracticeID, let life = state.phonePractice {
                        guard let owner = state.authority, let localEnd = life.endRequestID,
                              life.practiceID == practice, life.ownerID == owner.ownerID,
                              life.phoneEpoch == owner.phoneInstallationEpoch,
                              life.watchEpoch == owner.watchInstallationEpoch else { throw PhoneSetupFailure.reviewRequired }
                        var wireID = UUID()
                        while wireID == localEnd || wireID == pending.mutation.id { wireID = UUID() }
                        replacement = try .retirePractice(from: owner, practiceID: practice, mutationID: wireID)
                    } else { replacement = nil }
                    try channel.resolveObsoleteIntent(replacement: replacement)
                }
                return try PhoneSetupStores(setup, channel)
            })
            try await drivePending()
            publish(try await worker.run { setup, channel in
                let state = try channel.readSnapshot()
                if state.pending == nil, let ack = state.latest,
                   state.unqueuedRestriction == .all && state.authority?.isCollectionAllowed == false
                    || state.unqueuedRestriction == .heartRate && state.authority?.heartRateConsent == false {
                    try channel.resolveSatisfiedRestriction(expected: ack)
                }
                return try PhoneSetupStores(setup, channel)
            })
            finishRestriction()
        } catch { handle(error) }
    }

    private func restrictCollection(motion: Bool, token: UUID? = nil) async {
        let restriction = token ?? fence.restrict(motion ? .all : .heartRate, owner: channel?.authority)
        await beforeConsentPersistence?()
        do {
            publish(try await worker.run { setup, channel in
                let state = try channel.readSnapshot()
                let owner = try state.authority ?? state.pending?.mutation.resolve(from: nil)
                guard let owner else { throw PhoneSetupFailure.reviewRequired }
                let command = try motion
                    ? OwnerAuthorityMutation.withdraw(from: owner, decisionID: UUID(), confirmedAtUnixSeconds: Date().timeIntervalSince1970)
                    : .heartRate(from: owner, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: Date().timeIntervalSince1970)
                do { try channel.request(command) }
                catch OwnerChannelError.intentOutstanding { /* The channel durably raised the narrowing fence. */ }
                return try PhoneSetupStores(setup, channel)
            })
            fence.reconciled(restriction)
            if !mutationInFlight { try await drivePending() }
            finishRestriction()
        } catch { handle(error) }
    }

    private func drivePending() async throws {
        guard !mutationInFlight else { return }
        mutationInFlight = true; defer { mutationInFlight = false }
        for _ in 0..<8 {
            let staged = try await worker.run { setup, channel -> PhoneSetupValue<OwnerAuthorityMutation?> in
                var state = try channel.readSnapshot()
                if state.pending?.requiresResolution == true { throw OwnerChannelError.resolutionRequired }
                if state.pending == nil, let owner = state.authority {
                    if state.unqueuedRestriction == .all && owner.isCollectionAllowed {
                        try channel.request(.withdraw(from: owner, decisionID: UUID(), confirmedAtUnixSeconds: Date().timeIntervalSince1970))
                    } else if state.unqueuedRestriction == .heartRate && owner.heartRateConsent {
                        try channel.request(.heartRate(from: owner, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: Date().timeIntervalSince1970))
                    } else if state.phonePractice?.endRequestID != nil { _ = try channel.queueRequestedEnd() }
                    state = try channel.readSnapshot()
                }
                let mutation = try state.pending == nil ? nil : channel.dispatchPending()
                return PhoneSetupValue(snapshot: try PhoneSetupStores(setup, channel), value: mutation)
            }
            publish(staged.snapshot)
            guard let command = staged.value else { return }
            guard let observed = observation, observed.watchEpoch == command.watchEpoch else { throw PhoneSetupFailure.watchUnavailable }
            try await send(.mutate(requestID: UUID(), generations: observed.generations, mutation: command))
            // End/withdrawal arriving during a different in-flight decision waits for explicit retry.
            if endRequested && command.kind != .retirePractice { return }
        }
        throw PhoneSetupFailure.limit
    }

    private func replayVerifiedTransitions() async throws {
        for _ in 0..<64 {
            guard let owner = channel?.authority, let peer = observation?.authority,
                  peer.ownerID == owner.ownerID, peer.watchInstallationEpoch == owner.watchInstallationEpoch,
                  peer.revision > owner.revision else { return }
            let cursor = try OwnerAuthorityReplayCursor(ownerID: owner.ownerID, phoneEpoch: owner.phoneInstallationEpoch,
                watchEpoch: owner.watchInstallationEpoch, after: channel?.latest)
            let revision = owner.revision
            try await send(.replay(requestID: UUID(), cursor: cursor))
            guard channel?.authority?.revision != revision else { throw PhoneSetupFailure.reviewRequired }
        }
        throw PhoneSetupFailure.limit
    }

    private func send(_ message: OwnerPreparationMessage) async throws {
        guard let connectivity, let id = message.requestID else { throw PhoneSetupFailure.watchUnavailable }
        requests[id] = PhoneSetupRequest(message: message, fence: fence.current)
        defer { requests.removeValue(forKey: id) }
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OwnerPreparationMessage, any Error>) in
            connectivity.sendOwnerRequest(message) { continuation.resume(with: $0.mapError { $0 as any Error }) }
        }
    }

    private func sendAcknowledgement(_ ack: OwnerAuthorityAcknowledgement) async throws {
        guard let connectivity else { throw PhoneSetupFailure.watchUnavailable }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connectivity.queueOwnerControl(.acknowledge(ack)) { continuation.resume(with: $0.mapError { $0 as any Error }) }
        }
    }

    private func receive(_ message: OwnerPreparationMessage, work: OwnerPreparationWork) async throws -> OwnerPreparationMessage? {
        let request = message.requestID.flatMap { requests[$0] }
        if let request { guard message.isReply(to: request.message) else { throw OwnerTransportFailure.mismatchedReply } }
        else if case .transition = message { /* Verified contiguous owner transitions may arrive as queued control. */ }
        else { throw OwnerTransportFailure.mismatchedReply }
        let restriction = fence.restrict(message)
        await beforeReplyCommit?(message)
        let expectedObservation = observation, liveFence = fence
        let result = try await worker.run { setup, channel -> PhoneSetupValue<OwnerAuthorityAcknowledgement?> in
            try work.commit {
                var acknowledgement: OwnerAuthorityAcknowledgement?
                switch message {
                case let .applied(_, _, transition), let .transition(transition):
                    let state = try channel.readSnapshot()
                    guard state.authority != nil || state.pending?.mutation == transition.mutation else { throw PhoneSetupFailure.reviewRequired }
                    acknowledgement = try channel.mirror(transition)
                case let .replayResult(_, _, transition):
                    if let transition {
                        guard try channel.readSnapshot().authority != nil else { throw PhoneSetupFailure.reviewRequired }
                        acknowledgement = try channel.mirror(transition)
                    }
                case let .receipt(correlation, disposition, observed, _):
                    guard let request, liveFence.matches(request.fence),
                          case let .prepare(expected, preparation) = request.message,
                          correlation == expected, expectedObservation?.generations == correlation.generations,
                          expectedObservation?.watchEpoch == correlation.preparation.watchEpoch,
                          observed.generations == correlation.generations, observed.authority == preparation.authority,
                          observed.watchEpoch == preparation.authority.watchInstallationEpoch else { throw OwnerTransportFailure.cancelled }
                    let state = try channel.readSnapshot(), preferences = try setup.checkedSnapshot()
                    guard !state.admissionBlocked, state.authority == preparation.authority,
                          state.phonePractice?.practiceID == preparation.practiceID,
                          state.phonePractice?.preparationID == preparation.draft.identity.preparationID,
                          preferences.latestDraft == preparation.draft, preferences.highWater == preparation.draft.identity else {
                        throw PhoneSetupFailure.reviewRequired
                    }
                    let running = [.recording, .paused].contains(observed.state)
                    guard disposition == .acceptedNext ? running && observed.acceptedNext == preparation.identity
                        : disposition == .acceptedCurrent && !running && observed.state != .stopping && observed.acceptedCurrent == preparation.identity else {
                        throw OwnerTransportFailure.mismatchedReply
                    }
                case let .status(_, phone, _):
                    guard try setup.checkedSnapshot().localInstallationEpoch == phone else { throw OwnerTransportFailure.mismatchedReply }
                case .error: break
                default: throw OwnerTransportFailure.invalidMessage
                }
                return PhoneSetupValue(snapshot: try PhoneSetupStores(setup, channel), value: acknowledgement)
            }
        }
        if let restriction { fence.reconciled(restriction) }
        publish(result.snapshot)
        if let acknowledgement = result.value { try await sendAcknowledgement(acknowledgement) }
        switch message {
        case let .status(id, _, observed) where id == statusRequest:
            if observation.map({ $0.generations != observed.generations || $0.watchEpoch != observed.watchEpoch }) == true
                || observed.authority != channel?.authority {
                fence.advance(); acceptedCurrent = nil; acceptedNext = nil
                if !endRequested && !withdrawalRequested { status = .reviewRequired }
            }
            observation = observed
        case let .receipt(_, disposition, observed, _):
            guard let request, fence.matches(request.fence), !endRequested, !withdrawalRequested,
                  case let .prepare(_, preparation) = request.message else { return nil }
            observation = observed
            if disposition == .acceptedCurrent { acceptedCurrent = preparation; acceptedNext = nil; status = .acceptedCurrent }
            else { acceptedNext = preparation; status = .acceptedNext }
            lastError = nil
        case let .error(_, _, code): throw PhoneSetupFailure.rejected(code.rawValue)
        default: break
        }
        return nil
    }

    /// Historical evidence uses the retained checked worker, independently of capture admission.
    func publishVerifiedPractice(scope: OwnerPracticePublicationScope,
        preparedPublication: OwnerPracticePreparedPublication) async throws -> OwnerPracticeReceipt {
        guard scope == preparedPublication.scope else { throw OwnerPracticeBundleError.integrity }
        let expected = fence.current, liveFence = fence
        let before = beforePracticeRename, after = afterPracticeRename
        let base = self.base
        let result = try await worker.run { setup, channel in
            guard try OwnerPracticeDeletion.status(base: base, practiceID: scope.practiceID) == nil else { throw OwnerPracticeBundleError.unavailable }
            let current = try channel.readSnapshot()
            try OwnerPracticePublicationPermission.require(scope, current: current)
            before?()
            try liveFence.withCurrent(expected, scope: scope) { try preparedPublication.renameForPublication() }
            after?()
            return try PhoneSetupValue(snapshot: PhoneSetupStores(setup, channel),
                value: preparedPublication.confirmPublication())
        }
        return result.value
    }

    func fencePracticeDeletion(_ practiceID: UUID) {
        fence.delete(practiceID); connectivity?.fencePracticeDeletion(practiceID)
    }
    func deletePractice(_ practiceID: UUID, command: OwnerPracticeDeletionCommand? = nil) async throws -> OwnerPracticeDeletionAcknowledgment {
        if let command, let authority = channel?.authority { try command.requireOwner(authority) }
        fencePracticeDeletion(practiceID)
        await beforePracticeDeletion?()
        try Task.checkCancellation()
        let base = self.base, fault = practiceDeletionFault
        let result = try await worker.run { setup, channel in
            guard let authority = try channel.readSnapshot().authority else { throw PhoneSetupFailure.reviewRequired }
            let selected = try command ?? OwnerPracticeDeletion.makeCommand(base: base, authority: authority, practiceID: practiceID, requester: .phone)
            guard selected.practiceID == practiceID else { throw OwnerPracticeBundleError.integrity }
            try selected.requireOwner(authority)
            let acknowledgment = try OwnerPracticeDeletion.perform(command: selected, base: base, device: .phone, channel: channel, fault: fault)
            return try PhoneSetupValue(snapshot: PhoneSetupStores(setup, channel), value: acknowledgment)
        }
        publish(result.snapshot)
        connectivity?.resumePracticeDeletions()
        return result.value
    }

    private func publish(_ snapshot: PhoneSetupStores) {
        guard snapshot.serial > published else { return }
        if channel?.authority != snapshot.channel.authority {
            fence.advance(); acceptedCurrent = nil; acceptedNext = nil
            if !endRequested && !withdrawalRequested { status = .reviewRequired }
        }
        published = snapshot.serial; stored = snapshot.stores; channel = snapshot.channel
        if snapshot.channel.phonePractice?.endRequestID != nil { endRequested = true }
        if snapshot.channel.admissionBlocked { acceptedNext = nil }
    }

    private func invalidate(keepRunning: Bool) {
        input = UUID(); fence.advance(); acceptedNext = nil
        if !keepRunning || observation.map({ ![.recording, .paused].contains($0.state) }) != false { acceptedCurrent = nil }
        lastError = nil
        status = endRequested ? .endPending : .reviewRequired
    }

    private func finishRestriction() {
        if endRequested {
            if channel?.phonePractice == nil { endRequested = false; status = .reviewRequired }
            else { status = .endPending }
        } else if channel?.authority?.isCollectionAllowed == false {
            withdrawalRequested = false; status = .withdrawn
        } else if withdrawalRequested { status = .pending }
        else if acceptedCurrent == nil && acceptedNext == nil { status = .reviewRequired }
    }

    private func handle(_ error: any Error, persistence: Bool = false) {
        lastError = error.localizedDescription
        if persistence { fail(error) }
        else if endRequested { status = .endPending }
        else if withdrawalRequested { status = .pending }
        else if let transport = error as? OwnerTransportFailure,
                [.unavailable, .busy, .timedOut, .cancelled].contains(transport) { status = .offline }
        else if (error as? PhoneSetupFailure) == .watchUnavailable { status = .offline }
        else { fail(error) }
    }
    private func fail(_ error: any Error) {
        lastError = error.localizedDescription; status = .failed
        acceptedCurrent = nil; acceptedNext = nil; fence.advance()
    }

    #if DEBUG
    func closeForTesting() async {
        connectivity?.onOwnerPreparation = nil
        await worker.close(); loaded = false
    }
    #endif
}

private nonisolated enum PhoneSetupFailure: Error, Equatable, LocalizedError {
    case watchUnavailable, reviewRequired, noPractice, limit, closed, rejected(String)
    var errorDescription: String? {
        switch self {
        case .watchUnavailable: "Open the paired Watch app and retry. No remote Start was sent."
        case .reviewRequired: "Review the saved choices and pending owner decision before preparing again."
        case .noPractice: "No durable practice is available for this request."
        case .limit: "The bounded setup revision or reconciliation limit was reached."
        case .closed: "Setup storage is closed."
        case let .rejected(code): "Watch did not accept setup: \(code)."
        }
    }
}
private nonisolated struct PhoneSetupRequest: Sendable { let message: OwnerPreparationMessage; let fence: UUID }
private nonisolated final class PhoneSetupFence: @unchecked Sendable {
    private let lock = NSLock()
    private var token = UUID()
    private var restrictions: [UUID: OwnerPracticePendingRestriction] = [:]
    private var deletions: Set<UUID> = []
    private let ingress: OwnerPracticeDeletionIngress?
    init(ingress: OwnerPracticeDeletionIngress?) { self.ingress = ingress }
    func delete(_ id: UUID) { lock.withLock { deletions.insert(id); token = UUID() } }
    var current: UUID { lock.withLock { token } }
    func advance() { lock.withLock { token = UUID() } }
    func matches(_ expected: UUID) -> Bool { lock.withLock { token == expected } }
    func restrict(_ kind: OwnerLocalRestriction, owner: OwnerPracticeIdentity?) -> UUID {
        register(OwnerPracticePendingRestriction(kind: kind, owner: owner))
    }
    func restrict(_ message: OwnerPreparationMessage) -> UUID? {
        OwnerPracticePendingRestriction(message: message).map(register)
    }
    private func register(_ restriction: OwnerPracticePendingRestriction) -> UUID {
        lock.withLock { let id = UUID(); restrictions[id] = restriction; token = UUID(); return id }
    }
    func reconciled(_ id: UUID) { lock.withLock { _ = restrictions.removeValue(forKey: id) } }
    func withCurrent<T>(_ expected: UUID, scope: OwnerPracticePublicationScope, operation: () throws -> T) throws -> T {
        try lock.withLock {
            guard token == expected, !deletions.contains(scope.practiceID), !restrictions.values.contains(where: { $0.blocks(scope) }) else {
                throw OwnerPracticeBundleError.unavailable
            }
            if let ingress { return try ingress.withAllowed(scope, operation: operation) }
            return try operation()
        }
    }
}
private nonisolated protocol PhoneSetupOrdered: Sendable { var serial: UInt64 { get set } }
private nonisolated struct PhoneSetupValue<Value: Sendable>: PhoneSetupOrdered {
    var snapshot: PhoneSetupStores
    let value: Value
    var serial: UInt64 { get { snapshot.serial } set { snapshot.serial = newValue } }
}
private nonisolated struct PhoneSetupStores: PhoneSetupOrdered {
    let stores: PracticeSetupPersistentState
    let channel: OwnerChannelSnapshot
    var serial: UInt64 = 0
    init(_ setup: PracticeSetupStore, _ channel: PracticeSetupChannel) throws {
        stores = try setup.checkedSnapshot(); self.channel = try channel.readSnapshot()
    }
}

/// The only owner of the non-Sendable bootstrap and its two stores. Handles never escape withStores.
private nonisolated final class PhoneSetupWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "PadelStrokeLab.phone-owner-setup", qos: .userInitiated)
    private let base: URL
    private var bootstrap: OwnerPhoneBootstrap?
    private var serial: UInt64 = 0
    private var closed = false
    init(base: URL) { self.base = base }

    func run<T: PhoneSetupOrdered>(_ body: @escaping @Sendable (PracticeSetupStore, PracticeSetupChannel) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    guard !closed else { throw PhoneSetupFailure.closed }
                    if bootstrap == nil { bootstrap = try OwnerPhoneBootstrap(base: base) }
                    var value = try bootstrap!.withStores(body)
                    guard serial < UInt64.max else { throw PhoneSetupFailure.limit }
                    serial += 1
                    // Snapshot order remains monotonic even when main-actor continuations resume out of order.
                    value.serial = serial
                    continuation.resume(returning: value)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
    func read() async throws -> PhoneSetupStores { try await run { try PhoneSetupStores($0, $1) } }
    func close() async { await withCheckedContinuation { continuation in queue.async { [self] in
        bootstrap = nil; closed = true; continuation.resume()
    } } }

    func stage(choices: PracticeSetupPreferences, heartRate: Bool, peer: OwnerPreparationObservation,
               fence: PhoneSetupFence, expected: UUID) async throws -> PhoneSetupStores {
        try await run { setup, channel in
            guard fence.matches(expected) else { throw OwnerTransportFailure.cancelled }
            let state = try channel.readSnapshot(), preferences = try setup.checkedSnapshot()
            guard state.phonePractice?.endRequestID == nil, state.unqueuedRestriction == .none else { throw PhoneSetupFailure.reviewRequired }
            var owner = state.authority
            if owner == nil, let pending = state.pending, pending.mutation.kind == .enroll {
                owner = try pending.mutation.resolve(from: nil)
                guard owner?.heartRateConsent == heartRate else { throw OwnerChannelError.intentOutstanding }
            }
            if owner == nil {
                guard peer.authority == nil else { throw PhoneSetupFailure.reviewRequired }
                let enrollment = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: preferences.localInstallationEpoch,
                    watchInstallationEpoch: peer.watchEpoch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
                    includesHeartRate: heartRate, decisionID: UUID(), confirmedAtUnixSeconds: Date().timeIntervalSince1970,
                    policyDigest: OwnerPracticePolicy.digest)
                try channel.request(.enrollment(enrollment)); owner = enrollment
            }
            guard let owner, owner.watchInstallationEpoch == peer.watchEpoch,
                  owner.phoneInstallationEpoch == preferences.localInstallationEpoch else { throw PhoneSetupFailure.reviewRequired }
            if state.pending != nil && state.pending?.mutation.kind != .enroll { throw OwnerChannelError.intentOutstanding }
            if owner.isCollectionAllowed || state.phonePractice != nil { try Self.saveDraft(setup, channel, owner, choices) }
            if !owner.isCollectionAllowed {
                try channel.request(.reconsent(from: owner, includesHeartRate: heartRate, acknowledgesWithdrawal: true,
                    decisionID: UUID(), confirmedAtUnixSeconds: Date().timeIntervalSince1970))
            } else if owner.heartRateConsent != heartRate {
                try channel.request(.heartRate(from: owner, allowed: heartRate, decisionID: UUID(), confirmedAtUnixSeconds: Date().timeIntervalSince1970))
            }
            if try channel.readSnapshot().pending != nil { _ = try channel.dispatchPending() }
            return try PhoneSetupStores(setup, channel)
        }
    }
    func preparation(choices: PracticeSetupPreferences) async throws -> PhoneSetupValue<OwnerPreparation> {
        try await run { setup, channel in
            var state = try channel.readSnapshot()
            guard !state.admissionBlocked, let owner = state.authority else { throw PhoneSetupFailure.reviewRequired }
            if state.phonePractice == nil { try Self.saveDraft(setup, channel, owner, choices); state = try channel.readSnapshot() }
            guard let life = state.phonePractice, let draft = try setup.checkedSnapshot().latestDraft,
                  draft.identity.preparationID == life.preparationID, draft.preferences == choices else { throw PhoneSetupFailure.reviewRequired }
            return PhoneSetupValue(snapshot: try PhoneSetupStores(setup, channel),
                value: try OwnerPreparation(authority: owner, practiceID: life.practiceID, draft: draft))
        }
    }
    private static func saveDraft(_ setup: PracticeSetupStore, _ channel: PracticeSetupChannel,
                                  _ owner: OwnerPracticeIdentity, _ choices: PracticeSetupPreferences) throws {
        let retained = try channel.readSnapshot().phonePractice
        let practice = retained?.practiceID ?? UUID()
        var preparation = retained?.preparationID ?? UUID()
        while preparation == practice { preparation = UUID() }
        try channel.beginPhonePractice(practiceID: practice, preparationID: preparation, owner: owner)
        let saved = try setup.checkedSnapshot()
        let previous = max(saved.highWater?.revision ?? 0, saved.latestDraft?.identity.revision ?? 0)
        guard previous < PracticeSetupIdentity.maximumRevision else { throw PhoneSetupFailure.limit }
        let draft = try PracticeSetupDraft(originInstallationEpoch: saved.localInstallationEpoch,
            preparationID: preparation, revision: previous + 1, preferences: choices)
        try setup.savePreferences(choices)
        _ = try setup.recordExplicitPreparation(draft)
    }
}
