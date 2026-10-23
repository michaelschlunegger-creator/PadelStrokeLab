import CryptoKit
import Darwin
import Foundation
#if os(iOS) || os(watchOS)
@preconcurrency import WatchConnectivity
#endif

public enum RecordingTransferState: String, Codable, Sendable {
    case queued, transferring, sent, received, verified, failed
}

public struct RecordingTransferSnapshot: Codable, Equatable, Sendable {
    public let recordingID: UUID
    public let state: RecordingTransferState
    public let detail: String?

    public init(recordingID: UUID, state: RecordingTransferState, detail: String? = nil) {
        self.recordingID = recordingID; self.state = state; self.detail = detail
    }
}

public struct RecordingDeletionFailure: Error, LocalizedError, Sendable {
    public let message: String
    public var errorDescription: String? { message }
}

/// Current permission is independent of historical capture admission and its retired contexts.
public enum OwnerPracticePublicationPermission {
    public static func require(_ scope: OwnerPracticePublicationScope, current: OwnerChannelSnapshot) throws {
        guard let owner = current.authority, owner.ownerID == scope.ownerID,
              owner.phoneInstallationEpoch == scope.phoneInstallationEpoch,
              owner.watchInstallationEpoch == scope.watchInstallationEpoch,
              owner.policyDigest == scope.policyDigest, scope.policyDigest == OwnerPracticePolicy.digest,
              owner.isCollectionAllowed, !current.motionAccessBlocked,
              !scope.includesHeartRate || (owner.heartRateConsent && !current.heartRateAccessBlocked) else {
            throw OwnerPracticeBundleError.unavailable
        }
    }
}

/// An opaque ingress token's scope. It denies publication; it never supplies authority.
public struct OwnerPracticePendingRestriction: Sendable {
    private let kind: OwnerLocalRestriction
    private let ownerID: UUID?, phone: UUID?, watch: UUID?
    public init(kind: OwnerLocalRestriction, owner: OwnerPracticeIdentity?) {
        self.kind = kind; ownerID = owner?.ownerID
        phone = owner?.phoneInstallationEpoch; watch = owner?.watchInstallationEpoch
    }
    public init?(message: OwnerPreparationMessage) {
        let mutation: OwnerAuthorityMutation
        switch message {
        case let .mutate(_, _, value): mutation = value
        case let .applied(_, _, value), let .transition(value): mutation = value.mutation
        case let .replayResult(_, _, value):
            guard let value else { return nil }; mutation = value.mutation
        default: return nil
        }
        guard mutation.isRestrictive else { return nil }
        kind = mutation.isFullWithdrawal ? .all : .heartRate
        ownerID = mutation.ownerID; phone = mutation.phoneEpoch; watch = mutation.watchEpoch
    }
    public func blocks(_ scope: OwnerPracticePublicationScope) -> Bool {
        (ownerID == nil || (ownerID == scope.ownerID && phone == scope.phoneInstallationEpoch && watch == scope.watchInstallationEpoch))
            && (kind == .all || (kind == .heartRate && scope.includesHeartRate))
    }
}

/// Enumerate only final, canonically named revisions; every returned inventory is reverified.
public enum OwnerPracticeTransferInventory {
    public static func snapshots(base: URL) throws -> [OwnerPracticeBundleSnapshot] {
        let root = try AnnotationFiles.root(base); defer { close(root) }
        guard try OwnerBundleNode.at(OwnerPracticeReceiptStore.directoryName, parent: root, directory: true) != nil else { return [] }
        let store = try OwnerPracticeReceiptStore(base: base)
        let fd = try AnnotationFiles.root(store.directoryURL); defer { close(fd) }
        var result: [OwnerPracticeBundleSnapshot] = []
        for name in try AnnotationFiles.names(fd, limit: 258) {
            if name == "identity.json" || name == ".publication.lock" || name.hasPrefix(".stage-") { continue }
            let parts = name.components(separatedBy: "-r")
            guard parts.count == 2, let id = UUID(uuidString: parts[0]), let revision = Int64(parts[1]), revision > 0,
                  name == id.uuidString.lowercased() + "-r" + String(revision) else { throw OwnerPracticeBundleError.integrity }
            result.append(try store.open(practiceID: id, revision: revision))
        }
        return result.sorted { $0.receipt.revision > $1.receipt.revision }
    }
}

public struct OwnerPracticeTransferSnapshot: Equatable, Sendable {
    public let receipt: OwnerPracticeReceipt
    public let state: RecordingTransferState
    public let detail: String?
}

struct OwnerPracticeTransportAdapter: Sendable {
    let available: @Sendable () -> Bool
    let transferFile: @Sendable (URL, [String: String], @escaping @Sendable (Result<Void, OwnerTransportFailure>) -> Void) -> Void
    let transferReceipt: @Sendable (Data) -> Void
}
struct OwnerPracticeDeletionTransportAdapter: Sendable {
    let available: @Sendable () -> Bool
    let transferCommand: @Sendable (Data) -> Void
    let transferAcknowledgment: @Sendable (Data) -> Void
}

private struct OwnerPracticeTransferRecord: Codable {
    let receiptBytes: Data
    let fileName: String
    var state: RecordingTransferState
    var detail: String?
    var receipt: OwnerPracticeReceipt { get throws { try .decode(receiptBytes) } }
    var snapshot: OwnerPracticeTransferSnapshot { get throws {
        try .init(receipt: receipt, state: state, detail: detail)
    } }
}

private struct OwnerPracticeAcknowledgment: Codable {
    let receiptBytes: Data
    var delivered: Bool
}

struct RecordingTransferRecord: Codable, Equatable {
    let schemaVersion: Int
    let receipt: RecordingArchiveReceipt
    let fileName: String
    var state: RecordingTransferState
    var detail: String?

    var snapshot: RecordingTransferSnapshot {
        RecordingTransferSnapshot(recordingID: receipt.recordingID, state: state, detail: detail)
    }

    func validate() throws {
        try receipt.validate()
        guard schemaVersion == 1, fileName.hasSuffix(".pslrecording"), fileName.utf8.count <= 128,
              !fileName.contains("/"), !fileName.utf8.contains(0),
              (detail?.utf8.count ?? 0) <= 512, state != .received else {
            throw RecordingError.invalid("transfer record")
        }
    }
}

/// Durable sender state. WC transport completion is only Sent; receiver acknowledgment is separate.
final class RecordingTransferLedger {
    let directory: Int32
    init(root: URL) throws { directory = try AnnotationFiles.root(root) }
    deinit { close(directory) }

    func load(_ id: UUID) throws -> RecordingTransferRecord? {
        guard let data = try AnnotationFiles.read(id.uuidString + ".transfer.json", directory: directory, limit: 8192) else { return nil }
        let record: RecordingTransferRecord = try RecordingJSON.decode(data, limit: 8192)
        try record.validate()
        guard record.receipt.recordingID == id else { throw RecordingError.invalid("transfer ledger identity") }
        return record
    }

    func save(_ record: RecordingTransferRecord) throws {
        try record.validate()
        try AnnotationFiles.publish(RecordingJSON.encode(record, limit: 8192),
                                    name: record.receipt.recordingID.uuidString + ".transfer.json", directory: directory)
    }

    func all() throws -> [RecordingTransferRecord] {
        let names = try AnnotationFiles.names(directory, limit: 4096)
        return try names.filter { $0.hasSuffix(".transfer.json") }.map { name in
            guard let id = UUID(uuidString: String(name.dropLast(14))),
                  name == id.uuidString + ".transfer.json", let record = try load(id) else {
                throw RecordingError.invalid("transfer ledger name")
            }
            return record
        }
    }

    func transition(_ id: UUID, to state: RecordingTransferState, detail: String? = nil) throws -> RecordingTransferRecord {
        guard var record = try load(id) else { throw RecordingError.invalid("unknown transfer") }
        guard state != .verified, state != .received else { throw RecordingError.invalid("receipt required") }
        if record.state == .verified { return record }
        record.state = state; record.detail = detail
        try save(record)
        return record
    }

    func acknowledge(id: UUID, digest: String) throws -> RecordingTransferRecord {
        guard var record = try load(id), record.receipt.bundleSHA256 == digest else {
            throw RecordingError.integrity("unexpected application receipt")
        }
        record.state = .verified; record.detail = "Phone verified retained files; capture completeness remains separate."
        try save(record)
        return record
    }

    static func withResumeAuthorization<T>(_ record: RecordingTransferRecord, notesRoot: URL,
                                            _ action: () throws -> T) throws -> T {
        let transaction = try RecordingLocalTransaction(recordingID: record.receipt.recordingID, notesRoot: notesRoot)
        defer { withExtendedLifetime(transaction) {} }
        try transaction.requireAvailable()
        return try action()
    }
}

struct RecordingReceiptAcknowledgment: Codable, Equatable {
    let recordingID: UUID
    let digest: String
    var delivered: Bool
}

struct RecordingBackgroundState: Sendable {
    let activated: Bool
    let hasContentPending: Bool
}

private struct RecordingBackgroundDrain {
    let deadline: DispatchTime
    let completion: @Sendable (Bool) -> Void
}

public enum OwnerTransportFailure: Error, Equatable, Sendable {
    case unavailable, busy, cancelled, timedOut, invalidMessage, mismatchedReply, handlerFailure, alreadyCommitted
}

enum OwnerPreparationDelivery { case interactive, control, draft }

/// A synchronous, single-use final commit gate. Cancellation ordered before commit denies mutation;
/// concurrent cancellation waits for a commit already inside the gate. Same-thread cancellation
/// defers its callback until the commit closure exits. No suspension or escaped mutation is permitted inside
/// the closure. Reentrant/repeated commits are rejected.
public final class OwnerPreparationWork: @unchecked Sendable {
    private let gate = NSRecursiveLock()
    private let deadline: DispatchTime
    private var stopped: OwnerTransportFailure?
    private var finished = false
    private var committed = false
    private var committing = false

    fileprivate init(timeout: TimeInterval) {
        deadline = .now() + (timeout.isFinite ? min(60, max(0.001, timeout)) : 10)
    }
    public var isCancelled: Bool { gate.withLock { rejection != nil } }
    private var rejection: OwnerTransportFailure? {
        stopped ?? (!finished && DispatchTime.now() >= deadline ? .timedOut : nil)
    }
    public func commit<T>(_ operation: () throws -> T) throws -> T {
        try gate.withLock {
            if let rejection { throw rejection }
            guard !finished, !committed else { throw OwnerTransportFailure.alreadyCommitted }
            committed = true
            committing = true
            defer { committing = false }
            return try operation()
        }
    }
    @discardableResult fileprivate func stop(_ reason: OwnerTransportFailure) -> Bool {
        gate.withLock {
            guard !finished else { return false }
            if stopped == nil { stopped = rejection ?? reason }
            // Same-thread cancellation can be observed after the commit closure exits;
            // it cannot invoke an external completion while that closure is still executing.
            return !committing
        }
    }
    fileprivate func failure() -> OwnerTransportFailure? { gate.withLock { rejection } }
    fileprivate func close() -> OwnerTransportFailure? {
        gate.withLock { stopped = rejection; finished = true; return stopped }
    }
}

struct OwnerTransportAdapter: Sendable {
    let request: @Sendable (Data, @escaping @Sendable (Result<Data, OwnerTransportFailure>) -> Void) -> Void
    let control: @Sendable (Data) throws -> Void
    let draft: @Sendable (Data) throws -> Void
}

private typealias OwnerHandler = @Sendable (OwnerPreparationMessage, OwnerPreparationWork) async throws -> OwnerPreparationMessage?
private typealias OwnerCompletion = @Sendable (Result<OwnerPreparationMessage?, OwnerTransportFailure>) -> Void
private final class OwnerOperation: @unchecked Sendable {
    let id: UUID
    let message: OwnerPreparationMessage
    let work: OwnerPreparationWork
    let handler: OwnerHandler
    let completion: OwnerCompletion
    let requiresReply: Bool
    // These flags are accessed only under RecordingConnectivity.lock.
    var answered = false
    var responseClaimed = false
    init(id: UUID, message: OwnerPreparationMessage, timeout: TimeInterval,
         requiresReply: Bool, handler: @escaping OwnerHandler, completion: @escaping OwnerCompletion) {
        self.id = id; self.message = message; work = OwnerPreparationWork(timeout: timeout)
        self.handler = handler; self.completion = completion; self.requiresReply = requiresReply
    }
}

/// One serial file/transport owner and an explicit bounded admission count. No work is launched per
/// sensor sample. Retained Watch originals and immutable outbox archives are never auto-deleted.
/// Synchronous ingress ownership bridges WC delivery to the retained application worker.
/// Failed operations retain their token; only the exact durable completion releases it.
public final class OwnerPracticeDeletionIngress: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [UUID: OwnerPracticeDeletionCommand] = [:]
    private var overflow = false
    public init() {}
    fileprivate func register(_ command: OwnerPracticeDeletionCommand) -> UUID {
        lock.withLock {
            let token = UUID()
            if tokens.count < 512 { tokens[token] = command } else { overflow = true }
            return token
        }
    }
    fileprivate func reconciled(_ token: UUID, command: OwnerPracticeDeletionCommand) {
        lock.withLock { if tokens[token] == command { tokens.removeValue(forKey: token) } }
    }
    private func blocked(owner: UUID, phone: UUID, watch: UUID, practice: UUID) -> Bool {
        overflow || tokens.values.contains { $0.ownerID == owner && $0.phoneInstallationEpoch == phone &&
            $0.watchInstallationEpoch == watch && $0.practiceID == practice }
    }
    public func allows(_ authority: OwnerPracticeIdentity, practiceID: UUID) -> Bool {
        lock.withLock { !blocked(owner: authority.ownerID, phone: authority.phoneInstallationEpoch,
            watch: authority.watchInstallationEpoch, practice: practiceID) }
    }
    public func withAllowed<T>(_ scope: OwnerPracticePublicationScope, operation: () throws -> T) throws -> T {
        try lock.withLock {
            guard !blocked(owner: scope.ownerID, phone: scope.phoneInstallationEpoch,
                watch: scope.watchInstallationEpoch, practice: scope.practiceID) else { throw OwnerPracticeBundleError.unavailable }
            return try operation()
        }
    }
    public func withAllowed<T>(_ authority: OwnerPracticeIdentity, practiceID: UUID, operation: () throws -> T) throws -> T {
        try lock.withLock {
            guard !blocked(owner: authority.ownerID, phone: authority.phoneInstallationEpoch,
                watch: authority.watchInstallationEpoch, practice: practiceID) else { throw OwnerPracticeBundleError.unavailable }
            return try operation()
        }
    }
}

public final class RecordingConnectivity: NSObject, @unchecked Sendable {
    private let paths: RecordingPaths
    private let owner = DispatchQueue(label: "PadelStrokeLab.recording-connectivity", qos: .utility)
    private let lock = NSLock()
    private var pending = 0
    private var handler: (@Sendable (RecordingTransferSnapshot) -> Void)?
    private var drains: [UUID: RecordingBackgroundDrain] = [:]
    private var drainTimer: DispatchSourceTimer?
    private let backgroundStateProvider: (@Sendable () -> RecordingBackgroundState)?
    private let backgroundTimeout: TimeInterval
    private static let capacity = 16
    private let ownerTransportAdapter: OwnerTransportAdapter?
    private let practiceTransportAdapter: OwnerPracticeTransportAdapter?
    private let practiceDeletionTransportAdapter: OwnerPracticeDeletionTransportAdapter?
    private var deletionHandler: (@Sendable (OwnerPracticeDeletionCommand) async throws -> OwnerPracticeDeletionAcknowledgment)?
    private var deletingPractices: Set<UUID> = []
    public let practiceDeletionIngress = OwnerPracticeDeletionIngress()
    private var practicePublisher: (@Sendable (OwnerPracticePreparedPublication) async throws -> OwnerPracticeReceipt)?
    private var practiceHandler: (@Sendable (OwnerPracticeTransferSnapshot) -> Void)?
    private var practiceInFlight: [String: UUID] = [:]
    private var practiceAuthorizing: Set<String> = []
    private var ownerHandler: OwnerHandler?
    private var ownerOperations: [UUID: OwnerOperation] = [:]
    private var ownerTimer: DispatchSourceTimer?
    private var ownerTimerScheduled = false
    private var activeDraft: UUID?
    private var nextDraft: OwnerOperation?
    private var outgoingDraft: (Data, @Sendable (Result<Void, OwnerTransportFailure>) -> Void)?
    private var outgoingDraftScheduled = false
    #if os(iOS) || os(watchOS)
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    #endif

    public var onChange: (@Sendable (RecordingTransferSnapshot) -> Void)? {
        get { lock.withLock { handler } }
        set { lock.withLock { handler = newValue } }
    }

    /// Handles both incoming messages and correlated outbound replies on their original lease.
    /// Put final peer/generation revalidation and synchronous persistence inside work.commit.
    public var onOwnerPreparation: (@Sendable (OwnerPreparationMessage, OwnerPreparationWork) async throws -> OwnerPreparationMessage?)? {
        get { lock.withLock { ownerHandler } }
        set { lock.withLock { ownerHandler = newValue } }
    }

    public var onOwnerPracticePublication: (@Sendable (OwnerPracticePreparedPublication) async throws -> OwnerPracticeReceipt)? {
        get { lock.withLock { practicePublisher } }
        set { lock.withLock { practicePublisher = newValue } }
    }
    public var onPracticeChange: (@Sendable (OwnerPracticeTransferSnapshot) -> Void)? {
        get { lock.withLock { practiceHandler } }
        set { lock.withLock { practiceHandler = newValue } }
    }
    public var onPracticeDeletion: (@Sendable (OwnerPracticeDeletionCommand) async throws -> OwnerPracticeDeletionAcknowledgment)? {
        get { lock.withLock { deletionHandler } }
        set { lock.withLock { deletionHandler = newValue } }
    }

    public convenience init(paths: RecordingPaths) {
        self.init(paths: paths, backgroundStateProvider: nil, backgroundTimeout: 30)
    }

    /// Readiness/time seams isolate WC for host tests; public construction always uses real WC state.
    init(paths: RecordingPaths, backgroundStateProvider: (@Sendable () -> RecordingBackgroundState)?,
         backgroundTimeout: TimeInterval, ownerTransportAdapter: OwnerTransportAdapter? = nil,
         practiceTransportAdapter: OwnerPracticeTransportAdapter? = nil,
         practiceDeletionTransportAdapter: OwnerPracticeDeletionTransportAdapter? = nil) {
        self.paths = paths; self.backgroundStateProvider = backgroundStateProvider
        self.backgroundTimeout = min(30, max(0.01, backgroundTimeout))
        self.ownerTransportAdapter = ownerTransportAdapter
        self.practiceTransportAdapter = practiceTransportAdapter
        self.practiceDeletionTransportAdapter = practiceDeletionTransportAdapter
        super.init()
    }

    deinit {
        drainTimer?.cancel()
        ownerTimer?.cancel()
        for request in drains.values { request.completion(false) }
    }

    /// Complete a Watch connectivity background task only after framework delivery and admitted
    /// verification work both drain. Cancellation/deadline never discard files or pending receipts.
    @discardableResult
    public func drainForBackground(completion: @escaping @Sendable (Bool) -> Void) -> UUID {
        let id = UUID()
        let admitted = lock.withLock {
            guard drains.count < 8 else { return false }
            drains[id] = RecordingBackgroundDrain(deadline: .now() + backgroundTimeout, completion: completion)
            return true
        }
        guard admitted else { completion(false); return id }
        owner.async { [self] in
            guard drainTimer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: owner)
            timer.schedule(deadline: .now(), repeating: .milliseconds(250), leeway: .milliseconds(20))
            timer.setEventHandler { [weak self] in self?.pollBackgroundDrains() }
            drainTimer = timer
            timer.resume()
        }
        return id
    }

    public func cancelBackgroundDrain(_ id: UUID) {
        let completion = lock.withLock { drains.removeValue(forKey: id)?.completion }
        completion?(false)
    }

    private func pollBackgroundDrains() {
        let state: RecordingBackgroundState
        if let backgroundStateProvider { state = backgroundStateProvider() }
        else {
            #if os(iOS) || os(watchOS)
            state = RecordingBackgroundState(activated: session?.activationState == .activated,
                                             hasContentPending: session?.hasContentPending ?? true)
            #else
            state = RecordingBackgroundState(activated: false, hasContentPending: true)
            #endif
        }
        let now = DispatchTime.now().uptimeNanoseconds
        let completions: [(@Sendable (Bool) -> Void, Bool)] = lock.withLock {
            let ready = state.activated && !state.hasContentPending && pending == 0 && nextDraft == nil && outgoingDraft == nil
            var completed: [(@Sendable (Bool) -> Void, Bool)] = []
            for (id, request) in drains where ready || now >= request.deadline.uptimeNanoseconds {
                drains.removeValue(forKey: id)
                completed.append((request.completion, ready && now < request.deadline.uptimeNanoseconds))
            }
            return completed
        }
        for (completion, success) in completions { completion(success) }
        if lock.withLock({ drains.isEmpty }) { drainTimer?.cancel(); drainTimer = nil }
    }

    /// Used only to verify an explicitly supplied isolated test transport belongs to the same namespace.
    public func isBound(to expected: RecordingPaths) -> Bool {
        paths.rawRoot == expected.rawRoot && paths.notesRoot == expected.notesRoot
            && paths.outboxRoot == expected.outboxRoot && paths.inboxRoot == expected.inboxRoot
    }

    public func activate() {
        submit(id: nil) { [self] in
            #if os(iOS) || os(watchOS)
            guard let session else { return }
            session.delegate = self
            session.activate()
            #endif
        }
    }

    @discardableResult
    public func sendOwnerRequest(_ request: OwnerPreparationMessage, timeout: TimeInterval = 10,
        completion: @escaping @Sendable (Result<OwnerPreparationMessage, OwnerTransportFailure>) -> Void) -> UUID {
        let id = UUID()
        guard request.isRequest, let data = try? OwnerPreparationCodec.encode(request) else {
            completion(.failure(.invalidMessage)); return id
        }
        let operation = admitOwner(id: id, message: request, timeout: timeout, draft: false, requiresReply: true) { result in
            switch result {
            case .success(let reply):
                if let reply { completion(.success(reply)) } else { completion(.failure(.invalidMessage)) }
            case .failure(let failure): completion(.failure(failure))
            }
        }
        guard let operation else { return id }
        requestOwnerData(data) { [self] result in
            let claimed = lock.withLock {
                guard ownerOperations[id] === operation, !operation.responseClaimed else { return false }
                operation.responseClaimed = true; return true
            }
            guard claimed else { return }
            if let failure = operation.work.failure() { finishOwner(operation, .failure(failure)); return }
            switch result {
            case .failure(let failure): finishOwner(operation, .failure(failure))
            case .success(let data):
                guard let reply = try? OwnerPreparationCodec.decode(data) else {
                    finishOwner(operation, .failure(.invalidMessage)); return
                }
                guard reply.isReply(to: request) else { finishOwner(operation, .failure(.mismatchedReply)); return }
                runOwner(operation, message: reply, isReply: true)
            }
        }
        return id
    }

    /// May wait for synchronous persistence inside the commit gate; call off the main actor.
    public func cancelOwnerOperation(_ id: UUID) {
        let operation = lock.withLock { ownerOperations[id] ?? (nextDraft?.id == id ? nextDraft : nil) }
        guard let operation else { return }
        guard operation.work.stop(.cancelled) else { return }
        answerOwner(operation, .failure(operation.work.failure() ?? .cancelled))
    }

    @discardableResult
    func receiveOwnerData(_ data: Data, delivery: OwnerPreparationDelivery, timeout: TimeInterval = 10,
        completion: @escaping @Sendable (Result<OwnerPreparationMessage?, OwnerTransportFailure>) -> Void) -> UUID {
        let id = UUID()
        guard let message = try? OwnerPreparationCodec.decode(data), validOwner(message, delivery: delivery) else {
            completion(.failure(.invalidMessage)); return id
        }
        if let operation = admitOwner(id: id, message: message, timeout: timeout,
                                      draft: delivery == .draft, requiresReply: delivery == .interactive, completion: completion) {
            runOwner(operation, message: message, isReply: false)
        }
        return id
    }

    private func validOwner(_ message: OwnerPreparationMessage, delivery: OwnerPreparationDelivery) -> Bool {
        switch delivery {
        case .interactive: return message.isRequest
        case .draft: if case .draft = message { return true }; return false
        case .control:
            switch message { case .mutate, .transition, .acknowledge: return true; default: return false }
        }
    }

    private func admitOwner(id: UUID, message: OwnerPreparationMessage, timeout: TimeInterval, draft: Bool, requiresReply: Bool,
                            completion: @escaping OwnerCompletion) -> OwnerOperation? {
        var rejected: OwnerTransportFailure?, replaced: OwnerOperation?, cancelled: OwnerOperation?
        let operation: OwnerOperation? = lock.withLock {
            guard let ownerHandler else { rejected = .unavailable; return nil }
            let operation = OwnerOperation(id: id, message: message, timeout: timeout,
                                           requiresReply: requiresReply, handler: ownerHandler, completion: completion)
            if draft, activeDraft != nil || nextDraft != nil || pending == Self.capacity {
                replaced = nextDraft; nextDraft = operation
                cancelled = activeDraft.flatMap { ownerOperations[$0] }; return nil
            }
            guard pending < Self.capacity else { rejected = .busy; return nil }
            pending += 1; ownerOperations[id] = operation
            if draft { activeDraft = id }
            return operation
        }
        // Never enter a work gate or client callback while holding the shared state lock.
        if let replaced {
            replaced.work.stop(.cancelled); _ = replaced.work.close()
            answerOwner(replaced, .failure(.cancelled))
        }
        if let cancelled { cancelOwnerOperation(cancelled.id) }
        if let rejected { completion(.failure(rejected)) }
        if rejected == nil { startOwnerTimer(); scheduleWaitingDraft() }
        return operation
    }

    private func runOwner(_ operation: OwnerOperation, message: OwnerPreparationMessage, isReply: Bool) {
        Task { [self] in
            do {
                if let failure = operation.work.failure() { throw failure }
                let response = try await operation.handler(message, operation.work)
                if !isReply, operation.requiresReply {
                    guard let response, response.isReply(to: operation.message),
                          (try? OwnerPreparationCodec.encode(response)) != nil else {
                        throw OwnerTransportFailure.mismatchedReply
                    }
                }
                finishOwner(operation, .success(isReply ? message : response))
            } catch { finishOwner(operation, .failure(error as? OwnerTransportFailure ?? .handlerFailure)) }
        }
    }

    private func answerOwner(_ operation: OwnerOperation, _ result: Result<OwnerPreparationMessage?, OwnerTransportFailure>) {
        let answer = lock.withLock {
            guard !operation.answered else { return false }; operation.answered = true; return true
        }
        if answer { operation.completion(result) }
    }

    private func finishOwner(_ operation: OwnerOperation, _ result: Result<OwnerPreparationMessage?, OwnerTransportFailure>) {
        let result = operation.work.close().map { Result<OwnerPreparationMessage?, OwnerTransportFailure>.failure($0) } ?? result
        var next: OwnerOperation?
        let removed = lock.withLock {
            guard ownerOperations.removeValue(forKey: operation.id) != nil else { return false }
            if activeDraft == operation.id {
                next = nextDraft; nextDraft = nil; activeDraft = next?.id
                if let next { ownerOperations[next.id] = next }
            }
            if next == nil { pending -= 1 }
            return true
        }
        guard removed else { return }
        // A successor inherits the lease atomically: background drain never sees a zero-work gap.
        if let next { runOwner(next, message: next.message, isReply: false) }
        answerOwner(operation, result)
        scheduleWaitingDraft()
        scheduleOutgoingDraft()
    }

    private func startOwnerTimer() {
        let start = lock.withLock {
            guard !ownerTimerScheduled else { return false }
            ownerTimerScheduled = true; return true
        }
        guard start else { return }
        owner.async { [self] in
            let timer = DispatchSource.makeTimerSource(queue: owner)
            timer.schedule(deadline: .now(), repeating: .milliseconds(25))
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                let operations = lock.withLock { Array(ownerOperations.values) + [nextDraft].compactMap { $0 } }
                for operation in operations {
                    if let failure = operation.work.failure() { answerOwner(operation, .failure(failure)) }
                }
                let empty = lock.withLock {
                    guard ownerOperations.isEmpty, nextDraft == nil else { return false }
                    ownerTimerScheduled = false; return true
                }
                if empty { ownerTimer?.cancel(); ownerTimer = nil }
            }
            ownerTimer = timer; timer.resume()
        }
    }

    /// Success means submitted to transport, never remote authority application.
    public func queueOwnerControl(_ message: OwnerPreparationMessage,
        completion: @escaping @Sendable (Result<Void, OwnerTransportFailure>) -> Void) {
        guard validOwner(message, delivery: .control), let data = try? OwnerPreparationCodec.encode(message) else {
            completion(.failure(.invalidMessage)); return
        }
        if !submit(id: nil, { [self] in
            do { try sendOwnerControl(data); completion(.success(())) }
            catch { completion(.failure(error as? OwnerTransportFailure ?? .unavailable)) }
        }) { completion(.failure(.busy)) }
    }

    /// One latest suggestion is retained even while all shared work slots are occupied.
    public func updateOwnerDraft(_ preparation: OwnerPreparation,
        completion: @escaping @Sendable (Result<Void, OwnerTransportFailure>) -> Void) {
        guard let data = try? OwnerPreparationCodec.encode(.draft(preparation)) else {
            completion(.failure(.invalidMessage)); return
        }
        let replaced = lock.withLock { let old = outgoingDraft; outgoingDraft = (data, completion); return old }
        replaced?.1(.failure(.cancelled))
        scheduleOutgoingDraft()
    }

    private func scheduleOutgoingDraft() {
        let scheduled = lock.withLock {
            guard outgoingDraft != nil, !outgoingDraftScheduled, pending < Self.capacity else { return false }
            pending += 1; outgoingDraftScheduled = true; return true
        }
        guard scheduled else { return }
        owner.async { [self] in
            let draft = lock.withLock { let value = outgoingDraft; outgoingDraft = nil; return value }
            if let draft {
                do { try sendOwnerDraft(draft.0); draft.1(.success(())) }
                catch { draft.1(.failure(error as? OwnerTransportFailure ?? .unavailable)) }
            }
            lock.withLock { outgoingDraftScheduled = false }
            releaseWork()
        }
    }

    private func releaseWork() {
        lock.withLock { pending -= 1 }
        scheduleWaitingDraft()
        scheduleOutgoingDraft()
    }

    private func scheduleWaitingDraft() {
        let next: OwnerOperation? = lock.withLock {
            guard activeDraft == nil, let nextDraft, pending < Self.capacity else { return nil }
            self.nextDraft = nil; activeDraft = nextDraft.id
            ownerOperations[nextDraft.id] = nextDraft; pending += 1; return nextDraft
        }
        if let next { runOwner(next, message: next.message, isReply: false) }
    }

    private func requestOwnerData(_ data: Data, completion: @escaping @Sendable (Result<Data, OwnerTransportFailure>) -> Void) {
        if let ownerTransportAdapter { ownerTransportAdapter.request(data, completion); return }
        #if os(iOS) || os(watchOS)
        guard let session, session.activationState == .activated, session.isReachable else {
            completion(.failure(.unavailable)); return
        }
        session.sendMessageData(data, replyHandler: { completion(.success($0)) },
                                errorHandler: { _ in completion(.failure(.unavailable)) })
        #else
        completion(.failure(.unavailable))
        #endif
    }

    private func sendOwnerControl(_ data: Data) throws {
        if let ownerTransportAdapter { try ownerTransportAdapter.control(data); return }
        #if os(iOS) || os(watchOS)
        guard let session, session.activationState == .activated else { throw OwnerTransportFailure.unavailable }
        let queued = session.outstandingUserInfoTransfers.filter { $0.userInfo["kind"] as? String == "PSLOwnerSetup2.control" }
        if queued.contains(where: { $0.userInfo["payload"] as? Data == data }) { return }
        guard queued.count < Self.capacity else { throw OwnerTransportFailure.busy }
        session.transferUserInfo(["kind": "PSLOwnerSetup2.control", "payload": data])
        #else
        throw OwnerTransportFailure.unavailable
        #endif
    }

    private func sendOwnerDraft(_ data: Data) throws {
        if let ownerTransportAdapter { try ownerTransportAdapter.draft(data); return }
        #if os(iOS) || os(watchOS)
        guard let session, session.activationState == .activated else { throw OwnerTransportFailure.unavailable }
        try session.updateApplicationContext(["kind": "PSLOwnerSetup2.draft", "payload": data])
        #else
        throw OwnerTransportFailure.unavailable
        #endif
    }

    public func queue(recordingID: UUID, timeline: CaptureTimeline) {
        submit(id: recordingID) { [self] in
            do {
                try requireRecordingNotDeleted(recordingID)
                let transaction = try RecordingLocalTransaction(recordingID: recordingID, notesRoot: paths.notesRoot)
                defer { withExtendedLifetime(transaction) {} }
                try transaction.requireAvailable()
                let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
                let record: RecordingTransferRecord
                if let previous = try ledger.load(recordingID) {
                    if previous.state == .verified { emit(previous.snapshot); return }
                    try validateOutbound(previous)
                    record = try ledger.transition(recordingID, to: .queued)
                } else {
                    let fileName = recordingID.uuidString + "-" + UUID().uuidString + ".pslrecording"
                    let receipt = try RecordingArchive.write(recordingID: recordingID, rawRoot: paths.rawRoot,
                        timeline: timeline, destination: paths.outboxRoot.appendingPathComponent(fileName))
                    record = RecordingTransferRecord(schemaVersion: 1, receipt: receipt, fileName: fileName, state: .queued)
                    try ledger.save(record)
                }
                emit(record.snapshot)
                #if os(iOS) || os(watchOS)
                try send(record, ledger: ledger)
                #else
                emit(RecordingTransferSnapshot(recordingID: recordingID, state: .queued,
                    detail: "WatchConnectivity requires a paired physical iPhone and Apple Watch."))
                #endif
            } catch { failure(recordingID, error) }
        }
    }

    public func status(recordingID: UUID, completion: @escaping @Sendable (RecordingTransferSnapshot?) -> Void) {
        let accepted = submit(id: recordingID) { [self] in
            do { completion(try RecordingTransferLedger(root: paths.outboxRoot).load(recordingID)?.snapshot) }
            catch { failure(recordingID, error); completion(nil) }
        }
        if !accepted { completion(nil) }
    }

    /// Explicit user-confirmed deletion only. This sends no deletion command to the phone.
    public func deleteWatchCopy(recordingID: UUID,
        completion: @escaping @Sendable (Result<Void, RecordingDeletionFailure>) -> Void) {
        let accepted = submit(id: recordingID) { [self] in
            do {
                try RecordingLocalCopies.deleteWatchCopy(recordingID: recordingID, paths: paths) {
                    #if os(iOS) || os(watchOS)
                    for transfer in self.session?.outstandingFileTransfers ?? [] where
                        transfer.file.metadata?["recordingID"] as? String == recordingID.uuidString {
                        transfer.cancel()
                    }
                    #endif
                }
                completion(.success(()))
            } catch {
                completion(.failure(RecordingDeletionFailure(message: error is RecordingLocalCopyError ?
                    error.localizedDescription : String(describing: error))))
            }
        }
        if !accepted { completion(.failure(RecordingDeletionFailure(message: "Transfer queue is busy. Try deleting again shortly."))) }
    }

    @discardableResult
    func submit(id: UUID?, _ operation: @escaping @Sendable () -> Void) -> Bool {
        let accepted = lock.withLock {
            guard pending < Self.capacity else { return false }
            pending += 1; return true
        }
        guard accepted else {
            if let id { emit(RecordingTransferSnapshot(recordingID: id, state: .failed,
                detail: "Transfer queue is busy. Original recording is retained; retry later.")) }
            return false
        }
        owner.async { [self] in
            defer { releaseWork() }
            operation()
        }
        return true
    }

    func receiveUserInfo(_ userInfo: [String: Any]) {
        if let kind = userInfo["kind"] as? String, ["PSLOwnerPracticeDelete1", "PSLOwnerPracticeDeleteAck1"].contains(kind) {
            guard let bytes = userInfo["payload"] as? Data, bytes.count <= 32_768 else { return }
            if kind == "PSLOwnerPracticeDeleteAck1" {
                guard let acknowledgment = try? OwnerPracticeDeletionAcknowledgment.decode(bytes) else { return }
                submit(id: nil) { [self] in
                    try? OwnerPracticeDeletion.acknowledge(acknowledgment, base: practiceBase, device: deletionDevice)
                }
            } else {
                guard let command = try? OwnerPracticeDeletionCommand.decode(bytes), command.requester != deletionDevice,
                      let handler = onPracticeDeletion,
                      lock.withLock({ if pending >= Self.capacity { return false }; pending += 1; return true }) else { return }
                let ingressToken = practiceDeletionIngress.register(command)
                Task { [self] in
                    do {
                        let acknowledgment = try await handler(command)
                        guard acknowledgment.command == command, acknowledgment.device == deletionDevice else { throw OwnerTransportFailure.invalidMessage }
                        owner.async { [self] in
                            defer { releaseWork() }
                            do {
                                guard let status = try OwnerPracticeDeletion.status(base: practiceBase, practiceID: command.practiceID),
                                      status.command == command, status.localComplete else { throw OwnerPracticeBundleError.integrity }
                                practiceDeletionIngress.reconciled(ingressToken, command: command)
                                try sendDeletion(acknowledgment.encoded(), acknowledgment: true)
                            } catch { }
                        }
                    } catch { owner.async { [self] in releaseWork() } }
                }
            }
            return
        }
        if userInfo["kind"] as? String == "PSLOwnerPracticeReceipt1" {
            if let bytes = userInfo["payload"] as? Data, let receipt = try? OwnerPracticeReceipt.decode(bytes) {
                submit(id: nil) { [self] in
                    do {
                        let key = Self.practiceKey(receipt)
                        guard var record = try practiceRecord(key), try record.receipt == receipt else { return }
                        try validatePractice(record)
                        record.state = .verified; record.detail = "Phone verified the complete practice. Originals retained."
                        try savePractice(record); emitPractice(try record.snapshot)
                    } catch { /* Invalid/unknown receipts cannot alter another revision or infer verification. */ }
                }
            }
            return
        }
        if userInfo["kind"] as? String == "PSLOwnerSetup2.control" {
            if let data = userInfo["payload"] as? Data {
                receiveOwnerData(data, delivery: .control) { _ in }
            }
            return
        }
        guard userInfo["kind"] as? String == "PSLReceipt1",
              let text = userInfo["recordingID"] as? String, let id = UUID(uuidString: text),
              let digest = userInfo["sha256"] as? String else { return }
        submit(id: id) { [self] in
            do {
                try requireRecordingNotDeleted(id)
                let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
                guard let record = try ledger.load(id) else { throw RecordingError.invalid("unknown application receipt") }
                try RecordingTransferLedger.withResumeAuthorization(record, notesRoot: paths.notesRoot) {
                    emit(try ledger.acknowledge(id: id, digest: digest).snapshot)
                }
            }
            catch { failure(id, error) }
        }
    }


    private var practiceBase: URL { paths.rawRoot.deletingLastPathComponent().deletingLastPathComponent() }
    private var deletionDevice: OwnerPracticeDevice {
        #if os(watchOS)
        .watch
        #else
        .phone
        #endif
    }
    public func fencePracticeDeletion(_ practiceID: UUID) {
        lock.withLock { _ = deletingPractices.insert(practiceID) }
        owner.async { [self] in
            #if os(iOS) || os(watchOS)
            for transfer in session?.outstandingFileTransfers ?? [] where
                transfer.file.metadata?["practiceID"] as? String == practiceID.uuidString {
                transfer.cancel()
            }
            #endif
        }
    }
    private func requirePracticeNotDeleted(_ id: UUID) throws {
        guard !lock.withLock({ deletingPractices.contains(id) }),
              try OwnerPracticeDeletion.status(base: practiceBase, practiceID: id) == nil else { throw OwnerPracticeBundleError.unavailable }
    }
    private func requireRecordingNotDeleted(_ id: UUID) throws {
        guard try !OwnerPracticeDeletion.pending(base: practiceBase).contains(where: { $0.command.recordingIDs.contains(id) }) else {
            throw OwnerPracticeBundleError.unavailable
        }
        let pending = lock.withLock { deletingPractices }
        if !pending.isEmpty {
            guard try !OwnerPracticeTransferInventory.snapshots(base: practiceBase).contains(where: {
                pending.contains($0.receipt.practiceID) && $0.receipt.recordingIDs.contains(id)
            }) else { throw OwnerPracticeBundleError.unavailable }
        }
    }
    public func resumePracticeDeletions() {
        submit(id: nil) { [self] in
            do {
                for status in try OwnerPracticeDeletion.pending(base: practiceBase) where status.localComplete && !status.peerComplete {
                    if status.command.requester == deletionDevice {
                        try sendDeletion(status.command.encoded(), acknowledgment: false)
                    } else {
                        try sendDeletion(OwnerPracticeDeletionAcknowledgment(command: status.command, device: deletionDevice).encoded(), acknowledgment: true)
                    }
                }
            } catch { /* Durable intent remains pending until explicit retry or transport activation. */ }
        }
    }
    private func sendDeletion(_ bytes: Data, acknowledgment: Bool) throws {
        guard bytes.count <= 32_768 else { throw OwnerTransportFailure.invalidMessage }
        if let adapter = practiceDeletionTransportAdapter {
            guard adapter.available() else { return }
            if acknowledgment { adapter.transferAcknowledgment(bytes) } else { adapter.transferCommand(bytes) }
            return
        }
        #if os(iOS) || os(watchOS)
        guard practiceAvailable, let session else { return }
        let kind = acknowledgment ? "PSLOwnerPracticeDeleteAck1" : "PSLOwnerPracticeDelete1"
        if !session.outstandingUserInfoTransfers.contains(where: { $0.userInfo["kind"] as? String == kind && $0.userInfo["payload"] as? Data == bytes }) {
            session.transferUserInfo(["kind": kind, "payload": bytes])
        }
        #endif
    }
    private static func practiceKey(_ receipt: OwnerPracticeReceipt) -> String {
        OwnerBundleIO.digest(Data("\(receipt.practiceID.uuidString):\(receipt.revision):\(receipt.bundleSHA256)".utf8))
    }
    private func practiceRecord(_ key: String) throws -> OwnerPracticeTransferRecord? {
        let fd = try AnnotationFiles.root(paths.outboxRoot); defer { close(fd) }
        guard let bytes = try AnnotationFiles.read(key + ".practice.json", directory: fd, limit: 32_768) else { return nil }
        let record: OwnerPracticeTransferRecord = try RecordingJSON.decode(bytes, limit: 32_768)
        guard Self.practiceKey(try record.receipt) == key, record.fileName == key + ".pslpractice",
              record.state != .received, (record.detail?.utf8.count ?? 0) <= 512 else { throw OwnerPracticeBundleError.integrity }
        return record
    }
    private func savePractice(_ record: OwnerPracticeTransferRecord) throws {
        let key = Self.practiceKey(try record.receipt)
        guard record.fileName == key + ".pslpractice" else { throw OwnerPracticeBundleError.integrity }
        let fd = try AnnotationFiles.root(paths.outboxRoot); defer { close(fd) }
        try AnnotationFiles.publish(RecordingJSON.encode(record, limit: 32_768), name: key + ".practice.json", directory: fd)
    }
    private func validatePractice(_ record: OwnerPracticeTransferRecord) throws {
        let receipt = try record.receipt
        try requirePracticeNotDeleted(receipt.practiceID)
        let fd = try AnnotationFiles.root(paths.outboxRoot); defer { close(fd) }
        try OwnerBundleIO.match(record.fileName, directory: fd, bytes: receipt.byteCount, digest: receipt.bundleSHA256)
    }
    private func emitPractice(_ snapshot: OwnerPracticeTransferSnapshot) {
        onPracticeChange?(snapshot)
        for id in snapshot.receipt.recordingIDs {
            emit(.init(recordingID: id, state: snapshot.state, detail: snapshot.detail ?? "Complete practice transfer"))
        }
    }
    /// Counted synchronous ownership of ephemeral WC bytes, before its delegate returns.
    private func copyPractice(_ source: URL, root: URL, name: String) throws -> URL {
        let inputAnchor = try OwnerBundleAnchor(source.deletingLastPathComponent()), outputAnchor = try OwnerBundleAnchor(root)
        let (input, size) = try AnnotationFiles.openFile(source.lastPathComponent, directory: inputAnchor.fd)
        defer { close(input) }
        guard (45...OwnerPracticeBundle.maximumBytes).contains(size) else { throw OwnerPracticeBundleError.capacity }
        let output = try OwnerBundleIO.create(name, directory: outputAnchor.fd)
        defer { close(output) }
        _ = try OwnerBundleIO.consume(input, count: size) { try AnnotationFiles.write($0, fd: output) }
        try AnnotationFiles.sync(output); try inputAnchor.check(); try outputAnchor.check(); try AnnotationFiles.sync(outputAnchor.fd)
        return root.appendingPathComponent(name)
    }
    public func queuePractice(from source: URL) {
        submit(id: nil) { [self] in
            var known: OwnerPracticeReceipt?
            do {
                let copied = try copyPractice(source, root: paths.outboxRoot, name: UUID().uuidString + ".practice-staging")
                defer { try? FileManager.default.removeItem(at: copied) }
                let prepared = try OwnerPracticeBundle.prepareImport(from: copied, destinationBase: practiceBase)
                let receipt = prepared.receipt; prepared.cancel(); known = receipt
                try requirePracticeNotDeleted(receipt.practiceID)
                let key = Self.practiceKey(receipt), filename = key + ".pslpractice"
                var record: OwnerPracticeTransferRecord
                if let existing = try practiceRecord(key) {
                    guard try existing.receipt == receipt else { throw OwnerPracticeBundleError.integrity }
                    try validatePractice(existing)
                    if existing.state == .verified || practiceInFlight[key] != nil { emitPractice(try existing.snapshot); return }
                    record = existing; record.state = .queued; record.detail = nil
                } else {
                    let fd = try AnnotationFiles.root(paths.outboxRoot); defer { close(fd) }
                    if try OwnerBundleNode.at(filename, parent: fd, directory: false) == nil {
                        guard renameatx_np(fd, copied.lastPathComponent, fd, filename, UInt32(RENAME_EXCL)) == 0 else {
                            throw AnnotationFiles.error("retain complete practice outbox")
                        }
                        try AnnotationFiles.sync(fd)
                    }
                    record = try OwnerPracticeTransferRecord(receiptBytes: receipt.encoded(), fileName: filename, state: .queued)
                    try validatePractice(record)
                }
                try savePractice(record); emitPractice(try record.snapshot); try sendPractice(record)
            } catch {
                if let known { failPractice(known, detail: "Complete practice transfer failed; originals retained.") }
            }
        }
    }
    public func practiceStatus(practiceID: UUID, revision: Int64, bundleSHA256: String,
        completion: @escaping @Sendable (OwnerPracticeTransferSnapshot?) -> Void) {
        let key = OwnerBundleIO.digest(Data("\(practiceID.uuidString):\(revision):\(bundleSHA256)".utf8))
        if !submit(id: nil, { [self] in completion(try? practiceRecord(key)?.snapshot) }) { completion(nil) }
    }
    public func resumePracticeTransfers() {
        submit(id: nil) { [self] in
            do {
                let fd = try AnnotationFiles.root(paths.outboxRoot); defer { close(fd) }
                for name in try AnnotationFiles.names(fd, limit: 4096) where name.hasSuffix(".practice.json") {
                    let key = String(name.dropLast(".practice.json".count))
                    guard let record = try practiceRecord(key) else { continue }
                    if record.state == .queued || record.state == .transferring { try sendPractice(record) }
                }
                try resumePracticeAcknowledgments()
            } catch { /* A durable failure remains explicit; activation cannot silently retry it. */ }
        }
    }
    private var practiceAvailable: Bool {
        if let practiceTransportAdapter { return practiceTransportAdapter.available() }
        #if os(iOS) || os(watchOS)
        guard let session, session.activationState == .activated else { return false }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return false }
        #endif
        return true
        #else
        return false
        #endif
    }
    private func sendPractice(_ supplied: OwnerPracticeTransferRecord, authorized: Bool = false) throws {
        guard practiceAvailable else { return }
        let receipt = try supplied.receipt, key = Self.practiceKey(receipt)
        guard practiceInFlight[key] == nil, !practiceAuthorizing.contains(key) else { return }
        // Activation/retry must recheck live authority too; a previously queued envelope is not a grant.
        if !authorized, let publisher = onOwnerPracticePublication {
            guard lock.withLock({ if pending >= Self.capacity { return false }; pending += 1; return true }) else {
                throw OwnerTransportFailure.busy
            }
            let prepared: OwnerPracticePreparedPublication
            do { prepared = try OwnerPracticeBundle.prepareImport(from: paths.outboxRoot.appendingPathComponent(supplied.fileName), destinationBase: practiceBase) }
            catch { releaseWork(); throw error }
            practiceAuthorizing.insert(key)
            Task { [self] in
                let allowed: Bool
                do { allowed = try await publisher(prepared) == receipt } catch { allowed = false }
                owner.async { [self] in
                    defer { prepared.cancel(); releaseWork() }
                    practiceAuthorizing.remove(key)
                    do {
                        guard allowed else { throw OwnerPracticeBundleError.unavailable }
                        try sendPractice(supplied, authorized: true)
                    } catch { failPractice(receipt, detail: "Current practice permission or delivery is unavailable. Originals retained; retry explicitly.") }
                }
            }
            return
        }
        let metadata = ["kind": "PSLOwnerPractice1", "practiceID": receipt.practiceID.uuidString,
            "revision": String(receipt.revision), "sha256": receipt.bundleSHA256]
        #if os(iOS) || os(watchOS)
        if practiceTransportAdapter == nil, session?.outstandingFileTransfers.contains(where: {
            $0.file.metadata?["kind"] as? String == "PSLOwnerPractice1"
                && $0.file.metadata?["practiceID"] as? String == metadata["practiceID"]
                && $0.file.metadata?["revision"] as? String == metadata["revision"]
                && $0.file.metadata?["sha256"] as? String == metadata["sha256"]
        }) == true { return }
        #endif
        try validatePractice(supplied)
        var record = supplied; record.state = .transferring; record.detail = "Sending complete practice; originals retained."
        try savePractice(record)
        let attempt = UUID(); practiceInFlight[key] = attempt; emitPractice(try record.snapshot)
        let url = paths.outboxRoot.appendingPathComponent(record.fileName)
        if let practiceTransportAdapter {
            practiceTransportAdapter.transferFile(url, metadata) { [weak self] result in
                guard let self else { return }
                self.owner.async { self.finishPractice(key: key, attempt: attempt, success: (try? result.get()) != nil) }
            }
        } else {
            #if os(iOS) || os(watchOS)
            session?.transferFile(url, metadata: metadata)
            #endif
        }
    }
    private func finishPractice(key: String, attempt: UUID? = nil, success: Bool) {
        if let attempt, practiceInFlight[key] != attempt { return }
        practiceInFlight.removeValue(forKey: key)
        do {
            guard var record = try practiceRecord(key), record.state != .verified else { return }
            try validatePractice(record)
            record.state = success ? .sent : .failed
            record.detail = success ? "Sent; waiting for complete practice verification." : "Transfer failed; retry explicitly. Originals retained."
            try savePractice(record); emitPractice(try record.snapshot)
        } catch { /* Do not infer successful delivery when retained bytes or state cannot be checked. */ }
    }
    private func failPractice(_ receipt: OwnerPracticeReceipt, detail: String) {
        do {
            if var record = try practiceRecord(Self.practiceKey(receipt)), record.state != .verified {
                record.state = .failed; record.detail = detail; try savePractice(record)
            }
        } catch { }
        emitPractice(.init(receipt: receipt, state: .failed, detail: detail))
    }
    public func receivePracticeFile(from source: URL, metadata: [String: String],
        completion: @escaping @Sendable (Result<OwnerPracticeReceipt, OwnerTransportFailure>) -> Void) {
        guard metadata["kind"] == "PSLOwnerPractice1", let id = metadata["practiceID"].flatMap(UUID.init(uuidString:)),
              let revision = metadata["revision"].flatMap(Int64.init), revision > 0,
              let digest = metadata["sha256"], OwnerBundleIO.isDigest(digest), let publisher = onOwnerPracticePublication else {
            completion(.failure(.invalidMessage)); return
        }
        do { try requirePracticeNotDeleted(id) } catch { completion(.failure(.handlerFailure)); return }
        guard lock.withLock({ if pending >= Self.capacity { return false }; pending += 1; return true }) else {
            completion(.failure(.busy)); return
        }
        do {
            let copied = try owner.sync { try copyPractice(source, root: paths.inboxRoot, name: UUID().uuidString + ".pslpractice") }
            owner.async { [self] in
                do {
                    let prepared = try OwnerPracticeBundle.prepareImport(from: copied, destinationBase: practiceBase)
                    guard prepared.receipt.practiceID == id, prepared.receipt.revision == revision,
                          prepared.receipt.bundleSHA256 == digest else { prepared.cancel(); throw OwnerPracticeBundleError.integrity }
                    Task { [self] in
                        let result: Result<OwnerPracticeReceipt, OwnerTransportFailure>
                        do {
                            let receipt = try await publisher(prepared)
                            guard receipt == prepared.receipt else { throw OwnerPracticeBundleError.integrity }
                            result = .success(receipt)
                        } catch { result = .failure(error as? OwnerTransportFailure ?? .handlerFailure) }
                        owner.async { [self] in
                            defer { prepared.cancel(); try? FileManager.default.removeItem(at: copied); releaseWork() }
                            do {
                                let receipt = try result.get()
                                try requirePracticeNotDeleted(receipt.practiceID)
                                try savePracticeAcknowledgment(receipt, delivered: false)
                                try resumePracticeAcknowledgments()
                                emitPractice(.init(receipt: receipt, state: .verified, detail: "Complete practice retained and verified."))
                                completion(.success(receipt))
                            } catch { completion(.failure(error as? OwnerTransportFailure ?? .handlerFailure)) }
                        }
                    }
                } catch {
                    try? FileManager.default.removeItem(at: copied); releaseWork(); completion(.failure(.handlerFailure))
                }
            }
        } catch { releaseWork(); completion(.failure(.handlerFailure)) }
    }
    private func savePracticeAcknowledgment(_ receipt: OwnerPracticeReceipt, delivered: Bool) throws {
        try requirePracticeNotDeleted(receipt.practiceID)
        let fd = try AnnotationFiles.root(paths.outboxRoot); defer { close(fd) }
        let ack = try OwnerPracticeAcknowledgment(receiptBytes: receipt.encoded(), delivered: delivered)
        try AnnotationFiles.publish(RecordingJSON.encode(ack, limit: 32_768), name: Self.practiceKey(receipt) + ".practice-ack.json", directory: fd)
    }
    private func resumePracticeAcknowledgments() throws {
        guard practiceAvailable else { return }
        let fd = try AnnotationFiles.root(paths.outboxRoot); defer { close(fd) }
        for name in try AnnotationFiles.names(fd, limit: 4096) where name.hasSuffix(".practice-ack.json") {
            guard let bytes = try AnnotationFiles.read(name, directory: fd, limit: 32_768) else { continue }
            let ack: OwnerPracticeAcknowledgment = try RecordingJSON.decode(bytes, limit: 32_768)
            guard !ack.delivered else { continue }
            let receipt = try OwnerPracticeReceipt.decode(ack.receiptBytes)
            try requirePracticeNotDeleted(receipt.practiceID)
            guard name == Self.practiceKey(receipt) + ".practice-ack.json",
                  try OwnerPracticeReceiptStore(base: practiceBase).receipt(practiceID: receipt.practiceID, revision: receipt.revision) == receipt else {
                throw OwnerPracticeBundleError.integrity
            }
            if let practiceTransportAdapter { practiceTransportAdapter.transferReceipt(ack.receiptBytes) }
            else {
                #if os(iOS) || os(watchOS)
                if session?.outstandingUserInfoTransfers.contains(where: {
                    $0.userInfo["kind"] as? String == "PSLOwnerPracticeReceipt1" && $0.userInfo["payload"] as? Data == ack.receiptBytes
                }) != true { session?.transferUserInfo(["kind": "PSLOwnerPracticeReceipt1", "payload": ack.receiptBytes]) }
                #endif
            }
        }
    }

    private func emit(_ snapshot: RecordingTransferSnapshot) { onChange?(snapshot) }

    private func failure(_ id: UUID, _ error: any Error) {
        let detail = String((error is RecordingLocalCopyError ? error.localizedDescription : String(describing: error)).prefix(120))
        if error is RecordingLocalCopyError {
            emit(RecordingTransferSnapshot(recordingID: id, state: .failed, detail: detail))
            return
        }
        do {
            let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
            if try ledger.load(id) != nil {
                emit(try ledger.transition(id, to: .failed, detail: detail).snapshot)
                return
            }
        } catch { /* Preserve original error in the visible failure. No success is inferred. */ }
        emit(RecordingTransferSnapshot(recordingID: id, state: .failed, detail: detail))
    }

    private func validateOutbound(_ record: RecordingTransferRecord) throws {
        let directory = try AnnotationFiles.root(paths.outboxRoot)
        defer { close(directory) }
        let (fd, size) = try AnnotationFiles.openFile(record.fileName, directory: directory)
        defer { close(fd) }
        guard size == record.receipt.byteCount else { throw RecordingError.integrity("outbox file length") }
        var hash = SHA256()
        var remaining = size
        while remaining > 0 {
            let bytes = try AnnotationFiles.readExactly(fd, count: min(65_536, remaining))
            hash.update(data: bytes); remaining -= bytes.count
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == record.receipt.bundleSHA256 else { throw RecordingError.integrity("outbox file checksum") }
    }

    #if os(iOS) || os(watchOS)
    private func send(_ record: RecordingTransferRecord, ledger: RecordingTransferLedger) throws {
        guard let session, session.activationState == .activated else { return }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif
        if session.outstandingFileTransfers.contains(where: {
            ($0.file.metadata?["recordingID"] as? String) == record.receipt.recordingID.uuidString &&
            ($0.file.metadata?["sha256"] as? String) == record.receipt.bundleSHA256
        }) { return }
        try validateOutbound(record)
        // Persist before enqueueing. A crash here is recoverable by activation's pending scan.
        let transferring = try ledger.transition(record.receipt.recordingID, to: .transferring)
        session.transferFile(paths.outboxRoot.appendingPathComponent(record.fileName), metadata: [
            "kind": "PSLRecording1", "recordingID": record.receipt.recordingID.uuidString,
            "sha256": record.receipt.bundleSHA256
        ])
        emit(transferring.snapshot)
    }

    private func resumePending() {
        do {
            let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
            for record in try ledger.all() {
                do {
                    try RecordingTransferLedger.withResumeAuthorization(record, notesRoot: paths.notesRoot) {
                        emit(record.snapshot)
                        if record.state != .verified && record.state != .failed { try send(record, ledger: ledger) }
                    }
                } catch { failure(record.receipt.recordingID, error) }
            }
        } catch {
            // Existing per-record snapshots remain intact. A later explicit queue reports details.
        }
        resumeAcknowledgments()
    }

    private func sendAcknowledgment(_ receipt: RecordingArchiveReceipt, store: SessionAnnotationsStore,
                                    receivedCopy: URL? = nil) throws {
        try RecordingLocalCopies.withVerifiedReceipt(receipt, paths: paths) {
            if let receivedCopy { try RecordingLocalCopies.removeIncomingCopy(receivedCopy, recordingID: receipt.recordingID, paths: paths) }
            try enqueueAcknowledgment(receipt, store: store)
            if receivedCopy != nil {
                emit(RecordingTransferSnapshot(recordingID: receipt.recordingID, state: .verified,
                    detail: "Retained files verified. Capture completeness remains separate."))
            }
        }
    }

    private func enqueueAcknowledgment(_ receipt: RecordingArchiveReceipt, store: SessionAnnotationsStore) throws {
        guard let session, session.activationState == .activated else { return }
        let pending = RecordingReceiptAcknowledgment(recordingID: receipt.recordingID,
            digest: receipt.bundleSHA256, delivered: false)
        try store.save(RecordingJSON.encode(pending, limit: 4096), name: "receipt-ack.json", id: receipt.recordingID)
        if session.outstandingUserInfoTransfers.contains(where: {
            $0.userInfo["kind"] as? String == "PSLReceipt1" &&
            $0.userInfo["recordingID"] as? String == receipt.recordingID.uuidString &&
            $0.userInfo["sha256"] as? String == receipt.bundleSHA256
        }) { return }
        session.transferUserInfo(["kind": "PSLReceipt1", "recordingID": receipt.recordingID.uuidString,
                                  "sha256": receipt.bundleSHA256])
    }

    private func resumeAcknowledgments() {
        do {
            guard let session, session.activationState == .activated else { return }
            let store = try SessionAnnotationsStore(root: paths.notesRoot)
            var available = max(0, Self.capacity - session.outstandingUserInfoTransfers.count)
            for name in try AnnotationFiles.names(store.rootFD, limit: 4096) {
                guard available > 0 else { break }
                guard let id = UUID(uuidString: name), name == id.uuidString,
                      let receipt = try store.loadReceipt(recordingID: id) else { continue }
                if let data = try store.read("receipt-ack.json", id: id, limit: 4096) {
                    let ack: RecordingReceiptAcknowledgment = try RecordingJSON.decode(data, limit: 4096)
                    guard ack.recordingID == id, ack.digest == receipt.bundleSHA256 else {
                        throw RecordingError.integrity("receipt acknowledgment identity")
                    }
                    if ack.delivered { continue }
                }
                try sendAcknowledgment(receipt, store: store)
                available -= 1
            }
        } catch {
            // Durable receipts survive activation/queue failures; no sender verification is inferred.
        }
    }

    #endif
}

#if os(iOS) || os(watchOS)
private struct OwnerNativeReply: @unchecked Sendable {
    let call: (Data) -> Void
    init(_ call: @escaping (Data) -> Void) { self.call = call }
}

extension RecordingConnectivity: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                        error: (any Error)?) {
        guard error == nil, activationState == .activated else { return }
        submit(id: nil) { [self] in resumePending() }
        resumePracticeTransfers()
        resumePracticeDeletions()
    }

    public func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
        if fileTransfer.file.metadata?["kind"] as? String == "PSLOwnerPractice1",
           let id = fileTransfer.file.metadata?["practiceID"] as? String,
           let revision = fileTransfer.file.metadata?["revision"] as? String,
           let digest = fileTransfer.file.metadata?["sha256"] as? String {
            let key = OwnerBundleIO.digest(Data("\(id):\(revision):\(digest)".utf8)), success = error == nil
            submit(id: nil) { [self] in finishPractice(key: key, success: success) }
            return
        }
        guard let idText = fileTransfer.file.metadata?["recordingID"] as? String, let id = UUID(uuidString: idText),
              let digest = fileTransfer.file.metadata?["sha256"] as? String else { return }
        let errorText = error.map { String(describing: $0) }
        submit(id: id) { [self] in
            do {
                let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
                guard let expected = try ledger.load(id), expected.receipt.bundleSHA256 == digest else {
                    throw RecordingError.integrity("unexpected transfer completion")
                }
                try RecordingTransferLedger.withResumeAuthorization(expected, notesRoot: paths.notesRoot) {
                    let result = try ledger.transition(id, to: errorText == nil ? .sent : .failed,
                        detail: errorText == nil ? "Sent; waiting for phone verification." : "Transport failed; original retained.")
                    emit(result.snapshot)
                }
            } catch { failure(id, error) }
        }
    }

    public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        if file.metadata?["kind"] as? String == "PSLOwnerPractice1" {
            receivePracticeFile(from: file.fileURL, metadata: file.metadata as? [String: String] ?? [:]) { _ in }
            return
        }
        guard file.metadata?["kind"] as? String == "PSLRecording1",
              let text = file.metadata?["recordingID"] as? String, let id = UUID(uuidString: text),
              let digest = file.metadata?["sha256"] as? String else { return }
        // Admission covers the synchronous copy too, so delegate bursts cannot allocate unlimited work.
        let accepted = lock.withLock {
            guard pending < Self.capacity else { return false }
            pending += 1; return true
        }
        guard accepted else {
            emit(RecordingTransferSnapshot(recordingID: id, state: .failed, detail: "Receiver busy; retry from Watch."))
            return
        }
        do {
            let copy = try owner.sync {
                try requireRecordingNotDeleted(id)
                return try RecordingLocalCopies.copyIncoming(file.fileURL, recordingID: id, paths: paths)
            }
            owner.async { [self] in
                defer { releaseWork() }
                do {
                    try requireRecordingNotDeleted(id)
                    emit(RecordingTransferSnapshot(recordingID: id, state: .received,
                        detail: "Received; verifying retained files."))
                    let receipt = try RecordingArchive.importBundle(from: copy, rawRoot: paths.rawRoot, notesRoot: paths.notesRoot,
                        expectedIdentity: id, expectedDigest: digest, beforeReceipt: {})
                    guard receipt.recordingID == id, receipt.bundleSHA256 == digest else {
                        throw RecordingError.integrity("transport metadata differs from archive")
                    }
                    // Import's durable receipt is mandatory; transport delivery alone cannot reach here.
                    try sendAcknowledgment(receipt, store: SessionAnnotationsStore(root: paths.notesRoot), receivedCopy: copy)
                } catch { failure(id, error) }
            }
        } catch {
            releaseWork()
            emit(RecordingTransferSnapshot(recordingID: id, state: .failed,
                detail: error is RecordingLocalCopyError ? error.localizedDescription : "Incoming copy failed; retry from Watch."))
        }
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        receiveUserInfo(userInfo)
    }

    public func session(_ session: WCSession, didReceiveMessageData messageData: Data,
                        replyHandler: @escaping (Data) -> Void) {
        // WC's reply closure predates Sendable; the wrapper is only invoked once by the owner path.
        let reply = OwnerNativeReply(replyHandler)
        receiveOwnerData(messageData, delivery: .interactive) { result in
            let message: OwnerPreparationMessage?
            switch result {
            case .success(let response): message = response
            case .failure(let failure):
                let code: PracticeSetupFailureCode = failure == .busy ? .busy :
                    (failure == .cancelled || failure == .timedOut ? .cancelled : .unavailable)
                message = (try? OwnerPreparationCodec.decode(messageData)).flatMap { try? .failure(replyingTo: $0, code: code) }
            }
            reply.call((message.flatMap { try? OwnerPreparationCodec.encode($0) }) ?? Data())
        }
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard applicationContext["kind"] as? String == "PSLOwnerSetup2.draft",
              let data = applicationContext["payload"] as? Data else { return }
        receiveOwnerData(data, delivery: .draft) { _ in }
    }

    public func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: (any Error)?) {
        let info = userInfoTransfer.userInfo
        if info["kind"] as? String == "PSLOwnerPracticeReceipt1", let bytes = info["payload"] as? Data,
           let receipt = try? OwnerPracticeReceipt.decode(bytes) {
            let delivered = error == nil
            submit(id: nil) { [self] in try? savePracticeAcknowledgment(receipt, delivered: delivered) }
            return
        }
        guard info["kind"] as? String == "PSLReceipt1",
              let text = info["recordingID"] as? String, let id = UUID(uuidString: text),
              let digest = info["sha256"] as? String else { return }
        let delivered = error == nil
        submit(id: id) { [self] in
            do {
              do {
                let transaction = try RecordingLocalTransaction(recordingID: id, notesRoot: paths.notesRoot)
                defer { withExtendedLifetime(transaction) {} }
                try transaction.requireAvailable()
                let store = try SessionAnnotationsStore(root: paths.notesRoot)
                guard let receipt = try store.loadReceipt(recordingID: id), receipt.bundleSHA256 == digest else {
                    throw RecordingError.integrity("acknowledgment completion identity")
                }
                let ack = RecordingReceiptAcknowledgment(recordingID: id, digest: digest, delivered: delivered)
                try store.save(RecordingJSON.encode(ack, limit: 4096), name: "receipt-ack.json", id: id)
              }
              // Release this recording's transaction before advancing the bounded acknowledgment queue.
              if delivered { resumeAcknowledgments() }
            } catch { failure(id, error) }
        }
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
#endif
