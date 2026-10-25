import Foundation
import Testing
@testable import PadelCore

@Suite struct VideoMotionAnnotationTests {
    @Test func newAttemptIsUnclassifiedUnsureAndUnmatched() throws {
        let binding = try videoTestBinding()
        let label = try VideoMotionAnnotation(binding: binding, changedAtUnixSeconds: 1_800_000_001)
        #expect(label.stroke == .unclassified && label.contact == .unsure)
        #expect(label.evidence == .ownerRecall && label.author == .ownerSelf)
        #expect(label.videoRange == nil && label.motionMatch == nil && !label.isDeleted)
        #expect(label.bindingDigest == (try binding.digest))
        #expect(label.sessionID == binding.sessionID && label.recordingID == binding.recordingID)
        #expect(try VideoMotionAnnotation.decode(label.encoded()) == label)
    }

    @Test func mixedAttemptHistoryIsImmutableAndSurvivesRestart() throws {
        let fixture = try RecordingDirectoryFixture(), binding = try videoTestBinding()
        let store = try VideoMotionStore(base: fixture.root)
        let initial = try store.create(binding, authority: ownerTestIdentity())
        let first = try VideoMotionAnnotation(binding: binding, stroke: .forehand, contact: .clean,
            evidence: .audioAndVideo, changedAtUnixSeconds: 1_800_000_001)
        let second = try VideoMotionAnnotation(binding: binding, stroke: .backhand, contact: .mishit,
            evidence: .video, changedAtUnixSeconds: 1_800_000_002)
        let revision = try VideoMotionAnnotation(binding: binding, attemptID: first.attemptID,
            revision: 2, previousDigest: first.digest, stroke: .forehand, contact: .unsure,
            evidence: .video, changedAtUnixSeconds: 1_800_000_003, note: "Corrected after replay")
        let next = try initial.next(annotations: [first, second, revision])
        try store.publish(next, expectedDigest: initial.digest, authority: ownerTestIdentity())
        #expect(try store.read(binding).annotations == [first, second, revision])
        #expect(next.latestAnnotations == [revision, second])
        #expect(throws: (any Error).self) { try next.next(annotations: [revision, second]) }
        store.close()
        let reopened = try VideoMotionStore(base: fixture.root)
        defer { reopened.close() }
        #expect(try reopened.read(binding).annotations == [first, second, revision])
    }

    @Test func staleRevisionForeignBindingAndInventedParentAreRejected() throws {
        let binding = try videoTestBinding(), initial = try VideoMotionSession(binding: binding)
        let first = try VideoMotionAnnotation(binding: binding, changedAtUnixSeconds: 10)
        let current = try initial.next(annotations: [first])
        let conflicting = try VideoMotionAnnotation(binding: binding, attemptID: first.attemptID,
            stroke: .backhand, contact: .mishit, changedAtUnixSeconds: 11)
        let wrongParent = try VideoMotionAnnotation(binding: binding, attemptID: first.attemptID,
            revision: 2, previousDigest: String(repeating: "0", count: 64), changedAtUnixSeconds: 12)
        let foreign = try VideoMotionAnnotation(binding: videoTestBinding(), changedAtUnixSeconds: 10)
        for invalid in [conflicting, wrongParent, foreign] {
            #expect(throws: (any Error).self) { try current.next(annotations: [first, invalid]) }
        }
    }

    @Test func timeMatchingRequiresExplicitDomainsAndMappingRevision() throws {
        let binding = try videoTestBinding()
        let range = try VideoMotionVideoRange(mediaID: UUID(), startSeconds: 2, endSeconds: 3)
        let match = try VideoMotionMatch(clockDomainID: recordingTestClockID,
            startTimestamp: 20, endTimestamp: 21, mappingRevisionID: UUID(), uncertaintySeconds: 0.1)
        let label = try VideoMotionAnnotation(binding: binding, evidence: .video,
            changedAtUnixSeconds: 10, videoRange: range, motionMatch: match)
        #expect(label.motionMatch == match && label.videoRange == range)
        #expect(throws: (any Error).self) {
            try VideoMotionAnnotation(binding: binding, changedAtUnixSeconds: 10, motionMatch: match)
        }
        #expect(throws: (any Error).self) { try VideoMotionVideoRange(mediaID: UUID(), startSeconds: 3, endSeconds: 2) }
        #expect(throws: (any Error).self) {
            try VideoMotionMatch(clockDomainID: UUID(), startTimestamp: .nan, endTimestamp: 2,
                mappingRevisionID: UUID(), uncertaintySeconds: 0)
        }
        #expect(throws: (any Error).self) {
            try VideoMotionMatch(clockDomainID: UUID(), startTimestamp: 1, endTimestamp: 2,
                mappingRevisionID: UUID(), uncertaintySeconds: -1)
        }
    }

    @Test func deletionIsAnAppendOnlyRevisionAndCannotBeSilentlyUndone() throws {
        let binding = try videoTestBinding(), initial = try VideoMotionSession(binding: binding)
        let first = try VideoMotionAnnotation(binding: binding, changedAtUnixSeconds: 10)
        let deleted = try VideoMotionAnnotation(binding: binding, attemptID: first.attemptID,
            revision: 2, previousDigest: first.digest, changedAtUnixSeconds: 11, isDeleted: true)
        let history = try initial.next(annotations: [first, deleted])
        #expect(history.latestAnnotations.isEmpty)
        #expect(history.annotations.count == 2)
        let revived = try VideoMotionAnnotation(binding: binding, attemptID: first.attemptID,
            revision: 3, previousDigest: deleted.digest, changedAtUnixSeconds: 12)
        #expect(throws: (any Error).self) { try history.next(annotations: [first, deleted, revived]) }
    }

    @Test func boundedCanonicalAnnotationsRejectUnknownVersionsAndInvalidText() throws {
        let binding = try videoTestBinding()
        #expect(throws: (any Error).self) {
            try VideoMotionAnnotation(binding: binding, changedAtUnixSeconds: .infinity)
        }
        #expect(throws: (any Error).self) {
            try VideoMotionAnnotation(binding: binding, changedAtUnixSeconds: 1, note: String(repeating: "x", count: 1025))
        }
        #expect(throws: (any Error).self) {
            try VideoMotionAnnotation(binding: binding, changedAtUnixSeconds: 1, note: "invalid\u{0000}text")
        }
        let label = try VideoMotionAnnotation(binding: binding, changedAtUnixSeconds: 1)
        let unknown = try ownerTestResealed(label.encoded(), domain: "PSLVideoMotionAnnotation1") {
            $0["schemaVersion"] = 2
        }
        #expect(throws: (any Error).self) { try VideoMotionAnnotation.decode(unknown) }
        #expect(throws: (any Error).self) { try VideoMotionAnnotation.decode(Data([32]) + label.encoded()) }
        #expect(throws: (any Error).self) {
            try VideoMotionAnnotation.decode(Data(repeating: 0, count: VideoMotionAnnotation.maximumBytes + 1))
        }
    }

    @Test func partialReasonAndClosedRetentionCannotBeRewrittenAsPristine() throws {
        let initial = try VideoMotionSession(binding: videoTestBinding())
        let partial = try initial.next(retention: .partial, interruptionReason: "Tail unavailable")
        let closed = try partial.next(retention: .closed)
        #expect(closed.interruptionReason == "Tail unavailable")
        #expect(throws: (any Error).self) { try closed.next(retention: .reserved) }
        #expect(throws: (any Error).self) { try partial.next(interruptionReason: "Different story") }
        #expect(throws: (any Error).self) { try initial.next(retention: .partial) }
    }
}
