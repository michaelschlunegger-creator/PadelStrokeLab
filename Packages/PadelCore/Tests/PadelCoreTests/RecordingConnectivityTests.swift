import Foundation
import Testing
@testable import PadelCore

private final class BackgroundStateFixture: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = true
    private var results: [Bool] = []
    let observed = DispatchSemaphore(value: 0)
    let completed = DispatchSemaphore(value: 0)
    func state() -> RecordingBackgroundState {
        let value = lock.withLock { pending }
        observed.signal()
        return RecordingBackgroundState(activated: true, hasContentPending: value)
    }
    func setPending(_ value: Bool) { lock.withLock { pending = value } }
    func finish(_ value: Bool) { lock.withLock { results.append(value) }; completed.signal() }
    var values: [Bool] { lock.withLock { results } }
}

struct RecordingConnectivityTests {
    @Test func activationResumeRejectsTombstoneWhenCrashLeftQueuedOutbox() throws {
        let (fixture, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(fixture) {} }
        let receipt = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: bundle)
        let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
        let record = RecordingTransferRecord(schemaVersion: 1, receipt: receipt, fileName: bundle.lastPathComponent, state: .queued)
        try ledger.save(record)
        do {
            let transaction = try RecordingLocalTransaction(recordingID: recordingTestID, notesRoot: paths.notesRoot)
            try transaction.markDeleted(device: "watch")
        }
        let originalLedger = try Data(contentsOf: paths.outboxRoot.appendingPathComponent(recordingTestID.uuidString + ".transfer.json"))
        var sent = false
        for pending in try ledger.all() {
            #expect(throws: RecordingLocalCopyError.deletedOnWatch) {
                try RecordingTransferLedger.withResumeAuthorization(pending, notesRoot: paths.notesRoot) { sent = true }
            }
        }
        #expect(!sent)
        #expect(try Data(contentsOf: paths.outboxRoot.appendingPathComponent(recordingTestID.uuidString + ".transfer.json")) == originalLedger)
        #expect(try Data(contentsOf: bundle).count == receipt.byteCount)
    }

    @Test func backgroundDrainRequiresFrameworkAndRealOwnerQueueToDrain() throws {
        let fixture = try RecordingDirectoryFixture()
        let paths = try RecordingPaths(base: fixture.root)
        let state = BackgroundStateFixture()
        let connectivity = RecordingConnectivity(paths: paths, backgroundStateProvider: { state.state() }, backgroundTimeout: 5)
        let unblock = DispatchSemaphore(value: 0)
        #expect(connectivity.submit(id: nil) { _ = unblock.wait(timeout: .now() + 5) })
        let drain = connectivity.drainForBackground { state.finish($0) }
        #expect(state.completed.wait(timeout: .now()) == .timedOut)
        unblock.signal()
        #expect(state.observed.wait(timeout: .now() + 3) == .success)
        #expect(state.completed.wait(timeout: .now()) == .timedOut)
        state.setPending(false)
        #expect(state.completed.wait(timeout: .now() + 3) == .success)
        #expect(state.values == [true])
        connectivity.cancelBackgroundDrain(drain)
        #expect(state.values == [true])
    }

    @Test func backgroundCancellationAndDeadlineCompleteOnceAndRetainPendingData() throws {
        let (fixture, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(fixture) {} }
        let receipt = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: bundle)
        let state = BackgroundStateFixture()
        let connectivity = RecordingConnectivity(paths: paths, backgroundStateProvider: { state.state() }, backgroundTimeout: 0.05)
        let cancelled = connectivity.drainForBackground { state.finish($0) }
        connectivity.cancelBackgroundDrain(cancelled)
        connectivity.cancelBackgroundDrain(cancelled)
        #expect(state.completed.wait(timeout: .now() + 1) == .success)
        #expect(state.values == [false])
        _ = connectivity.drainForBackground { state.finish($0) }
        #expect(state.completed.wait(timeout: .now() + 2) == .success)
        #expect(state.values == [false, false])
        #expect(try Data(contentsOf: bundle).count == receipt.byteCount)
        #expect(try RecordingStore.inspect(root: paths.rawRoot, recordingID: recordingTestID).status == .finalized)
    }

    @Test func boundedWorkAdmissionRejectsSeventeenthJobUntilDrain() throws {
        let fixture = try RecordingDirectoryFixture()
        let paths = try RecordingPaths(base: fixture.root)
        let connectivity = RecordingConnectivity(paths: paths)
        let gate = DispatchSemaphore(value: 0)
        let completed = DispatchGroup()
        completed.enter()
        #expect(connectivity.submit(id: nil) { _ = gate.wait(timeout: .now() + 10); completed.leave() })
        for _ in 0..<15 {
            completed.enter()
            #expect(connectivity.submit(id: nil) { completed.leave() })
        }
        #expect(!connectivity.submit(id: nil) {})
        gate.signal()
        #expect(completed.wait(timeout: .now() + 10) == .success)
        #expect(connectivity.submit(id: nil) {})
    }
    @Test func transportCompletionNeverVerifiesAndOnlyMatchingReceiptPersists() throws {
        let (fixture, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(fixture) {} }
        let receipt = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot,
                                                 timeline: timeline, destination: bundle)
        let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
        try ledger.save(RecordingTransferRecord(schemaVersion: 1, receipt: receipt,
            fileName: bundle.lastPathComponent, state: .queued))
        #expect(try ledger.all().count == 1)
        #expect(try ledger.transition(recordingTestID, to: .transferring).state == .transferring)
        #expect(try ledger.transition(recordingTestID, to: .sent).state == .sent)
        #expect(throws: (any Error).self) { try ledger.transition(recordingTestID, to: .verified) }
        #expect(throws: (any Error).self) { try ledger.acknowledge(id: UUID(), digest: receipt.bundleSHA256) }
        #expect(throws: (any Error).self) { try ledger.acknowledge(id: recordingTestID, digest: String(repeating: "a", count: 64)) }
        #expect(try ledger.load(recordingTestID)?.state == .sent)
        #expect(try ledger.acknowledge(id: recordingTestID, digest: receipt.bundleSHA256).state == .verified)
        #expect(try ledger.acknowledge(id: recordingTestID, digest: receipt.bundleSHA256).state == .verified)
        let reopened = try RecordingTransferLedger(root: paths.outboxRoot)
        #expect(try reopened.load(recordingTestID)?.state == .verified)
        #expect(try reopened.transition(recordingTestID, to: .sent).state == .verified)
    }

    @Test func failedRetryRetainsImmutablePayloadAndUnknownReceiptRejected() throws {
        let (fixture, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(fixture) {} }
        let receipt = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot,
                                                 timeline: timeline, destination: bundle)
        let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
        let record = RecordingTransferRecord(schemaVersion: 1, receipt: receipt,
            fileName: bundle.lastPathComponent, state: .queued)
        try ledger.save(record)
        _ = try ledger.transition(recordingTestID, to: .failed, detail: "Synthetic offline error")
        let queued = try ledger.transition(recordingTestID, to: .queued)
        #expect(queued.receipt == receipt)
        #expect(queued.fileName == record.fileName)
        #expect(try RecordingStore.inspect(root: paths.rawRoot, recordingID: recordingTestID).status == .finalized)
        #expect(try Data(contentsOf: bundle).count == receipt.byteCount)
    }

    @Test func transportMetadataMismatchCannotInstallOrAcknowledge() throws {
        let (fixture, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(fixture) {} }
        _ = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot,
                                      timeline: timeline, destination: bundle)
        let target = try RecordingDirectoryFixture()
        let destination = try RecordingPaths(base: target.root)
        #expect(throws: (any Error).self) {
            try RecordingArchive.importBundle(from: bundle, rawRoot: destination.rawRoot, notesRoot: destination.notesRoot,
                expectedIdentity: UUID(), beforeReceipt: {})
        }
        #expect(throws: (any Error).self) {
            try RecordingArchive.importBundle(from: bundle, rawRoot: destination.rawRoot, notesRoot: destination.notesRoot,
                expectedDigest: String(repeating: "a", count: 64), beforeReceipt: {})
        }
        #expect(!FileManager.default.fileExists(atPath: destination.rawRoot.appendingPathComponent(recordingTestID.uuidString).path))
        #expect(try SessionAnnotationsStore(root: destination.notesRoot).loadReceipt(recordingID: recordingTestID) == nil)
    }

    @Test func realQueuePersistsArchiveAndExplicitRetryReusesIt() async throws {
        let (fixture, paths, timeline, _) = try archiveFixture()
        defer { withExtendedLifetime(fixture) {} }
        let connectivity = RecordingConnectivity(paths: paths)
        connectivity.queue(recordingID: recordingTestID, timeline: timeline)
        let first = await withCheckedContinuation { continuation in
            connectivity.status(recordingID: recordingTestID) { continuation.resume(returning: $0) }
        }
        #expect(first?.state == .queued)
        let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
        let before = try #require(try ledger.load(recordingTestID))
        connectivity.queue(recordingID: recordingTestID, timeline: timeline)
        let next = await withCheckedContinuation { continuation in
            connectivity.status(recordingID: recordingTestID) { continuation.resume(returning: $0) }
        }
        #expect(next?.state == .queued)
        #expect(try ledger.load(recordingTestID)?.fileName == before.fileName)
        #expect(try ledger.load(recordingTestID)?.receipt == before.receipt)
    }
}
