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

/// One serial file/transport owner and an explicit bounded admission count. No work is launched per
/// sensor sample. Retained Watch originals and immutable outbox archives are never auto-deleted.
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
    #if os(iOS) || os(watchOS)
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    #endif

    public var onChange: (@Sendable (RecordingTransferSnapshot) -> Void)? {
        get { lock.withLock { handler } }
        set { lock.withLock { handler = newValue } }
    }

    public convenience init(paths: RecordingPaths) {
        self.init(paths: paths, backgroundStateProvider: nil, backgroundTimeout: 30)
    }

    /// Readiness/time seams isolate WC for host tests; public construction always uses real WC state.
    init(paths: RecordingPaths, backgroundStateProvider: (@Sendable () -> RecordingBackgroundState)?,
         backgroundTimeout: TimeInterval) {
        self.paths = paths; self.backgroundStateProvider = backgroundStateProvider
        self.backgroundTimeout = min(30, max(0.01, backgroundTimeout))
        super.init()
    }

    deinit {
        drainTimer?.cancel()
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
            let ready = state.activated && !state.hasContentPending && pending == 0
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

    public func activate() {
        submit(id: nil) { [self] in
            #if os(iOS) || os(watchOS)
            guard let session else { return }
            session.delegate = self
            session.activate()
            #endif
        }
    }

    public func queue(recordingID: UUID, timeline: CaptureTimeline) {
        submit(id: recordingID) { [self] in
            do {
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
            defer { lock.withLock { pending -= 1 } }
            operation()
        }
        return true
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
extension RecordingConnectivity: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                        error: (any Error)?) {
        guard error == nil, activationState == .activated else { return }
        submit(id: nil) { [self] in resumePending() }
    }

    public func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
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
            let copy = try owner.sync { try RecordingLocalCopies.copyIncoming(file.fileURL, recordingID: id, paths: paths) }
            owner.async { [self] in
                defer { lock.withLock { pending -= 1 } }
                do {
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
            lock.withLock { pending -= 1 }
            emit(RecordingTransferSnapshot(recordingID: id, state: .failed,
                detail: error is RecordingLocalCopyError ? error.localizedDescription : "Incoming copy failed; retry from Watch."))
        }
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard userInfo["kind"] as? String == "PSLReceipt1",
              let text = userInfo["recordingID"] as? String, let id = UUID(uuidString: text),
              let digest = userInfo["sha256"] as? String else { return }
        submit(id: id) { [self] in
            do {
                let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
                guard let record = try ledger.load(id) else { throw RecordingError.invalid("unknown application receipt") }
                try RecordingTransferLedger.withResumeAuthorization(record, notesRoot: paths.notesRoot) {
                    emit(try ledger.acknowledge(id: id, digest: digest).snapshot)
                }
            }
            catch { failure(id, error) }
        }
    }

    public func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: (any Error)?) {
        let info = userInfoTransfer.userInfo
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
