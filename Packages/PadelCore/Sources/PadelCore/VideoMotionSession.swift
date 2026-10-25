import Foundation

public enum VideoMotionError: Error, Equatable, Sendable {
    case invalid(String), integrity, conflict, retired, busy, closed, capacity
}

/// Immutable reservation metadata. This is not a live preparation acceptance or capture token.
public struct VideoMotionBinding: Codable, Equatable, Sendable {
    public static let maximumBytes = 16_384
    private let schemaVersion: Int
    public let sessionID: UUID
    public let recordingID: UUID
    public let preparation: OwnerPreparation
    public let createdAtUnixSeconds: Double
    public let appBuild: String
    public var practiceID: UUID { preparation.practiceID }

    public init(sessionID: UUID, recordingID: UUID, preparation: OwnerPreparation,
                createdAtUnixSeconds: Double, appBuild: String) throws {
        schemaVersion = 1; self.sessionID = sessionID; self.recordingID = recordingID
        self.preparation = preparation; self.createdAtUnixSeconds = createdAtUnixSeconds; self.appBuild = appBuild
        try validate()
    }

    func validate() throws {
        guard schemaVersion == 1, createdAtUnixSeconds.isFinite, createdAtUnixSeconds >= 0,
              VideoMotionValidation.text(appBuild, maximum: 128), !appBuild.isEmpty,
              preparation.draft.preferences.captureMode == .videoMotionMixedReferenceV1,
              preparation.draft.preferences.isValidOwnerCaptureIntent else {
            throw VideoMotionError.invalid("video/motion reservation")
        }
        // Reconstruct rather than treating the stored identity as a source of authority.
        let checked = try OwnerPreparation(authority: preparation.authority, practiceID: practiceID,
                                          draft: preparation.draft)
        guard checked == preparation else { throw VideoMotionError.integrity }
        let draft = preparation.draft
        guard try PracticeSetupDraft(originInstallationEpoch: draft.identity.originInstallationEpoch,
            preparationID: draft.identity.preparationID, revision: draft.identity.revision,
            preferences: draft.preferences) == draft else { throw VideoMotionError.integrity }
    }

    func requireCurrent(_ authority: OwnerPracticeIdentity) throws {
        try validate()
        guard authority.isCollectionAllowed, try preparation.identity.matches(authority) else {
            throw OwnerPracticeError.staleAuthority
        }
    }

    func requireSameOwner(_ authority: OwnerPracticeIdentity) throws {
        try validate()
        let identity = preparation.identity
        guard identity.ownerID == authority.ownerID,
              identity.phoneEpoch == authority.phoneInstallationEpoch,
              identity.watchEpoch == authority.watchInstallationEpoch else { throw VideoMotionError.integrity }
    }

    public func encoded() throws -> Data {
        try validate()
        return try OwnerCanonical.encode(self, domain: "PSLVideoMotionBinding1", limit: Self.maximumBytes)
    }
    public static func decode(_ bytes: Data) throws -> Self {
        let value: Self = try OwnerCanonical.decode(bytes, domain: "PSLVideoMotionBinding1", limit: maximumBytes)
        try value.validate(); return value
    }
    public var digest: String { get throws { RecordingChunkCodec.digest(try encoded()) } }
}

/// Retention bookkeeping only. Closed does not assert media playability, motion coverage or combined success.
public enum VideoMotionRetention: String, Codable, Sendable { case reserved, partial, closed }

/// Canonical snapshots retain all annotation revisions. Native acquisition and timing facts are separate.
public struct VideoMotionSession: Codable, Equatable, Sendable {
    public static let maximumBytes = 524_288
    public static let maximumRevisions = 256
    public static let maximumAnnotations = 512
    private let schemaVersion: Int
    public let binding: VideoMotionBinding
    public let revision: Int
    public let previousDigest: String?
    public let retention: VideoMotionRetention
    public let interruptionReason: String?
    public let annotations: [VideoMotionAnnotation]

    public init(binding: VideoMotionBinding) throws {
        schemaVersion = 1; self.binding = binding; revision = 1; previousDigest = nil
        retention = .reserved; interruptionReason = nil; annotations = []
        try validate()
    }

    private init(binding: VideoMotionBinding, revision: Int, previousDigest: String,
                 retention: VideoMotionRetention, interruptionReason: String?,
                 annotations: [VideoMotionAnnotation]) throws {
        schemaVersion = 1; self.binding = binding; self.revision = revision; self.previousDigest = previousDigest
        self.retention = retention; self.interruptionReason = interruptionReason; self.annotations = annotations
        try validate()
    }

    public func next(retention: VideoMotionRetention? = nil, interruptionReason: String? = nil,
                     annotations: [VideoMotionAnnotation]? = nil) throws -> Self {
        let value = try Self(binding: binding, revision: revision + 1, previousDigest: digest,
            retention: retention ?? self.retention, interruptionReason: interruptionReason ?? self.interruptionReason,
            annotations: annotations ?? self.annotations)
        try value.requireSuccessor(of: self)
        return value
    }

    public var latestAnnotations: [VideoMotionAnnotation] {
        var order: [UUID] = [], latest: [UUID: VideoMotionAnnotation] = [:]
        for value in annotations {
            if latest[value.attemptID] == nil { order.append(value.attemptID) }
            latest[value.attemptID] = value
        }
        return order.compactMap { latest[$0] }.filter { !$0.isDeleted }
    }

    func validate() throws {
        try binding.validate()
        guard schemaVersion == 1, (1...Self.maximumRevisions).contains(revision),
              (revision == 1 ? previousDigest == nil : VideoMotionValidation.digest(previousDigest)),
              annotations.count <= Self.maximumAnnotations,
              interruptionReason.map({ VideoMotionValidation.text($0, maximum: 512) && !$0.isEmpty }) ?? true,
              retention != .partial || interruptionReason != nil,
              retention != .reserved || interruptionReason == nil else { throw VideoMotionError.invalid("session snapshot") }
        if revision == 1 {
            guard annotations.isEmpty, retention == .reserved else { throw VideoMotionError.invalid("initial session") }
        }
        let expected = try binding.digest
        var latest: [UUID: VideoMotionAnnotation] = [:]
        for value in annotations {
            try value.validate()
            guard value.bindingDigest == expected, value.sessionID == binding.sessionID,
                  value.recordingID == binding.recordingID else { throw VideoMotionError.integrity }
            if let previous = latest[value.attemptID] {
                guard !previous.isDeleted, value.revision == previous.revision + 1,
                      try value.previousDigest == previous.digest else { throw VideoMotionError.conflict }
            } else {
                guard value.revision == 1, value.previousDigest == nil, !value.isDeleted else { throw VideoMotionError.conflict }
            }
            latest[value.attemptID] = value
        }
    }

    func requireSuccessor(of previous: Self) throws {
        try validate(); try previous.validate()
        guard binding == previous.binding, revision == previous.revision + 1,
              try previousDigest == previous.digest,
              annotations.starts(with: previous.annotations),
              previous.interruptionReason == nil || interruptionReason == previous.interruptionReason,
              previous.retention != .closed || retention == .closed,
              previous.retention != .partial || retention != .reserved else { throw VideoMotionError.conflict }
    }

    public func encoded() throws -> Data {
        try validate()
        return try OwnerCanonical.encode(self, domain: "PSLVideoMotionSession1", limit: Self.maximumBytes)
    }
    public static func decode(_ bytes: Data) throws -> Self {
        let value: Self = try OwnerCanonical.decode(bytes, domain: "PSLVideoMotionSession1", limit: maximumBytes)
        try value.validate(); return value
    }
    public var digest: String { get throws { RecordingChunkCodec.digest(try encoded()) } }
}

enum VideoMotionValidation {
    static func digest(_ value: String?) -> Bool {
        guard let value else { return false }
        return value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    static func text(_ value: String, maximum: Int) -> Bool {
        value.utf8.count <= maximum && !value.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0) && $0 != "\n"
        }
    }
}
