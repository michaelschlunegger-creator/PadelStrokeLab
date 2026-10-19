import Darwin
import Foundation

public enum RecordingCaptureEventKind: String, Codable, Sendable {
    case start, pauseRequested, paused, resumeRequested, resumed, stopRequested, stopped
    case interruption, bufferOverflow, writeFailure, limitReached
}

public struct RecordingCaptureEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let kind: RecordingCaptureEventKind
    public let timestamp: Double
    public let detail: String?

    public init(kind: RecordingCaptureEventKind, timestamp: Double, detail: String? = nil,
                id: UUID = UUID()) throws {
        self.id = id; self.kind = kind; self.timestamp = timestamp; self.detail = detail
        try validate()
    }

    func validate() throws {
        guard timestamp.isFinite, timestamp >= 0, (detail?.utf8.count ?? 0) <= 128,
              detail?.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) != true else {
            throw RecordingError.invalid("capture event")
        }
    }
}

public struct CaptureTimeline: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let recordingID: UUID
    public let clockDomainID: UUID
    public var events: [RecordingCaptureEvent]
    public let terminalTailVerified: Bool

    public init(recordingID: UUID, clockDomainID: UUID, events: [RecordingCaptureEvent] = []) {
        schemaVersion = 1; self.recordingID = recordingID; self.clockDomainID = clockDomainID
        self.events = events; terminalTailVerified = false
    }

    public func validate(metadata: RecordingMetadata? = nil) throws {
        guard schemaVersion == 1, !terminalTailVerified, events.count <= 512,
              Set(events.map(\.id)).count == events.count else { throw RecordingError.invalid("capture timeline") }
        if let metadata {
            guard recordingID == metadata.recordingID, clockDomainID == metadata.clock.domainID else {
                throw RecordingError.invalid("timeline clock identity")
            }
        }
        var previous = metadata?.clock.monotonicAnchorSeconds ?? 0
        for event in events {
            try event.validate()
            guard event.timestamp >= previous else { throw RecordingError.invalid("timeline order") }
            previous = event.timestamp
        }
    }
}

public enum RecordingLabelConfidence: String, Codable, CaseIterable, Sendable {
    case unspecified, low, medium, high
}
public enum RecordingLabelEvidence: String, Codable, CaseIterable, Sendable {
    case ownerRecall, orderedNotes, video, observer
}
public enum RecordingLabelAuthor: String, Codable, Sendable { case ownerSelf }

public struct RecordingAttemptLabel: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let attemptID: UUID
    public let ordinal: Int
    public let revision: Int
    public let category: ContactCategory
    public let createdAtUnixSeconds: Double
    public var createdAt: Date { Date(timeIntervalSince1970: createdAtUnixSeconds) }
    public let author: RecordingLabelAuthor
    public let confidence: RecordingLabelConfidence
    public let evidence: RecordingLabelEvidence
    public let note: String?
    public let clockDomainID: UUID?
    public let startTimestamp: Double?
    public let endTimestamp: Double?

    public init(id: UUID = UUID(), recordingID: UUID, attemptID: UUID, ordinal: Int,
                revision: Int = 1, category: ContactCategory, createdAt: Date = Date(),
                confidence: RecordingLabelConfidence = .unspecified,
                evidence: RecordingLabelEvidence = .ownerRecall, note: String? = nil,
                clockDomainID: UUID? = nil, startTimestamp: Double? = nil, endTimestamp: Double? = nil) throws {
        self.id = id; self.recordingID = recordingID; self.attemptID = attemptID; self.ordinal = ordinal
        self.revision = revision; self.category = category
        self.createdAtUnixSeconds = createdAt.timeIntervalSince1970; author = .ownerSelf
        self.confidence = confidence; self.evidence = evidence; self.note = note
        self.clockDomainID = clockDomainID; self.startTimestamp = startTimestamp; self.endTimestamp = endTimestamp
        try validate()
    }

    public var isTimeMatched: Bool { startTimestamp != nil && endTimestamp != nil && clockDomainID != nil }

    func validate() throws {
        guard (1...4096).contains(ordinal), (1...4096).contains(revision),
              createdAt.timeIntervalSince1970.isFinite, (note?.utf8.count ?? 0) <= 1024,
              note?.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && $0 != "\n" }) != true else {
            throw RecordingError.invalid("attempt label")
        }
        if let startTimestamp, let endTimestamp, clockDomainID != nil {
            guard startTimestamp.isFinite, endTimestamp.isFinite, startTimestamp >= 0,
                  endTimestamp >= startTimestamp else { throw RecordingError.invalid("label interval") }
        } else if startTimestamp != nil || endTimestamp != nil || clockDomainID != nil {
            throw RecordingError.invalid("incomplete label interval")
        }
    }
}

struct RecordingLabelHistory: Codable {
    let schemaVersion: Int
    let recordingID: UUID
    let labels: [RecordingAttemptLabel]

    func validate(timeline: CaptureTimeline? = nil) throws {
        guard schemaVersion == 1, labels.count <= 4096, Set(labels.map(\.id)).count == labels.count else {
            throw RecordingError.invalid("label history")
        }
        var ordinalOwners: [Int: UUID] = [:]
        var previous: [UUID: RecordingAttemptLabel] = [:]
        for label in labels {
            try label.validate()
            guard label.recordingID == recordingID else { throw RecordingError.invalid("label recording identity") }
            if let clock = label.clockDomainID {
                guard let timeline, clock == timeline.clockDomainID,
                      let first = timeline.events.first, let start = label.startTimestamp,
                      start >= first.timestamp else { throw RecordingError.invalid("label clock identity or origin") }
                if let last = timeline.events.last, last.kind == .stopped,
                   let end = label.endTimestamp, end > last.timestamp {
                    throw RecordingError.invalid("label interval exceeds stopped timeline")
                }
            }
            let old = previous[label.attemptID]
            guard label.revision == (old?.revision ?? 0) + 1,
                  old.map({ $0.ordinal == label.ordinal && $0.createdAt <= label.createdAt }) ?? true,
                  ordinalOwners[label.ordinal].map({ $0 == label.attemptID }) ?? true else {
                throw RecordingError.invalid("label revision or ordinal")
            }
            previous[label.attemptID] = label; ordinalOwners[label.ordinal] = label.attemptID
        }
    }
}

/// Exclusive caller ownership is required. All edits preserve immutable revision prefixes.
public final class SessionAnnotationsStore {
    let rootFD: Int32
    static let timelineLimit = 131_072
    static let labelsLimit = 1_048_576

    public init(root: URL) throws { rootFD = try AnnotationFiles.root(root) }
    deinit { close(rootFD) }

    func read(_ name: String, id: UUID, limit: Int) throws -> Data? {
        let directory: Int32
        do { directory = try AnnotationFiles.directory(id.uuidString, parent: rootFD, create: false) }
        catch RecordingError.io(_, let code) where code == ENOENT { return nil }
        defer { close(directory) }
        return try AnnotationFiles.read(name, directory: directory, limit: limit)
    }

    func save(_ data: Data, name: String, id: UUID) throws {
        let directory = try AnnotationFiles.directory(id.uuidString, parent: rootFD, create: true)
        defer { close(directory) }
        try AnnotationFiles.publish(data, name: name, directory: directory)
    }

    public func loadTimeline(recordingID: UUID) throws -> CaptureTimeline? {
        guard let data = try read("capture-events.json", id: recordingID, limit: Self.timelineLimit) else { return nil }
        let value: CaptureTimeline = try RecordingJSON.decode(data, limit: Self.timelineLimit)
        try value.validate()
        guard value.recordingID == recordingID else { throw RecordingError.invalid("timeline identity") }
        return value
    }

    public func saveTimeline(_ timeline: CaptureTimeline) throws {
        guard flock(rootFD, LOCK_EX) == 0 else { throw AnnotationFiles.error("lock timeline") }
        defer { flock(rootFD, LOCK_UN) }
        try timeline.validate()
        if let previous = try loadTimeline(recordingID: timeline.recordingID) {
            guard previous.clockDomainID == timeline.clockDomainID,
                  timeline.events.starts(with: previous.events) else { throw RecordingError.invalid("timeline history rewrite") }
        }
        try save(RecordingJSON.encode(timeline, limit: Self.timelineLimit), name: "capture-events.json", id: timeline.recordingID)
    }

    public func loadLabels(recordingID: UUID) throws -> [RecordingAttemptLabel] {
        guard let data = try read("labels.json", id: recordingID, limit: Self.labelsLimit) else { return [] }
        let history: RecordingLabelHistory = try RecordingJSON.decode(data, limit: Self.labelsLimit)
        guard history.recordingID == recordingID else { throw RecordingError.invalid("label history identity") }
        try history.validate(timeline: loadTimeline(recordingID: recordingID))
        return history.labels
    }

    public func saveLabels(_ labels: [RecordingAttemptLabel], recordingID: UUID) throws {
        guard flock(rootFD, LOCK_EX) == 0 else { throw AnnotationFiles.error("lock labels") }
        defer { flock(rootFD, LOCK_UN) }
        let history = RecordingLabelHistory(schemaVersion: 1, recordingID: recordingID, labels: labels)
        try history.validate(timeline: loadTimeline(recordingID: recordingID))
        let old = try loadLabels(recordingID: recordingID)
        guard labels.starts(with: old) else { throw RecordingError.invalid("label history rewrite") }
        try save(RecordingJSON.encode(history, limit: Self.labelsLimit), name: "labels.json", id: recordingID)
    }

    func seedLabels(_ labels: [RecordingAttemptLabel], recordingID: UUID) throws {
        guard flock(rootFD, LOCK_EX) == 0 else { throw AnnotationFiles.error("lock label import") }
        defer { flock(rootFD, LOCK_UN) }
        if try read("labels.json", id: recordingID, limit: Self.labelsLimit) != nil {
            _ = try loadLabels(recordingID: recordingID)
            return
        }
        let history = RecordingLabelHistory(schemaVersion: 1, recordingID: recordingID, labels: labels)
        try history.validate(timeline: loadTimeline(recordingID: recordingID))
        try save(RecordingJSON.encode(history, limit: Self.labelsLimit), name: "labels.json", id: recordingID)
    }
}
