import Foundation
import Testing
@testable import PadelCore

// PRIVATE O10p contract proposal; not placed in the repository or executed.
// Proposed bounded API writes a new staged envelope; it does not publish authority:
// OwnerPracticeBundle.writeLabelRevision(from: snapshot, recordingID: id,
//     appending: [RecordingAttemptLabel], revision: Int64, destination: URL)
// -> OwnerPracticeReceipt. It freshly verifies retained source bytes before use.
// Reuses accepted O8 real-store fixtures and the unchanged publication verifier.
@Suite(.serialized) struct OwnerPracticeLabelRevisionTests {
    @Test(arguments: ["included", "absent", "excluded"])
    func bothStrokesAppendImmutableHistoryPreservingOriginalEvidence(mode: String) throws {
        try o6WithDirectory { root in
            let fixture = try O8Fixture(o8Directory(root, "source"), samples: mode != "absent")
            let (originalFile, originalReceipt) = try fixture.write(heartRate: mode == "excluded" ? .excludedByOwner : .asRecorded)
            let originalBytes = try Data(contentsOf: originalFile)
            let originalWire = try o8Wire(originalBytes)
            let destination = try o8Directory(root, "retained")
            let publishedOriginalReceipt = try o8Publish(originalFile, to: destination)
            #expect(publishedOriginalReceipt == originalReceipt)
            let store = try OwnerPracticeReceiptStore(base: destination)
            let original = try store.open(practiceID: originalReceipt.practiceID, revision: 1)
            let originalTree = try o10pFiles(original.directoryURL)
            let originalRaw = try o10pFiles(original.rawRoot)
            var current = original
            for (index, context) in fixture.contexts.enumerated() {
                let id = context.recordingID, revision = Int64(index + 2)
                let old = fixture.labels[index][0]
                let correction = try o10pCorrection(old, category: index == 0 ? .uncertain : .nonStroke)
                let output = root.appendingPathComponent("revision-\(revision).pslpractice")
                let receipt = try OwnerPracticeBundle.writeLabelRevision(from: current, recordingID: id,
                    appending: [correction], revision: revision, destination: output)
                // Writing produces only the envelope: publication still uses the existing verifier.
                #expect(throws: (any Error).self) { try store.open(practiceID: receipt.practiceID, revision: revision) }
                let prepared = try OwnerPracticeBundle.prepareImport(from: output, destinationBase: destination)
                defer { prepared.cancel() }
                #expect(prepared.receipt == receipt)
                #expect(prepared.scope.ownerID == original.scope.ownerID)
                try prepared.renameForPublication()
                let confirmedReceipt = try prepared.confirmPublication()
                #expect(confirmedReceipt == receipt)
                current = try store.open(practiceID: receipt.practiceID, revision: revision)
                #expect(current.receipt == receipt && receipt.revision == revision)
                #expect(receipt.recordingIDs == originalReceipt.recordingIDs)
                #expect(receipt.bundleSHA256 != originalReceipt.bundleSHA256)
                #expect(current.scope.phoneInstallationEpoch == original.scope.phoneInstallationEpoch)
                #expect(current.scope.watchInstallationEpoch == original.scope.watchInstallationEpoch)
                #expect(current.status == original.status && current.heartRate == original.heartRate)
                #expect(current.absenceReasons == original.absenceReasons && current.sets == original.sets)
                let currentRawFiles = try o10pFiles(current.rawRoot)
                #expect(currentRawFiles == originalRaw)
                let notes = try SessionAnnotationsStore(root: current.notesRoot)
                for (setIndex, set) in fixture.contexts.enumerated() {
                    let history = try notes.loadLabels(recordingID: set.recordingID)
                    let additions = setIndex <= index ? [try o10pCorrection(fixture.labels[setIndex][0], category: setIndex == 0 ? .uncertain : .nonStroke)] : []
                    #expect(history == fixture.labels[setIndex] + additions)
                    let retainedTimeline = try notes.loadTimeline(recordingID: set.recordingID)
                    #expect(retainedTimeline == fixture.timelines[setIndex])
                }
                let wire = try o8Wire(Data(contentsOf: output))
                #expect(Set(wire.components.keys) == Set(originalWire.components.keys))
                #expect(wire.components["evidence.json"] == originalWire.components["evidence.json"])
                #expect(wire.components["telemetry.json"] == originalWire.components["telemetry.json"])
                for (setIndex, set) in fixture.contexts.enumerated() {
                    let name = set.recordingID.uuidString.lowercased()
                    #expect(wire.components[name + ".context.json"] == originalWire.components[name + ".context.json"])
                    if setIndex > index {
                        #expect(wire.components[name + ".pslrecording"] == originalWire.components[name + ".pslrecording"])
                    }
                }
                try o10pSameComponentIdentity(originalWire.manifest, wire.manifest)
                if mode == "excluded" {
                    #expect(current.telemetry == nil && wire.components["telemetry.json"] == nil)
                    let retainedEvidence = try #require(wire.components["evidence.json"])
                    #expect(!o8HasHR(retainedEvidence))
                } else {
                    let telemetry = try #require(current.telemetry), prior = try #require(original.telemetry)
                    let currentTelemetryBytes = try telemetry.encoded()
                    let priorTelemetryBytes = try prior.encoded()
                    #expect(currentTelemetryBytes == priorTelemetryBytes)
                    for set in fixture.contexts {
                        let revisedRecovery = try OwnerRecoverySummary.calculate(telemetry: telemetry, recordingID: set.recordingID)
                        let originalRecovery = try OwnerRecoverySummary.calculate(telemetry: prior, recordingID: set.recordingID)
                        #expect(revisedRecovery == originalRecovery)
                    }
                }
                let retainedOriginalBytes = try Data(contentsOf: originalFile)
                #expect(retainedOriginalBytes == originalBytes)
                let retainedOriginalTree = try o10pFiles(original.directoryURL)
                #expect(retainedOriginalTree == originalTree)
                let retainedOriginalReceipt = try store.receipt(practiceID: originalReceipt.practiceID, revision: 1)
                #expect(retainedOriginalReceipt == originalReceipt)
            }
        }
    }

    @Test func rejectsInvalidLabelJoinsHistoryAndNonincreasingRevisionWithoutOutput() throws {
        try o6WithDirectory { root in
            let fixture = try O8Fixture(o8Directory(root, "source"))
            let (file, receipt) = try fixture.write()
            let base = try o8Directory(root, "retained")
            _ = try o8Publish(file, to: base)
            let store = try OwnerPracticeReceiptStore(base: base)
            let snapshot = try store.open(practiceID: receipt.practiceID, revision: 1)
            let before = try o10pFiles(snapshot.directoryURL), old = fixture.labels[0][0]
            let valid = try o10pCorrection(old, category: .mishit)
            let foreign = try RecordingAttemptLabel(recordingID: fixture.contexts[1].recordingID,
                attemptID: UUID(), ordinal: 4, category: .uncertain)
            let wrongClock = try RecordingAttemptLabel(recordingID: old.recordingID, attemptID: UUID(),
                ordinal: 4, category: .uncertain, clockDomainID: UUID(), startTimestamp: 100.5, endTimestamp: 101)
            let skippedHistory = try RecordingAttemptLabel(recordingID: old.recordingID, attemptID: old.attemptID,
                ordinal: old.ordinal, revision: 3, category: .uncertain, createdAt: old.createdAt.addingTimeInterval(1))
            let cases: [(UUID, [RecordingAttemptLabel], Int64)] = [
                (old.recordingID, [foreign], 2), (old.recordingID, [wrongClock], 2),
                (old.recordingID, [skippedHistory], 2), (old.recordingID, [old], 2),
                (UUID(), [valid], 2), (old.recordingID, [valid], 1), (old.recordingID, [valid], 0)
            ]
            for (index, invalid) in cases.enumerated() {
                let output = root.appendingPathComponent("invalid-\(index).pslpractice")
                #expect(throws: (any Error).self) {
                    try OwnerPracticeBundle.writeLabelRevision(from: snapshot, recordingID: invalid.0,
                        appending: invalid.1, revision: invalid.2, destination: output)
                }
                #expect(!FileManager.default.fileExists(atPath: output.path))
                let retainedSourceTree = try o10pFiles(snapshot.directoryURL)
                #expect(retainedSourceTree == before)
                let reopenedOriginalReceipt = try store.open(practiceID: receipt.practiceID, revision: 1).receipt
                #expect(reopenedOriginalReceipt == receipt)
            }
            #expect(throws: (any Error).self) { try store.open(practiceID: receipt.practiceID, revision: 2) }
        }
    }

    @Test func conflictingImmutableRevisionCannotReplacePublishedHistory() throws {
        try o6WithDirectory { root in
            let fixture = try O8Fixture(o8Directory(root, "source"))
            let (file, receipt) = try fixture.write()
            let base = try o8Directory(root, "retained")
            _ = try o8Publish(file, to: base)
            let store = try OwnerPracticeReceiptStore(base: base)
            let snapshot = try store.open(practiceID: receipt.practiceID, revision: 1)
            let before = try o10pFiles(snapshot.directoryURL), old = fixture.labels[0][0]
            let first = root.appendingPathComponent("first.pslpractice"), conflict = root.appendingPathComponent("conflict.pslpractice")
            let accepted = try OwnerPracticeBundle.writeLabelRevision(from: snapshot, recordingID: old.recordingID,
                appending: [o10pCorrection(old, category: .mishit)], revision: 2, destination: first)
            let conflicting = try OwnerPracticeBundle.writeLabelRevision(from: snapshot, recordingID: old.recordingID,
                appending: [o10pCorrection(old, category: .uncertain)], revision: 2, destination: conflict)
            #expect(accepted != conflicting)
            let publishedAcceptedReceipt = try o8Publish(first, to: base)
            #expect(publishedAcceptedReceipt == accepted)
            let published = try store.open(practiceID: receipt.practiceID, revision: 2)
            let publishedTree = try o10pFiles(published.directoryURL)
            #expect(throws: (any Error).self) {
                let prepared = try OwnerPracticeBundle.prepareImport(from: conflict, destinationBase: base)
                defer { prepared.cancel() }
                try prepared.renameForPublication(); _ = try prepared.confirmPublication()
            }
            let reopenedAcceptedReceipt = try store.open(practiceID: receipt.practiceID, revision: 2).receipt
            #expect(reopenedAcceptedReceipt == accepted)
            let retainedPublishedTree = try o10pFiles(published.directoryURL)
            #expect(retainedPublishedTree == publishedTree)
            let retainedSourceTree = try o10pFiles(snapshot.directoryURL)
            #expect(retainedSourceTree == before)
        }
    }

    @Test func retainedSnapshotMustBeReverifiedBeforeLabelReissue() throws {
        try o6WithDirectory { root in
            let fixture = try O8Fixture(o8Directory(root, "source"))
            let (file, receipt) = try fixture.write(heartRate: .excludedByOwner)
            let originalBundle = try Data(contentsOf: file)
            let base = try o8Directory(root, "retained")
            _ = try o8Publish(file, to: base)
            let store = try OwnerPracticeReceiptStore(base: base)
            let snapshot = try store.open(practiceID: receipt.practiceID, revision: 1)
            let evidence = snapshot.directoryURL.appendingPathComponent("components/evidence.json")
            let original = try Data(contentsOf: evidence)
            defer { try? original.write(to: evidence) }
            var corrupted = original; corrupted[corrupted.startIndex] ^= 1
            try corrupted.write(to: evidence)
            let before = try o10pFiles(snapshot.directoryURL)
            let output = root.appendingPathComponent("stale.pslpractice"), old = fixture.labels[0][0]
            #expect(throws: (any Error).self) {
                try OwnerPracticeBundle.writeLabelRevision(from: snapshot, recordingID: old.recordingID,
                    appending: [o10pCorrection(old, category: .uncertain)], revision: 2, destination: output)
            }
            #expect(!FileManager.default.fileExists(atPath: output.path))
            let retainedSourceTree = try o10pFiles(snapshot.directoryURL)
            #expect(retainedSourceTree == before)
            let retainedBundleBytes = try Data(contentsOf: file)
            #expect(retainedBundleBytes == originalBundle)
            #expect(throws: (any Error).self) { try store.open(practiceID: receipt.practiceID, revision: 2) }
        }
    }
}

private func o10pCorrection(_ old: RecordingAttemptLabel, category: ContactCategory) throws -> RecordingAttemptLabel {
    // Stable synthetic identity makes each expected correction independent of serialization.
    let id = UUID(uuidString: old.recordingID == o6ID(10)
        ? "A6201010-0010-4000-8000-000000000001" : "A6201010-0010-4000-8000-000000000002")!
    return try RecordingAttemptLabel(id: id, recordingID: old.recordingID, attemptID: old.attemptID,
        ordinal: old.ordinal, revision: old.revision + 1, category: category, createdAt: old.createdAt.addingTimeInterval(1),
        confidence: .medium, evidence: .orderedNotes, note: "Synthetic repeat label; not independent ground truth",
        clockDomainID: old.clockDomainID, startTimestamp: old.startTimestamp, endTimestamp: old.endTimestamp)
}
private func o10pFiles(_ base: URL) throws -> [String: Data] {
    var result: [String: Data] = [:]
    let enumerator = try #require(FileManager.default.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey]))
    for case let url as URL in enumerator {
        if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            result[String(url.path.dropFirst(base.path.count + 1))] = try Data(contentsOf: url)
        }
    }
    return result
}
private func o10pSameComponentIdentity(_ original: Data, _ revised: Data) throws {
    let originalJSON = try o6JSON(original)
    let a = try #require(originalJSON["body"] as? [String: Any])
    let revisedJSON = try o6JSON(revised)
    let b = try #require(revisedJSON["body"] as? [String: Any])
    let originalEntries = try #require(a["components"] as? [[String: Any]])
    let revisedEntries = try #require(b["components"] as? [[String: Any]])
    #expect(originalEntries.count == revisedEntries.count)
    for (before, after) in zip(originalEntries, revisedEntries) {
        for key in ["name", "schema", "identity"] { #expect(before[key] as? String == after[key] as? String) }
        #expect(before["required"] as? Bool == after["required"] as? Bool)
    }
}
