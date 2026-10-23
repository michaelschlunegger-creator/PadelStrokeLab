import Foundation

/// An immutable metadata binding, not a runtime admission token or evidence of samples.
/// Only the checked bind factory creates this type; decoded historical contexts cannot publish.
public struct OwnerContextBinding: Equatable, Sendable {
    public let context: OwnerRecordingContext
    public let rawMetadataBytes: Data
    fileprivate let authorityBytes: Data

    fileprivate init(context: OwnerRecordingContext, rawMetadataBytes: Data, authorityBytes: Data) {
        self.context = context
        self.rawMetadataBytes = rawMetadataBytes
        self.authorityBytes = authorityBytes
    }

    public func validateCurrentAuthority(_ authority: OwnerPracticeIdentity) throws {
        guard authority.isCollectionAllowed, try authority.encoded() == authorityBytes else {
            throw OwnerPracticeError.staleAuthority
        }
    }
}

/// Context-free legacy raw data is not accepted as an owner record without explicit new binding.
/// The future exclusive store must reject existing/failed IDs and the live actor must gate Start.
public struct OwnerRecordingContext: Equatable, Sendable {
    public static let maximumBytes = 8_192
    public static let acquisitionMode = "ownerBatchedWorkout"
    private let body: OwnerContextBody
    public let metadata: RecordingMetadata

    public var ownerID: UUID { body.ownerID }
    public var phoneInstallationEpoch: UUID { body.phoneEpoch }
    public var watchInstallationEpoch: UUID { body.watchEpoch }
    public var practiceID: UUID { body.practiceID }
    public var recordingID: UUID { body.recordingID }
    public var rawMetadataDigest: String { body.rawMetadataDigest }
    public var authorityDigest: String { body.authorityDigest }
    public var authorityRevision: Int64 { body.authorityRevision }
    public var consentGeneration: Int64 { body.consentGeneration }
    public var withdrawalBarrier: Int64 { body.withdrawalBarrier }
    public var heartRateConsent: Bool { body.heartRateConsent }
    public var acceptedSetup: PracticeSetupDraft { body.acceptedSetup }
    public var generations: PracticeSetupGenerations { body.generations }
    public var manualStroke: RecordingDrill { body.acceptedSetup.preferences.intendedDrill }

    private init(body: OwnerContextBody, rawMetadataBytes: Data) throws {
        let metadata = try Self.canonicalMetadata(rawMetadataBytes)
        try Self.validate(body, metadata: metadata, rawMetadataBytes: rawMetadataBytes)
        self.body = body
        self.metadata = metadata
    }

    public static func bind(rawMetadataBytes: Data, authority: OwnerPracticeIdentity, practiceID: UUID,
                             acceptedSetup: PracticeSetupDraft,
                             generations: PracticeSetupGenerations) throws -> OwnerContextBinding {
        guard authority.isCollectionAllowed else { throw OwnerPracticeError.consentRequired }
        let metadata = try canonicalMetadata(rawMetadataBytes)
        let authorityBytes = try authority.encoded()
        let body = OwnerContextBody(schemaVersion: 1, ownerID: authority.ownerID,
            phoneEpoch: authority.phoneInstallationEpoch, watchEpoch: authority.watchInstallationEpoch,
            studyID: OwnerPracticePolicy.studyID, policyVersion: OwnerPracticePolicy.version,
            policyDigest: authority.policyDigest, authorityDigest: RecordingChunkCodec.digest(authorityBytes),
            authorityRevision: authority.revision, consentGeneration: authority.consentGeneration,
            withdrawalBarrier: authority.withdrawalBarrier, consentDecisionID: authority.lastDecisionID,
            heartRateConsent: authority.heartRateConsent, practiceID: practiceID,
            recordingID: metadata.recordingID, clockDomainID: metadata.clock.domainID,
            rawMetadataDigest: RecordingChunkCodec.digest(rawMetadataBytes), acquisitionMode: acquisitionMode,
            acceptedSetup: acceptedSetup, generations: generations, playingArm: metadata.playingArm,
            watchWrist: metadata.watchWrist, watchOrientation: metadata.watchOrientation)
        let context = try Self(body: body, rawMetadataBytes: rawMetadataBytes)
        _ = try context.encoded()
        return OwnerContextBinding(context: context, rawMetadataBytes: rawMetadataBytes, authorityBytes: authorityBytes)
    }

    public func encoded() throws -> Data {
        try OwnerCanonical.encode(body, domain: "PSLOwnerContext1", limit: Self.maximumBytes)
    }

    /// Historical inspection always requires the exact accompanying raw metadata bytes.
    /// Current authorization is intentionally not inferred; this returns no publication binding.
    public static func decode(_ bytes: Data, rawMetadataBytes: Data) throws -> Self {
        let body: OwnerContextBody = try OwnerCanonical.decode(bytes, domain: "PSLOwnerContext1",
                                                               limit: maximumBytes)
        return try Self(body: body, rawMetadataBytes: rawMetadataBytes)
    }

    private static func canonicalMetadata(_ bytes: Data) throws -> RecordingMetadata {
        let metadata = try RecordingChunkCodec.decodeMetadata(bytes)
        guard try RecordingChunkCodec.encodeMetadata(metadata) == bytes else { throw OwnerPracticeError.integrity }
        return metadata
    }

    private static func validate(_ body: OwnerContextBody, metadata: RecordingMetadata,
                                  rawMetadataBytes: Data) throws {
        let preferences = body.acceptedSetup.preferences
        let reserve: Int64 = body.heartRateConsent ? 2 : 1
        guard body.schemaVersion == 1, body.studyID == OwnerPracticePolicy.studyID,
              body.policyVersion == OwnerPracticePolicy.version, body.policyDigest == OwnerPracticePolicy.digest,
              body.phoneEpoch != body.watchEpoch,
              body.acceptedSetup.identity.originInstallationEpoch == body.phoneEpoch,
              body.acquisitionMode == acquisitionMode, body.recordingID == metadata.recordingID,
              body.clockDomainID == metadata.clock.domainID,
              body.rawMetadataDigest == RecordingChunkCodec.digest(rawMetadataBytes),
              Self.isDigest(body.authorityDigest),
              (1...(OwnerPracticeIdentity.maximumRevision - reserve)).contains(body.authorityRevision),
              (1...(Int64(OwnerPracticeIdentity.maximumConsentDecisions) - reserve)).contains(body.consentGeneration),
              body.authorityRevision >= body.consentGeneration,
              (0..<body.consentGeneration).contains(body.withdrawalBarrier),
              preferences.intendedDrill == .forehandGroundstroke || preferences.intendedDrill == .backhandGroundstroke,
              metadata.drill == preferences.intendedDrill.rawValue,
              metadata.protocolVersion == RecordingDrill.protocolVersion,
              metadata.handedness == preferences.usualHand,
              metadata.playingArm == preferences.currentRacketArm, body.playingArm == metadata.playingArm,
              body.watchWrist == metadata.watchWrist, body.watchOrientation == metadata.watchOrientation,
              ["Crown left", "Crown right"].contains(body.watchOrientation),
              Set(metadata.streams.map(\.stream)) == Set(RecordingStream.allCases),
              metadata.streams.allSatisfy(\.supported) else {
            throw OwnerPracticeError.invalid("owner context binding")
        }
        // Reconstruct the draft to validate its digest even at internal/directly-constructed boundaries.
        let canonical = try PracticeSetupDraft(originInstallationEpoch: body.phoneEpoch,
            preparationID: body.acceptedSetup.identity.preparationID,
            revision: body.acceptedSetup.identity.revision, preferences: preferences)
        guard canonical == body.acceptedSetup else { throw OwnerPracticeError.integrity }
    }

    private static func isDigest(_ text: String) -> Bool {
        text.utf8.count == 64 && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}

private struct OwnerContextBody: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let ownerID: UUID
    let phoneEpoch: UUID
    let watchEpoch: UUID
    let studyID: String
    let policyVersion: Int
    let policyDigest: String
    let authorityDigest: String
    let authorityRevision: Int64
    let consentGeneration: Int64
    let withdrawalBarrier: Int64
    let consentDecisionID: UUID
    let heartRateConsent: Bool
    let practiceID: UUID
    let recordingID: UUID
    let clockDomainID: UUID
    let rawMetadataDigest: String
    let acquisitionMode: String
    let acceptedSetup: PracticeSetupDraft
    let generations: PracticeSetupGenerations
    let playingArm: PlayingArm
    let watchWrist: PlayingArm
    let watchOrientation: String
}
