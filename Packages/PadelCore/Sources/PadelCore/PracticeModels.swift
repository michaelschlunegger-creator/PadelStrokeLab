import Foundation

public enum PlayingArm: String, Codable, CaseIterable, Identifiable, Sendable {
    case left, right
    public var id: String { rawValue }
    public var title: String { self == .left ? "Left" : "Right" }
}

public enum PracticeDrill: String, Codable, Sendable {
    case forehandGroundstroke
    public var title: String { "Forehand groundstroke" }
}

public enum ContactCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case cleanContact, mishit, uncertain, airSwing, nonStroke

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .cleanContact: "Clean contact"
        case .mishit: "Mishit"
        case .uncertain: "Uncertain"
        case .airSwing: "Air swing"
        case .nonStroke: "Other movement"
        }
    }
}

public enum LabelOrigin: String, Codable, Sendable {
    case selfAssessment
}

public enum PracticeValidationError: Error, Equatable, Sendable {
    case invalidAttemptNumber
    case invalidRevision
    case noteTooLong
    case invalidDate
    case duplicateLabelID
    case duplicateLabelRevision
    case conflictingAttemptNumber
    case unsupportedSchema(Int)
    case archiveTooLarge
}

/// A player's reference judgement, separate from any sensor observation or score.
public struct ReferenceLabel: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let attemptID: UUID
    public let attemptNumber: Int
    public let category: ContactCategory
    public let revision: Int
    public let origin: LabelOrigin
    public let note: String?

    public init(
        id: UUID = UUID(), attemptID: UUID, attemptNumber: Int,
        category: ContactCategory, revision: Int = 1,
        origin: LabelOrigin = .selfAssessment, note: String? = nil
    ) throws {
        guard attemptNumber > 0 else { throw PracticeValidationError.invalidAttemptNumber }
        guard revision > 0 else { throw PracticeValidationError.invalidRevision }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed?.count ?? 0) <= 500 else { throw PracticeValidationError.noteTooLong }
        self.id = id
        self.attemptID = attemptID
        self.attemptNumber = attemptNumber
        self.category = category
        self.revision = revision
        self.origin = origin
        self.note = trimmed?.isEmpty == false ? trimmed : nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, attemptID, attemptNumber, category, revision, origin, note
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(UUID.self, forKey: .id),
            attemptID: c.decode(UUID.self, forKey: .attemptID),
            attemptNumber: c.decode(Int.self, forKey: .attemptNumber),
            category: c.decode(ContactCategory.self, forKey: .category),
            revision: c.decode(Int.self, forKey: .revision),
            origin: c.decode(LabelOrigin.self, forKey: .origin),
            note: c.decodeIfPresent(String.self, forKey: .note)
        )
    }
}

/// Practice metadata only. Its existence does not imply that motion was recorded.
public struct PracticeSession: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public let createdAt: Date
    public let playingArm: PlayingArm
    public let drill: PracticeDrill
    public let labels: [ReferenceLabel]

    public init(
        id: UUID = UUID(), createdAt: Date = Date(), playingArm: PlayingArm,
        drill: PracticeDrill = .forehandGroundstroke, labels: [ReferenceLabel] = []
    ) throws {
        guard createdAt.timeIntervalSince1970.isFinite else { throw PracticeValidationError.invalidDate }
        var labelIDs = Set<UUID>()
        var revisions: [UUID: Set<Int>] = [:]
        var numberByAttempt: [UUID: Int] = [:]
        var attemptByNumber: [Int: UUID] = [:]
        for label in labels {
            guard labelIDs.insert(label.id).inserted else { throw PracticeValidationError.duplicateLabelID }
            guard revisions[label.attemptID, default: []].insert(label.revision).inserted else {
                throw PracticeValidationError.duplicateLabelRevision
            }
            if let existing = numberByAttempt[label.attemptID], existing != label.attemptNumber {
                throw PracticeValidationError.conflictingAttemptNumber
            }
            if let existing = attemptByNumber[label.attemptNumber], existing != label.attemptID {
                throw PracticeValidationError.conflictingAttemptNumber
            }
            numberByAttempt[label.attemptID] = label.attemptNumber
            attemptByNumber[label.attemptNumber] = label.attemptID
        }
        schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.createdAt = createdAt
        self.playingArm = playingArm
        self.drill = drill
        self.labels = labels.sorted {
            $0.attemptNumber == $1.attemptNumber ? $0.revision < $1.revision : $0.attemptNumber < $1.attemptNumber
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, createdAt, playingArm, drill, labels
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.currentSchemaVersion else { throw PracticeValidationError.unsupportedSchema(version) }
        try self.init(
            id: c.decode(UUID.self, forKey: .id),
            createdAt: c.decode(Date.self, forKey: .createdAt),
            playingArm: c.decode(PlayingArm.self, forKey: .playingArm),
            drill: c.decode(PracticeDrill.self, forKey: .drill),
            labels: c.decode([ReferenceLabel].self, forKey: .labels)
        )
    }
}
