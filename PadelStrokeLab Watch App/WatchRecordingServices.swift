import Foundation
import Darwin
import Observation
import PadelCore
import WatchKit

/// One transport owner for foreground UI and background-only process launches.
@MainActor @Observable
final class WatchRecordingServices {
    static let shared = WatchRecordingServices()
    let environment: WatchRuntimeEnvironment
    let preferences: UserDefaults
    let paths: RecordingPaths?
    let connectivity: RecordingConnectivity?
    let coordinator: OwnerCaptureCoordinator?
    let practice: OwnerPracticeCoordinator?
    private(set) var storageError: String?
    private(set) var ownerLoaded = false
    private(set) var transfers: [UUID: String] = [:]
    private(set) var practiceDeletionMessage: String?
    var onPracticeDeleted: (([UUID]) -> Void)?
    private let beforePracticeImport: (@MainActor (URL) async throws -> Void)?

    init(environment: WatchRuntimeEnvironment = .current,
         afterPublication: (@MainActor (OwnerContextPublication) async -> Void)? = nil,
         workout: WatchWorkoutDriver? = nil, heartRate: OwnerHeartRateSource? = nil,
         practiceClock: (@MainActor () throws -> OwnerTelemetryInstant)? = nil,
         beforeTelemetryPublication: (@MainActor (OwnerPracticeTelemetry) async throws -> Void)? = nil,
         injectedConnectivity: RecordingConnectivity? = nil,
         beforePracticeImport: (@MainActor (URL) async throws -> Void)? = nil) {
        self.environment = environment
        self.beforePracticeImport = beforePracticeImport
        preferences = environment.preferenceSuite.flatMap(UserDefaults.init(suiteName:))
            ?? (environment.allowsHardware ? .standard : UserDefaults(suiteName: "PadelStrokeLab.Blocked.\(UUID().uuidString)")!)
        do {
            let injected = workout != nil || heartRate != nil || practiceClock != nil || beforeTelemetryPublication != nil || injectedConnectivity != nil || beforePracticeImport != nil
            guard environment.failure == nil, !injected || environment.isCoherentFixture else { throw OwnerCaptureFailure.unavailable }
            try environment.prepareFixtureDirectory()
            let paths = try RecordingPaths(base: environment.base)
            guard injectedConnectivity?.isBound(to: paths) != false else { throw OwnerCaptureFailure.unavailable }
            self.paths = paths; storageError = nil
            let connection = injectedConnectivity ?? (environment.allowsHardware ? RecordingConnectivity(paths: paths) : nil)
            let coordinator = OwnerCaptureCoordinator(base: paths.rawRoot.deletingLastPathComponent().deletingLastPathComponent(),
                afterPublication: environment.fixtureID == nil ? nil : afterPublication, deletionIngress: connection?.practiceDeletionIngress)
            self.coordinator = coordinator
            practice = OwnerPracticeCoordinator(owner: coordinator,
                base: paths.rawRoot.deletingLastPathComponent().deletingLastPathComponent(),
                workout: workout ?? (environment.allowsHardware ? WatchWorkoutDriver() : nil),
                heartRate: heartRate ?? (environment.allowsHardware ? OwnerHeartRateSource() : nil),
                clock: practiceClock ?? { try OwnerTelemetryInstant(wallUnixSeconds: Date().timeIntervalSince1970,
                    monotonicSeconds: ProcessInfo.processInfo.systemUptime) }, beforePublication: beforeTelemetryPublication)
            connectivity = connection
            connection?.onChange = { [weak self] transfer in
                Task { @MainActor [weak self] in
                    self?.transfers[transfer.recordingID] = "\(transfer.state.rawValue.capitalized)\(transfer.detail.map { ": " + $0 } ?? "")"
                }
            }
            connection?.onOwnerPreparation = { [weak coordinator] message, work in
                guard let coordinator else { throw OwnerCaptureFailure.closed }
                return try await coordinator.receive(message, work: work)
            }
            connection?.onOwnerPracticePublication = { [weak coordinator] prepared in
                guard let coordinator else { throw OwnerCaptureFailure.closed }
                return try await coordinator.publishVerifiedPractice(scope: prepared.scope, preparedPublication: prepared)
            }
            connection?.onPracticeDeletion = { [weak self] command in
                guard let self else { throw OwnerCaptureFailure.closed }
                return try await self.performPracticeDeletion(command.practiceID, command: command)
            }
            // The counted owner handler exists before the sole foreground/background activation.
            if environment.allowsHardware { connection?.activate() }
            Task { [weak self, weak coordinator] in
                do {
                    try await coordinator?.load()
                    #if DEBUG
                    try await self?.prepareSyntheticFixtureIfRequested()
                    #endif
                    self?.ownerLoaded = true
                    connection?.resumePracticeDeletions()
                } catch { self?.storageError = "Owner setup unavailable: \(error.localizedDescription)" }
            }
        } catch {
            paths = nil; connectivity = nil; coordinator = nil; practice = nil
            storageError = "Recording storage is unavailable: \(error.localizedDescription)"
        }
    }

    /// Ended owner practices use the complete envelope; historical raw-only recordings keep their old path.
    func queueRecording(_ id: UUID, timeline: CaptureTimeline) {
        guard let paths, let connectivity, let coordinator else { return }
        transfers[id] = "Preparing retained practice…"
        Task { [weak self] in
            do {
                let prepared = try await WatchPracticeTransferWorker.prepare(id: id, paths: paths, beforeImport: self?.beforePracticeImport)
                guard let prepared else { connectivity.queue(recordingID: id, timeline: timeline); return }
                defer { prepared.publication.cancel() }
                _ = try await coordinator.publishVerifiedPractice(scope: prepared.publication.scope,
                    preparedPublication: prepared.publication)
                connectivity.queuePractice(from: prepared.url)
            } catch {
                self?.transfers[id] = "Complete practice pending: end the practice or resolve its permission/storage issue, then retry. Originals retained."
            }
        }
    }

    func removeTransfer(_ id: UUID) { transfers.removeValue(forKey: id) }

    /// Collection consent is not deletion authority. Unknown owner evidence never becomes legacy.
    func deletionPracticeID(recordingID: UUID) async throws -> UUID? {
        guard ownerLoaded, storageError == nil, let coordinator, let paths else { throw OwnerCaptureFailure.unavailable }
        let stored = try await coordinator.inspectContext(recordingID: recordingID)
        let retained = try await WatchPracticeTransferWorker.deletionContext(id: recordingID, paths: paths)
        let context: OwnerRecordingContext
        switch stored {
        case .missing:
            guard retained == nil else { throw OwnerPracticeBundleError.integrity }
            return nil
        case .valid(let value):
            guard retained == nil || retained == value else { throw OwnerPracticeBundleError.conflict }
            context = value
        case .retired:
            guard let retained else { throw OwnerPracticeBundleError.integrity }
            context = retained
        case .partial, .corrupt: throw OwnerPracticeBundleError.integrity
        }
        guard let owner = coordinator.authority, context.ownerID == owner.ownerID,
              context.phoneInstallationEpoch == owner.phoneInstallationEpoch,
              context.watchInstallationEpoch == owner.watchInstallationEpoch else { throw OwnerPracticeBundleError.integrity }
        return context.practiceID
    }

    @discardableResult func deletePractice(_ practiceID: UUID) -> Task<Void, Never> {
        coordinator?.fencePracticeDeletion(practiceID)
        connectivity?.fencePracticeDeletion(practiceID)
        practiceDeletionMessage = "Deleting this practice…"
        return Task { [weak self] in
            guard let self else { return }
            do {
                let acknowledgment = try await performPracticeDeletion(practiceID)
                for id in acknowledgment.command.recordingIDs { transfers.removeValue(forKey: id) }
                practiceDeletionMessage = "Owner practice deleted on this Watch. Paired device deletion pending. Independent exports remain."
                connectivity?.resumePracticeDeletions()
            } catch { practiceDeletionMessage = "Deletion incomplete. Retry to finish removing this practice." }
        }
    }
    private func performPracticeDeletion(_ id: UUID, command: OwnerPracticeDeletionCommand? = nil) async throws -> OwnerPracticeDeletionAcknowledgment {
        guard let coordinator, let practice else { throw OwnerCaptureFailure.unavailable }
        if let command {
            guard let authority = coordinator.authority else { throw OwnerCaptureFailure.unprepared }
            try command.requireOwner(authority)
        }
        coordinator.fencePracticeDeletion(id); connectivity?.fencePracticeDeletion(id)
        try await practice.prepareForDeletion(practiceID: id)
        let acknowledgment = try await coordinator.deletePractice(id, command: command)
        for recordingID in acknowledgment.command.recordingIDs { transfers.removeValue(forKey: recordingID) }
        onPracticeDeleted?(acknowledgment.command.recordingIDs)
        return acknowledgment
    }

    func handleConnectivityRefresh(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        let gate = WatchBackgroundCompletionGate {
            task.expirationHandler = nil
            task.setTaskCompletedWithSnapshot(false)
        }
        task.expirationHandler = { @Sendable in gate.finish(cancelDrain: true) }
        guard let connectivity else { gate.finish(cancelDrain: true); return }
        let token = connectivity.drainForBackground { _ in gate.finish(cancelDrain: false) }
        gate.installCancellation { connectivity.cancelBackgroundDrain(token) }
    }

    #if DEBUG
    private func prepareSyntheticFixtureIfRequested() async throws {
        guard environment.fixtureID != nil, let coordinator, coordinator.authority == nil,
              let raw = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--owner-watch-prepared=") })
                .map({ String($0.dropFirst("--owner-watch-prepared=".count)) }),
              let drill = RecordingDrill(rawValue: raw), [.forehandGroundstroke, .backhandGroundstroke].contains(drill),
              let epoch = coordinator.watchEpoch else { return }
        let arguments = ProcessInfo.processInfo.arguments
        let arm: PlayingArm = arguments.contains("--owner-watch-match-wrist")
            ? (WKInterfaceDevice.current().wristLocation == .left ? .left : .right)
            : (arguments.contains("--owner-watch-left-arm") ? .left : .right)
        let owner = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: UUID(),
            watchInstallationEpoch: epoch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
            includesHeartRate: false, decisionID: UUID(), confirmedAtUnixSeconds: Date().timeIntervalSince1970,
            policyDigest: OwnerPracticePolicy.digest)
        _ = try await coordinator.receive(.mutate(requestID: UUID(), generations: coordinator.generations, mutation: .enrollment(owner)))
        let draft = try PracticeSetupDraft(originInstallationEpoch: owner.phoneInstallationEpoch,
            preparationID: UUID(), revision: 1, preferences: .init(currentRacketArm: arm, usualHand: arm, intendedDrill: drill))
        let prepared = try OwnerPreparation(authority: owner, practiceID: UUID(), draft: draft)
        _ = try await coordinator.receive(.prepare(correlation: .init(requestID: UUID(), generations: coordinator.generations,
            preparation: prepared.identity), preparation: prepared))
    }
    #endif
}

/// No MainActor assumption: expiration and drain callbacks can race on arbitrary framework executors.
nonisolated final class WatchBackgroundCompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private var cancellationRequested = false
    private var cancel: (@Sendable () -> Void)?
    private let completion: @Sendable () -> Void

    init(completion: @escaping @Sendable () -> Void) { self.completion = completion }

    func installCancellation(_ action: @escaping @Sendable () -> Void) {
        let shouldCancel = lock.withLock {
            if completed { return cancellationRequested }
            cancel = action; return false
        }
        if shouldCancel { action() }
    }

    func finish(cancelDrain: Bool) {
        let result: (Bool, (@Sendable () -> Void)?) = lock.withLock {
            guard !completed else { return (false, nil) }
            completed = true; cancellationRequested = cancelDrain
            let action = cancelDrain ? cancel : nil
            cancel = nil
            return (true, action)
        }
        guard result.0 else { return }
        result.1?()
        completion()
    }
}

/// Discovery/export run off MainActor and never reopen the active exclusive O6 store.
private nonisolated enum WatchPracticeTransferWorker {
    struct Prepared: Sendable { let url: URL; let publication: OwnerPracticePreparedPublication }
    private struct Candidate: Sendable { let url: URL; let newlyWritten: Bool }
    private static let queue = DispatchQueue(label: "PadelStrokeLab.watch-practice-export", qos: .utility)

    private static func run<Value: Sendable>(_ operation: @escaping @Sendable () throws -> Value) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    static func deletionContext(id: UUID, paths: RecordingPaths) async throws -> OwnerRecordingContext? {
        try await run {
            let base = paths.rawRoot.deletingLastPathComponent().deletingLastPathComponent()
            var found: OwnerRecordingContext?
            func consider(_ value: OwnerRecordingContext) throws {
                guard value.recordingID == id else { return }
                guard found == nil || found == value else { throw OwnerPracticeBundleError.conflict }
                found = value
            }
            for revision in try OwnerPracticeTransferInventory.snapshots(base: base) {
                for set in revision.sets { try consider(set.context) }
            }
            try OwnerPracticeRecoveryReader.forEachCandidate(base: base) { candidate in
                for set in candidate.sets { try consider(set.context) }
            }
            return found
        }
    }

    static func prepare(id: UUID, paths: RecordingPaths,
                        beforeImport: (@MainActor (URL) async throws -> Void)?) async throws -> Prepared? {
        let candidate: Candidate? = try await run {
            let base = paths.rawRoot.deletingLastPathComponent().deletingLastPathComponent()
            let revisions = try OwnerPracticeTransferInventory.snapshots(base: base)
            if let existing = revisions.first(where: { $0.receipt.recordingIDs.contains(id) }) {
                return Candidate(url: existing.directoryURL.appendingPathComponent("bundle.pslpractice"), newlyWritten: false)
            }
            var historical: OwnerPracticeTelemetry?
            try OwnerPracticeRecoveryReader.forEachCandidate(base: base) { candidate in
                if candidate.sets.contains(where: { $0.context.recordingID == id }) {
                    guard historical == nil else { throw OwnerPracticeBundleError.conflict }
                    historical = candidate
                }
            }
            guard let historical else { return nil }
            guard historical.status != .open, historical.finalization != nil else { throw OwnerPracticeBundleError.unavailable }
            // The same checked readback namespace used on iPhone is attributable before a receipt exists.
            // Unknown/incomplete writer debris remains visible and makes deletion fail closed.
            let name = ".owner-readback-" + UUID().uuidString
            let parent = open(paths.outboxRoot.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard parent >= 0 else { throw RecordingError.io(operation: "open practice staging parent", code: errno) }
            defer { close(parent) }
            guard mkdirat(parent, name, 0o700) == 0, fsync(parent) == 0 else {
                throw RecordingError.io(operation: "create durable practice stage", code: errno)
            }
            let url = paths.outboxRoot.appendingPathComponent(name).appendingPathComponent("bundle")
            _ = try OwnerPracticeBundle.write(telemetry: historical, rawRoot: paths.rawRoot, notesRoot: paths.notesRoot,
                revision: 1, heartRate: .asRecorded, destination: url)
            guard fsync(parent) == 0 else { throw RecordingError.io(operation: "sync practice stage", code: errno) }
            return Candidate(url: url, newlyWritten: true)
        }
        guard let candidate else { return nil }
        if candidate.newlyWritten { try await beforeImport?(candidate.url) }
        return try await run {
            let base = paths.rawRoot.deletingLastPathComponent().deletingLastPathComponent()
            return try Prepared(url: candidate.url,
                publication: OwnerPracticeBundle.prepareImport(from: candidate.url, destinationBase: base))
        }
    }
}
