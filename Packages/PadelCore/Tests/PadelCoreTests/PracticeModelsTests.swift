import Foundation
import Testing
@testable import PadelCore

struct PracticeModelsTests {
    private let attemptID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let sessionID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    @Test(arguments: [0, -1])
    func rejectsInvalidAttemptNumber(_ number: Int) {
        #expect(throws: PracticeValidationError.invalidAttemptNumber) {
            try ReferenceLabel(attemptID: attemptID, attemptNumber: number, category: .uncertain)
        }
    }

    @Test(arguments: [0, -1])
    func rejectsInvalidRevision(_ revision: Int) {
        #expect(throws: PracticeValidationError.invalidRevision) {
            try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .cleanContact, revision: revision)
        }
    }

    @Test(arguments: ContactCategory.allCases)
    func preservesCategoryAndSelfAssessment(_ category: ContactCategory) throws {
        let label = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: category)
        let session = try makeSession(labels: [label])
        let restored = try PracticeArchive.decode(PracticeArchive.encode(session))
        #expect(restored == session)
        #expect(restored.labels.first?.origin == .selfAssessment)
        #expect(restored.labels.first?.category == category)
    }

    @Test
    func preservesIdentityDateArmAndUnicodeNote() throws {
        let label = try ReferenceLabel(attemptID: attemptID, attemptNumber: 4, category: .mishit, note: "  Felt off-centre — 左  ")
        let session = try makeSession(labels: [label])
        let result = try PracticeArchive.decode(PracticeArchive.encode(session))
        #expect(result.id == sessionID)
        #expect(result.createdAt == session.createdAt)
        #expect(result.playingArm == .left)
        #expect(result.labels[0].note == "Felt off-centre — 左")
        #expect(result.labels[0].attemptID == attemptID)
        #expect(result.labels[0].id == label.id)
    }

    @Test
    func blankNoteDoesNotChangeUncertainty() throws {
        let label = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .uncertain, note: " \n ")
        #expect(label.note == nil)
        #expect(label.category == .uncertain)
    }

    @Test
    func rejectsOversizedNote() {
        #expect(throws: PracticeValidationError.noteTooLong) {
            try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .uncertain, note: String(repeating: "x", count: 501))
        }
    }

    @Test
    func acceptsNoteAtLimit() throws {
        let label = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .uncertain, note: String(repeating: "x", count: 500))
        #expect(label.note?.count == 500)
    }

    @Test
    func preservesLabelHistoryWithoutMutatingEarlierLabel() throws {
        let first = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .uncertain)
        let second = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .cleanContact, revision: 2)
        let result = try PracticeArchive.decode(PracticeArchive.encode(makeSession(labels: [second, first])))
        #expect(result.labels.map(\.revision) == [1, 2])
        #expect(first.category == .uncertain)
        #expect(result.labels.map(\.category) == [.uncertain, .cleanContact])
    }

    @Test
    func rejectsDuplicateLabelIdentity() throws {
        let label = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .uncertain)
        #expect(throws: PracticeValidationError.duplicateLabelID) {
            try makeSession(labels: [label, label])
        }
    }

    @Test
    func rejectsConflictingRevision() throws {
        let first = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .uncertain)
        let conflicting = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .mishit)
        #expect(throws: PracticeValidationError.duplicateLabelRevision) {
            try makeSession(labels: [first, conflicting])
        }
    }

    @Test
    func rejectsTwoAttemptsWithSameOrdinal() throws {
        let first = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .cleanContact)
        let second = try ReferenceLabel(attemptID: UUID(), attemptNumber: 1, category: .mishit)
        #expect(throws: PracticeValidationError.conflictingAttemptNumber) {
            try makeSession(labels: [first, second])
        }
    }

    @Test
    func rejectsChangedOrdinalAcrossRevisions() throws {
        let first = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .uncertain)
        let second = try ReferenceLabel(attemptID: attemptID, attemptNumber: 2, category: .cleanContact, revision: 2)
        #expect(throws: PracticeValidationError.conflictingAttemptNumber) {
            try makeSession(labels: [first, second])
        }
    }

    @Test
    func deterministicEncodingIgnoresInputLabelOrder() throws {
        let first = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .uncertain)
        let second = try ReferenceLabel(attemptID: UUID(), attemptNumber: 2, category: .cleanContact)
        #expect(try PracticeArchive.encode(makeSession(labels: [first, second])) == PracticeArchive.encode(makeSession(labels: [second, first])))
    }

    @Test
    func rejectsFutureSchema() throws {
        let data = try changedArchive { $0["schemaVersion"] = 2 }
        #expect(throws: PracticeValidationError.unsupportedSchema(2)) { try PracticeArchive.decode(data) }
    }

    @Test
    func rejectsMissingRequiredArm() throws {
        let data = try changedArchive { $0.removeValue(forKey: "playingArm") }
        #expect(throws: (any Error).self) { try PracticeArchive.decode(data) }
    }

    @Test(arguments: ["category", "origin"])
    func rejectsUnknownLabelMeaning(_ key: String) throws {
        let data = try changedArchive { object in
            var labels = object["labels"] as! [[String: Any]]
            labels[0][key] = "unknown-future-value"
            object["labels"] = labels
        }
        #expect(throws: (any Error).self) { try PracticeArchive.decode(data) }
    }

    @Test
    func decoderCannotBypassAttemptValidation() throws {
        let data = try changedArchive { object in
            var labels = object["labels"] as! [[String: Any]]
            labels[0]["attemptNumber"] = 0
            object["labels"] = labels
        }
        #expect(throws: PracticeValidationError.invalidAttemptNumber) { try PracticeArchive.decode(data) }
    }

    @Test
    func rejectsOversizedMetadataBeforeDecoding() {
        let data = Data(repeating: 0, count: PracticeArchive.maximumMetadataBytes + 1)
        #expect(throws: PracticeValidationError.archiveTooLarge) { try PracticeArchive.decode(data) }
    }

    @Test
    func rejectsOversizedEncodedMetadata() throws {
        let labels = try (1...2_200).map { number in
            try ReferenceLabel(attemptID: UUID(), attemptNumber: number, category: .uncertain,
                               note: String(repeating: "x", count: 500))
        }
        let session = try makeSession(labels: labels)
        #expect(throws: PracticeValidationError.archiveTooLarge) { try PracticeArchive.encode(session) }
    }

    @Test(arguments: ["playingArm", "drill"])
    func rejectsUnknownSessionMeaning(_ key: String) throws {
        let data = try changedArchive { $0[key] = "unknown-future-value" }
        #expect(throws: (any Error).self) { try PracticeArchive.decode(data) }
    }

    @Test
    func decoderCannotBypassRevisionValidation() throws {
        let data = try changedArchive { object in
            var labels = object["labels"] as! [[String: Any]]
            labels[0]["revision"] = -1
            object["labels"] = labels
        }
        #expect(throws: PracticeValidationError.invalidRevision) { try PracticeArchive.decode(data) }
    }

    @Test
    func decoderCannotBypassNoteLimit() throws {
        let data = try changedArchive { object in
            var labels = object["labels"] as! [[String: Any]]
            labels[0]["note"] = String(repeating: "x", count: 501)
            object["labels"] = labels
        }
        #expect(throws: PracticeValidationError.noteTooLong) { try PracticeArchive.decode(data) }
    }

    @Test
    func decoderRejectsDuplicateLabelIdentity() throws {
        let data = try changedArchive { object in
            let labels = object["labels"] as! [[String: Any]]
            object["labels"] = labels + labels
        }
        #expect(throws: PracticeValidationError.duplicateLabelID) { try PracticeArchive.decode(data) }
    }

    @Test
    func decoderRejectsConflictingRevision() throws {
        let data = try changedArchive { object in
            let labels = object["labels"] as! [[String: Any]]
            var conflicting = labels[0]
            conflicting["id"] = UUID().uuidString
            conflicting["category"] = "mishit"
            object["labels"] = labels + [conflicting]
        }
        #expect(throws: PracticeValidationError.duplicateLabelRevision) { try PracticeArchive.decode(data) }
    }

    @Test(arguments: [true, false])
    func decoderRejectsConflictingAttemptNumbers(_ sameAttempt: Bool) throws {
        let data = try changedArchive { object in
            let labels = object["labels"] as! [[String: Any]]
            var conflicting = labels[0]
            conflicting["id"] = UUID().uuidString
            if sameAttempt {
                conflicting["revision"] = 2
                conflicting["attemptNumber"] = 2
            } else {
                conflicting["attemptID"] = UUID().uuidString
            }
            object["labels"] = labels + [conflicting]
        }
        #expect(throws: PracticeValidationError.conflictingAttemptNumber) { try PracticeArchive.decode(data) }
    }

    @Test(arguments: ["schemaVersion", "createdAt"])
    func rejectsMissingRequiredMetadata(_ key: String) throws {
        let data = try changedArchive { $0.removeValue(forKey: key) }
        #expect(throws: (any Error).self) { try PracticeArchive.decode(data) }
    }

    @Test
    func rejectsMalformedTimestamp() throws {
        let data = try changedArchive { $0["createdAt"] = "not-a-timestamp" }
        #expect(throws: (any Error).self) { try PracticeArchive.decode(data) }
    }

    @Test(arguments: ["", "null", "{", "[]"])
    func rejectsMalformedArchive(_ json: String) {
        #expect(throws: (any Error).self) { try PracticeArchive.decode(Data(json.utf8)) }
    }

    @Test
    func rejectsNonFiniteDate() {
        #expect(throws: PracticeValidationError.invalidDate) {
            try PracticeSession(createdAt: Date(timeIntervalSince1970: .infinity), playingArm: .right)
        }
    }

    private func makeSession(labels: [ReferenceLabel]) throws -> PracticeSession {
        try PracticeSession(id: sessionID, createdAt: Date(timeIntervalSince1970: 1_792_137_600.5), playingArm: .left, labels: labels)
    }

    private func changedArchive(_ change: (inout [String: Any]) -> Void) throws -> Data {
        let label = try ReferenceLabel(attemptID: attemptID, attemptNumber: 1, category: .uncertain)
        var object = try JSONSerialization.jsonObject(with: PracticeArchive.encode(makeSession(labels: [label]))) as! [String: Any]
        change(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
