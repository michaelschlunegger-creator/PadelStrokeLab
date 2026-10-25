import Foundation

/// Exact immutable scope. The application still checks its current arm, phase and owner authority
/// inside the supplied work.commit gate before accepting a probe or applying any control effect.
public struct VideoMotionTransportScope: Codable, Equatable, Sendable {
    public let binding: VideoMotionBinding
    public let armGeneration: UUID
    public let phoneEpoch: UUID
    public let watchEpoch: UUID
    public init(binding: VideoMotionBinding, armGeneration: UUID, phoneEpoch: UUID, watchEpoch: UUID) throws {
        self.binding = binding; self.armGeneration = armGeneration
        self.phoneEpoch = phoneEpoch; self.watchEpoch = watchEpoch
        try validate()
    }
    init(_ control: VideoMotionControlEnvelope) throws {
        try self.init(binding: control.binding, armGeneration: control.armGeneration,
                      phoneEpoch: control.phoneEpoch, watchEpoch: control.watchEpoch)
    }
    func validate() throws { try binding.validate() }
}

/// This distinct frame is used only with interactive sendMessageData. There is no outbox,
/// application-context slot or background delivery route for this family.
public struct VideoMotionTransportRequest: Codable, Equatable, Sendable {
    public static let maximumBytes = 98_304
    private static let prefix = Data("PSLVM1Q\n".utf8)
    private let schemaVersion: Int
    public let id: UUID
    public let scope: VideoMotionTransportScope
    public let sender: VideoMotionDevice
    public let control: VideoMotionControlEnvelope?
    /// Present only on phone-originated clock probes, sampled before serialization and sending.
    public let phoneSent: Double?

    public init(control: VideoMotionControlEnvelope) throws {
        schemaVersion = 1; id = UUID(); scope = try VideoMotionTransportScope(control)
        sender = control.sender; self.control = control; phoneSent = nil; try validate()
    }
    init(scope: VideoMotionTransportScope, phoneSent: Double) throws {
        schemaVersion = 1; id = UUID(); self.scope = scope; sender = .phone
        control = nil; self.phoneSent = phoneSent; try validate()
    }
    func validate() throws {
        try scope.validate()
        guard schemaVersion == 1 else { throw VideoMotionError.invalid("transport request version") }
        if let control {
            try control.validate()
            guard phoneSent == nil, sender == control.sender, try scope == VideoMotionTransportScope(control) else {
                throw VideoMotionError.integrity
            }
        } else {
            guard sender == .phone, let phoneSent, VideoMotionTime.valid(phoneSent) else {
                throw VideoMotionError.invalid("clock probe")
            }
        }
    }
    public static func recognizes(_ bytes: Data) -> Bool { bytes.starts(with: prefix) }
    public func encoded() throws -> Data {
        try validate()
        return try Self.prefix + OwnerCanonical.encode(self, domain: "PSLVideoMotionTransportRequest1",
                                                       limit: Self.maximumBytes - Self.prefix.count)
    }
    public static func decode(_ bytes: Data) throws -> Self {
        guard recognizes(bytes), bytes.count <= maximumBytes else { throw VideoMotionError.invalid("transport family/size") }
        let value: Self = try OwnerCanonical.decode(Data(bytes.dropFirst(prefix.count)),
            domain: "PSLVideoMotionTransportRequest1", limit: maximumBytes - prefix.count)
        try value.validate(); return value
    }
    var digest: String { get throws { RecordingChunkCodec.digest(try encoded()) } }
}

private enum VideoMotionWireFailure: String, Codable, Sendable {
    case unavailable, busy, cancelled, timedOut, invalidMessage, mismatchedReply, handlerFailure
    init(_ failure: OwnerTransportFailure) {
        switch failure {
        case .unavailable: self = .unavailable
        case .busy: self = .busy
        case .cancelled: self = .cancelled
        case .timedOut: self = .timedOut
        case .invalidMessage: self = .invalidMessage
        case .mismatchedReply: self = .mismatchedReply
        case .handlerFailure, .alreadyCommitted: self = .handlerFailure
        }
    }
    var failure: OwnerTransportFailure {
        switch self {
        case .unavailable: .unavailable
        case .busy: .busy
        case .cancelled: .cancelled
        case .timedOut: .timedOut
        case .invalidMessage: .invalidMessage
        case .mismatchedReply: .mismatchedReply
        case .handlerFailure: .handlerFailure
        }
    }
}

public struct VideoMotionTransportReply: Codable, Equatable, Sendable {
    public static let maximumBytes = 8_192
    private static let prefix = Data("PSLVM1R\n".utf8)
    private let schemaVersion: Int
    public let requestID: UUID
    public let requestDigest: String
    public let sender: VideoMotionDevice
    public let receipt: VideoMotionControlReceipt?
    public let watchReceived: Double?
    public let watchSent: Double?
    private let wireFailure: VideoMotionWireFailure?
    public var failure: OwnerTransportFailure? { wireFailure?.failure }

    public init(request: VideoMotionTransportRequest, sender: VideoMotionDevice,
                receipt: VideoMotionControlReceipt) throws {
        try self.init(request: request, sender: sender, receipt: receipt, watchReceived: nil, watchSent: nil, failure: nil)
    }
    init(request: VideoMotionTransportRequest, sender: VideoMotionDevice, watchReceived: Double, watchSent: Double) throws {
        try self.init(request: request, sender: sender, receipt: nil,
                      watchReceived: watchReceived, watchSent: watchSent, failure: nil)
    }
    init(request: VideoMotionTransportRequest, sender: VideoMotionDevice, failure: OwnerTransportFailure) throws {
        try self.init(request: request, sender: sender, receipt: nil, watchReceived: nil, watchSent: nil, failure: failure)
    }
    private init(request: VideoMotionTransportRequest, sender: VideoMotionDevice, receipt: VideoMotionControlReceipt?,
                 watchReceived: Double?, watchSent: Double?, failure: OwnerTransportFailure?) throws {
        schemaVersion = 1; requestID = request.id; requestDigest = try request.digest; self.sender = sender
        self.receipt = receipt; self.watchReceived = watchReceived; self.watchSent = watchSent
        wireFailure = failure.map(VideoMotionWireFailure.init)
        try requireReply(to: request, localDevice: request.sender)
    }
    private func validate() throws {
        guard schemaVersion == 1, VideoMotionValidation.digest(requestDigest) else {
            throw VideoMotionError.invalid("transport reply version/digest")
        }
        if let receipt {
            guard wireFailure == nil, watchReceived == nil, watchSent == nil,
                  VideoMotionValidation.digest(receipt.messageDigest), VideoMotionTime.valid(receipt.acceptedAt) else {
                throw VideoMotionError.invalid("control receipt")
            }
        } else if let watchReceived, let watchSent {
            guard wireFailure == nil, sender == .watch, VideoMotionTime.valid(watchReceived),
                  VideoMotionTime.valid(watchSent), watchSent >= watchReceived else {
                throw VideoMotionError.invalid("clock reply")
            }
        } else {
            guard wireFailure != nil, watchReceived == nil, watchSent == nil else {
                throw VideoMotionError.invalid("empty transport reply")
            }
        }
    }
    public func requireReply(to request: VideoMotionTransportRequest, localDevice: VideoMotionDevice) throws {
        try request.validate(); try validate()
        guard request.sender == localDevice, sender != localDevice, requestID == request.id,
              try requestDigest == request.digest else { throw OwnerTransportFailure.mismatchedReply }
        if wireFailure != nil { return }
        if let control = request.control {
            guard let receipt, receipt.operationID == control.operationID,
                  receipt.messageDigest == RecordingChunkCodec.digest(try control.encoded()) else {
                throw OwnerTransportFailure.mismatchedReply
            }
        } else {
            guard receipt == nil, watchReceived != nil, watchSent != nil else { throw OwnerTransportFailure.mismatchedReply }
        }
    }
    public func encoded() throws -> Data {
        try validate()
        return try Self.prefix + OwnerCanonical.encode(self, domain: "PSLVideoMotionTransportReply1",
                                                       limit: Self.maximumBytes - Self.prefix.count)
    }
    public static func decode(_ bytes: Data) throws -> Self {
        guard bytes.starts(with: prefix), bytes.count <= maximumBytes else { throw VideoMotionError.invalid("reply family/size") }
        let value: Self = try OwnerCanonical.decode(Data(bytes.dropFirst(prefix.count)),
            domain: "PSLVideoMotionTransportReply1", limit: maximumBytes - prefix.count)
        try value.validate(); return value
    }
}

/// An internal seam only. Public RecordingConnectivity construction supplies the real live WC adapter;
/// isolated fixture construction has no native fallback. No method can enqueue a message for later.
struct VideoMotionTransportAdapter: Sendable {
    let reachable: @Sendable () -> Bool
    let request: @Sendable (Data, @escaping @Sendable (Result<Data, OwnerTransportFailure>) -> Void) -> Void
}

typealias VideoMotionRequestHandler = @Sendable (VideoMotionTransportRequest, OwnerPreparationWork) async throws -> VideoMotionControlReceipt?
typealias VideoMotionBytesCompletion = @Sendable (Result<Data, OwnerTransportFailure>) -> Void

/// Holds one shared RecordingConnectivity admission for the lifetime of real work. Incoming tasks
/// retain admission after caller cancellation until their handler actually exits; outbound waits can
/// release immediately because late callbacks are fenced and cannot invoke an application handler.
final class VideoMotionTransport: @unchecked Sendable {
    private final class Operation: @unchecked Sendable {
        let id = UUID()
        let request: VideoMotionTransportRequest
        let incoming: Bool
        let work: OwnerPreparationWork
        let completion: VideoMotionBytesCompletion
        var answered = false
        var responseClaimed = false
        init(request: VideoMotionTransportRequest, incoming: Bool, timeout: TimeInterval,
             completion: @escaping VideoMotionBytesCompletion) {
            self.request = request; self.incoming = incoming
            work = OwnerPreparationWork(timeout: timeout); self.completion = completion
        }
    }
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "PadelStrokeLab.video-motion-transport", qos: .userInitiated)
    private let device: VideoMotionDevice
    private let clock: @Sendable () -> Double
    private let adapter: VideoMotionTransportAdapter?
    private let acquire: @Sendable () -> Bool
    private let release: @Sendable () -> Void
    private var operations: [UUID: Operation] = [:]
    private var handler: VideoMotionRequestHandler?
    // Timer is accessed on queue only and exists only while work remains.
    private var timer: DispatchSourceTimer?

    init(device: VideoMotionDevice, clock: @escaping @Sendable () -> Double,
         adapter: VideoMotionTransportAdapter?, acquire: @escaping @Sendable () -> Bool,
         release: @escaping @Sendable () -> Void) {
        self.device = device; self.clock = clock; self.adapter = adapter; self.acquire = acquire; self.release = release
    }
    deinit {
        timer?.cancel()
        for operation in operations.values where !operation.answered {
            operation.work.stop(.cancelled); _ = operation.work.close()
            operation.completion(.failure(.cancelled))
        }
    }
    var onRequest: VideoMotionRequestHandler? {
        get { lock.withLock { handler } }
        set { lock.withLock { handler = newValue } }
    }

    func send(_ control: VideoMotionControlEnvelope, timeout: TimeInterval,
              completion: @escaping @Sendable (Result<VideoMotionControlReceipt, OwnerTransportFailure>) -> Void) -> UUID {
        guard control.sender == device, let request = try? VideoMotionTransportRequest(control: control) else {
            completion(.failure(.invalidMessage)); return UUID()
        }
        return send(request, timeout: timeout) { result, _ in
            completion(result.flatMap { reply in
                if let receipt = reply.receipt { return .success(receipt) }
                return .failure(.invalidMessage)
            })
        }
    }
    func probe(_ scope: VideoMotionTransportScope, timeout: TimeInterval,
               completion: @escaping @Sendable (Result<VideoMotionClockExchange, OwnerTransportFailure>) -> Void) -> UUID {
        guard device == .phone, let request = try? VideoMotionTransportRequest(scope: scope, phoneSent: clock()) else {
            completion(.failure(.invalidMessage)); return UUID()
        }
        return send(request, timeout: timeout) { result, phoneReceived in
            completion(result.flatMap { reply in
                guard let p0 = request.phoneSent, let w1 = reply.watchReceived, let w2 = reply.watchSent else {
                    return .failure(.invalidMessage)
                }
                do { return .success(try VideoMotionClockExchange(id: request.id, phoneEpoch: scope.phoneEpoch,
                    watchEpoch: scope.watchEpoch, phoneSent: p0, watchReceived: w1, watchSent: w2, phoneReceived: phoneReceived)) }
                catch { return .failure(.invalidMessage) }
            })
        }
    }
    private func send(_ request: VideoMotionTransportRequest, timeout: TimeInterval,
                      completion: @escaping @Sendable (Result<VideoMotionTransportReply, OwnerTransportFailure>, Double) -> Void) -> UUID {
        guard let bytes = try? request.encoded() else { completion(.failure(.invalidMessage), 0); return UUID() }
        guard let adapter, adapter.reachable() else { completion(.failure(.unavailable), 0); return UUID() }
        let operation = Operation(request: request, incoming: false, timeout: timeout) { result in
            // The callback boundary time is serialized alongside the response inside the local
            // completion closure below; errors require no clock estimate.
            if case let .failure(failure) = result { completion(.failure(failure), 0) }
        }
        guard admit(operation) else { completion(.failure(.busy), 0); return operation.id }
        let callback: @Sendable (Result<Data, OwnerTransportFailure>) -> Void = { [weak self] result in
            guard let self else { return }
            let receivedAt = clock() // p3: before decoding or scheduling any application work.
            let claimed = lock.withLock {
                guard operations[operation.id] === operation, !operation.responseClaimed else { return false }
                operation.responseClaimed = true; return true
            }
            guard claimed else { return }
            let parsed: Result<VideoMotionTransportReply, OwnerTransportFailure>
            do {
                let reply = try VideoMotionTransportReply.decode(result.get())
                try reply.requireReply(to: request, localDevice: device)
                if let failure = reply.failure { throw failure }
                parsed = .success(reply)
            } catch { parsed = .failure(error as? OwnerTransportFailure ?? .invalidMessage) }
            finishOutbound(operation, result: parsed, receivedAt: receivedAt, completion: completion)
        }
        do {
            // Cancellation ordered before this synchronous handoff prevents the send. An already
            // handed-off request cannot be recalled; remote scope/phase validation remains binding.
            try operation.work.commit {
                guard adapter.reachable() else { throw OwnerTransportFailure.unavailable }
                adapter.request(bytes, callback)
            }
        } catch {
            finishOutbound(operation, result: .failure(error as? OwnerTransportFailure ?? .unavailable),
                           receivedAt: 0, completion: completion)
        }
        return operation.id
    }

    func receive(_ bytes: Data, timeout: TimeInterval, completion: @escaping VideoMotionBytesCompletion) -> UUID {
        let receivedAt = clock() // w1: synchronous entry, before decoding, validation or actor hops.
        guard let request = try? VideoMotionTransportRequest.decode(bytes), request.sender != device,
              VideoMotionTime.valid(receivedAt) else { completion(.failure(.invalidMessage)); return UUID() }
        guard let handler = onRequest else { completion(.failure(.unavailable)); return UUID() }
        let operation = Operation(request: request, incoming: true, timeout: timeout, completion: completion)
        guard admit(operation) else { completion(.failure(.busy)); return operation.id }
        Task { [self] in
            do {
                if let failure = operation.work.failure() { throw failure }
                let receipt = try await handler(request, operation.work)
                guard operation.work.didCommit else { throw OwnerTransportFailure.handlerFailure }
                let reply: VideoMotionTransportReply
                if request.control != nil {
                    guard let receipt else { throw OwnerTransportFailure.invalidMessage }
                    reply = try VideoMotionTransportReply(request: request, sender: device, receipt: receipt)
                } else {
                    guard receipt == nil else { throw OwnerTransportFailure.invalidMessage }
                    reply = try VideoMotionTransportReply(request: request, sender: device,
                        watchReceived: receivedAt, watchSent: clock()) // w2: before reply serialization/send.
                }
                finishIncoming(operation, .success(try reply.encoded()))
            } catch { finishIncoming(operation, .failure(error as? OwnerTransportFailure ?? .handlerFailure)) }
        }
        return operation.id
    }
    func cancel(_ id: UUID) {
        guard let operation = lock.withLock({ operations[id] }), operation.work.stop(.cancelled) else { return }
        expire(operation, reason: operation.work.failure() ?? .cancelled)
    }
    private func admit(_ operation: Operation) -> Bool {
        guard acquire() else { return false }
        let admitted = lock.withLock {
            guard operations.count < 16 else { return false }
            operations[operation.id] = operation; return true
        }
        guard admitted else { release(); return false }
        queue.async { [self] in
            guard timer == nil, lock.withLock({ !operations.isEmpty }) else { return }
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(25), leeway: .milliseconds(2))
            timer.setEventHandler { [weak self] in self?.poll() }
            self.timer = timer; timer.resume()
        }
        return true
    }
    private func answer(_ operation: Operation, _ result: Result<Data, OwnerTransportFailure>) {
        let claimed = lock.withLock {
            guard !operation.answered else { return false }; operation.answered = true; return true
        }
        if claimed { operation.completion(result) }
    }
    private func remove(_ operation: Operation) -> Bool {
        let removed = lock.withLock {
            guard operations[operation.id] === operation else { return false }
            operations.removeValue(forKey: operation.id); return true
        }
        if removed { release() }; return removed
    }
    private func finishIncoming(_ operation: Operation, _ result: Result<Data, OwnerTransportFailure>) {
        let failure = operation.work.close()
        guard remove(operation) else { return }
        answer(operation, failure.map { .failure($0) } ?? result)
    }
    private func finishOutbound(_ operation: Operation, result: Result<VideoMotionTransportReply, OwnerTransportFailure>,
                                receivedAt: Double,
                                completion: @Sendable (Result<VideoMotionTransportReply, OwnerTransportFailure>, Double) -> Void) {
        let failure = operation.work.close()
        guard remove(operation) else { return }
        let claimed = lock.withLock {
            guard !operation.answered else { return false }; operation.answered = true; return true
        }
        if claimed { completion(failure.map { .failure($0) } ?? result, receivedAt) }
    }
    private func expire(_ operation: Operation, reason: OwnerTransportFailure) {
        if operation.incoming { answer(operation, .failure(reason)) }
        else {
            _ = operation.work.close()
            if remove(operation) { answer(operation, .failure(reason)) }
        }
    }
    private func poll() {
        let snapshot = lock.withLock { Array(operations.values) }
        for operation in snapshot {
            if let failure = operation.work.failure(), operation.work.stop(failure) { expire(operation, reason: failure) }
        }
        if lock.withLock({ operations.isEmpty }) { timer?.cancel(); timer = nil }
    }
}
