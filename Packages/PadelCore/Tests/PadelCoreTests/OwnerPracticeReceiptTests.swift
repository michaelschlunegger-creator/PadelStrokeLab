import Foundation
import Testing
@testable import PadelCore

// Receipt domain OwnerPracticeReceipt1. A decoded/sender/legacy receipt is not local
// proof: lookup/open/export revalidate every retained component. Prepared publication
// owns staging descriptors and applicable leases until cancel or confirmed completion.
// renameForPublication is internal, nonescaping, bounded descriptor-relative work;
// confirmPublication runs outside O8b's authority fence. No public callback gate exists.
// Failure injection below fires only at actual PRE-publication I/O boundaries.

private final class O8CancellationResult: @unchecked Sendable {
    private let lock = NSLock()
    private var result: String?
    func record(_ value: String) { lock.withLock { result = value } }
    var value: String? { lock.withLock { result } }
}

@Suite struct OwnerPracticeReceiptTests {
    @Test func prepareIsPrivateCancelIsSafeAndSourceCanDisappearAfterCompletePreparation() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, receipt) = try source.write()
            let target = try o8Directory(base, "target")
            let reader = try OwnerPracticeReceiptStore(base: target)
            let cancelled = try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: target)
            #expect(cancelled.receipt == receipt)
            #expect(cancelled.scope.practiceID == o6Practice && cancelled.scope.revision == 1)
            #expect(cancelled.scope.inventorySHA256 == receipt.inventorySHA256)
            #expect(try reader.receipt(practiceID: o6Practice, revision: 1) == nil)
            #expect(throws: (any Error).self) { try reader.open(practiceID: o6Practice, revision: 1) }
            cancelled.cancel()
            #expect(throws: (any Error).self) { try cancelled.renameForPublication() }
            let prepared = try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: target)
            try FileManager.default.removeItem(at: bundle)
            try prepared.renameForPublication()
            #expect(try prepared.confirmPublication() == receipt)
            #expect(try reader.receipt(practiceID: o6Practice, revision: 1) == receipt)
        }
    }

    @Test(arguments: [OwnerPracticeBundleStage.rawImported, .inventoryVerified, .stagingSynced])
    func realStagingFailuresWithholdWholeReceiptAndReopenAllowsExactRetry(stage: OwnerPracticeBundleStage) throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, receipt) = try source.write()
            let before = try o6Tree(source.base)
            let target = try o8Directory(base, "target")
            var reached = false
            #expect(throws: O8Injected.stop) {
                try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: target, failureInjector: { boundary in
                    if boundary == stage {
                        reached = true
                        #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: o6Practice, revision: 1) == nil)
                        throw O8Injected.stop
                    }
                })
            }
            #expect(reached)
            let reopened = try OwnerPracticeReceiptStore(base: target)
            #expect(try reopened.receipt(practiceID: o6Practice, revision: 1) == nil)
            #expect(throws: (any Error).self) { try reopened.open(practiceID: o6Practice, revision: 1) }
            #expect(try o8Publish(bundle, to: target) == receipt)
            #expect(try o6Tree(source.base) == before)
        }
    }

    @Test func postRenamePreConfirmationLossReopensAndRetriesByteIdentically() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, receipt) = try source.write()
            let target = try o8Directory(base, "target")
            // Lose the pending handle at the actual rename/confirmation boundary.
            // No confirmPublication or returned success is allowed before reopening.
            var pending = Optional(try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: target))
            try #require(pending).renameForPublication()
            pending = nil
            let reopened = try OwnerPracticeReceiptStore(base: target)
            #expect(try reopened.receipt(practiceID: o6Practice, revision: 1) == receipt)
            let before = try o6Tree(target)
            #expect(try o8Publish(bundle, to: target) == receipt)
            #expect(try o6Tree(target) == before)
            #expect(try reopened.receipt(practiceID: o6Practice, revision: 1) == receipt)
            let export = base.appendingPathComponent("readback.pslpractice")
            #expect(try reopened.exportBundle(practiceID: o6Practice, revision: 1, destination: export) == receipt)
            #expect(try Data(contentsOf: export) == Data(contentsOf: bundle))
            let second = try o8Directory(base, "second")
            #expect(try o8Publish(export, to: second) == receipt)
            #expect(try OwnerPracticeReceiptStore(base: second).open(practiceID: o6Practice, revision: 1).sets.count == 2)
        }
    }

    @Test func labelRevisionIsNewImmutableEvidenceAndEqualRevisionConflictCannotReplaceIt() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (firstURL, first) = try source.write("first.pslpractice")
            let original = try Data(contentsOf: firstURL), rawBefore = try o6Tree(source.paths.rawRoot)
            let target = try o8Directory(base, "target")
            _ = try o8Publish(firstURL, to: target)
            let notes = try SessionAnnotationsStore(root: source.paths.notesRoot), old = source.labels[0][0]
            let revised = try RecordingAttemptLabel(id: o6ID(999_001), recordingID: old.recordingID,
                attemptID: old.attemptID, ordinal: old.ordinal, revision: 2, category: .uncertain,
                createdAt: old.createdAt.addingTimeInterval(1), confidence: .low, evidence: .ownerRecall)
            try notes.saveLabels(source.labels[0] + [revised], recordingID: old.recordingID)
            let (conflictURL, conflict) = try source.write("conflict.pslpractice")
            #expect(conflict.inventorySHA256 != first.inventorySHA256)
            #expect(throws: OwnerPracticeBundleError.conflict) { try o8Publish(conflictURL, to: target) }
            let (secondURL, second) = try source.write("second.pslpractice", revision: 2)
            _ = try o8Publish(secondURL, to: target)
            let reader = try OwnerPracticeReceiptStore(base: target)
            let earlier = try reader.open(practiceID: o6Practice, revision: 1)
            let later = try reader.open(practiceID: o6Practice, revision: 2)
            #expect(first.revision == 1 && second.revision == 2 && first.inventorySHA256 != second.inventorySHA256)
            #expect(try reader.receipt(practiceID: o6Practice, revision: 1) == first)
            #expect(try reader.receipt(practiceID: o6Practice, revision: 2) == second)
            #expect(try SessionAnnotationsStore(root: earlier.notesRoot).loadLabels(recordingID: old.recordingID) == source.labels[0])
            #expect(try SessionAnnotationsStore(root: later.notesRoot).loadLabels(recordingID: old.recordingID) == source.labels[0] + [revised])
            let oldExport = base.appendingPathComponent("old-export.pslpractice")
            _ = try reader.exportBundle(practiceID: o6Practice, revision: 1, destination: oldExport)
            #expect(try Data(contentsOf: oldExport) == original)
            #expect(try o6Tree(source.paths.rawRoot) == rawBefore)
            #expect(throws: (any Error).self) { try source.write("zero.pslpractice", revision: 0) }
            #expect(throws: (any Error).self) { try source.write("negative.pslpractice", revision: -1) }
        }
    }

    @Test func legacyRawReceiptAndCopiedSenderReceiptNeverCertifyOwnerPractice() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, receipt) = try source.write()
            let target = try o8Directory(base, "target"), livePaths = try RecordingPaths(base: target)
            let id = source.contexts[0].recordingID
            let rawURL = base.appendingPathComponent("raw.pslrecording")
            let rawReceipt = try RecordingArchive.write(recordingID: id, rawRoot: source.paths.rawRoot,
                timeline: source.timelines[0], destination: rawURL, labels: source.labels[0])
            _ = try RecordingArchive.importBundle(from: rawURL, rawRoot: livePaths.rawRoot, notesRoot: livePaths.notesRoot)
            #expect(try SessionAnnotationsStore(root: livePaths.notesRoot).loadReceipt(recordingID: id) == rawReceipt)
            let reader = try OwnerPracticeReceiptStore(base: target)
            #expect(try reader.receipt(practiceID: o6Practice, revision: 1) == nil)
            #expect(throws: (any Error).self) { try OwnerPracticeReceipt.decode(RecordingJSON.encode(rawReceipt, limit: 16_384)) }
            #expect(throws: (any Error).self) { try OwnerPracticeBundle.prepareImport(from: rawURL, destinationBase: target) }
            #expect(try OwnerPracticeReceipt.decode(receipt.encoded()) == receipt)
            try receipt.encoded().write(to: target.appendingPathComponent("copied-sender-receipt.json"))
            #expect(try reader.receipt(practiceID: o6Practice, revision: 1) == nil)
            #expect(FileManager.default.fileExists(atPath: bundle.path))
        }
    }

    @Test(arguments: ["raw", "timeline", "labels", "telemetry"])
    func readAndExportRevalidateStoredComponentsInsteadOfTrustingReceipt(component: String) throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, _) = try source.write(), target = try o8Directory(base, "target")
            _ = try o8Publish(bundle, to: target)
            let reader = try OwnerPracticeReceiptStore(base: target)
            let value = try reader.open(practiceID: o6Practice, revision: 1), id = source.contexts[0].recordingID.uuidString
            let path: URL
            switch component {
            case "raw": path = value.rawRoot.appendingPathComponent(id + "/chunk-1-0.bin")
            case "timeline": path = value.notesRoot.appendingPathComponent(id + "/capture-events.json")
            case "labels": path = value.notesRoot.appendingPathComponent(id + "/labels.json")
            default: path = value.directoryURL.appendingPathComponent(OwnerTelemetryStore.directoryName)
                .appendingPathComponent(o6Practice.uuidString.lowercased()).appendingPathComponent("telemetry.json")
            }
            try FileManager.default.removeItem(at: path)
            #expect(throws: (any Error).self) { try reader.open(practiceID: o6Practice, revision: 1) }
            #expect(throws: (any Error).self) { try reader.receipt(practiceID: o6Practice, revision: 1) }
            let export = base.appendingPathComponent("invalid-export.pslpractice")
            #expect(throws: (any Error).self) { try reader.exportBundle(practiceID: o6Practice, revision: 1, destination: export) }
            #expect(!FileManager.default.fileExists(atPath: export.path))
        }
    }

    @Test func detachedDestinationCannotPublishIntoReplacementNamespace() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, _) = try source.write(), target = try o8Directory(base, "target")
            let pending = try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: target)
            let displaced = base.appendingPathComponent("displaced")
            try FileManager.default.moveItem(at: target, to: displaced)
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            #expect(throws: (any Error).self) { try pending.renameForPublication() }
            pending.cancel()
            #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: o6Practice, revision: 1) == nil)
            #expect(try OwnerPracticeReceiptStore(base: displaced).receipt(practiceID: o6Practice, revision: 1) == nil)
        }
    }

    @Test func receiptCanonicalEncodingRejectsRecomputedSemanticAndEncodingAttacks() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source")), (_, receipt) = try source.write()
            let bytes = try receipt.encoded()
            #expect(try OwnerPracticeReceipt.decode(bytes).encoded() == bytes)
            for field in ["schemaVersion", "revision", "byteCount", "inventorySHA256", "bundleSHA256", "unknown"] {
                let bad = try o6RewriteEnvelope(bytes, domain: "OwnerPracticeReceipt1") { body in
                    if field.hasSuffix("SHA256") { body[field] = "not-a-digest" }
                    else if field == "schemaVersion" { body[field] = 2 }
                    else { body[field] = 0 }
                }
                #expect(throws: (any Error).self) { try OwnerPracticeReceipt.decode(bad) }
            }
            #expect(throws: (any Error).self) { try OwnerPracticeReceipt.decode(Data([32]) + bytes) }
            #expect(throws: (any Error).self) { try OwnerPracticeReceipt.decode(Data(bytes.dropLast())) }
        }
    }

    @Test func cancellationClaimsClosedBeforeHeavyCleanupAndRenameRejectsWhileCleanupIsHeld() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, _) = try source.write(), target = try o8Directory(base, "target")
            let pending = try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: target)
            let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
            let cancellation = DispatchGroup(), rename = DispatchGroup(), result = O8CancellationResult()
            // Proposed nil-default INTERNAL seam: fires once after cancel claims closed
            // and cleanup ownership, immediately before its real recursive cleanup/fsync.
            // It cannot replace cleanup or manufacture a publication/authority outcome.
            pending.beforeCancellationCleanup = {
                entered.signal()
                release.wait()
            }
            defer {
                release.signal()
                #expect(cancellation.wait(timeout: .now() + 2) == .success)
                #expect(rename.wait(timeout: .now() + 2) == .success)
            }
            cancellation.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                pending.cancel()
                cancellation.leave()
            }
            try #require(entered.wait(timeout: .now() + 2) == .success)
            rename.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                do { try pending.renameForPublication(); result.record("published") }
                catch OwnerPracticeBundleError.closed { result.record("closed") }
                catch { result.record("unexpected: \(error)") }
                rename.leave()
            }
            // This must finish before cleanup is released, not merely eventually reject.
            let promptRejection = rename.wait(timeout: .now() + 1)
            #expect(promptRejection == .success)
            if promptRejection == .success { #expect(result.value == "closed") }
            #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: o6Practice, revision: 1) == nil)
            release.signal()
            #expect(cancellation.wait(timeout: .now() + 2) == .success)
            #expect(rename.wait(timeout: .now() + 2) == .success)
            #expect(result.value == "closed")
            #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: o6Practice, revision: 1) == nil)
        }
    }
}
