import Foundation

/// Setup metadata only. None of these types authorizes capture or asserts physical placement.
public enum PracticeSetupError: Error, Equatable, Sendable {
    case invalid(String), limit(String), corrupt(String), io(operation: String, code: Int32)
    case staleRevision, conflictingRevision, originChangeRequiresExplicit, busy, poisoned
}

public struct PracticeSetupPreferences: Equatable, Sendable, Codable {
    public let currentRacketArm: PlayingArm
    public let usualHand: PlayingArm
    public let intendedDrill: RecordingDrill

    public init(currentRacketArm: PlayingArm, usualHand: PlayingArm, intendedDrill: RecordingDrill) {
        self.currentRacketArm = currentRacketArm
        self.usualHand = usualHand
        self.intendedDrill = intendedDrill
    }

    private enum CodingKeys: String, CodingKey { case currentRacketArm, usualHand, intendedDrill }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let drill = RecordingDrill(rawValue: try c.decode(String.self, forKey: .intendedDrill)) else {
            throw PracticeSetupError.invalid("manual development drill")
        }
        self.init(currentRacketArm: try c.decode(PlayingArm.self, forKey: .currentRacketArm),
                  usualHand: try c.decode(PlayingArm.self, forKey: .usualHand), intendedDrill: drill)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(currentRacketArm, forKey: .currentRacketArm)
        try c.encode(usualHand, forKey: .usualHand)
        try c.encode(intendedDrill.rawValue, forKey: .intendedDrill)
    }
}

public struct PracticeSetupIdentity: Equatable, Sendable, Codable {
    public static let maximumRevision: Int64 = 9_007_199_254_740_991
    public let originInstallationEpoch: UUID
    public let preparationID: UUID
    /// Monotonic across ALL preparation IDs within this sender installation epoch.
    public let revision: Int64
    public let canonicalDigest: String

    public init(originInstallationEpoch: UUID, preparationID: UUID, revision: Int64, canonicalDigest: String) throws {
        self.originInstallationEpoch = originInstallationEpoch
        self.preparationID = preparationID
        self.revision = revision
        self.canonicalDigest = canonicalDigest
        try validate()
    }
    func validate() throws {
        guard revision > 0, revision <= Self.maximumRevision else { throw PracticeSetupError.invalid("revision") }
        guard canonicalDigest.utf8.count == 64, canonicalDigest.utf8.allSatisfy({
            (48...57).contains($0) || (97...102).contains($0)
        }) else { throw PracticeSetupError.invalid("digest") }
    }
}

public struct PracticeSetupDraft: Equatable, Sendable, Codable {
    public let identity: PracticeSetupIdentity
    public let preferences: PracticeSetupPreferences

    public init(originInstallationEpoch: UUID, preparationID: UUID, revision: Int64,
                preferences: PracticeSetupPreferences) throws {
        let unsigned = Unsigned(originInstallationEpoch: originInstallationEpoch, preparationID: preparationID,
            revision: revision, currentRacketArm: preferences.currentRacketArm,
            usualHand: preferences.usualHand, intendedDrill: preferences.intendedDrill.rawValue)
        identity = try PracticeSetupIdentity(originInstallationEpoch: originInstallationEpoch,
            preparationID: preparationID, revision: revision, canonicalDigest: Self.digest(unsigned))
        self.preferences = preferences
    }

    private struct Unsigned: Codable {
        let originInstallationEpoch: UUID
        let preparationID: UUID
        let revision: Int64
        let currentRacketArm: PlayingArm
        let usualHand: PlayingArm
        let intendedDrill: String
    }
    private static func digest(_ value: Unsigned) throws -> String {
        var bytes = Data("PSLPracticeSetupDraft1\n".utf8)
        bytes.append(try PracticeSetupJSON.encode(value))
        return RecordingChunkCodec.digest(bytes)
    }
    private enum CodingKeys: String, CodingKey {
        case originInstallationEpoch, preparationID, revision, currentRacketArm, usualHand, intendedDrill, canonicalDigest
    }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let preferences = try PracticeSetupPreferences(from: decoder)
        try self.init(originInstallationEpoch: c.decode(UUID.self, forKey: .originInstallationEpoch),
            preparationID: c.decode(UUID.self, forKey: .preparationID), revision: c.decode(Int64.self, forKey: .revision),
            preferences: preferences)
        guard try c.decode(String.self, forKey: .canonicalDigest) == identity.canonicalDigest else {
            throw PracticeSetupError.corrupt("draft digest")
        }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(identity.originInstallationEpoch, forKey: .originInstallationEpoch)
        try c.encode(identity.preparationID, forKey: .preparationID)
        try c.encode(identity.revision, forKey: .revision)
        try c.encode(identity.canonicalDigest, forKey: .canonicalDigest)
        try c.encode(preferences.currentRacketArm, forKey: .currentRacketArm)
        try c.encode(preferences.usualHand, forKey: .usualHand)
        try c.encode(preferences.intendedDrill.rawValue, forKey: .intendedDrill)
    }
}

public struct PracticeSetupGenerations: Equatable, Sendable, Codable {
    public let runtimeGeneration: UUID
    public let preparationGeneration: UUID
    public init(runtimeGeneration: UUID, preparationGeneration: UUID) {
        self.runtimeGeneration = runtimeGeneration
        self.preparationGeneration = preparationGeneration
    }
}

public struct PracticeSetupCorrelation: Equatable, Sendable, Codable {
    public let requestID: UUID
    public let generations: PracticeSetupGenerations
    public let identity: PracticeSetupIdentity
    public init(requestID: UUID, generations: PracticeSetupGenerations, identity: PracticeSetupIdentity) {
        self.requestID = requestID
        self.generations = generations
        self.identity = identity
    }
}

public enum PracticeSetupWrist: String, Codable, Sendable { case unknown, left, right }
public enum PracticeSetupCrown: String, Codable, Sendable { case unknown, left, right }
public enum PracticeSetupCapability: String, Codable, Sendable { case unknown, supported, unsupported }
public enum PracticeSetupStorage: String, Codable, Sendable { case unknown, available, unavailable }
public enum PracticeSetupWatchState: String, Codable, Sendable {
    case unavailable, idle, awaitingConfirmation, recording, paused, stopping, saved, interrupted, failed
}

/// Watch-authored observation, never a lasting readiness guarantee. Phone retains its own receive time.
public struct PracticeSetupSnapshot: Equatable, Sendable, Codable {
    public let generations: PracticeSetupGenerations
    public let observedAtUnixSeconds: Double
    public let state: PracticeSetupWatchState
    public let wrist: PracticeSetupWrist
    public let crown: PracticeSetupCrown
    public let capability: PracticeSetupCapability
    public let storage: PracticeSetupStorage
    public let acceptedCurrent: PracticeSetupIdentity?
    public let acceptedNext: PracticeSetupIdentity?

    public init(generations: PracticeSetupGenerations, observedAtUnixSeconds: Double, state: PracticeSetupWatchState,
                wrist: PracticeSetupWrist = .unknown, crown: PracticeSetupCrown = .unknown,
                capability: PracticeSetupCapability = .unknown, storage: PracticeSetupStorage = .unknown,
                acceptedCurrent: PracticeSetupIdentity? = nil, acceptedNext: PracticeSetupIdentity? = nil) throws {
        self.generations = generations
        self.observedAtUnixSeconds = observedAtUnixSeconds
        self.state = state
        self.wrist = wrist
        self.crown = crown
        self.capability = capability
        self.storage = storage
        self.acceptedCurrent = acceptedCurrent
        self.acceptedNext = acceptedNext
        try validate()
    }
    func validate() throws {
        guard observedAtUnixSeconds.isFinite, observedAtUnixSeconds >= 0 else { throw PracticeSetupError.invalid("observation time") }
        try acceptedCurrent?.validate()
        try acceptedNext?.validate()
        if state == .unavailable {
            guard wrist == .unknown, crown == .unknown, capability == .unknown, storage == .unknown,
                  acceptedCurrent == nil, acceptedNext == nil else { throw PracticeSetupError.invalid("unavailable observation") }
        }
    }
}

public enum PracticeSetupDisposition: String, Codable, Sendable { case acceptedCurrent, acceptedNext, retired }
public enum PracticeSetupRetirementReason: String, Codable, Sendable { case endPractice, cancelPreparation }
public enum PracticeSetupFailureCode: String, Codable, Sendable {
    case staleGenerations, busy, invalidOrigin, olderRevision, conflictingRevision, storageFailure, unavailable, cancelled, invalidRequest
}

/// Context carries only `draft`. Interactive routing/actor authority is supplied by the separate channel.
public enum PracticeSetupMessage: Equatable, Sendable {
    case draft(PracticeSetupDraft)
    case statusRequest(requestID: UUID)
    case status(requestID: UUID, snapshot: PracticeSetupSnapshot)
    case prepare(requestID: UUID, generations: PracticeSetupGenerations, draft: PracticeSetupDraft, allowsOriginReplacement: Bool)
    case receipt(correlation: PracticeSetupCorrelation, disposition: PracticeSetupDisposition, snapshot: PracticeSetupSnapshot)
    case retire(correlation: PracticeSetupCorrelation, reason: PracticeSetupRetirementReason)
    case error(correlation: PracticeSetupCorrelation, code: PracticeSetupFailureCode, currentGenerations: PracticeSetupGenerations)

    public var correlation: PracticeSetupCorrelation? {
        switch self {
        case let .prepare(id, generations, draft, _):
            PracticeSetupCorrelation(requestID: id, generations: generations, identity: draft.identity)
        case let .receipt(value, _, _), let .retire(value, _), let .error(value, _, _): value
        default: nil
        }
    }

    /// Correlation only; callers must also reject invalidated drafts, stale observations and cancelled work.
    public func isReply(to request: Self) -> Bool {
        do { try validate(); try request.validate() }
        catch { return false }
        switch (self, request) {
        case let (.status(id, _), .statusRequest(expected)): return id == expected
        case let (.receipt(value, disposition, _), .prepare):
            return disposition != .retired && value == request.correlation
        case let (.receipt(value, disposition, _), .retire):
            return disposition == .retired && value == request.correlation
        case let (.error(value, _, _), .prepare), let (.error(value, _, _), .retire):
            return value == request.correlation
        default: return false
        }
    }

    func validate() throws {
        try correlation?.identity.validate()
        switch self {
        case let .draft(draft), let .prepare(_, _, draft, _): try draft.identity.validate()
        case let .status(_, snapshot): try snapshot.validate()
        case let .receipt(correlation, disposition, snapshot):
            try snapshot.validate()
            guard snapshot.state != .unavailable else { throw PracticeSetupError.invalid("receipt without live recorder") }
            switch disposition {
            case .acceptedCurrent, .acceptedNext:
                let accepted = disposition == .acceptedCurrent ? snapshot.acceptedCurrent : snapshot.acceptedNext
                guard snapshot.generations == correlation.generations, accepted == correlation.identity else {
                    throw PracticeSetupError.invalid("acceptance correlation")
                }
            case .retired:
                guard snapshot.generations.runtimeGeneration == correlation.generations.runtimeGeneration,
                      snapshot.generations.preparationGeneration != correlation.generations.preparationGeneration,
                      snapshot.acceptedCurrent == nil, snapshot.acceptedNext == nil else {
                    throw PracticeSetupError.invalid("retirement correlation")
                }
            }
        default: break
        }
    }
}

public enum PracticeSetupCodec {
    public static let maximumBytes = 8_192

    public static func encode(_ message: PracticeSetupMessage) throws -> Data {
        try message.validate()
        let data = try PracticeSetupJSON.encode(Wire(message))
        guard data.count <= maximumBytes else { throw PracticeSetupError.limit("wire bytes") }
        return data
    }

    public static func decode(_ data: Data) throws -> PracticeSetupMessage {
        guard !data.isEmpty, data.count <= maximumBytes else { throw PracticeSetupError.limit("wire bytes") }
        let wire = try JSONDecoder().decode(Wire.self, from: data)
        let message = try wire.message()
        // One wire representation rejects unknown fields, duplicate keys, coercions and hidden alternatives.
        guard try encode(message) == data else { throw PracticeSetupError.invalid("noncanonical wire") }
        return message
    }

    private struct Wire: Codable {
        var version = 1
        var kind: String
        var draft: PracticeSetupDraft?
        var requestID: UUID?
        var generations: PracticeSetupGenerations?
        var allowsOriginReplacement: Bool?
        var correlation: PracticeSetupCorrelation?
        var snapshot: PracticeSetupSnapshot?
        var disposition: PracticeSetupDisposition?
        var reason: PracticeSetupRetirementReason?
        var code: PracticeSetupFailureCode?
        var currentGenerations: PracticeSetupGenerations?

        init(_ message: PracticeSetupMessage) {
            switch message {
            case let .draft(value): kind = "PSLPracticeSetup1.draft"; draft = value
            case let .statusRequest(id): kind = "PSLPracticeSetup1.statusRequest"; requestID = id
            case let .status(id, value): kind = "PSLPracticeSetup1.status"; requestID = id; snapshot = value
            case let .prepare(id, generation, value, replace):
                kind = "PSLPracticeSetup1.prepare"; requestID = id; generations = generation
                draft = value; allowsOriginReplacement = replace
            case let .receipt(value, result, observation):
                kind = "PSLPracticeSetup1.receipt"; correlation = value; disposition = result; snapshot = observation
            case let .retire(value, why): kind = "PSLPracticeSetup1.retire"; correlation = value; reason = why
            case let .error(value, failure, generation):
                kind = "PSLPracticeSetup1.error"; correlation = value; code = failure; currentGenerations = generation
            }
        }
        func required<T>(_ value: T?) throws -> T {
            guard let value else { throw PracticeSetupError.invalid("missing wire field") }; return value
        }
        func message() throws -> PracticeSetupMessage {
            guard version == 1 else { throw PracticeSetupError.invalid("wire version") }
            switch kind {
            case "PSLPracticeSetup1.draft": return .draft(try required(draft))
            case "PSLPracticeSetup1.statusRequest": return .statusRequest(requestID: try required(requestID))
            case "PSLPracticeSetup1.status": return .status(requestID: try required(requestID), snapshot: try required(snapshot))
            case "PSLPracticeSetup1.prepare":
                return .prepare(requestID: try required(requestID), generations: try required(generations),
                    draft: try required(draft), allowsOriginReplacement: try required(allowsOriginReplacement))
            case "PSLPracticeSetup1.receipt":
                return .receipt(correlation: try required(correlation), disposition: try required(disposition), snapshot: try required(snapshot))
            case "PSLPracticeSetup1.retire": return .retire(correlation: try required(correlation), reason: try required(reason))
            case "PSLPracticeSetup1.error":
                return .error(correlation: try required(correlation), code: try required(code), currentGenerations: try required(currentGenerations))
            default: throw PracticeSetupError.invalid("wire kind")
            }
        }
    }
}

/// Internal shared canonical serialization; outer boundaries impose byte limits before decoding.
enum PracticeSetupJSON {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
