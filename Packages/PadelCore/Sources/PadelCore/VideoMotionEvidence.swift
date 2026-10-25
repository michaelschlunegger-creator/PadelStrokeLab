import Foundation

public enum VideoMotionClockSource: Codable, Equatable, Sendable {
    case coreMediaHost
    case machAbsolute(ticks: UInt64, numerator: UInt32, denominator: UInt32)
}

/// One observed source/runtime offset interval. Native adapters supply actual brackets and retain
/// the documented source-clock contract; this value does not prove a hardware clock or zero drift.
public struct VideoMotionClockBridge: Codable, Equatable, Sendable {
    public let id: UUID
    public let device: VideoMotionDevice
    public let sourceClockDomainID: UUID
    public let runtimeEpoch: UUID
    public let source: VideoMotionClockSource
    public let sourceBeforeSeconds: Double
    public let sourceAfterSeconds: Double
    public let runtimeBeforeSeconds: Double
    public let runtimeAfterSeconds: Double
    public let roundingUncertaintySeconds: Double

    public init(id: UUID = UUID(), device: VideoMotionDevice, sourceClockDomainID: UUID, runtimeEpoch: UUID,
                source: VideoMotionClockSource, sourceBeforeSeconds: Double, sourceAfterSeconds: Double,
                runtimeBeforeSeconds: Double, runtimeAfterSeconds: Double, roundingUncertaintySeconds: Double) throws {
        self.id = id; self.device = device; self.sourceClockDomainID = sourceClockDomainID; self.runtimeEpoch = runtimeEpoch
        self.source = source; self.sourceBeforeSeconds = sourceBeforeSeconds; self.sourceAfterSeconds = sourceAfterSeconds
        self.runtimeBeforeSeconds = runtimeBeforeSeconds; self.runtimeAfterSeconds = runtimeAfterSeconds
        self.roundingUncertaintySeconds = roundingUncertaintySeconds; try validate()
    }
    public var offsetRange: ClosedRange<Double> {
        // Round each operation outward before any later intersection. Adding the reported
        // uncertainty alone can disappear when large source times cancel small runtime times.
        let lower = ((runtimeBeforeSeconds - sourceAfterSeconds).nextDown - roundingUncertaintySeconds).nextDown
        let upper = ((runtimeAfterSeconds - sourceBeforeSeconds).nextUp + roundingUncertaintySeconds).nextUp
        return lower...upper
    }
    func validate() throws {
        guard [sourceBeforeSeconds, sourceAfterSeconds, runtimeBeforeSeconds, runtimeAfterSeconds].allSatisfy(VideoMotionTime.valid),
              sourceBeforeSeconds <= sourceAfterSeconds, runtimeBeforeSeconds <= runtimeAfterSeconds,
              roundingUncertaintySeconds.isFinite, roundingUncertaintySeconds > 0, roundingUncertaintySeconds <= 1 else {
            throw VideoMotionError.invalid("source clock bracket")
        }
        switch source {
        case .coreMediaHost:
            guard device == .phone else { throw VideoMotionError.invalid("source clock device") }
        case let .machAbsolute(ticks, numerator, denominator):
            guard device == .watch, numerator > 0, denominator > 0 else { throw VideoMotionError.invalid("Mach timebase") }
            let seconds = Double(ticks) * Double(numerator) / Double(denominator) / 1_000_000_000
            guard VideoMotionTime.valid(seconds), seconds >= sourceBeforeSeconds - roundingUncertaintySeconds,
                  seconds <= sourceAfterSeconds + roundingUncertaintySeconds,
                  roundingUncertaintySeconds >= seconds.ulp else { throw VideoMotionError.invalid("Mach conversion bracket") }
        }
    }
}

public enum VideoMotionTransitionKind: String, Codable, Sendable { case phase, countdown, go, stop, finalized }
public struct VideoMotionLocalTransition: Codable, Equatable, Sendable {
    public let id: UUID
    public let device: VideoMotionDevice
    public let phase: VideoMotionPhase
    public let kind: VideoMotionTransitionKind
    public let timestamp: Double
    public let reason: String?
    public init(id: UUID = UUID(), device: VideoMotionDevice, phase: VideoMotionPhase,
                kind: VideoMotionTransitionKind, timestamp: Double, reason: String? = nil) throws {
        self.id = id; self.device = device; self.phase = phase; self.kind = kind; self.timestamp = timestamp; self.reason = reason
        try validate()
    }
    func validate() throws {
        guard VideoMotionTime.valid(timestamp), reason.map({ VideoMotionValidation.text($0, maximum: 512) }) ?? true else {
            throw VideoMotionError.invalid("local transition")
        }
        switch kind {
        case .countdown, .go:
            guard phase == .capturing else { throw VideoMotionError.invalid("Go phase") }
        case .stop:
            guard phase == .stopping || phase == .terminal else { throw VideoMotionError.invalid("stop phase") }
        case .finalized:
            guard phase == .terminal else { throw VideoMotionError.invalid("final phase") }
        case .phase: break
        }
    }
}

public enum VideoMotionEvidenceFact: Codable, Equatable, Sendable {
    /// Observer identifies the device whose reducer produced this receipt, including local commands.
    case control(VideoMotionControlEnvelope, VideoMotionControlReceipt, observer: VideoMotionDevice)
    case clockExchange(VideoMotionClockExchange)
    case clockMapping(VideoMotionClockMapping)
    case clockBridge(VideoMotionClockBridge)
    case transition(VideoMotionLocalTransition)

    fileprivate var key: String {
        switch self {
        case let .control(value, _, observer): "control-\(observer.rawValue)-\(value.operationID)"
        case .clockExchange(let value): "exchange-\(value.id)"
        case .clockMapping(let value): "mapping-\(value.id)"
        case .clockBridge(let value): "bridge-\(value.id)"
        case .transition(let value): "transition-\(value.id)"
        }
    }
}

/// A bounded append-only account of one arm. Native acquisition, current owner permission and
/// playable media still require their independent production checks. Facts never grant Start.
public struct VideoMotionEvidence: Codable, Equatable, Sendable {
    public static let maximumFacts = 256
    public static let maximumBytes = 262_144
    private let schemaVersion: Int
    public let scope: VideoMotionTransportScope
    public let facts: [VideoMotionEvidenceFact]

    public init(scope: VideoMotionTransportScope) throws {
        schemaVersion = 1; self.scope = scope; facts = []; try validate()
    }
    private init(scope: VideoMotionTransportScope, facts: [VideoMotionEvidenceFact]) throws {
        schemaVersion = 1; self.scope = scope; self.facts = facts; try validate()
    }
    public func appending(_ fact: VideoMotionEvidenceFact) throws -> Self {
        try validate()
        if let previous = facts.first(where: { $0.key == fact.key }) {
            guard previous == fact else { throw VideoMotionError.conflict }
            return self
        }
        let value = try Self(scope: scope, facts: facts + [fact])
        _ = try value.encoded(); return value
    }
    public func phase(for device: VideoMotionDevice) -> VideoMotionPhase {
        for fact in facts.reversed() {
            switch fact {
            case let .control(_, receipt, observer) where observer == device: return receipt.phase
            case let .transition(value) where value.device == device: return value.phase
            default: continue
            }
        }
        return .armed
    }
    func requireSuccessor(of previous: Self) throws {
        try validate(); try previous.validate()
        guard scope == previous.scope, facts.starts(with: previous.facts) else { throw VideoMotionError.conflict }
    }
    func validate() throws {
        try scope.validate()
        guard schemaVersion == 1, facts.count <= Self.maximumFacts else { throw VideoMotionError.capacity }
        var keys = Set<String>(), phases: [VideoMotionDevice: VideoMotionPhase] = [:]
        var times: [VideoMotionDevice: Double] = [:], sequences: [String: Int] = [:]
        var exchanges: [VideoMotionClockExchange] = [], mapping: VideoMotionClockMapping?
        var bridges: [VideoMotionClockBridge] = []
        var phoneStart: VideoMotionPhoneStart?, motionReady: VideoMotionMotionReady?
        var countdown = Set<VideoMotionDevice>(), went = Set<VideoMotionDevice>(), finalized = Set<VideoMotionDevice>()
        for fact in facts {
            guard keys.insert(fact.key).inserted else { throw VideoMotionError.conflict }
            switch fact {
            case let .control(control, receipt, observer):
                try control.validate()
                guard try VideoMotionTransportScope(control) == scope, receipt.operationID == control.operationID,
                      receipt.messageDigest == RecordingChunkCodec.digest(try control.encoded()),
                      VideoMotionTime.valid(receipt.acceptedAt) else { throw VideoMotionError.integrity }
                if case .start = control.message, phases[observer] == .terminal { throw VideoMotionError.retired }
                let sequenceKey = observer.rawValue + ":" + control.sender.rawValue
                guard control.sequence > (sequences[sequenceKey] ?? 0) else { throw VideoMotionError.conflict }
                try Self.advance(observer, phase: receipt.phase, at: receipt.acceptedAt, phases: &phases, times: &times)
                sequences[sequenceKey] = control.sequence
                switch control.message {
                case .phoneStarted(let value):
                    guard phoneStart == nil || phoneStart == value else { throw VideoMotionError.conflict }; phoneStart = value
                    if let bridge = value.clockBridge { try retainBridge(bridge, in: &bridges) }
                case .motionReady(let value):
                    guard motionReady == nil || motionReady == value else { throw VideoMotionError.conflict }; motionReady = value
                    if let bridge = value.clockBridge { try retainBridge(bridge, in: &bridges) }
                case .finalized: finalized.insert(control.sender)
                default: break
                }
            case .clockExchange(let value):
                try value.validate()
                guard value.phoneEpoch == scope.phoneEpoch, value.watchEpoch == scope.watchEpoch,
                      exchanges.count < VideoMotionClockMapping.maximumExchanges else { throw VideoMotionError.integrity }
                if let previous = exchanges.last {
                    guard value.phoneSent > previous.phoneReceived, value.watchReceived > previous.watchSent else {
                        throw VideoMotionError.invalid("reordered clock evidence")
                    }
                }
                exchanges.append(value)
            case .clockMapping(let value):
                try value.validate()
                guard value.phoneEpoch == scope.phoneEpoch, value.watchEpoch == scope.watchEpoch,
                      value.exchanges.allSatisfy({ exchanges.contains($0) }),
                      mapping.map({ value.exchanges.starts(with: $0.exchanges) }) ?? true else { throw VideoMotionError.integrity }
                mapping = value
            case .clockBridge(let value):
                try retainBridge(value, in: &bridges)
            case .transition(let value):
                try value.validate()
                if value.kind == .countdown || value.kind == .go {
                    guard phases[value.device] == .capturing, let phoneStart, let motionReady, let mapping,
                          mapping.driftPPMRange != nil,
                          Self.supports(phoneStart: phoneStart, motionReady: motionReady,
                                        mapping: mapping, bridges: bridges) else {
                        throw VideoMotionError.invalid("unsubstantiated Go evidence")
                    }
                    if value.kind == .countdown {
                        guard countdown.insert(value.device).inserted else { throw VideoMotionError.conflict }
                    } else {
                        guard countdown.contains(value.device), went.insert(value.device).inserted else { throw VideoMotionError.conflict }
                    }
                }
                if value.kind == .finalized, !finalized.contains(value.device) { throw VideoMotionError.invalid("missing finalization fact") }
                try Self.advance(value.device, phase: value.phase, at: value.timestamp, phases: &phases, times: &times)
            }
        }
    }
    private func retainBridge(_ value: VideoMotionClockBridge, in bridges: inout [VideoMotionClockBridge]) throws {
        try value.validate()
        guard value.runtimeEpoch == (value.device == .phone ? scope.phoneEpoch : scope.watchEpoch) else {
            throw VideoMotionError.integrity
        }
        if let previous = bridges.first(where: { $0.id == value.id }) {
            guard previous == value else { throw VideoMotionError.conflict }
            return
        }
        for previous in bridges where previous.device == value.device {
            guard previous.sourceClockDomainID == value.sourceClockDomainID,
                  previous.offsetRange.overlaps(value.offsetRange) else { throw VideoMotionError.invalid("discontinuous clock bridge") }
            if case let .machAbsolute(_, oldNumerator, oldDenominator) = previous.source,
               case let .machAbsolute(_, numerator, denominator) = value.source {
                guard oldNumerator == numerator, oldDenominator == denominator else { throw VideoMotionError.integrity }
            }
        }
        bridges.append(value)
    }
    /// Coverage must include every endpoint of the measured source/runtime offset interval.
    /// Neither source times nor interval midpoints can stand in for runtime observations.
    static func supports(phoneStart: VideoMotionPhoneStart, motionReady: VideoMotionMotionReady,
                         mapping: VideoMotionClockMapping, bridges: [VideoMotionClockBridge]) -> Bool {
        guard let phone = runtimeRange(atSource: phoneStart.firstHostTime, device: .phone,
                                       domain: phoneStart.clockDomainID, bridges: bridges),
              let firstMotion = runtimeRange(atSource: motionReady.firstTimestamp, device: .watch,
                                             domain: motionReady.clockDomainID, bridges: bridges),
              let lastMotion = runtimeRange(atSource: motionReady.lastTimestamp, device: .watch,
                                            domain: motionReady.clockDomainID, bridges: bridges) else { return false }
        return [phone.lowerBound, phone.upperBound].allSatisfy { (try? mapping.estimateWatch(atPhone: $0)) != nil }
            && [firstMotion.lowerBound, firstMotion.upperBound, lastMotion.lowerBound, lastMotion.upperBound]
                .allSatisfy { (try? mapping.estimatePhone(atWatch: $0)) != nil }
    }
    private static func runtimeRange(atSource timestamp: Double, device: VideoMotionDevice, domain: UUID,
                                     bridges: [VideoMotionClockBridge]) -> ClosedRange<Double>? {
        let matching = bridges.filter { $0.device == device && $0.sourceClockDomainID == domain }
        guard let first = matching.first else { return nil }
        // Repeated, same-run observations constrain the same offset; disjoint bridges are rejected
        // during validation. Outward rounding also covers the final floating-point addition.
        let offsetLower = matching.reduce(first.offsetRange.lowerBound) { max($0, $1.offsetRange.lowerBound) }
        let offsetUpper = matching.reduce(first.offsetRange.upperBound) { min($0, $1.offsetRange.upperBound) }
        let lower = (timestamp + offsetLower).nextDown, upper = (timestamp + offsetUpper).nextUp
        guard offsetLower <= offsetUpper, VideoMotionTime.valid(lower), VideoMotionTime.valid(upper) else { return nil }
        return lower...upper
    }
    private static func advance(_ device: VideoMotionDevice, phase: VideoMotionPhase, at time: Double,
                                phases: inout [VideoMotionDevice: VideoMotionPhase], times: inout [VideoMotionDevice: Double]) throws {
        guard time >= (times[device] ?? 0) else { throw VideoMotionError.invalid("reordered device observations") }
        let old = phases[device] ?? .armed
        let allowed: Bool
        switch old {
        case .armed: allowed = phase == .armed || phase == .starting || phase == .stopping || phase == .terminal
        case .starting: allowed = phase != .armed
        case .capturing: allowed = phase == .capturing || phase == .stopping || phase == .terminal
        case .stopping: allowed = phase == .stopping || phase == .terminal
        case .terminal: allowed = phase == .terminal
        }
        guard allowed else { throw VideoMotionError.retired }
        phases[device] = phase; times[device] = time
    }
    public func encoded() throws -> Data {
        try validate()
        return try OwnerCanonical.encode(self, domain: "PSLVideoMotionEvidence1", limit: Self.maximumBytes)
    }
    public static func decode(_ bytes: Data) throws -> Self {
        let value: Self = try OwnerCanonical.decode(bytes, domain: "PSLVideoMotionEvidence1", limit: maximumBytes)
        try value.validate(); return value
    }
}
