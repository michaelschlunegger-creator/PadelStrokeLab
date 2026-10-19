import Foundation
import Testing
@testable import PadelCore

private final class TransactionTestErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func append(_ error: any Error) { lock.withLock { values.append(String(describing: error)) } }
    var isEmpty: Bool { lock.withLock { values.isEmpty } }
}

struct RecordingLocalCopiesTests {
    @Test func confirmedWatchDeleteCancelsAndRemovesOnlyAutomaticCopies() async throws {
        let (fixture, paths, timeline, _) = try archiveFixture()
        defer { withExtendedLifetime(fixture) {} }
        let automatic = paths.outboxRoot.appendingPathComponent(recordingTestID.uuidString + "-" + UUID().uuidString + ".pslrecording")
        let receipt = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: automatic)
        try RecordingTransferLedger(root: paths.outboxRoot).save(RecordingTransferRecord(schemaVersion: 1,
            receipt: receipt, fileName: automatic.lastPathComponent, state: .queued))
        let independent = paths.outboxRoot.appendingPathComponent("export-independent.pslrecording")
        try FileManager.default.copyItem(at: automatic, to: independent)
        let partial = paths.outboxRoot.appendingPathComponent(".pending-auto-\(recordingTestID.uuidString)-\(UUID().uuidString)")
        try Data([1, 2, 3]).write(to: partial)
        var lease: RecordingCaptureLease? = try RecordingCaptureLease(recordingID: recordingTestID, rawRoot: paths.rawRoot)
        var cancelled = false
        #expect(throws: (any Error).self) {
            try RecordingLocalCopies.deleteWatchCopy(recordingID: recordingTestID, paths: paths, cancelTransfers: { cancelled = true })
        }
        #expect(!cancelled)
        #expect(FileManager.default.fileExists(atPath: automatic.path))
        withExtendedLifetime(lease) {}
        lease = nil
        let connectivity = RecordingConnectivity(paths: paths)
        let outcome = await withCheckedContinuation { continuation in
            connectivity.deleteWatchCopy(recordingID: recordingTestID) { continuation.resume(returning: $0) }
        }
        try outcome.get()
        #expect(!FileManager.default.fileExists(atPath: automatic.path))
        #expect(!FileManager.default.fileExists(atPath: partial.path))
        #expect(FileManager.default.fileExists(atPath: independent.path))
        #expect(try RecordingTransferLedger(root: paths.outboxRoot).load(recordingTestID) == nil)
        #expect(!FileManager.default.fileExists(atPath: paths.rawRoot.appendingPathComponent(recordingTestID.uuidString).path))
        #expect(throws: RecordingLocalCopyError.deletedOnWatch) {
            try RecordingLocalTransaction(recordingID: recordingTestID, notesRoot: paths.notesRoot).requireAvailable()
        }
        connectivity.queue(recordingID: recordingTestID, timeline: timeline)
        let state = await withCheckedContinuation { continuation in
            connectivity.status(recordingID: recordingTestID) { continuation.resume(returning: $0) }
        }
        #expect(state == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: paths.outboxRoot.path) == [independent.lastPathComponent])
    }

    @Test func activeCaptureLeaseRejectsExportUntilReleased() throws {
        let (fixture, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(fixture) {} }
        var capture: RecordingCaptureLease? = try RecordingCaptureLease(recordingID: recordingTestID, rawRoot: paths.rawRoot)
        #expect(throws: (any Error).self) {
            try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: bundle)
        }
        #expect(!FileManager.default.fileExists(atPath: bundle.path))
        withExtendedLifetime(capture) {}
        capture = nil
        let receipt = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: bundle)
        #expect(receipt.streams.map(\.sampleCount) == [2, 2])
    }

    @Test func deletionWaitsForImportThenWithholdsAckAndPreventsResurrection() throws {
        let (source, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(source) {} }
        let receipt = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: bundle)
        let fixture = try RecordingDirectoryFixture()
        let target = try RecordingPaths(base: fixture.root)
        _ = try RecordingArchive.importBundle(from: bundle, rawRoot: target.rawRoot, notesRoot: target.notesRoot)
        let notes = try SessionAnnotationsStore(root: target.notesRoot)
        let label = try RecordingAttemptLabel(recordingID: recordingTestID, attemptID: UUID(), ordinal: 1, category: .mishit)
        try notes.saveLabels([label], recordingID: recordingTestID)
        let incoming = try RecordingLocalCopies.copyIncoming(bundle, recordingID: recordingTestID, paths: target)
        let atReceipt = DispatchSemaphore(value: 0)
        let releaseImport = DispatchSemaphore(value: 0)
        let deleteContended = DispatchSemaphore(value: 0)
        let importFinished = DispatchSemaphore(value: 0)
        let deleteFinished = DispatchSemaphore(value: 0)
        let errors = TransactionTestErrors()
        DispatchQueue.global().async {
            defer { importFinished.signal() }
            do {
                _ = try RecordingArchive.importBundle(from: incoming, rawRoot: target.rawRoot, notesRoot: target.notesRoot,
                    beforeReceipt: {
                        atReceipt.signal()
                        guard releaseImport.wait(timeout: .now() + 10) == .success else { throw RecordingError.closed }
                    })
            } catch { errors.append(error) }
        }
        #expect(atReceipt.wait(timeout: .now() + 10) == .success)
        DispatchQueue.global().async {
            defer { deleteFinished.signal() }
            do {
                try RecordingLocalCopies.deletePhoneCopy(recordingID: recordingTestID, paths: target,
                                                         onContention: { deleteContended.signal() })
            } catch { errors.append(error) }
        }
        // This signal is emitted only after the real transaction lock reports EWOULDBLOCK.
        #expect(deleteContended.wait(timeout: .now() + 10) == .success)
        #expect(try notes.loadLabels(recordingID: recordingTestID) == [label])
        #expect(FileManager.default.fileExists(atPath: target.rawRoot.appendingPathComponent(recordingTestID.uuidString).path))
        releaseImport.signal()
        #expect(importFinished.wait(timeout: .now() + 10) == .success)
        #expect(deleteFinished.wait(timeout: .now() + 10) == .success)
        #expect(errors.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: target.rawRoot.appendingPathComponent(recordingTestID.uuidString).path))
        #expect(!FileManager.default.fileExists(atPath: incoming.path))
        var acknowledged = false
        #expect(throws: RecordingLocalCopyError.deletedOnPhone) {
            try RecordingLocalCopies.withVerifiedReceipt(receipt, paths: target) { acknowledged = true }
        }
        #expect(!acknowledged)
        #expect(throws: RecordingLocalCopyError.deletedOnPhone) {
            try RecordingArchive.importBundle(from: bundle, rawRoot: target.rawRoot, notesRoot: target.notesRoot)
        }
        #expect(throws: RecordingLocalCopyError.deletedOnPhone) {
            try RecordingLocalCopies.copyIncoming(bundle, recordingID: recordingTestID, paths: target)
        }
        #expect(try notes.loadReceipt(recordingID: recordingTestID) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.inboxRoot.path).isEmpty)
        #expect(try RecordingStore.inspect(root: paths.rawRoot, recordingID: recordingTestID).status == .finalized)
        #expect(FileManager.default.fileExists(atPath: bundle.path))
    }

    @Test func verifiedIncomingCleanupAndDeletionRemoveFailedPrivateCopies() throws {
        let (source, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(source) {} }
        _ = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: bundle)
        let fixture = try RecordingDirectoryFixture()
        let target = try RecordingPaths(base: fixture.root)
        let incoming = try RecordingLocalCopies.copyIncoming(bundle, recordingID: recordingTestID, paths: target)
        let receipt = try RecordingArchive.importBundle(from: incoming, rawRoot: target.rawRoot, notesRoot: target.notesRoot)
        try RecordingLocalCopies.withVerifiedReceipt(receipt, paths: target) {
            try RecordingLocalCopies.removeIncomingCopy(incoming, recordingID: recordingTestID, paths: target)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.inboxRoot.path).isEmpty)
        let failed = try RecordingLocalCopies.copyIncoming(bundle, recordingID: recordingTestID, paths: target)
        #expect(throws: RecordingError.closed) {
            try RecordingArchive.importBundle(from: failed, rawRoot: target.rawRoot, notesRoot: target.notesRoot,
                                              beforeReceipt: { throw RecordingError.closed })
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.rawRoot.path).contains { $0.hasPrefix(".incoming-") })
        let exported = target.outboxRoot.appendingPathComponent("independent-export.pslrecording")
        try FileManager.default.copyItem(at: bundle, to: exported)
        let foreignStage = target.rawRoot.appendingPathComponent(".incoming-\(UUID().uuidString)-\(UUID().uuidString)")
        // An unrelated in-flight import may disappear at any moment. Do not even open it.
        try FileManager.default.createSymbolicLink(at: foreignStage, withDestinationURL: target.rawRoot.appendingPathComponent("unrelated-gone"))
        try RecordingLocalCopies.deletePhoneCopy(recordingID: recordingTestID, paths: target)
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.inboxRoot.path).isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.rawRoot.path).filter { $0.hasPrefix(".incoming-") } == [foreignStage.lastPathComponent])
        #expect(FileManager.default.fileExists(atPath: exported.path))
        #expect(throws: RecordingLocalCopyError.deletedOnPhone) {
            try RecordingArchive.importBundle(from: bundle, rawRoot: target.rawRoot, notesRoot: target.notesRoot)
        }
    }
}
