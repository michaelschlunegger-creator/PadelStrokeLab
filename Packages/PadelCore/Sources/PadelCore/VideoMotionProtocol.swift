import Foundation

public enum VideoMotionDevice: String, Codable, Sendable { case phone, watch }

/// Original rational presentation time, including epoch; not a callback arrival time.
public struct VideoMotionMediaTimestamp: Codable, Equatable, Sendable {
    public let value: Int64
    public let timescale: Int32
    public let epoch: Int64
    public init(value: Int64, timescale: Int32, epoch: Int64) throws {
        self.value = value; self.timescale = timescale; self.epoch = epoch
        try validate()
    }
    func validate() throws {
        guard value >= 0, timescale > 0, epoch >= 0 else { throw VideoMotionError.invalid("media timestamp") }
    }
}

/// The adapter must obtain both PTS values from successfully appended native samples and
/// firstHostTime by actual capture-clock conversion. Constructing this value proves neither.
public struct VideoMotionPhoneStart: Codable, Equatable, Sendable {
    public let writerGeneration: UUID
    public let clockDomainID: UUID
    public let firstVideoPTS: VideoMotionMediaTimestamp
    public let firstAudioPTS: VideoMotionMediaTimestamp
    public let firstHostTime: Double
    public init(writerGeneration: UUID, clockDomainID: UUID, firstVideoPTS: VideoMotionMediaTimestamp,
                firstAudioPTS: VideoMotionMediaTimestamp, firstHostTime: Double) throws {
        self.writerGeneration = writerGeneration; self.clockDomainID = clockDomainID
        self.firstVideoPTS = firstVideoPTS; self.firstAudioPTS = firstAudioPTS; self.firstHostTime = firstHostTime
        try validate()
    }
    func validate() throws {
        try firstVideoPTS.validate(); try firstAudioPTS.validate()
        guard firstVideoPTS.epoch == firstAudioPTS.epoch, VideoMotionTime.valid(firstHostTime) else {
            throw VideoMotionError.invalid("native phone start")
        }
    }
}

/// The adapter must inspect durable chunks, THEN await the engine's serial snapshot barrier,
/// require completed writers covering them and recheck the live generation and owner authority.
/// A reducer value or rename-visible chunk alone is not durable acquisition evidence.
public struct VideoMotionMotionReady: Codable, Equatable, Sendable {
    public let captureGeneration: UUID
    public let clockDomainID: UUID
    public let firstTimestamp: Double
    public let lastTimestamp: Double
    public let accelerationChunks: Int
    public let deviceMotionChunks: Int
    public let completedChunkCount: Int
    public let manifestDigest: String
    public init(captureGeneration: UUID, clockDomainID: UUID, firstTimestamp: Double, lastTimestamp: Double,
                accelerationChunks: Int, deviceMotionChunks: Int, completedChunkCount: Int,
                manifestDigest: String) throws {
        self.captureGeneration = captureGeneration; self.clockDomainID = clockDomainID
        self.firstTimestamp = firstTimestamp; self.lastTimestamp = lastTimestamp
        self.accelerationChunks = accelerationChunks; self.deviceMotionChunks = deviceMotionChunks
        self.completedChunkCount = completedChunkCount; self.manifestDigest = manifestDigest
        try validate()
    }
    func validate() throws {
        guard VideoMotionTime.valid(firstTimestamp), VideoMotionTime.valid(lastTimestamp),
              lastTimestamp >= firstTimestamp, (1...1_024).contains(accelerationChunks),
              (1...1_024).contains(deviceMotionChunks), (2...4_096).contains(completedChunkCount),
              completedChunkCount >= accelerationChunks + deviceMotionChunks,
              VideoMotionValidation.digest(manifestDigest) else { throw VideoMotionError.invalid("durable motion readiness") }
    }
}

/// Local completion evidence supplied by the native durable-manifest adapter, not a stop request.
public struct VideoMotionFinalization: Codable, Equatable, Sendable {
    public let manifestDigest: String
    public let interrupted: Bool
    public init(manifestDigest: String, interrupted: Bool) throws {
        self.manifestDigest = manifestDigest; self.interrupted = interrupted; try validate()
    }
    func validate() throws {
        guard VideoMotionValidation.digest(manifestDigest) else { throw VideoMotionError.invalid("finalization digest") }
    }
}

public enum VideoMotionControlMessage: Codable, Equatable, Sendable {
    case start, stop, cancel, heartbeat
    case phoneStarted(VideoMotionPhoneStart)
    case motionReady(VideoMotionMotionReady)
    case clockMapping(VideoMotionClockMapping)
    case finalized(VideoMotionFinalization)
}

public struct VideoMotionControlEnvelope: Codable, Equatable, Sendable {
    public static let maximumBytes = 65_536
    public static let maximumSequence = 1_000_000
    private let schemaVersion: Int
    public let operationID: UUID
    public let binding: VideoMotionBinding
    public let armGeneration: UUID
    public let phoneEpoch: UUID
    public let watchEpoch: UUID
    public let sender: VideoMotionDevice
    public let sequence: Int
    public let message: VideoMotionControlMessage

    public init(operationID: UUID, binding: VideoMotionBinding, armGeneration: UUID,
                phoneEpoch: UUID, watchEpoch: UUID, sender: VideoMotionDevice, sequence: Int,
                message: VideoMotionControlMessage) throws {
        schemaVersion = 1; self.operationID = operationID; self.binding = binding
        self.armGeneration = armGeneration; self.phoneEpoch = phoneEpoch; self.watchEpoch = watchEpoch
        self.sender = sender; self.sequence = sequence; self.message = message; try validate()
    }
    func validate() throws {
        try binding.validate()
        guard schemaVersion == 1, (1...Self.maximumSequence).contains(sequence) else {
            throw VideoMotionError.invalid("control version/sequence")
        }
        switch message {
        case .start:
            guard sender == .watch else { throw VideoMotionError.invalid("Start source") }
        case .phoneStarted(let fact):
            guard sender == .phone else { throw VideoMotionError.invalid("phone fact source") }
            try fact.validate()
        case .motionReady(let fact):
            guard sender == .watch else { throw VideoMotionError.invalid("motion fact source") }
            try fact.validate()
        case .clockMapping(let mapping):
            try mapping.validate()
            guard sender == .phone, mapping.phoneEpoch == phoneEpoch, mapping.watchEpoch == watchEpoch else {
                throw VideoMotionError.integrity
            }
        case .finalized(let fact): try fact.validate()
        case .stop, .cancel, .heartbeat: break
        }
    }
    public func encoded() throws -> Data {
        try validate()
        return try OwnerCanonical.encode(self, domain: "PSLVideoMotionControl1", limit: Self.maximumBytes)
    }
    public static func decode(_ data: Data) throws -> Self {
        let value: Self = try OwnerCanonical.decode(data, domain: "PSLVideoMotionControl1", limit: maximumBytes)
        try value.validate(); return value
    }
}

public enum VideoMotionPhase: String, Codable, Sendable { case armed, starting, capturing, stopping, terminal }
public enum VideoMotionPeerStatus: String, Codable, Sendable { case unknown, recent }
public enum VideoMotionEffect: Equatable, Sendable {
    case requestPhoneStart, beginLocalCapture, beginCountdown, stopLocalCapture, requestPeerStop
}
public struct VideoMotionControlReceipt: Codable, Equatable, Sendable {
    public let operationID: UUID
    public let messageDigest: String
    public let phase: VideoMotionPhase
    public let acceptedAt: Double
}
public struct VideoMotionControlResult: Equatable, Sendable {
    public let receipt: VideoMotionControlReceipt
    public let effects: [VideoMotionEffect]
}

/// One runtime/arm only; never reconstruct an active reducer after relaunch or queue Start offline.
/// The native coordinator must persist facts/receipts, revalidate current authority before effects,
/// and separately enforce engine limits. This pure model provides no authority or hardware proof.
public struct VideoMotionProtocol: Sendable {
    public static let maximumOperations = 512
    public static let armLeaseSeconds: Double = 15
    public static let startupDeadlineSeconds: Double = 12
    public static let heartbeatTimeoutSeconds: Double = 6
    public static let stopAcknowledgmentSeconds: Double = 5
    public static let watchCaptureLimitSeconds: Double = 120
    public static let phoneCaptureLimitSeconds: Double = 132
    public let binding: VideoMotionBinding
    public let armGeneration: UUID
    public let phoneEpoch: UUID
    public let watchEpoch: UUID
    public let device: VideoMotionDevice
    public private(set) var phase: VideoMotionPhase = .armed
    public private(set) var phoneStart: VideoMotionPhoneStart?
    public private(set) var motionReady: VideoMotionMotionReady?
    public private(set) var clockMapping: VideoMotionClockMapping?
    public private(set) var localFinalization: VideoMotionFinalization?
    public private(set) var peerFinalization: VideoMotionFinalization?
    private var receipts: [UUID: VideoMotionControlReceipt] = [:]
    private var phoneSequence = 0
    private var watchSequence = 0
    private var lastTime: Double
    private var armExpiresAt: Double
    private var lastPeerAt: Double?
    private var startRequestedAt: Double?
    private var localCaptureRequestedAt: Double?
    private var stopRequestedAt: Double?
    private var countdownIssued = false

    /// Supply the current monotonic time in production; zero is useful for deterministic traces.
    public init(binding: VideoMotionBinding, armGeneration: UUID, phoneEpoch: UUID, watchEpoch: UUID,
                device: VideoMotionDevice, armedAt: Double = 0) throws {
        try binding.validate()
        guard VideoMotionTime.valid(armedAt) else { throw VideoMotionError.invalid("arm time") }
        self.binding = binding; self.armGeneration = armGeneration
        self.phoneEpoch = phoneEpoch; self.watchEpoch = watchEpoch; self.device = device
        lastTime = armedAt; armExpiresAt = armedAt + Self.armLeaseSeconds
    }

    public var peerStatus: VideoMotionPeerStatus {
        guard let lastPeerAt, lastTime - lastPeerAt < Self.heartbeatTimeoutSeconds,
              !stopAcknowledgmentOverdue else { return .unknown }
        return .recent
    }
    public var stopAcknowledgmentOverdue: Bool {
        guard let stopRequestedAt else { return false }
        return peerFinalization == nil && lastTime - stopRequestedAt >= Self.stopAcknowledgmentSeconds
    }
    public var canCountdown: Bool {
        guard phase == .capturing, peerStatus == .recent, localFinalization == nil, peerFinalization == nil,
              let phoneStart, let motionReady, let clockMapping, clockMapping.driftPPMRange != nil else { return false }
        // Require supported coverage of both acquisition facts; no fabricated zero-drift fallback.
        return (try? clockMapping.estimateWatch(atPhone: phoneStart.firstHostTime)) != nil
            && (try? clockMapping.estimatePhone(atWatch: motionReady.firstTimestamp)) != nil
            && (try? clockMapping.estimatePhone(atWatch: motionReady.lastTimestamp)) != nil
    }

    /// Invalid input is transactional: no sequence, receipt, timer or native effect is consumed.
    public mutating func receive(_ envelope: VideoMotionControlEnvelope, at time: Double) throws -> VideoMotionControlResult {
        var candidate = self
        let result = try candidate.accept(envelope, at: time)
        self = candidate; return result
    }
    private mutating func accept(_ envelope: VideoMotionControlEnvelope, at time: Double) throws -> VideoMotionControlResult {
        try checkTime(time); try envelope.validate()
        guard envelope.binding == binding, envelope.armGeneration == armGeneration,
              envelope.phoneEpoch == phoneEpoch, envelope.watchEpoch == watchEpoch else { throw VideoMotionError.integrity }
        let digest = RecordingChunkCodec.digest(try envelope.encoded())
        if let previous = receipts[envelope.operationID] {
            guard previous.messageDigest == digest else { throw VideoMotionError.conflict }
            lastTime = time // A replay never refreshes peer freshness or repeats effects.
            return VideoMotionControlResult(receipt: previous, effects: [])
        }
        let previousSequence = envelope.sender == .phone ? phoneSequence : watchSequence
        guard envelope.sequence > previousSequence else { throw VideoMotionError.conflict }
        guard receipts.count < Self.maximumOperations else { throw VideoMotionError.capacity }
        lastTime = time
        var effects = advanceDeadlines()
        if envelope.sender != device { lastPeerAt = time }
        switch envelope.message {
        case .start:
            guard phase == .armed else { throw VideoMotionError.conflict }
            phase = .starting; startRequestedAt = time
            if device == .phone { localCaptureRequestedAt = time; effects.append(.beginLocalCapture) }
            else { effects.append(.requestPhoneStart) }
        case .stop, .cancel:
            effects += stop(at: time, requestPeer: envelope.sender == device)
        case .heartbeat:
            if phase == .armed { armExpiresAt = time + Self.armLeaseSeconds }
        case .phoneStarted(let fact):
            guard phase != .armed else { throw VideoMotionError.conflict }
            guard phoneStart == nil || phoneStart == fact else { throw VideoMotionError.conflict }
            phoneStart = fact
            if phase == .starting || phase == .capturing {
                if device == .phone { phase = .capturing }
                else if localCaptureRequestedAt == nil {
                    localCaptureRequestedAt = time; effects.append(.beginLocalCapture)
                }
            }
        case .motionReady(let fact):
            guard phase != .armed, phoneStart != nil else { throw VideoMotionError.conflict }
            guard motionReady == nil || motionReady == fact else { throw VideoMotionError.conflict }
            motionReady = fact
            if phase == .starting || phase == .capturing { phase = .capturing }
        case .clockMapping(let mapping):
            // A mapping is immutable; later revisions append observations to the same epoch pair.
            if let previous = clockMapping {
                guard mapping == previous || (mapping.id != previous.id && mapping.exchanges.starts(with: previous.exchanges)) else {
                    throw VideoMotionError.conflict
                }
            }
            clockMapping = mapping
        case .finalized(let fact):
            if envelope.sender == device {
                guard localFinalization == nil || localFinalization == fact else { throw VideoMotionError.conflict }
                localFinalization = fact
                if stopRequestedAt == nil { stopRequestedAt = time; effects.append(.requestPeerStop) }
                phase = .terminal
            } else {
                guard peerFinalization == nil || peerFinalization == fact else { throw VideoMotionError.conflict }
                peerFinalization = fact
                effects += stop(at: time, requestPeer: false)
            }
        }
        if canCountdown && !countdownIssued { countdownIssued = true; effects.append(.beginCountdown) }
        if envelope.sender == .phone { phoneSequence = envelope.sequence } else { watchSequence = envelope.sequence }
        let receipt = VideoMotionControlReceipt(operationID: envelope.operationID, messageDigest: digest,
                                                phase: phase, acceptedAt: time)
        receipts[envelope.operationID] = receipt
        return VideoMotionControlResult(receipt: receipt, effects: effects)
    }

    public mutating func tick(at time: Double) throws -> [VideoMotionEffect] {
        try checkTime(time); lastTime = time
        return advanceDeadlines()
    }
    private func checkTime(_ time: Double) throws {
        guard VideoMotionTime.valid(time), time >= lastTime else { throw VideoMotionError.invalid("nonmonotonic event") }
    }
    private var hasLocalAcquisitionFact: Bool { device == .phone ? phoneStart != nil : motionReady != nil }
    private mutating func advanceDeadlines() -> [VideoMotionEffect] {
        if phase == .armed && lastTime >= armExpiresAt { phase = .terminal; return [] }
        guard phase == .starting || phase == .capturing else { return [] }
        if let localCaptureRequestedAt {
            let limit = device == .phone ? Self.phoneCaptureLimitSeconds : Self.watchCaptureLimitSeconds
            if lastTime - localCaptureRequestedAt >= limit {
                return stop(at: lastTime, requestPeer: true)
            }
            // Missing local acquisition can fail startup. Peer heartbeat loss cannot stop an
            // already confirmed local writer, and its finite maximum is never extended.
            if !hasLocalAcquisitionFact && lastTime - localCaptureRequestedAt >= Self.startupDeadlineSeconds {
                return stop(at: lastTime, requestPeer: true)
            }
        } else if let startRequestedAt, lastTime - startRequestedAt >= Self.startupDeadlineSeconds {
            return stop(at: lastTime, requestPeer: true)
        }
        return []
    }
    private mutating func stop(at time: Double, requestPeer: Bool) -> [VideoMotionEffect] {
        guard phase != .stopping, phase != .terminal else { return [] }
        stopRequestedAt = time
        var effects: [VideoMotionEffect] = []
        if localCaptureRequestedAt != nil { phase = .stopping; effects.append(.stopLocalCapture) }
        else { phase = .terminal }
        if requestPeer { effects.append(.requestPeerStop) }
        return effects
    }
}
