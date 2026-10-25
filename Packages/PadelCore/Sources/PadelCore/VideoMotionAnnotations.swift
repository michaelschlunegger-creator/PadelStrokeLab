import Foundation

public enum VideoMotionStroke: String, Codable, Sendable { case unclassified, forehand, backhand }
public enum VideoMotionContact: String, Codable, Sendable { case unsure, clean, mishit }
public enum VideoMotionLabelEvidence: String, Codable, Sendable { case ownerRecall, audioAndVideo, video }

public struct VideoMotionVideoRange: Codable, Equatable, Sendable {
    public let mediaID: UUID
    /// Seconds in the identified playable media timeline, not capture-clock or Watch uptime seconds.
    public let startSeconds: Double, endSeconds: Double
    public init(mediaID: UUID, startSeconds: Double, endSeconds: Double) throws {
        self.mediaID = mediaID; self.startSeconds = startSeconds; self.endSeconds = endSeconds
        try validate()
    }
    func validate() throws {
        guard startSeconds.isFinite, endSeconds.isFinite, startSeconds >= 0,
              endSeconds >= startSeconds else { throw VideoMotionError.invalid("video annotation range") }
    }
}

public struct VideoMotionMatch: Codable, Equatable, Sendable {
    public let clockDomainID: UUID
    public let startTimestamp: Double, endTimestamp: Double
    public let mappingRevisionID: UUID
    public let uncertaintySeconds: Double
    public init(clockDomainID: UUID, startTimestamp: Double, endTimestamp: Double,
                mappingRevisionID: UUID, uncertaintySeconds: Double) throws {
        self.clockDomainID = clockDomainID; self.startTimestamp = startTimestamp; self.endTimestamp = endTimestamp
        self.mappingRevisionID = mappingRevisionID; self.uncertaintySeconds = uncertaintySeconds
        try validate()
    }
    func validate() throws {
        guard startTimestamp.isFinite, endTimestamp.isFinite, startTimestamp >= 0,
              endTimestamp >= startTimestamp, uncertaintySeconds.isFinite, uncertaintySeconds >= 0 else {
            throw VideoMotionError.invalid("motion annotation match")
        }
    }
}

/// Owner-authored references only. Raw audio/motion are never rewritten by label edits.
public struct VideoMotionAnnotation: Codable, Equatable, Sendable {
    public static let maximumBytes = 8_192
    private let schemaVersion: Int
    public let sessionID: UUID, recordingID: UUID, attemptID: UUID
    public let bindingDigest: String
    public let revision: Int
    public let previousDigest: String?
    public let stroke: VideoMotionStroke
    public let contact: VideoMotionContact
    public let author: RecordingLabelAuthor
    public let evidence: VideoMotionLabelEvidence
    public let changedAtUnixSeconds: Double
    public let note: String?
    public let videoRange: VideoMotionVideoRange?
    public let motionMatch: VideoMotionMatch?
    public let isDeleted: Bool

    public init(binding: VideoMotionBinding, attemptID: UUID = UUID(), revision: Int = 1,
                previousDigest: String? = nil, stroke: VideoMotionStroke = .unclassified,
                contact: VideoMotionContact = .unsure, evidence: VideoMotionLabelEvidence = .ownerRecall,
                changedAtUnixSeconds: Double, note: String? = nil, videoRange: VideoMotionVideoRange? = nil,
                motionMatch: VideoMotionMatch? = nil, isDeleted: Bool = false) throws {
        schemaVersion = 1; sessionID = binding.sessionID; recordingID = binding.recordingID
        bindingDigest = try binding.digest; self.attemptID = attemptID; self.revision = revision
        self.previousDigest = previousDigest; self.stroke = stroke; self.contact = contact; author = .ownerSelf
        self.evidence = evidence; self.changedAtUnixSeconds = changedAtUnixSeconds; self.note = note
        self.videoRange = videoRange; self.motionMatch = motionMatch; self.isDeleted = isDeleted
        try validate()
    }

    func validate() throws {
        guard schemaVersion == 1, VideoMotionValidation.digest(bindingDigest), (1...256).contains(revision),
              (revision == 1 ? previousDigest == nil : VideoMotionValidation.digest(previousDigest)),
              changedAtUnixSeconds.isFinite, changedAtUnixSeconds >= 0,
              note.map({ VideoMotionValidation.text($0, maximum: 1_024) }) ?? true,
              motionMatch == nil || videoRange != nil else { throw VideoMotionError.invalid("attempt annotation") }
        try videoRange?.validate(); try motionMatch?.validate()
    }

    public func encoded() throws -> Data {
        try validate()
        return try OwnerCanonical.encode(self, domain: "PSLVideoMotionAnnotation1", limit: Self.maximumBytes)
    }
    public static func decode(_ bytes: Data) throws -> Self {
        let value: Self = try OwnerCanonical.decode(bytes, domain: "PSLVideoMotionAnnotation1", limit: maximumBytes)
        try value.validate(); return value
    }
    public var digest: String { get throws { RecordingChunkCodec.digest(try encoded()) } }
}
