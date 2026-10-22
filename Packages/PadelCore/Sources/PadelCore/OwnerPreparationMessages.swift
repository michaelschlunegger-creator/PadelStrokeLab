import Foundation

public enum OwnerPreparationError: Error, Equatable, Sendable {
    case invalid(String), stale, conflict, capacity
}

/// A compact command, not an authority snapshot or proof that a device applied it.
public struct OwnerAuthorityMutation: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case enroll, heartRate, withdraw, reconsent, advance, retirePractice }
    public static let maximumBytes = 4_096
    private let body: Body
    public var id: UUID { body.id }
    public var kind: Kind { body.kind }
    public var ownerID: UUID { body.ownerID }
    public var phoneEpoch: UUID { body.phoneEpoch }
    public var watchEpoch: UUID { body.watchEpoch }
    public var beforeDigest: String? { body.beforeDigest }
    public var afterDigest: String { body.afterDigest }
    public var beforeRevision: Int64 { body.revision }
    public var beforeConsentGeneration: Int64 { body.consentGeneration }
    public var beforeWithdrawalBarrier: Int64 { body.withdrawalBarrier }
    public var retiredPracticeID: UUID? { body.practiceID }
    public var isRevisionOnly: Bool { kind == .advance || kind == .retirePractice }
    public var isRestrictive: Bool { kind == .withdraw || (kind == .heartRate && body.heartRate == false) }
    public var isFullWithdrawal: Bool { kind == .withdraw }

    private struct Body: Codable, Equatable, Sendable {
        let kind: Kind
        let id: UUID
        let ownerID: UUID
        let phoneEpoch: UUID
        let watchEpoch: UUID
        let policyDigest: String
        let revision: Int64
        let consentGeneration: Int64
        let withdrawalBarrier: Int64
        let beforeDigest: String?
        let afterDigest: String
        let confirmedAt: Double?
        let heartRate: Bool?
        let acknowledgesWithdrawal: Bool?
        let practiceID: UUID?
        let enrollment: Data?
    }

    private init(_ body: Body) throws { self.body = body; try validate() }
    public init(from decoder: any Decoder) throws { try self.init(Body(from: decoder)) }
    public func encode(to encoder: any Encoder) throws { try body.encode(to: encoder) }

    public static func enrollment(_ owner: OwnerPracticeIdentity) throws -> Self {
        guard owner.revision == 1, owner.consentGeneration == 1, owner.withdrawalBarrier == 0,
              owner.isCollectionAllowed else { throw OwnerPreparationError.invalid("initial owner enrollment") }
        return try Self(Body(kind: .enroll, id: owner.lastDecisionID, ownerID: owner.ownerID,
            phoneEpoch: owner.phoneInstallationEpoch, watchEpoch: owner.watchInstallationEpoch,
            policyDigest: owner.policyDigest, revision: 0, consentGeneration: 0, withdrawalBarrier: 0,
            beforeDigest: nil, afterDigest: digest(owner), confirmedAt: nil, heartRate: nil,
            acknowledgesWithdrawal: nil, practiceID: nil, enrollment: owner.encoded()))
    }

    public static func heartRate(from owner: OwnerPracticeIdentity, allowed: Bool,
                                  decisionID: UUID, confirmedAtUnixSeconds: Double) throws -> Self {
        try make(.heartRate, owner: owner, id: decisionID, date: confirmedAtUnixSeconds, heartRate: allowed)
    }
    public static func withdraw(from owner: OwnerPracticeIdentity, decisionID: UUID,
                                 confirmedAtUnixSeconds: Double) throws -> Self {
        try make(.withdraw, owner: owner, id: decisionID, date: confirmedAtUnixSeconds)
    }
    public static func reconsent(from owner: OwnerPracticeIdentity, includesHeartRate: Bool,
        acknowledgesWithdrawal: Bool, decisionID: UUID, confirmedAtUnixSeconds: Double) throws -> Self {
        try make(.reconsent, owner: owner, id: decisionID, date: confirmedAtUnixSeconds,
                 heartRate: includesHeartRate, acknowledged: acknowledgesWithdrawal)
    }
    public static func advance(from owner: OwnerPracticeIdentity, mutationID: UUID) throws -> Self {
        try make(.advance, owner: owner, id: mutationID)
    }
    public static func retirePractice(from owner: OwnerPracticeIdentity, practiceID: UUID, mutationID: UUID) throws -> Self {
        try make(.retirePractice, owner: owner, id: mutationID, practiceID: practiceID)
    }

    private static func make(_ kind: Kind, owner: OwnerPracticeIdentity, id: UUID, date: Double? = nil,
                             heartRate: Bool? = nil, acknowledged: Bool? = nil, practiceID: UUID? = nil) throws -> Self {
        let result: OwnerPracticeIdentity
        if kind == .advance || kind == .retirePractice {
            result = try owner.advancingRevision(expectedRevision: owner.revision)
        } else {
            result = try owner.applying(decision(kind, owner: owner, id: id, date: date,
                                                heartRate: heartRate, acknowledged: acknowledged))
        }
        return try Self(Body(kind: kind, id: id, ownerID: owner.ownerID,
            phoneEpoch: owner.phoneInstallationEpoch, watchEpoch: owner.watchInstallationEpoch,
            policyDigest: owner.policyDigest, revision: owner.revision, consentGeneration: owner.consentGeneration,
            withdrawalBarrier: owner.withdrawalBarrier, beforeDigest: digest(owner), afterDigest: digest(result),
            confirmedAt: date, heartRate: heartRate, acknowledgesWithdrawal: acknowledged,
            practiceID: practiceID, enrollment: nil))
    }

    /// Only exact before-state reconstruction is allowed. Duplicate recognition belongs to the retained journal.
    public func resolve(from current: OwnerPracticeIdentity?) throws -> OwnerPracticeIdentity {
        try validate()
        if kind == .enroll {
            guard current == nil, let bytes = body.enrollment else { throw OwnerPreparationError.stale }
            return try OwnerPracticeIdentity.decode(bytes)
        }
        guard let current, try Self.digest(current) == beforeDigest,
              current.ownerID == ownerID, current.phoneInstallationEpoch == phoneEpoch,
              current.watchInstallationEpoch == watchEpoch, current.revision == beforeRevision,
              current.consentGeneration == beforeConsentGeneration,
              current.withdrawalBarrier == beforeWithdrawalBarrier else { throw OwnerPreparationError.stale }
        let result: OwnerPracticeIdentity
        if isRevisionOnly { result = try current.advancingRevision(expectedRevision: beforeRevision) }
        else { result = try current.applying(consentDecision(for: current)) }
        guard try Self.digest(result) == afterDigest else { throw OwnerPreparationError.conflict }
        return result
    }

    public func consentDecision(for current: OwnerPracticeIdentity) throws -> OwnerConsentDecision {
        guard !isRevisionOnly, kind != .enroll, try Self.digest(current) == beforeDigest else {
            throw OwnerPreparationError.stale
        }
        return try Self.decision(kind, owner: current, id: id, date: body.confirmedAt,
                                  heartRate: body.heartRate, acknowledged: body.acknowledgesWithdrawal)
    }

    /// The journal must first verify every intervening transition. A grant cannot use this path.
    public func rebasingRestriction(afterVerifiedRevisionOnlyChangesTo current: OwnerPracticeIdentity) throws -> Self {
        guard isRestrictive, current.ownerID == ownerID, current.phoneInstallationEpoch == phoneEpoch,
              current.watchInstallationEpoch == watchEpoch, current.revision >= beforeRevision,
              current.consentGeneration == beforeConsentGeneration,
              current.withdrawalBarrier == beforeWithdrawalBarrier else { throw OwnerPreparationError.stale }
        return try Self.make(kind, owner: current, id: id, date: body.confirmedAt, heartRate: body.heartRate)
    }

    public func encoded() throws -> Data { try OwnerCanonical.encode(self, domain: "PSLOwnerAuthorityCommand2", limit: Self.maximumBytes) }
    public static func decode(_ bytes: Data) throws -> Self {
        try OwnerCanonical.decode(bytes, domain: "PSLOwnerAuthorityCommand2", limit: maximumBytes)
    }
    public var canonicalDigest: String { get throws { RecordingChunkCodec.digest(try encoded()) } }
    public static func digest(_ owner: OwnerPracticeIdentity) throws -> String { RecordingChunkCodec.digest(try owner.encoded()) }

    private static func decision(_ kind: Kind, owner: OwnerPracticeIdentity, id: UUID, date: Double?,
                                 heartRate: Bool?, acknowledged: Bool?) throws -> OwnerConsentDecision {
        guard let date else { throw OwnerPreparationError.invalid("decision date") }
        switch kind {
        case .heartRate:
            guard let heartRate else { throw OwnerPreparationError.invalid("HR choice") }
            return try .heartRate(for: owner, allowed: heartRate, decisionID: id,
                confirmedAtUnixSeconds: date, policyDigest: OwnerPracticePolicy.digest)
        case .withdraw: return try .withdraw(for: owner, decisionID: id, confirmedAtUnixSeconds: date)
        case .reconsent:
            guard let heartRate, acknowledged == true else { throw OwnerPreparationError.invalid("new consent") }
            return try .reconsent(for: owner, includesHeartRate: heartRate, acknowledgesWithdrawal: true,
                decisionID: id, confirmedAtUnixSeconds: date, policyDigest: OwnerPracticePolicy.digest)
        default: throw OwnerPreparationError.invalid("consent command kind")
        }
    }

    private func validate() throws {
        guard body.policyDigest == OwnerPracticePolicy.digest, phoneEpoch != watchEpoch else { throw OwnerPreparationError.invalid("policy or peer") }
        try ownerWireDigest(afterDigest)
        if kind == .enroll {
            guard beforeDigest == nil, beforeRevision == 0, beforeConsentGeneration == 0, beforeWithdrawalBarrier == 0,
                  let bytes = body.enrollment, body.confirmedAt == nil, body.heartRate == nil,
                  body.acknowledgesWithdrawal == nil, body.practiceID == nil else { throw OwnerPreparationError.invalid("enrollment fields") }
            let owner = try OwnerPracticeIdentity.decode(bytes)
            guard owner.revision == 1, owner.consentGeneration == 1, owner.withdrawalBarrier == 0,
                  owner.isCollectionAllowed, owner.lastDecisionID == id, owner.ownerID == ownerID,
                  owner.phoneInstallationEpoch == phoneEpoch, owner.watchInstallationEpoch == watchEpoch,
                  try Self.digest(owner) == afterDigest else { throw OwnerPreparationError.invalid("enrollment identity") }
        } else {
            guard let beforeDigest, body.enrollment == nil,
                  (1..<OwnerPracticeIdentity.maximumRevision).contains(beforeRevision),
                  (1...Int64(OwnerPracticeIdentity.maximumConsentDecisions)).contains(beforeConsentGeneration),
                  beforeRevision >= beforeConsentGeneration,
                  (0...beforeConsentGeneration).contains(beforeWithdrawalBarrier) else { throw OwnerPreparationError.invalid("transition base") }
            try ownerWireDigest(beforeDigest)
            if isRevisionOnly {
                guard body.confirmedAt == nil, body.heartRate == nil, body.acknowledgesWithdrawal == nil,
                      (kind == .retirePractice) == (body.practiceID != nil) else { throw OwnerPreparationError.invalid("revision command") }
            } else {
                guard let date = body.confirmedAt, date.isFinite, date >= 0, body.practiceID == nil,
                      (kind == .withdraw) == (body.heartRate == nil),
                      (kind == .reconsent ? body.acknowledgesWithdrawal == true : body.acknowledgesWithdrawal == nil) else {
                    throw OwnerPreparationError.invalid("consent fields")
                }
            }
        }
        guard try PracticeSetupJSON.encode(body).count <= Self.maximumBytes - 128 else { throw OwnerPreparationError.capacity }
    }
}

public struct OwnerAuthorityTransition: Codable, Equatable, Sendable {
    public static let maximumBytes = 4_096
    public let sequence: Int64
    public let mutation: OwnerAuthorityMutation
    public init(sequence: Int64, mutation: OwnerAuthorityMutation) throws {
        guard (1...OwnerPracticeIdentity.maximumRevision).contains(sequence), sequence == mutation.beforeRevision + 1 else {
            throw OwnerPreparationError.invalid("transition sequence")
        }
        self.sequence = sequence; self.mutation = mutation
        _ = try mutation.encoded()
    }
    public func encoded() throws -> Data { try OwnerCanonical.encode(self, domain: "PSLOwnerAuthorityTransition2", limit: Self.maximumBytes) }
    public static func decode(_ bytes: Data) throws -> Self {
        try OwnerCanonical.decode(bytes, domain: "PSLOwnerAuthorityTransition2", limit: maximumBytes)
    }
    public var canonicalDigest: String { get throws { RecordingChunkCodec.digest(try encoded()) } }
    private enum CodingKeys: String, CodingKey { case sequence, mutation }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(sequence: c.decode(Int64.self, forKey: .sequence), mutation: c.decode(OwnerAuthorityMutation.self, forKey: .mutation))
    }
}

public struct OwnerAuthorityAcknowledgement: Codable, Equatable, Sendable {
    public let ownerID: UUID
    public let phoneEpoch: UUID
    public let watchEpoch: UUID
    public let sequence: Int64
    public let transitionDigest: String
    public let authorityDigest: String
    public init(transition: OwnerAuthorityTransition) throws {
        ownerID = transition.mutation.ownerID; phoneEpoch = transition.mutation.phoneEpoch; watchEpoch = transition.mutation.watchEpoch
        sequence = transition.sequence; transitionDigest = try transition.canonicalDigest; authorityDigest = transition.mutation.afterDigest
        try validate()
    }
    public func matches(_ transition: OwnerAuthorityTransition) -> Bool {
        (try? Self(transition: transition)) == self
    }
    private enum CodingKeys: String, CodingKey { case ownerID, phoneEpoch, watchEpoch, sequence, transitionDigest, authorityDigest }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ownerID = try c.decode(UUID.self, forKey: .ownerID); phoneEpoch = try c.decode(UUID.self, forKey: .phoneEpoch)
        watchEpoch = try c.decode(UUID.self, forKey: .watchEpoch); sequence = try c.decode(Int64.self, forKey: .sequence)
        transitionDigest = try c.decode(String.self, forKey: .transitionDigest); authorityDigest = try c.decode(String.self, forKey: .authorityDigest)
        try validate()
    }
    func validate() throws {
        guard phoneEpoch != watchEpoch, (1...OwnerPracticeIdentity.maximumRevision).contains(sequence) else { throw OwnerPreparationError.invalid("ack sequence or peer") }
        try ownerWireDigest(transitionDigest); try ownerWireDigest(authorityDigest)
    }
}

/// The exact durable prefix the phone has mirrored; nil means initial enrollment, never an inferred snapshot.
public struct OwnerAuthorityReplayCursor: Codable, Equatable, Sendable {
    public let ownerID: UUID
    public let phoneEpoch: UUID
    public let watchEpoch: UUID
    public let after: OwnerAuthorityAcknowledgement?
    public init(ownerID: UUID, phoneEpoch: UUID, watchEpoch: UUID, after: OwnerAuthorityAcknowledgement? = nil) throws {
        self.ownerID = ownerID; self.phoneEpoch = phoneEpoch; self.watchEpoch = watchEpoch; self.after = after
        guard phoneEpoch != watchEpoch, after == nil || (after?.ownerID == ownerID && after?.phoneEpoch == phoneEpoch
            && after?.watchEpoch == watchEpoch) else { throw OwnerPreparationError.invalid("replay peer") }
        try after?.validate()
    }
    private enum CodingKeys: String, CodingKey { case ownerID, phoneEpoch, watchEpoch, after }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(ownerID: c.decode(UUID.self, forKey: .ownerID), phoneEpoch: c.decode(UUID.self, forKey: .phoneEpoch),
            watchEpoch: c.decode(UUID.self, forKey: .watchEpoch), after: c.decodeIfPresent(OwnerAuthorityAcknowledgement.self, forKey: .after))
    }
    func validateSuccessor(_ transition: OwnerAuthorityTransition) throws {
        let mutation = transition.mutation
        guard mutation.ownerID == ownerID, mutation.phoneEpoch == phoneEpoch, mutation.watchEpoch == watchEpoch,
              transition.sequence - 1 == (after?.sequence ?? 0), mutation.beforeDigest == after?.authorityDigest else {
            throw OwnerPreparationError.invalid("replay successor")
        }
    }
}

public struct OwnerPreparationIdentity: Codable, Equatable, Sendable {
    public let ownerID: UUID
    public let phoneEpoch: UUID
    public let watchEpoch: UUID
    public let authorityRevision: Int64
    public let authorityDigest: String
    public let practiceID: UUID
    public let setup: PracticeSetupIdentity
    fileprivate init(authority: OwnerPracticeIdentity, practiceID: UUID, draft: PracticeSetupDraft) throws {
        ownerID = authority.ownerID; phoneEpoch = authority.phoneInstallationEpoch; watchEpoch = authority.watchInstallationEpoch
        authorityRevision = authority.revision; authorityDigest = try OwnerAuthorityMutation.digest(authority)
        self.practiceID = practiceID; setup = draft.identity
        try validate()
    }
    private enum CodingKeys: String, CodingKey { case ownerID, phoneEpoch, watchEpoch, authorityRevision, authorityDigest, practiceID, setup }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ownerID = try c.decode(UUID.self, forKey: .ownerID); phoneEpoch = try c.decode(UUID.self, forKey: .phoneEpoch)
        watchEpoch = try c.decode(UUID.self, forKey: .watchEpoch); authorityRevision = try c.decode(Int64.self, forKey: .authorityRevision)
        authorityDigest = try c.decode(String.self, forKey: .authorityDigest); practiceID = try c.decode(UUID.self, forKey: .practiceID)
        setup = try c.decode(PracticeSetupIdentity.self, forKey: .setup)
        try validate()
    }
    func validate() throws {
        try setup.validate(); try ownerWireDigest(authorityDigest)
        guard phoneEpoch != watchEpoch, setup.originInstallationEpoch == phoneEpoch,
              (1...OwnerPracticeIdentity.maximumRevision).contains(authorityRevision) else { throw OwnerPreparationError.invalid("preparation identity") }
    }
    public func matches(_ authority: OwnerPracticeIdentity) throws -> Bool {
        let digest = try OwnerAuthorityMutation.digest(authority)
        return ownerID == authority.ownerID && phoneEpoch == authority.phoneInstallationEpoch && watchEpoch == authority.watchInstallationEpoch
            && authorityRevision == authority.revision && authorityDigest == digest
    }
}

/// A suggestion/accepted setup value. It contains no physical confirmation or Start permission.
public struct OwnerPreparation: Codable, Equatable, Sendable {
    public let authority: OwnerPracticeIdentity
    public let practiceID: UUID
    public let draft: PracticeSetupDraft
    public let identity: OwnerPreparationIdentity
    public init(authority: OwnerPracticeIdentity, practiceID: UUID, draft: PracticeSetupDraft) throws {
        guard authority.isCollectionAllowed, authority.phoneInstallationEpoch == draft.identity.originInstallationEpoch,
              [.forehandGroundstroke, .backhandGroundstroke].contains(draft.preferences.intendedDrill) else {
            throw OwnerPreparationError.invalid("owner forehand/backhand preparation")
        }
        try draft.identity.validate()
        self.authority = authority; self.practiceID = practiceID; self.draft = draft
        identity = try OwnerPreparationIdentity(authority: authority, practiceID: practiceID, draft: draft)
    }
    private enum CodingKeys: String, CodingKey { case authority, practiceID, draft }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(authority: OwnerPracticeIdentity.decode(c.decode(Data.self, forKey: .authority)),
            practiceID: c.decode(UUID.self, forKey: .practiceID), draft: c.decode(PracticeSetupDraft.self, forKey: .draft))
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(authority.encoded(), forKey: .authority); try c.encode(practiceID, forKey: .practiceID); try c.encode(draft, forKey: .draft)
    }
}

public struct OwnerPreparationCorrelation: Codable, Equatable, Sendable {
    public let requestID: UUID
    public let generations: PracticeSetupGenerations
    public let preparation: OwnerPreparationIdentity
    public init(requestID: UUID, generations: PracticeSetupGenerations, preparation: OwnerPreparationIdentity) {
        self.requestID = requestID; self.generations = generations; self.preparation = preparation
    }
}

public struct OwnerPreparationObservation: Codable, Equatable, Sendable {
    public let watchEpoch: UUID
    public let generations: PracticeSetupGenerations
    public let observedAtUnixSeconds: Double
    public let state: PracticeSetupWatchState
    public let wrist: PracticeSetupWrist
    public let crown: PracticeSetupCrown
    public let capability: PracticeSetupCapability
    public let storage: PracticeSetupStorage
    public let authority: OwnerPracticeIdentity?
    public let acceptedCurrent: OwnerPreparationIdentity?
    public let acceptedNext: OwnerPreparationIdentity?
    public init(watchEpoch: UUID, generations: PracticeSetupGenerations, observedAtUnixSeconds: Double,
        state: PracticeSetupWatchState, authority: OwnerPracticeIdentity?, acceptedCurrent: OwnerPreparationIdentity? = nil,
        acceptedNext: OwnerPreparationIdentity? = nil, wrist: PracticeSetupWrist = .unknown, crown: PracticeSetupCrown = .unknown,
        capability: PracticeSetupCapability = .unknown, storage: PracticeSetupStorage = .unknown) throws {
        self.watchEpoch = watchEpoch; self.generations = generations; self.observedAtUnixSeconds = observedAtUnixSeconds
        self.state = state; self.authority = authority; self.acceptedCurrent = acceptedCurrent; self.acceptedNext = acceptedNext
        self.wrist = wrist; self.crown = crown; self.capability = capability; self.storage = storage
        try validate()
    }
    func validate() throws {
        guard observedAtUnixSeconds.isFinite, observedAtUnixSeconds >= 0,
              authority == nil || authority?.watchInstallationEpoch == watchEpoch else { throw OwnerPreparationError.invalid("Watch observation") }
        for accepted in [acceptedCurrent, acceptedNext].compactMap({ $0 }) {
            try accepted.validate()
            guard let authority, authority.isCollectionAllowed, try accepted.matches(authority) else {
                throw OwnerPreparationError.invalid("accepted owner differs from observed authority")
            }
        }
        if state == .unavailable {
            guard acceptedCurrent == nil, acceptedNext == nil, wrist == .unknown, crown == .unknown,
                  capability == .unknown, storage == .unknown else { throw OwnerPreparationError.invalid("unavailable Watch") }
        }
    }
    private enum CodingKeys: String, CodingKey {
        case watchEpoch, generations, observedAtUnixSeconds, state, wrist, crown, capability, storage, authority, acceptedCurrent, acceptedNext
    }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(watchEpoch: c.decode(UUID.self, forKey: .watchEpoch), generations: c.decode(PracticeSetupGenerations.self, forKey: .generations),
            observedAtUnixSeconds: c.decode(Double.self, forKey: .observedAtUnixSeconds), state: c.decode(PracticeSetupWatchState.self, forKey: .state),
            authority: c.decodeIfPresent(Data.self, forKey: .authority).map(OwnerPracticeIdentity.decode),
            acceptedCurrent: c.decodeIfPresent(OwnerPreparationIdentity.self, forKey: .acceptedCurrent),
            acceptedNext: c.decodeIfPresent(OwnerPreparationIdentity.self, forKey: .acceptedNext),
            wrist: c.decode(PracticeSetupWrist.self, forKey: .wrist), crown: c.decode(PracticeSetupCrown.self, forKey: .crown),
            capability: c.decode(PracticeSetupCapability.self, forKey: .capability), storage: c.decode(PracticeSetupStorage.self, forKey: .storage))
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(watchEpoch, forKey: .watchEpoch); try c.encode(generations, forKey: .generations)
        try c.encode(observedAtUnixSeconds, forKey: .observedAtUnixSeconds); try c.encode(state, forKey: .state)
        try c.encode(wrist, forKey: .wrist); try c.encode(crown, forKey: .crown)
        try c.encode(capability, forKey: .capability); try c.encode(storage, forKey: .storage)
        try c.encodeIfPresent(authority?.encoded(), forKey: .authority)
        try c.encodeIfPresent(acceptedCurrent, forKey: .acceptedCurrent); try c.encodeIfPresent(acceptedNext, forKey: .acceptedNext)
    }
}

/// Values alone never apply authority, acknowledge persistence, confirm physical placement or start capture.
public enum OwnerPreparationMessage: Equatable, Sendable {
    case statusRequest(requestID: UUID, phoneEpoch: UUID)
    case status(requestID: UUID, phoneEpoch: UUID, observation: OwnerPreparationObservation)
    case draft(OwnerPreparation)
    case prepare(correlation: OwnerPreparationCorrelation, preparation: OwnerPreparation)
    case receipt(correlation: OwnerPreparationCorrelation, disposition: PracticeSetupDisposition,
                 observation: OwnerPreparationObservation, retirementReason: PracticeSetupRetirementReason? = nil)
    case retire(correlation: OwnerPreparationCorrelation, reason: PracticeSetupRetirementReason)
    case mutate(requestID: UUID, generations: PracticeSetupGenerations, mutation: OwnerAuthorityMutation)
    case applied(requestID: UUID, generations: PracticeSetupGenerations, transition: OwnerAuthorityTransition)
    case transition(OwnerAuthorityTransition)
    case acknowledge(OwnerAuthorityAcknowledgement)
    case replay(requestID: UUID, cursor: OwnerAuthorityReplayCursor)
    case replayResult(requestID: UUID, cursor: OwnerAuthorityReplayCursor, transition: OwnerAuthorityTransition?)
    case error(requestID: UUID, requestDigest: String, code: PracticeSetupFailureCode)

    public var requestID: UUID? {
        switch self {
        case let .statusRequest(id, _), let .status(id, _, _), let .mutate(id, _, _), let .applied(id, _, _),
             let .replay(id, _), let .replayResult(id, _, _), let .error(id, _, _): id
        case let .prepare(value, _), let .receipt(value, _, _, _), let .retire(value, _): value.requestID
        default: nil
        }
    }
    public var mutation: OwnerAuthorityMutation? {
        if case let .mutate(_, _, value) = self { return value }; return nil
    }
    public var correlation: OwnerPreparationCorrelation? {
        switch self {
        case let .prepare(value, _), let .receipt(value, _, _, _), let .retire(value, _): value
        default: nil
        }
    }
    public var isRequest: Bool {
        switch self {
        case .statusRequest, .prepare, .retire, .mutate, .replay: true
        default: false
        }
    }
    /// Hashes the entire canonical request, including its peer, both generations and immutable contents.
    public static func failure(replyingTo request: Self, code: PracticeSetupFailureCode) throws -> Self {
        guard request.isRequest, let id = request.requestID else { throw OwnerPreparationError.invalid("failure request") }
        return .error(requestID: id, requestDigest: RecordingChunkCodec.digest(try OwnerPreparationCodec.encode(request)), code: code)
    }
    /// Correlation is necessary but not current admission: the caller must recheck cancellation and local authority.
    public func isReply(to request: Self) -> Bool {
        do {
            try validate(); try request.validate()
            switch (self, request) {
            case let (.status(id, phone, _), .statusRequest(expectedID, expectedPhone)):
                return id == expectedID && phone == expectedPhone
            case let (.receipt(value, disposition, _, _), .prepare(expected, _)):
                return disposition != .retired && value == expected
            case let (.receipt(value, disposition, _, reason), .retire(expected, expectedReason)):
                return disposition == .retired && value == expected && reason == expectedReason
            case let (.applied(id, generations, transition), .mutate(expectedID, expectedGenerations, mutation)):
                return id == expectedID && generations == expectedGenerations && transition.mutation == mutation
            case let (.replayResult(id, cursor, _), .replay(expectedID, expectedCursor)):
                return id == expectedID && cursor == expectedCursor
            case let (.error(id, digest, _), _):
                let expectedDigest = RecordingChunkCodec.digest(try OwnerPreparationCodec.encode(request))
                return request.isRequest && id == request.requestID && digest == expectedDigest
            default: return false
            }
        } catch { return false }
    }

    func validate() throws {
        try correlation?.preparation.validate()
        switch self {
        case let .status(_, phone, observation):
            try observation.validate()
            guard observation.authority == nil || observation.authority?.phoneInstallationEpoch == phone else {
                throw OwnerPreparationError.invalid("status phone")
            }
        case let .draft(value): try value.identity.validate()
        case let .prepare(correlation, value):
            guard correlation.preparation == value.identity else { throw OwnerPreparationError.invalid("preparation correlation") }
        case let .receipt(correlation, disposition, observation, reason):
            try observation.validate()
            let identity = correlation.preparation
            guard observation.state != .unavailable, let authority = observation.authority,
                  identity.ownerID == authority.ownerID, identity.phoneEpoch == authority.phoneInstallationEpoch,
                  identity.watchEpoch == authority.watchInstallationEpoch else { throw OwnerPreparationError.invalid("receipt owner") }
            switch disposition {
            case .acceptedCurrent, .acceptedNext:
                let accepted = disposition == .acceptedCurrent ? observation.acceptedCurrent : observation.acceptedNext
                guard reason == nil, observation.generations == correlation.generations, accepted == identity else {
                    throw OwnerPreparationError.invalid("acceptance correlation")
                }
            case .retired:
                guard reason != nil, authority.revision > identity.authorityRevision,
                      observation.generations.runtimeGeneration == correlation.generations.runtimeGeneration,
                      observation.generations.preparationGeneration != correlation.generations.preparationGeneration,
                      observation.acceptedCurrent == nil, observation.acceptedNext == nil else {
                    throw OwnerPreparationError.invalid("retirement correlation")
                }
            }
        case let .mutate(_, _, mutation): _ = try mutation.encoded()
        case let .applied(_, _, transition), let .transition(transition): _ = try transition.encoded()
        case let .acknowledge(ack): try ack.validate()
        case let .replayResult(_, cursor, transition):
            if let transition { _ = try transition.encoded(); try cursor.validateSuccessor(transition) }
        case let .error(_, digest, _): try ownerWireDigest(digest)
        default: break
        }
    }
}

public enum OwnerPreparationCodec {
    public static let maximumBytes = 32_768
    public static func encode(_ message: OwnerPreparationMessage) throws -> Data {
        try message.validate()
        let bytes = try PracticeSetupJSON.encode(Wire(message))
        guard bytes.count <= maximumBytes else { throw OwnerPreparationError.capacity }
        return bytes
    }
    public static func decode(_ bytes: Data) throws -> OwnerPreparationMessage {
        guard !bytes.isEmpty, bytes.count <= maximumBytes else { throw OwnerPreparationError.capacity }
        let message = try JSONDecoder().decode(Wire.self, from: bytes).message()
        guard try encode(message) == bytes else { throw OwnerPreparationError.invalid("noncanonical owner wire") }
        return message
    }
    private struct Wire: Codable {
        var version = 2
        var kind: String
        var requestID: UUID?
        var phoneEpoch: UUID?
        var observation: OwnerPreparationObservation?
        var preparation: OwnerPreparation?
        var correlation: OwnerPreparationCorrelation?
        var disposition: PracticeSetupDisposition?
        var reason: PracticeSetupRetirementReason?
        var generations: PracticeSetupGenerations?
        var mutation: OwnerAuthorityMutation?
        var transition: OwnerAuthorityTransition?
        var acknowledgement: OwnerAuthorityAcknowledgement?
        var cursor: OwnerAuthorityReplayCursor?
        var requestDigest: String?
        var code: PracticeSetupFailureCode?

        init(_ message: OwnerPreparationMessage) {
            switch message {
            case let .statusRequest(id, phone): kind = "PSLOwnerSetup2.statusRequest"; requestID = id; phoneEpoch = phone
            case let .status(id, phone, value): kind = "PSLOwnerSetup2.status"; requestID = id; phoneEpoch = phone; observation = value
            case let .draft(value): kind = "PSLOwnerSetup2.draft"; preparation = value
            case let .prepare(reference, value): kind = "PSLOwnerSetup2.prepare"; correlation = reference; preparation = value
            case let .receipt(reference, result, value, why):
                kind = "PSLOwnerSetup2.receipt"; correlation = reference; disposition = result; observation = value; reason = why
            case let .retire(reference, why): kind = "PSLOwnerSetup2.retire"; correlation = reference; reason = why
            case let .mutate(id, generation, command): kind = "PSLOwnerSetup2.mutate"; requestID = id; generations = generation; mutation = command
            case let .applied(id, generation, value): kind = "PSLOwnerSetup2.applied"; requestID = id; generations = generation; transition = value
            case let .transition(value): kind = "PSLOwnerSetup2.transition"; transition = value
            case let .acknowledge(value): kind = "PSLOwnerSetup2.acknowledge"; acknowledgement = value
            case let .replay(id, value): kind = "PSLOwnerSetup2.replay"; requestID = id; cursor = value
            case let .replayResult(id, value, next): kind = "PSLOwnerSetup2.replayResult"; requestID = id; cursor = value; transition = next
            case let .error(id, digest, failure): kind = "PSLOwnerSetup2.error"; requestID = id; requestDigest = digest; code = failure
            }
        }
        func required<T>(_ value: T?) throws -> T {
            guard let value else { throw OwnerPreparationError.invalid("missing owner wire field") }; return value
        }
        func message() throws -> OwnerPreparationMessage {
            guard version == 2 else { throw OwnerPreparationError.invalid("owner wire version") }
            switch kind {
            case "PSLOwnerSetup2.statusRequest": return .statusRequest(requestID: try required(requestID), phoneEpoch: try required(phoneEpoch))
            case "PSLOwnerSetup2.status": return .status(requestID: try required(requestID), phoneEpoch: try required(phoneEpoch), observation: try required(observation))
            case "PSLOwnerSetup2.draft": return .draft(try required(preparation))
            case "PSLOwnerSetup2.prepare": return .prepare(correlation: try required(correlation), preparation: try required(preparation))
            case "PSLOwnerSetup2.receipt":
                return .receipt(correlation: try required(correlation), disposition: try required(disposition),
                    observation: try required(observation), retirementReason: reason)
            case "PSLOwnerSetup2.retire": return .retire(correlation: try required(correlation), reason: try required(reason))
            case "PSLOwnerSetup2.mutate": return .mutate(requestID: try required(requestID), generations: try required(generations), mutation: try required(mutation))
            case "PSLOwnerSetup2.applied": return .applied(requestID: try required(requestID), generations: try required(generations), transition: try required(transition))
            case "PSLOwnerSetup2.transition": return .transition(try required(transition))
            case "PSLOwnerSetup2.acknowledge": return .acknowledge(try required(acknowledgement))
            case "PSLOwnerSetup2.replay": return .replay(requestID: try required(requestID), cursor: try required(cursor))
            case "PSLOwnerSetup2.replayResult": return .replayResult(requestID: try required(requestID), cursor: try required(cursor), transition: transition)
            case "PSLOwnerSetup2.error": return .error(requestID: try required(requestID), requestDigest: try required(requestDigest), code: try required(code))
            default: throw OwnerPreparationError.invalid("owner wire kind")
            }
        }
    }
}

private func ownerWireDigest(_ value: String) throws {
    guard value.utf8.count == 64, value.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
        throw OwnerPreparationError.invalid("SHA-256 digest")
    }
}
