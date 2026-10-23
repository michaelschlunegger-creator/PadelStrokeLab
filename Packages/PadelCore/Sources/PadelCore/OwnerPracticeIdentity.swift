import Foundation

public enum OwnerPracticeError: Error, Equatable, Sendable {
    case invalid(String), staleAuthority, consentRequired, capacity, integrity
}

/// A versioned explanation of app consent, separate from HealthKit authorization.
public enum OwnerPracticePolicy {
    public static let version = 1
    public static let studyID = "PSL-OWNER-FH-BH-1"
    public static let text = """
    Owner-only personal forehand/backhand feasibility. I am the paired Watch account owner and wearer.
    I consent to local motion recording and my reference labels for this personal study.
    Live heart rate and recovery are optional and limited to my current practice.
    Export requires a separate deliberate action. No guest, unrelated history, cloud upload or future study is authorized.
    This feasibility app saves no workout summary. Local content stays until I delete it; storage limits refuse new content instead of silently evicting existing content.
    An owner workout can cause system Health samples and Activity effects even without an app-saved workout summary.
    App deletion cannot erase independent system Health data or separately exported copies.
    """
    public static var digest: String { RecordingChunkCodec.digest(Data(text.utf8)) }
}

/// A revision-bound declaration. The caller must obtain the actual affirmative human decision.
/// Values cannot be decoded or mutated into permission, and never authorize runtime Start.
public struct OwnerConsentDecision: Equatable, Sendable {
    fileprivate let body: OwnerDecisionBody
    public var id: UUID { body.id }

    public static func withdraw(for state: OwnerPracticeIdentity, decisionID: UUID,
                                confirmedAtUnixSeconds: Double) throws -> Self {
        guard state.isCollectionAllowed else { throw OwnerPracticeError.consentRequired }
        return try make(state, kind: "withdraw", heartRate: false, acknowledged: false,
                        id: decisionID, date: confirmedAtUnixSeconds, policy: OwnerPracticePolicy.digest)
    }

    public static func heartRate(for state: OwnerPracticeIdentity, allowed: Bool, decisionID: UUID,
                                 confirmedAtUnixSeconds: Double, policyDigest: String) throws -> Self {
        guard state.isCollectionAllowed else { throw OwnerPracticeError.consentRequired }
        return try make(state, kind: "heartRate", heartRate: allowed, acknowledged: false,
                        id: decisionID, date: confirmedAtUnixSeconds, policy: policyDigest)
    }

    public static func reconsent(for state: OwnerPracticeIdentity, includesHeartRate: Bool,
                                 acknowledgesWithdrawal: Bool, decisionID: UUID,
                                 confirmedAtUnixSeconds: Double, policyDigest: String) throws -> Self {
        guard !state.isCollectionAllowed, state.withdrawalBarrier > 0, acknowledgesWithdrawal else {
            throw OwnerPracticeError.consentRequired
        }
        return try make(state, kind: "reconsent", heartRate: includesHeartRate, acknowledged: true,
                        id: decisionID, date: confirmedAtUnixSeconds, policy: policyDigest)
    }

    private static func make(_ state: OwnerPracticeIdentity, kind: String, heartRate: Bool,
                             acknowledged: Bool, id: UUID, date: Double, policy: String) throws -> Self {
        // Reported wall time is evidence, not authority order. Clock correction must not block revocation.
        guard policy == OwnerPracticePolicy.digest, date.isFinite, date >= 0 else {
            throw OwnerPracticeError.invalid("policy or decision time")
        }
        guard !state.body.usedDecisionIDs.contains(id) else { throw OwnerPracticeError.staleAuthority }
        return Self(body: OwnerDecisionBody(id: id, kind: kind, ownerID: state.ownerID,
            phoneEpoch: state.phoneInstallationEpoch, watchEpoch: state.watchInstallationEpoch,
            expectedRevision: state.revision, expectedConsentGeneration: state.consentGeneration,
            observedWithdrawalBarrier: state.withdrawalBarrier, includesHeartRate: heartRate,
            acknowledgesWithdrawal: acknowledged, confirmedAtUnixSeconds: date, policyDigest: policy))
    }
}

/// One immutable owner/paired-installation authority. No aliases, guest role or restoration API.
/// This pure value describes app consent, not persistence, Apple identity or actual wearer proof.
public struct OwnerPracticeIdentity: Equatable, Sendable {
    public static let maximumRevision = PracticeSetupIdentity.maximumRevision
    public static let maximumBytes = 16_384
    public static let maximumConsentDecisions = 128
    fileprivate let body: OwnerIdentityBody

    public var ownerID: UUID { body.ownerID }
    public var phoneInstallationEpoch: UUID { body.phoneEpoch }
    public var watchInstallationEpoch: UUID { body.watchEpoch }
    public var revision: Int64 { body.revision }
    public var consentGeneration: Int64 { body.consentGeneration }
    public var withdrawalBarrier: Int64 { body.withdrawalBarrier }
    public var isCollectionAllowed: Bool { body.collectionAllowed }
    public var heartRateConsent: Bool { body.heartRateConsent }
    public var policyDigest: String { body.policyDigest }
    public var lastDecisionID: UUID { body.lastDecision.id }

    private init(_ body: OwnerIdentityBody) throws {
        try Self.validate(body)
        self.body = body
    }

    public static func enrolled(ownerID: UUID, phoneInstallationEpoch: UUID, watchInstallationEpoch: UUID,
                                attestsWatchAccountOwner: Bool, acceptsMotionStudy: Bool,
                                includesHeartRate: Bool, decisionID: UUID,
                                confirmedAtUnixSeconds: Double, policyDigest: String) throws -> Self {
        guard attestsWatchAccountOwner, acceptsMotionStudy else { throw OwnerPracticeError.consentRequired }
        let decision = OwnerDecisionBody(id: decisionID, kind: "enroll", ownerID: ownerID,
            phoneEpoch: phoneInstallationEpoch, watchEpoch: watchInstallationEpoch,
            expectedRevision: 0, expectedConsentGeneration: 0, observedWithdrawalBarrier: 0,
            includesHeartRate: includesHeartRate, acknowledgesWithdrawal: false,
            confirmedAtUnixSeconds: confirmedAtUnixSeconds, policyDigest: policyDigest)
        return try Self(OwnerIdentityBody(schemaVersion: 1, ownerID: ownerID,
            phoneEpoch: phoneInstallationEpoch, watchEpoch: watchInstallationEpoch,
            studyID: OwnerPracticePolicy.studyID, policyVersion: OwnerPracticePolicy.version,
            policyDigest: policyDigest, attestsWatchAccountOwner: true, revision: 1,
            consentGeneration: 1, withdrawalBarrier: 0, collectionAllowed: true,
            heartRateConsent: includesHeartRate, lastDecision: decision, usedDecisionIDs: [decisionID]))
    }

    public func permits(ownerID: UUID, phoneEpoch: UUID, watchEpoch: UUID, requiresHeartRate: Bool) -> Bool {
        isCollectionAllowed && self.ownerID == ownerID && phoneInstallationEpoch == phoneEpoch
            && watchInstallationEpoch == watchEpoch && (!requiresHeartRate || heartRateConsent)
    }

    /// Preparation/retirement mutations also retire pending consent/context tokens.
    /// The exclusive store and runtime coordinator must enforce this revision durably.
    public func advancingRevision(expectedRevision: Int64) throws -> Self {
        guard expectedRevision == revision else { throw OwnerPracticeError.staleAuthority }
        var next = body
        next.revision = try Self.increment(revision)
        return try Self(next)
    }

    public func applying(_ command: OwnerConsentDecision) throws -> Self {
        let decision = command.body
        // Exact replay of the most recent decision is metadata-idempotent; it grants no new Start.
        if decision == body.lastDecision { return self }
        guard decision.ownerID == ownerID, decision.phoneEpoch == phoneInstallationEpoch,
              decision.watchEpoch == watchInstallationEpoch, decision.expectedRevision == revision,
              decision.expectedConsentGeneration == consentGeneration,
              decision.observedWithdrawalBarrier == withdrawalBarrier,
              !body.usedDecisionIDs.contains(decision.id) else { throw OwnerPracticeError.staleAuthority }
        // Valid active states reserve both optional HR-disable (if needed) and full withdrawal.
        guard body.usedDecisionIDs.count < Self.maximumConsentDecisions else {
            throw OwnerPracticeError.capacity
        }
        guard decision.policyDigest == policyDigest,
              decision.confirmedAtUnixSeconds.isFinite, decision.confirmedAtUnixSeconds >= 0 else {
            throw OwnerPracticeError.invalid("decision")
        }
        var next = body
        next.revision = try Self.increment(revision)
        next.consentGeneration = try Self.increment(consentGeneration)
        switch decision.kind {
        case "withdraw":
            guard isCollectionAllowed else { throw OwnerPracticeError.consentRequired }
            next.collectionAllowed = false
            next.heartRateConsent = false
            next.withdrawalBarrier = next.consentGeneration
        case "heartRate":
            guard isCollectionAllowed else { throw OwnerPracticeError.consentRequired }
            next.heartRateConsent = decision.includesHeartRate
        case "reconsent":
            guard !isCollectionAllowed, withdrawalBarrier > 0, decision.acknowledgesWithdrawal else {
                throw OwnerPracticeError.consentRequired
            }
            next.collectionAllowed = true
            next.heartRateConsent = decision.includesHeartRate
        default: throw OwnerPracticeError.invalid("decision action")
        }
        next.lastDecision = decision
        next.usedDecisionIDs.append(decision.id)
        let result = try Self(next)
        _ = try result.encoded()
        return result
    }

    public func encoded() throws -> Data {
        try OwnerCanonical.encode(body, domain: "PSLOwnerIdentity1", limit: Self.maximumBytes)
    }

    public static func decode(_ bytes: Data) throws -> Self {
        let body: OwnerIdentityBody = try OwnerCanonical.decode(bytes, domain: "PSLOwnerIdentity1",
                                                                limit: maximumBytes)
        return try Self(body)
    }

    private static func increment(_ number: Int64) throws -> Int64 {
        guard number < maximumRevision else { throw OwnerPracticeError.capacity }
        return number + 1
    }

    private static func validate(_ state: OwnerIdentityBody) throws {
        let decision = state.lastDecision
        let reserve: Int64 = state.heartRateConsent ? 2 : 1
        guard state.schemaVersion == 1, state.studyID == OwnerPracticePolicy.studyID,
              state.policyVersion == OwnerPracticePolicy.version, state.policyDigest == OwnerPracticePolicy.digest,
              state.attestsWatchAccountOwner, state.phoneEpoch != state.watchEpoch,
              (1...maximumRevision).contains(state.revision),
              (1...Int64(maximumConsentDecisions)).contains(state.consentGeneration),
              state.revision >= state.consentGeneration,
              !state.collectionAllowed || (state.revision <= maximumRevision - reserve
                  && state.consentGeneration <= Int64(maximumConsentDecisions) - reserve),
              (0...state.consentGeneration).contains(state.withdrawalBarrier),
              state.usedDecisionIDs.count == Int(state.consentGeneration),
              Set(state.usedDecisionIDs).count == state.usedDecisionIDs.count,
              state.usedDecisionIDs.last == decision.id,
              decision.ownerID == state.ownerID, decision.phoneEpoch == state.phoneEpoch,
              decision.watchEpoch == state.watchEpoch, decision.policyDigest == state.policyDigest,
              decision.confirmedAtUnixSeconds.isFinite, decision.confirmedAtUnixSeconds >= 0,
              decision.expectedRevision >= 0, decision.expectedRevision < state.revision,
              decision.expectedConsentGeneration == state.consentGeneration - 1,
              decision.expectedRevision >= decision.expectedConsentGeneration,
              decision.observedWithdrawalBarrier >= 0,
              decision.observedWithdrawalBarrier <= decision.expectedConsentGeneration else {
            throw OwnerPracticeError.invalid("owner authority invariants")
        }
        switch decision.kind {
        case "enroll":
            guard state.consentGeneration == 1, state.withdrawalBarrier == 0,
                  decision.expectedRevision == 0, !decision.acknowledgesWithdrawal,
                  state.collectionAllowed, state.heartRateConsent == decision.includesHeartRate else {
                throw OwnerPracticeError.invalid("enrollment")
            }
        case "withdraw":
            guard state.consentGeneration > 1, !state.collectionAllowed, !state.heartRateConsent,
                  !decision.includesHeartRate, !decision.acknowledgesWithdrawal,
                  state.withdrawalBarrier == state.consentGeneration else {
                throw OwnerPracticeError.invalid("withdrawal")
            }
        case "heartRate", "reconsent":
            guard state.consentGeneration > 1, state.collectionAllowed,
                  state.heartRateConsent == decision.includesHeartRate,
                  state.withdrawalBarrier == decision.observedWithdrawalBarrier,
                  decision.acknowledgesWithdrawal == (decision.kind == "reconsent"),
                  decision.kind != "reconsent" || state.withdrawalBarrier > 0 else {
                throw OwnerPracticeError.invalid("consent decision")
            }
        default: throw OwnerPracticeError.invalid("unknown consent action")
        }
    }
}

fileprivate struct OwnerDecisionBody: Codable, Equatable, Sendable {
    let id: UUID
    let kind: String
    let ownerID: UUID
    let phoneEpoch: UUID
    let watchEpoch: UUID
    let expectedRevision: Int64
    let expectedConsentGeneration: Int64
    let observedWithdrawalBarrier: Int64
    let includesHeartRate: Bool
    let acknowledgesWithdrawal: Bool
    let confirmedAtUnixSeconds: Double
    let policyDigest: String
}

fileprivate struct OwnerIdentityBody: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let ownerID: UUID
    let phoneEpoch: UUID
    let watchEpoch: UUID
    let studyID: String
    let policyVersion: Int
    let policyDigest: String
    let attestsWatchAccountOwner: Bool
    var revision: Int64
    var consentGeneration: Int64
    var withdrawalBarrier: Int64
    var collectionAllowed: Bool
    var heartRateConsent: Bool
    var lastDecision: OwnerDecisionBody
    var usedDecisionIDs: [UUID]
}

/// Canonical envelopes detect corruption, not an adversary or dishonest human declarations.
/// Decode/re-encode equality also rejects ignored unknown fields, duplicates and noncanonical JSON.
enum OwnerCanonical {
    private struct Envelope<T: Codable>: Codable {
        let body: T
        let sha256: String
    }

    static func encode<T: Codable>(_ body: T, domain: String, limit: Int) throws -> Data {
        let payload = try PracticeSetupJSON.encode(body)
        let checksum = RecordingChunkCodec.digest(Data((domain + "\n").utf8) + payload)
        let bytes = try PracticeSetupJSON.encode(Envelope(body: body, sha256: checksum))
        guard !bytes.isEmpty, bytes.count <= limit else { throw OwnerPracticeError.capacity }
        return bytes
    }

    static func decode<T: Codable>(_ bytes: Data, domain: String, limit: Int) throws -> T {
        guard !bytes.isEmpty, bytes.count <= limit else { throw OwnerPracticeError.capacity }
        let envelope = try JSONDecoder().decode(Envelope<T>.self, from: bytes)
        guard try encode(envelope.body, domain: domain, limit: limit) == bytes else {
            throw OwnerPracticeError.integrity
        }
        return envelope.body
    }
}
