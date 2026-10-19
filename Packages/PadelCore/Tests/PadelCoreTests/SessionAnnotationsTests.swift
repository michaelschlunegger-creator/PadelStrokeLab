import Darwin
import Foundation
import Testing
@testable import PadelCore

struct SessionAnnotationsTests {
    @Test func realRootsTimelineAndAppendOnlyLabels() throws {
        let fixture = try RecordingDirectoryFixture()
        let paths = try RecordingPaths(base: fixture.root)
        let store = try SessionAnnotationsStore(root: paths.notesRoot)
        var timeline = CaptureTimeline(recordingID: recordingTestID, clockDomainID: recordingTestClockID)
        timeline.events.append(try RecordingCaptureEvent(kind: .start, timestamp: 10))
        try store.saveTimeline(timeline)
        #expect(try store.loadTimeline(recordingID: recordingTestID) == timeline)
        #expect(!timeline.terminalTailVerified)
        let label = try RecordingAttemptLabel(recordingID: recordingTestID, attemptID: UUID(), ordinal: 1,
                                             category: .uncertain)
        let revised = try RecordingAttemptLabel(recordingID: recordingTestID, attemptID: label.attemptID,
            ordinal: 1, revision: 2, category: .cleanContact, confidence: .high,
            evidence: .video, clockDomainID: recordingTestClockID, startTimestamp: 10, endTimestamp: 11)
        try store.saveLabels([label], recordingID: recordingTestID)
        try store.saveLabels([label, revised], recordingID: recordingTestID)
        #expect(try store.loadLabels(recordingID: recordingTestID) == [label, revised])
        #expect(!label.isTimeMatched)
        #expect(revised.isTimeMatched)
        #expect(throws: (any Error).self) { try store.saveLabels([revised], recordingID: recordingTestID) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: paths.rawRoot.path).isEmpty)
        #expect(throws: (any Error).self) {
            try store.saveTimeline(CaptureTimeline(recordingID: recordingTestID, clockDomainID: recordingTestClockID))
        }
    }

    @Test func rejectsBadEvidenceIdentityAndLimits() throws {
        #expect(throws: (any Error).self) { try RecordingCaptureEvent(kind: .start, timestamp: .nan) }
        #expect(throws: (any Error).self) {
            try RecordingCaptureEvent(kind: .start, timestamp: 0, detail: String(repeating: "é", count: 65))
        }
        let first = try RecordingCaptureEvent(kind: .start, timestamp: 10)
        #expect(throws: (any Error).self) {
            try CaptureTimeline(recordingID: recordingTestID, clockDomainID: recordingTestClockID,
                                events: [first, first]).validate()
        }
        #expect(throws: (any Error).self) {
            try CaptureTimeline(recordingID: recordingTestID, clockDomainID: recordingTestClockID,
                events: [RecordingCaptureEvent(kind: .start, timestamp: 9)]).validate(metadata: recordingMetadata())
        }
        #expect(throws: (any Error).self) {
            try RecordingAttemptLabel(recordingID: recordingTestID, attemptID: UUID(), ordinal: 1,
                category: .mishit, note: String(repeating: "é", count: 513))
        }
        #expect(throws: (any Error).self) {
            try RecordingAttemptLabel(recordingID: recordingTestID, attemptID: UUID(), ordinal: 1,
                category: .mishit, startTimestamp: 10)
        }
        let fixture = try RecordingDirectoryFixture()
        let paths = try RecordingPaths(base: fixture.root)
        let store = try SessionAnnotationsStore(root: paths.notesRoot)
        try store.saveTimeline(CaptureTimeline(recordingID: recordingTestID, clockDomainID: recordingTestClockID))
        let foreign = try RecordingAttemptLabel(recordingID: recordingTestID, attemptID: UUID(), ordinal: 1,
            category: .mishit, clockDomainID: UUID(), startTimestamp: 10, endTimestamp: 11)
        #expect(throws: (any Error).self) { try store.saveLabels([foreign], recordingID: recordingTestID) }
        let notes = paths.notesRoot.appendingPathComponent(recordingTestID.uuidString)
        let file = notes.appendingPathComponent("capture-events.json")
        var text = try String(contentsOf: file, encoding: .utf8)
        text = text.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":2")
        try Data(text.utf8).write(to: file)
        #expect(throws: (any Error).self) { try store.loadTimeline(recordingID: recordingTestID) }
    }

    @Test func noFollowDescendantsAndCanonicalJSON() throws {
        let fixture = try RecordingDirectoryFixture()
        let paths = try RecordingPaths(base: fixture.root)
        let store = try SessionAnnotationsStore(root: paths.notesRoot)
        let id = UUID()
        try FileManager.default.createSymbolicLink(at: paths.notesRoot.appendingPathComponent(id.uuidString),
                                                  withDestinationURL: paths.rawRoot)
        #expect(throws: (any Error).self) {
            try store.saveTimeline(CaptureTimeline(recordingID: id, clockDomainID: UUID()))
        }
        let timeline = CaptureTimeline(recordingID: recordingTestID, clockDomainID: recordingTestClockID)
        try store.saveTimeline(timeline)
        let file = paths.notesRoot.appendingPathComponent(recordingTestID.uuidString).appendingPathComponent("capture-events.json")
        var bytes = try Data(contentsOf: file)
        bytes.append(32)
        try bytes.write(to: file)
        #expect(throws: (any Error).self) { try store.loadTimeline(recordingID: recordingTestID) }
    }
}
