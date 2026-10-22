import Darwin
import Foundation
import CryptoKit
import Observation
import PadelCore

struct OwnerPhysicalConfirmation: Equatable, Sendable {
    fileprivate let id: UUID
    fileprivate let preparation: OwnerPreparationIdentity
    fileprivate let fence: UUID
    fileprivate let wrist: PlayingArm
    fileprivate let crown: String
}

struct OwnerCaptureAttempt: Equatable, Sendable {
    let id: UUID
    let recordingID: UUID
    fileprivate let fence: UUID
    fileprivate let binding: OwnerContextBinding
    fileprivate let publication: OwnerContextPublication
    var context: OwnerRecordingContext { binding.context }
}

nonisolated enum OwnerCaptureFailure: Error, Sendable {
    case unavailable, stale, unprepared, physicalCheck, resourcesOpen, duplicate, invalidMessage, closed
}

/// The retained service owns this MainActor admission authority. Disk handles stay on its worker.
@MainActor @Observable
final class OwnerCaptureCoordinator {
    private(set) var generations = PracticeSetupGenerations(runtimeGeneration: UUID(), preparationGeneration: UUID())
    private(set) var acceptedPreparation: OwnerPreparation?
    private(set) var nextPreparation: OwnerPreparation?
    private(set) var watchEpoch: UUID?
    private(set) var lastError: String?
    var onChange: (() -> Void)?
    var onInvalidation: ((String) -> Void)?
    var onPracticeRetirement: (() -> Void)?
    var onPracticeStartupInvalidation: (() -> Void)?
    var onPracticeRecovery: (() async throws -> Bool)?
    var canRetainPracticeWorkout: (() -> Bool)?
    var practiceCallbacksClosed: (() -> Bool)?
    var practiceStartupFence: UUID { fence.current }
    var onHeartRateFence: (() -> Void)?
    var onHeartRateTransition: ((OwnerPracticeIdentity, OwnerPracticeIdentity, OwnerAuthorityMutation) async throws -> Void)?
    var retainsPracticeWorkout = false
    private var sourceClosed = false
    private var carryPending = false
    private var carryAuthority: OwnerPracticeIdentity?
    private let worker: OwnerCaptureStoreWorker
    private let base: URL
    private let fence: OwnerCaptureFence
    var beforeAuthorityPersistence: (@Sendable () async -> Void)?
    var beforePracticeRename: (@Sendable () -> Void)?
    var afterPracticeRename: (@Sendable () -> Void)?
    var beforePracticeDeletion: (@MainActor () async -> Void)?
    private let afterPublication: (@MainActor (OwnerContextPublication) async -> Void)?
    private var view: OwnerCaptureStoreView?
    private var physical: OwnerPhysicalConfirmation?
    private var pending: UUID?
    private var active: OwnerCaptureAttempt?
    private var admitted = false
    private var closing = false
    private var writerClosed = false
    private var nativeClosed = false
    private var recoveryBlocked = false
    private var usedRecordings: Set<UUID> = []
    private var retiredPreparations: [OwnerPreparationIdentity] = []
    private var state: PracticeSetupWatchState = .idle
    private var wrist: PracticeSetupWrist = .unknown
    private var crown: PracticeSetupCrown = .unknown
    private var capability: PracticeSetupCapability = .unknown

    init(base: URL, afterPublication: (@MainActor (OwnerContextPublication) async -> Void)? = nil,
         deletionIngress: OwnerPracticeDeletionIngress? = nil) {
        self.base = base
        fence = OwnerCaptureFence(ingress: deletionIngress)
        worker = OwnerCaptureStoreWorker(base: base)
        self.afterPublication = afterPublication
    }

    var canBeginNextSet: Bool { view != nil && pending == nil && active == nil && !recoveryBlocked && lastError == nil &&
        acceptedPreparation.map { fence.allows($0.authority, practiceID: $0.practiceID) } != false }
    var authority: OwnerPracticeIdentity? { view?.channel.authority }

    func load() async throws {
        do {
            let result = try await worker.run { _, _ in true }; apply(result.view)
            if try await onPracticeRecovery?() == true { recoveryBlocked = true }
        }
        catch { fail(error); throw error }
    }

    func publishVerifiedPractice(scope: OwnerPracticePublicationScope,
        preparedPublication: OwnerPracticePreparedPublication) async throws -> OwnerPracticeReceipt {
        guard scope == preparedPublication.scope else { throw OwnerPracticeBundleError.integrity }
        let expected = fence.current, liveFence = fence
        let before = beforePracticeRename, after = afterPracticeRename
        let base = self.base
        let result = try await worker.run { _, channel in
            guard try OwnerPracticeDeletion.status(base: base, practiceID: scope.practiceID) == nil else { throw OwnerPracticeBundleError.unavailable }
            try OwnerPracticePublicationPermission.require(scope, current: channel.readSnapshot())
            before?()
            try liveFence.withCurrent(expected, scope: scope) { try preparedPublication.renameForPublication() }
            after?()
            return try preparedPublication.confirmPublication()
        }
        return result.value
    }

    func fencePracticeDeletion(_ practiceID: UUID) { fence.delete(practiceID) }
    func deletePractice(_ practiceID: UUID, command: OwnerPracticeDeletionCommand? = nil) async throws -> OwnerPracticeDeletionAcknowledgment {
        fencePracticeDeletion(practiceID)
        await beforePracticeDeletion?()
        try Task.checkCancellation()
        let base = self.base
        let result = try await worker.run { _, channel in
            guard let authority = try channel.readSnapshot().authority else { throw OwnerCaptureFailure.unprepared }
            let selected = try command ?? OwnerPracticeDeletion.makeCommand(base: base, authority: authority, practiceID: practiceID, requester: .watch)
            guard selected.practiceID == practiceID else { throw OwnerPracticeBundleError.integrity }
            try selected.requireOwner(authority)
            return try OwnerPracticeDeletion.perform(command: selected, base: base, device: .watch, channel: channel)
        }
        apply(result.view)
        return result.value
    }

    func validatePracticeStartup(_ preparation: OwnerPreparation, expectedFence: UUID) async throws {
        let result = try await worker.run { [fence] _, channel in
            guard fence.matches(expectedFence), fence.allows(preparation.authority, practiceID: preparation.practiceID) else { throw OwnerCaptureFailure.stale }
            try Self.validate(preparation, channel: channel)
            return true
        }
        apply(result.view)
        guard fence.matches(expectedFence), fence.allows(preparation.authority, practiceID: preparation.practiceID), acceptedPreparation == preparation,
              authority == preparation.authority, !recoveryBlocked else { throw OwnerCaptureFailure.stale }
    }
    func retireLocalPractice(_ practiceID: UUID) async throws {
        invalidate(revokeCapture: true, retirePreparation: true)
        generations = PracticeSetupGenerations(runtimeGeneration: generations.runtimeGeneration, preparationGeneration: UUID())
        let expected = fence.current, mutationID = UUID()
        do {
            let result = try await worker.run { [fence] _, channel in
                guard fence.matches(expected) else { throw OwnerCaptureFailure.stale }
                let snapshot = try channel.readSnapshot()
                // Closure remains durable after withdrawal; the current authority retains its denied collection consent.
                guard let authority = snapshot.authority else { throw OwnerCaptureFailure.unprepared }
                if try !channel.hasReplayGuard(scope: .practice, id: practiceID) {
                    _ = try channel.sequence(.retirePractice(from: authority, practiceID: practiceID, mutationID: mutationID))
                }
                return true
            }
            apply(result.view)
            guard fence.matches(expected) else { throw OwnerCaptureFailure.stale }
        } catch { fail(error); throw error }
    }
    func updateObservation(state: PracticeSetupWatchState, wrist: PracticeSetupWrist,
                           crown: PracticeSetupCrown, capability: PracticeSetupCapability) {
        self.state = state; self.wrist = wrist; self.crown = crown; self.capability = capability
    }

    func observation() throws -> OwnerPreparationObservation {
        guard let view else { throw OwnerCaptureFailure.unavailable }
        return try .init(watchEpoch: view.epoch, generations: generations,
            observedAtUnixSeconds: Date().timeIntervalSince1970, state: state,
            authority: view.channel.authority, acceptedCurrent: acceptedPreparation?.identity,
            acceptedNext: nextPreparation?.identity, wrist: wrist, crown: crown,
            capability: capability, storage: lastError == nil ? .available : .unavailable)
    }

    /// Advances the synchronous fence before every mutating worker hop, including background delivery.
    func receive(_ message: OwnerPreparationMessage, work: OwnerPreparationWork? = nil) async throws -> OwnerPreparationMessage? {
        let restriction = fence.restrict(message)
        let mutating: Bool
        switch message {
        case .prepare, .draft, .mutate, .retire, .transition: mutating = true
        default: mutating = false
        }
        var heartChange: (OwnerPracticeIdentity, OwnerPracticeIdentity, OwnerAuthorityMutation)?
        var duplicateHeart = false, reconcileHeartRate = false
        if case let .mutate(_, _, mutation) = message, mutation.kind == .heartRate, let before = authority {
            duplicateHeart = mutation.id == before.lastDecisionID && mutation.afterDigest == (try? SHA256.hash(data: before.encoded()).map { String(format: "%02x", $0) }.joined())
            if !duplicateHeart, let after = try? mutation.resolve(from: before), after.isCollectionAllowed {
                heartChange = (before, after, mutation)
            }
        }
        if mutating && !duplicateHeart {
            let revokes: Bool
            switch message { case .mutate, .retire, .transition: revokes = true; default: revokes = false }
            if heartChange != nil, retainsPracticeWorkout, pending == nil, active == nil || (admitted && !closing) {
                fence.advance(); physical = nil; acceptedPreparation = nil; nextPreparation = nil
                onPracticeStartupInvalidation?(); reconcileHeartRate = true
                carryPending = active != nil; onHeartRateFence?(); onChange?()
            } else { invalidate(revokeCapture: revokes, retirePreparation: revokes) }
        }
        let expected = fence.current
        if restriction != nil { await beforeAuthorityPersistence?() }
        if view == nil { try await load() }
        guard fence.matches(expected), work?.isCancelled != true else { throw OwnerCaptureFailure.stale }
        do {
            switch message {
            case let .statusRequest(requestID, phoneEpoch):
                let result = try await worker.run { _, _ in true }
                guard fence.matches(expected), work?.isCancelled != true else { throw OwnerCaptureFailure.stale }
                apply(result.view)
                return .status(requestID: requestID, phoneEpoch: phoneEpoch, observation: try observation())
            case let .mutate(requestID, suppliedGenerations, mutation):
                guard suppliedGenerations == generations else { throw OwnerCaptureFailure.stale }
                let result = try await worker.run { [fence] _, channel in
                    try Self.commit(work, fence: fence, expected: expected) { try channel.sequence(mutation) }
                }
                if let restriction { fence.reconciled(restriction) }
                guard fence.matches(expected) else { throw OwnerCaptureFailure.stale }
                apply(result.view)
                if reconcileHeartRate, let (before, after, mutation) = heartChange, !duplicateHeart, retainsPracticeWorkout {
                    guard authority == after else { throw OwnerCaptureFailure.stale }
                    // Cancellation can close startup while the checked durable mutation awaits its worker.
                    let canceledBeforeAdmission = active == nil && pending == nil && !admitted && canRetainPracticeWorkout?() == false
                    if !canceledBeforeAdmission { try await onHeartRateTransition?(before, after, mutation) }
                    guard fence.matches(expected), authority == after else { throw OwnerCaptureFailure.stale }
                    if !canceledBeforeAdmission && admitted && !closing { carryAuthority = after }
                    carryPending = false; onChange?()
                }
                return .applied(requestID: requestID, generations: suppliedGenerations, transition: result.value)
            case let .draft(preparation):
                let result = try await worker.run { [fence] setup, channel in
                    try Self.commit(work, fence: fence, expected: expected) {
                        try Self.validate(preparation, channel: channel)
                        try setup.saveSuggestion(preparation.draft)
                        return true
                    }
                }
                guard fence.matches(expected) else { throw OwnerCaptureFailure.stale }
                apply(result.view); return nil
            case let .prepare(correlation, preparation):
                guard correlation.generations == generations, correlation.preparation == preparation.identity,
                      !retiredPreparations.contains(preparation.identity) else {
                    throw OwnerCaptureFailure.stale
                }
                let result = try await worker.run { [fence] setup, channel in
                    try Self.commit(work, fence: fence, expected: expected) {
                        try Self.validate(preparation, channel: channel)
                        return try setup.recordExplicitPreparation(preparation.draft)
                    }
                }
                guard fence.matches(expected), work?.isCancelled != true else { throw OwnerCaptureFailure.stale }
                apply(result.view)
                try requireAuthority(preparation.authority)
                let disposition: PracticeSetupDisposition
                if active != nil && admitted && !closing {
                    guard acceptedPreparation?.practiceID == preparation.practiceID else { throw OwnerCaptureFailure.resourcesOpen }
                    nextPreparation = preparation; disposition = .acceptedNext
                } else {
                    guard pending == nil && active == nil && !recoveryBlocked else { throw OwnerCaptureFailure.resourcesOpen }
                    acceptedPreparation = preparation; nextPreparation = nil; disposition = .acceptedCurrent
                }
                onChange?()
                return .receipt(correlation: correlation, disposition: disposition, observation: try observation())
            case let .retire(correlation, reason):
                guard correlation.generations == generations else { throw OwnerCaptureFailure.stale }
                generations = PracticeSetupGenerations(runtimeGeneration: generations.runtimeGeneration,
                    preparationGeneration: UUID())
                let result = try await worker.run { [fence] _, channel in
                    try Self.commit(work, fence: fence, expected: expected) {
                        let snapshot = try channel.readSnapshot()
                        guard let owner = snapshot.authority, try correlation.preparation.matches(owner) else {
                            throw OwnerCaptureFailure.stale
                        }
                        if reason == .endPractice {
                            _ = try channel.sequence(.retirePractice(from: owner,
                                practiceID: correlation.preparation.practiceID, mutationID: correlation.requestID))
                        } else {
                            _ = try channel.sequence(.advance(from: owner, mutationID: correlation.requestID))
                        }
                        return true
                    }
                }
                guard fence.matches(expected), work?.isCancelled != true else { throw OwnerCaptureFailure.stale }
                apply(result.view)
                return .receipt(correlation: correlation, disposition: .retired,
                    observation: try observation(), retirementReason: reason)
            case let .acknowledge(ack):
                let result = try await worker.run { _, channel in
                    if let work { try work.commit { try channel.acknowledge(ack) } }
                    else { try channel.acknowledge(ack) }
                    return true
                }
                apply(result.view); return nil
            case let .replay(requestID, cursor):
                let result = try await worker.run { _, channel in try channel.nextTransition(after: cursor) }
                apply(result.view)
                return .replayResult(requestID: requestID, cursor: cursor, transition: result.value)
            default: throw OwnerCaptureFailure.invalidMessage
            }
        } catch {
            if !(error is OwnerCaptureFailure) { fail(error) }
            throw error
        }
    }

    func confirmPhysical(wrist: PlayingArm?, crown: String, fit: Bool) -> OwnerPhysicalConfirmation? {
        guard canBeginNextSet, let acceptedPreparation, let wrist,
              wrist == acceptedPreparation.draft.preferences.currentRacketArm,
              !crown.isEmpty, fit, (try? requireAuthority(acceptedPreparation.authority)) != nil else { return nil }
        let value = OwnerPhysicalConfirmation(id: UUID(), preparation: acceptedPreparation.identity,
            fence: fence.current, wrist: wrist, crown: crown)
        physical = value; return value
    }

    func invalidatePhysical() { invalidate(revokeCapture: false, retirePreparation: false) }

    func prepareCapture(metadata: RecordingMetadata, confirmation: OwnerPhysicalConfirmation?) async throws -> OwnerCaptureAttempt {
        guard canBeginNextSet, let preparation = acceptedPreparation else { throw OwnerCaptureFailure.unprepared }
        guard let confirmation, confirmation == physical, confirmation.fence == fence.current,
              confirmation.preparation == preparation.identity, metadata.watchWrist == confirmation.wrist,
              metadata.watchOrientation == confirmation.crown else { throw OwnerCaptureFailure.physicalCheck }
        guard !usedRecordings.contains(metadata.recordingID) else { throw OwnerCaptureFailure.duplicate }
        try requireAuthority(preparation.authority)
        let binding = try OwnerRecordingContext.bind(rawMetadataBytes: RecordingChunkCodec.encodeMetadata(metadata),
            authority: preparation.authority, practiceID: preparation.practiceID,
            acceptedSetup: preparation.draft, generations: generations)
        let id = UUID(), expected = fence.current
        usedRecordings.insert(metadata.recordingID); pending = id; physical = nil
        do {
            let result = try await worker.run { [fence] _, channel in
                guard fence.matches(expected) else { throw OwnerCaptureFailure.stale }
                let snapshot = try channel.readSnapshot()
                guard let owner = snapshot.authority, !snapshot.admissionBlocked else { throw OwnerCaptureFailure.unprepared }
                try binding.validateCurrentAuthority(owner)
                let publication = try channel.publish(binding, expectedRevision: owner.revision)
                guard case let .valid(context) = try channel.inspectContext(recordingID: metadata.recordingID),
                      context == binding.context else { throw OwnerCaptureFailure.stale }
                return (publication: publication, context: context)
            }
            guard fence.matches(expected), pending == id else { throw OwnerCaptureFailure.stale }
            apply(result.view)
            let publication = result.value.publication
            if let afterPublication { await afterPublication(publication) }
            guard fence.matches(expected), pending == id, !recoveryBlocked,
                  acceptedPreparation == preparation, publication.disposition == .newlyPublished,
                  publication.storeInstanceID == view?.channel.storeInstanceID,
                  publication.recordingID == metadata.recordingID,
                  result.value.context == binding.context,
                  publication.authorityDigest == binding.context.authorityDigest,
                  publication.validatedRevision == binding.context.authorityRevision else {
                throw OwnerCaptureFailure.stale
            }
            try requireAuthority(preparation.authority)
            let attempt = OwnerCaptureAttempt(id: id, recordingID: metadata.recordingID, fence: expected,
                binding: binding, publication: publication)
            pending = nil; active = attempt; admitted = false; closing = false
            writerClosed = false; nativeClosed = false; sourceClosed = false; carryAuthority = nil; carryPending = false
            return attempt
        } catch {
            if pending == id { pending = nil }
            throw error
        }
    }

    func admit(_ attempt: OwnerCaptureAttempt, operation: @MainActor () throws -> Void) async throws {
        try await validateAdmission(attempt, resuming: false, operation: operation)
    }

    func resume(_ attempt: OwnerCaptureAttempt, operation: @MainActor () throws -> Void) async throws {
        try await validateAdmission(attempt, resuming: true, operation: operation)
    }

    private func validateAdmission(_ attempt: OwnerCaptureAttempt, resuming: Bool, operation: @MainActor () throws -> Void) async throws {
        guard active == attempt, !closing, !carryPending, admitted == resuming, !recoveryBlocked,
              resuming || fence.matches(attempt.fence) else { throw OwnerCaptureFailure.stale }
        let expected = fence.current
        let result = try await worker.run { _, channel in try channel.inspectContext(recordingID: attempt.recordingID) }
        guard fence.matches(expected), active == attempt, !closing, !carryPending, admitted == resuming, !recoveryBlocked else {
            throw OwnerCaptureFailure.stale
        }
        apply(result.view)
        guard attempt.publication.disposition == .newlyPublished,
              attempt.publication.storeInstanceID == result.view.channel.storeInstanceID,
              case let .valid(context) = result.value, context == attempt.binding.context,
              let authority = result.view.channel.authority, !result.view.channel.admissionBlocked else {
            throw OwnerCaptureFailure.stale
        }
        if !(resuming && carryAuthority == authority) { try attempt.binding.validateCurrentAuthority(authority) }
        // No suspension or queued actor turn is permitted between these checks and engine.begin/resume.
        do {
            try fence.claimAdmission(authority, practiceID: attempt.binding.context.practiceID)
            try operation()
            admitted = true; carryAuthority = authority
        } catch {
            retireCapture(attempt)
            throw error
        }
    }

    func isAdmitted(_ attempt: OwnerCaptureAttempt) -> Bool { active == attempt && admitted && !closing && !carryPending && !recoveryBlocked }
    func isCurrent(_ attempt: OwnerCaptureAttempt) -> Bool {
        active == attempt && !closing && !carryPending && !recoveryBlocked && (admitted || fence.matches(attempt.fence))
    }
    func retireCapture(_ attempt: OwnerCaptureAttempt) {
        guard active == attempt else { return }
        fence.advance(); physical = nil; closing = true; admitted = false
    }
    func engineDrained(_ attempt: OwnerCaptureAttempt) {
        guard active == attempt, closing else { return }
        writerClosed = true; finishClosure()
    }
    /// Called only for an observed native ended event, or a verified attempt that created no session.
    func motionClosed(_ attempt: OwnerCaptureAttempt, witness: WatchMotionClosureWitness) {
        guard active == attempt, closing, retainsPracticeWorkout else { return }
        sourceClosed = true; finishClosure()
    }
    func workoutClosed(_ attempt: OwnerCaptureAttempt) {
        guard active == attempt, closing else { return }
        nativeClosed = true; finishClosure()
    }
    func shutdownTimedOut(_ attempt: OwnerCaptureAttempt) {
        guard active == attempt, closing else { return }
        lastError = "Waiting for actual writer drain and workout end. A new set is blocked."
        onChange?()
    }
    func beginRecovery() {
        recoveryBlocked = true; invalidate(revokeCapture: true, retirePreparation: true)
    }
    func recoveryEnded() { recoveryBlocked = false; onChange?() }

    func inspectContext(recordingID: UUID) async throws -> OwnerStoredContext {
        let result = try await worker.run { _, channel in try channel.inspectContext(recordingID: recordingID) }
        apply(result.view); return result.value
    }
    func closeForTesting() async {
        fence.advance(); physical = nil; pending = nil; active = nil
        acceptedPreparation = nil; nextPreparation = nil; view = nil
        await worker.close()
    }

    private func finishClosure() {
        let samePractice = retainsPracticeWorkout && sourceClosed && canRetainPracticeWorkout?() == true
        let wholePractice = nativeClosed && (!retainsPracticeWorkout || (sourceClosed && practiceCallbacksClosed?() != false))
        guard closing, writerClosed, samePractice || wholePractice else { return }
        active = nil; closing = false; admitted = false; lastError = nil
        if let nextPreparation { acceptedPreparation = nextPreparation; self.nextPreparation = nil }
        onChange?()
    }
    private func invalidate(revokeCapture: Bool, retirePreparation: Bool) {
        fence.advance(); physical = nil
        onPracticeStartupInvalidation?()
        if revokeCapture { carryPending = false; carryAuthority = nil; onPracticeRetirement?() }
        if retirePreparation {
            if let acceptedPreparation { retiredPreparations.append(acceptedPreparation.identity) }
            if let nextPreparation { retiredPreparations.append(nextPreparation.identity) }
            acceptedPreparation = nil; nextPreparation = nil
        }
        if pending != nil { pending = nil; onInvalidation?("Preparation changed before capture admission.") }
        if active != nil && (revokeCapture || !admitted) {
            closing = true; admitted = false; onInvalidation?("Owner preparation was retired. Capture is stopping.")
        }
        onChange?()
    }
    private func apply(_ value: OwnerCaptureStoreView) {
        guard view == nil || value.serial > view!.serial else { return }
        view = value; watchEpoch = value.epoch
    }
    private func requireAuthority(_ authority: OwnerPracticeIdentity) throws {
        guard let view, !view.channel.admissionBlocked, view.channel.authority == authority,
              authority.isCollectionAllowed else { throw OwnerCaptureFailure.unprepared }
    }
    private func fail(_ error: any Error) {
        lastError = "Owner storage is unavailable: \(error.localizedDescription)"
        invalidate(revokeCapture: true, retirePreparation: true)
    }
    nonisolated private static func validate(_ preparation: OwnerPreparation, channel: PracticeSetupChannel) throws {
        let view = try channel.readSnapshot()
        guard !view.admissionBlocked, let authority = view.authority, authority == preparation.authority,
              try preparation.identity.matches(authority),
              try !channel.hasReplayGuard(scope: .practice, id: preparation.practiceID) else {
            throw OwnerCaptureFailure.unprepared
        }
    }
    nonisolated private static func commit<T>(_ work: OwnerPreparationWork?, fence: OwnerCaptureFence,
                                              expected: UUID, body: () throws -> T) throws -> T {
        if let work {
            return try work.commit {
                guard fence.matches(expected) else { throw OwnerCaptureFailure.stale }
                return try body()
            }
        }
        guard fence.matches(expected) else { throw OwnerCaptureFailure.stale }
        return try body()
    }
}

/// Resolve before any eager service, recovery, preference or default-container access.
struct WatchRuntimeEnvironment {
    let fixtureID: UUID?
    let base: URL?
    let preferenceSuite: String?
    let allowsHardware: Bool
    let failure: String?
    static let current: Self = {
        do { return try resolve(arguments: ProcessInfo.processInfo.arguments, environment: ProcessInfo.processInfo.environment) }
        catch { return Self(fixtureID: nil, base: nil, preferenceSuite: nil, allowsHardware: false,
                            failure: "Invalid Watch test namespace. Default storage and hardware are blocked.") }
    }()
    static func resolve(arguments: [String], environment: [String: String]) throws -> Self {
        #if DEBUG
        let supplied = arguments.filter { $0.hasPrefix("--owner-watch-fixture=") }
            .map { String($0.dropFirst("--owner-watch-fixture=".count)) }
        guard supplied.count <= 1 else { throw OwnerCaptureFailure.invalidMessage }
        let fromEnvironment = environment["PSL_WATCH_FIXTURE_UUID"]
        if let argument = supplied.first, let fromEnvironment,
           argument.caseInsensitiveCompare(fromEnvironment) != .orderedSame { throw OwnerCaptureFailure.invalidMessage }
        if let raw = supplied.first ?? fromEnvironment {
            guard let id = UUID(uuidString: raw), id.uuidString.caseInsensitiveCompare(raw) == .orderedSame else {
                throw OwnerCaptureFailure.invalidMessage
            }
            let base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
                .appendingPathComponent("O5WatchFixtures", isDirectory: true).appendingPathComponent(id.uuidString, isDirectory: true)
            return Self(fixtureID: id, base: base, preferenceSuite: "PadelStrokeLab.O5.\(id.uuidString)", allowsHardware: false, failure: nil)
        }
        guard environment["XCTestConfigurationFilePath"] == nil, environment["XCTestBundlePath"] == nil else {
            throw OwnerCaptureFailure.invalidMessage
        }
        #endif
        return Self(fixtureID: nil, base: nil, preferenceSuite: nil, allowsHardware: true, failure: nil)
    }
    func prepareFixtureDirectory() throws {
        guard let fixtureID else { return }
        let temporary = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        let root = open(temporary.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard root >= 0 else { throw OwnerCaptureFailure.unavailable }
        defer { close(root) }
        func directory(_ name: String, in parent: Int32) throws -> Int32 {
            if mkdirat(parent, name, 0o700) != 0 && errno != EEXIST { throw OwnerCaptureFailure.unavailable }
            let fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard fd >= 0 else { throw OwnerCaptureFailure.unavailable }
            var info = stat()
            guard fstat(fd, &info) == 0, info.st_uid == geteuid() else { close(fd); throw OwnerCaptureFailure.unavailable }
            return fd
        }
        let parent = try directory("O5WatchFixtures", in: root)
        defer { close(parent) }
        let owned = try directory(fixtureID.uuidString, in: parent)
        close(owned)
    }
}

private nonisolated final class OwnerCaptureFence: @unchecked Sendable {
    private let lock = NSLock()
    private var value = UUID()
    private var restrictions: [UUID: OwnerPracticePendingRestriction] = [:]
    private var deletions: Set<UUID> = []
    private let ingress: OwnerPracticeDeletionIngress?
    init(ingress: OwnerPracticeDeletionIngress?) { self.ingress = ingress }
    func allows(_ authority: OwnerPracticeIdentity, practiceID: UUID) -> Bool {
        lock.withLock { !deletions.contains(practiceID) && ingress?.allows(authority, practiceID: practiceID) != false }
    }
    func claimAdmission(_ authority: OwnerPracticeIdentity, practiceID: UUID) throws {
        try lock.withLock {
            guard !deletions.contains(practiceID) else { throw OwnerCaptureFailure.stale }
            // This bounded claim linearizes before ingress. The no-await MainActor operation
            // follows outside both locks; an earlier claim is owned by the existing O7 drain.
            if let ingress { try ingress.withAllowed(authority, practiceID: practiceID) {} }
        }
    }
    func delete(_ id: UUID) { lock.withLock { deletions.insert(id); value = UUID() } }
    var current: UUID { lock.withLock { value } }
    func advance() { lock.withLock { value = UUID() } }
    func matches(_ expected: UUID) -> Bool { lock.withLock { value == expected } }
    func restrict(_ message: OwnerPreparationMessage) -> UUID? {
        guard let restriction = OwnerPracticePendingRestriction(message: message) else { return nil }
        return lock.withLock { let id = UUID(); restrictions[id] = restriction; value = UUID(); return id }
    }
    func reconciled(_ id: UUID) { lock.withLock { _ = restrictions.removeValue(forKey: id) } }
    func withCurrent<T>(_ expected: UUID, scope: OwnerPracticePublicationScope, operation: () throws -> T) throws -> T {
        try lock.withLock {
            guard value == expected, !deletions.contains(scope.practiceID), !restrictions.values.contains(where: { $0.blocks(scope) }) else {
                throw OwnerPracticeBundleError.unavailable
            }
            if let ingress { return try ingress.withAllowed(scope, operation: operation) }
            return try operation()
        }
    }
}

private nonisolated struct OwnerCaptureStoreView: Sendable {
    let epoch: UUID
    let channel: OwnerChannelSnapshot
    var serial: UInt64 = 0
    init(_ setup: PracticeSetupStore, _ channel: PracticeSetupChannel) throws {
        epoch = try setup.checkedSnapshot().localInstallationEpoch
        self.channel = try channel.readSnapshot()
    }
}
private nonisolated struct OwnerCaptureStoreResult<Value: Sendable>: Sendable {
    let value: Value
    var view: OwnerCaptureStoreView
}
private nonisolated final class OwnerCaptureStoreWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "PadelStrokeLab.watch-owner-admission", qos: .userInitiated)
    private let base: URL
    private var bootstrap: OwnerWatchBootstrap?
    private var serial: UInt64 = 0
    private var closed = false
    init(base: URL) { self.base = base }
    func run<T: Sendable>(_ body: @escaping @Sendable (PracticeSetupStore, PracticeSetupChannel) throws -> T) async throws -> OwnerCaptureStoreResult<T> {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    guard !closed, serial < UInt64.max else { throw OwnerCaptureFailure.closed }
                    if bootstrap == nil { bootstrap = try OwnerWatchBootstrap(base: base) }
                    var result = try bootstrap!.withStores { setup, channel in
                        let value = try body(setup, channel)
                        return try OwnerCaptureStoreResult(value: value, view: OwnerCaptureStoreView(setup, channel))
                    }
                    serial += 1; result.view.serial = serial
                    continuation.resume(returning: result)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
    func close() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in bootstrap = nil; closed = true; continuation.resume() }
        }
    }
}


/// Synchronous non-Sendable owner; construct and use on one non-main serial executor.
/// The witness can deny reinitialization. It cannot grant or reconstruct authority.
nonisolated final class OwnerWatchBootstrap {
    enum Failure: Error { case invalidStorage, unavailable, poisoned }
    enum Stage: Equatable, Sendable { case pendingSynced, preferencesInitialized, channelInitialized }
    private static let witness = "OwnerWatchBootstrap-v1"
    private static let namespaces = [PracticeSetupStore.directoryName, OwnerPracticeStore.directoryName, PracticeSetupChannel.directoryName]
    private static let pending = Data("PSLWatchBootstrap1\npending\n".utf8)
    private struct Node: Equatable { let device: dev_t; let inode: ino_t }
    private let base: URL
    private let root: Int32
    private let witness: Int32
    private let ready: Data
    private let namespaces: [Node]
    private var stores: (PracticeSetupStore, PracticeSetupChannel)?
    private var poisoned = false

    // Nil in production. Faults occur after the actual durable/store initialization boundaries.
    init(base: URL, fault: ((Stage) throws -> Void)? = nil) throws {
        let root = try Self.openBase(base)
        var witness: Int32 = -1
        do {
            let existing = try Self.named(Self.witness, root)
            let namespaces = try Self.namespaces.map { try Self.named($0, root) }
            let creating = existing == nil
            guard creating ? namespaces.allSatisfy({ $0 == nil }) : namespaces.allSatisfy({
                $0.map { $0.st_mode & S_IFMT == S_IFDIR } == true
            }) else { throw Failure.invalidStorage }
            if let existing {
                guard existing.st_mode & S_IFMT == S_IFREG, existing.st_nlink == 1 else { throw Failure.invalidStorage }
            }
            let flags = O_RDWR | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | (creating ? O_CREAT | O_EXCL : 0)
            witness = openat(root, Self.witness, flags, 0o600)
            guard witness >= 0 else { throw Failure.unavailable }
            _ = try Self.read(witness)
            guard flock(witness, LOCK_EX | LOCK_NB) == 0 else { throw Failure.unavailable }
            let loaded: Data
            if creating {
                try Self.write(Self.pending, witness)
                guard fsync(root) == 0 else { throw Failure.unavailable }
                loaded = Self.pending
            } else {
                loaded = try Self.read(witness)
                _ = try Self.epoch(loaded)
                guard fsync(witness) == 0 else { throw Failure.unavailable }
            }
            try Self.checkPaths(base, root, witness, expected: loaded)
            if creating { try fault?(.pendingSynced) }
            let preferences = try PracticeSetupStore(base: base)
            let epoch = try preferences.checkedSnapshot().localInstallationEpoch
            if !creating, try Self.epoch(loaded) != epoch { throw Failure.invalidStorage }
            if creating { try fault?(.preferencesInitialized) }
            let channel = try PracticeSetupChannel(base: base, localInstallationEpoch: epoch,
                device: .watch, intent: creating ? .createNew : .openExisting)
            _ = try channel.readSnapshot()
            if creating { try fault?(.channelInitialized) }
            let nodes = try Self.namespaceNodes(root)
            let ready = Data("PSLWatchBootstrap1\nready\n\(epoch.uuidString)\n".utf8)
            try Self.verify(base, root, witness, loaded, nodes, preferences, channel)
            if creating { try Self.write(ready, witness) }
            try Self.verify(base, root, witness, ready, nodes, preferences, channel)
            self.base = base; self.root = root; self.witness = witness
            self.ready = ready; self.namespaces = nodes; stores = (preferences, channel)
        } catch {
            if witness >= 0 { flock(witness, LOCK_UN); close(witness) }
            close(root)
            throw error
        }
    }

    deinit {
        stores = nil
        flock(witness, LOCK_UN)
        close(witness)
        close(root)
    }

    /// Callers must keep both store handles inside this synchronous, nonescaping operation.
    func withStores<T: Sendable>(_ body: (PracticeSetupStore, PracticeSetupChannel) throws -> T) throws -> T {
        try checkLive()
        guard let stores else { throw Failure.poisoned }
        let result = Result { try body(stores.0, stores.1) }
        // Even a throwing body can have durably raised a fence or damaged storage.
        try checkLive()
        return try result.get()
    }

    private func checkLive() throws {
        guard !poisoned, let stores else { throw Failure.poisoned }
        do { try Self.verify(base, root, witness, ready, namespaces, stores.0, stores.1) }
        catch { poisoned = true; throw error }
    }

    private static func verify(_ base: URL, _ root: Int32, _ witness: Int32, _ expected: Data,
                               _ namespaces: [Node], _ preferences: PracticeSetupStore, _ channel: PracticeSetupChannel) throws {
        try checkPaths(base, root, witness, expected: expected)
        guard try namespaceNodes(root) == namespaces else { throw Failure.invalidStorage }
        _ = try preferences.checkedSnapshot()
        _ = try channel.readSnapshot()
    }

    private static func checkPaths(_ base: URL, _ root: Int32, _ witness: Int32, expected: Data) throws {
        let reopened = try openBase(base)
        defer { close(reopened) }
        guard try node(reopened) == node(root), let named = try named(Self.witness, root),
              named.st_mode & S_IFMT == S_IFREG, named.st_nlink == 1,
              try node(witness) == Node(device: named.st_dev, inode: named.st_ino),
              try read(witness) == expected else { throw Failure.invalidStorage }
    }

    private static func namespaceNodes(_ root: Int32) throws -> [Node] {
        try namespaces.map { name in
            guard let info = try named(name, root), info.st_mode & S_IFMT == S_IFDIR else { throw Failure.invalidStorage }
            return Node(device: info.st_dev, inode: info.st_ino)
        }
    }

    private static func epoch(_ bytes: Data) throws -> UUID {
        guard let text = String(data: bytes, encoding: .utf8) else { throw Failure.invalidStorage }
        let fields = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard fields.count == 4, fields[0] == "PSLWatchBootstrap1", fields[1] == "ready", fields[3].isEmpty,
              let epoch = UUID(uuidString: String(fields[2])), epoch.uuidString == fields[2] else { throw Failure.invalidStorage }
        return epoch
    }

    private static func openBase(_ base: URL) throws -> Int32 {
        guard base.isFileURL, base.path.hasPrefix("/"), !base.path.utf8.contains(0),
              !base.pathComponents.contains("Recordings") else { throw Failure.invalidStorage }
        var root = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard root >= 0 else { throw Failure.unavailable }
        do {
            for part in base.path.split(separator: "/") {
                guard part != ".", part != ".." else { throw Failure.invalidStorage }
                let next = openat(root, String(part), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard next >= 0 else { throw Failure.unavailable }
                close(root); root = next
            }
            return root
        } catch { close(root); throw error }
    }

    private static func named(_ name: String, _ root: Int32) throws -> stat? {
        var info = stat()
        if fstatat(root, name, &info, AT_SYMLINK_NOFOLLOW) == 0 { return info }
        guard errno == ENOENT else { throw Failure.unavailable }
        return nil
    }

    private static func node(_ descriptor: Int32) throws -> Node {
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw Failure.unavailable }
        return Node(device: info.st_dev, inode: info.st_ino)
    }

    private static func read(_ descriptor: Int32) throws -> Data {
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1,
              (0...128).contains(info.st_size) else { throw Failure.invalidStorage }
        var buffer = [UInt8](repeating: 0, count: 129)
        let count = buffer.withUnsafeMutableBytes { pread(descriptor, $0.baseAddress, $0.count, 0) }
        guard count >= 0, count == info.st_size else { throw Failure.invalidStorage }
        return Data(buffer.prefix(count))
    }

    private static func write(_ bytes: Data, _ descriptor: Int32) throws {
        guard bytes.count <= 128 else { throw Failure.invalidStorage }
        try bytes.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let written = pwrite(descriptor, buffer.baseAddress!.advanced(by: offset), buffer.count - offset, off_t(offset))
                guard written > 0 else { throw Failure.unavailable }
                offset += written
            }
        }
        guard ftruncate(descriptor, off_t(bytes.count)) == 0, fsync(descriptor) == 0 else { throw Failure.unavailable }
    }
}
