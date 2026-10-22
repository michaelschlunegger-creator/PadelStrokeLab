import Darwin
import Foundation
import Testing
@testable import PadelCore

// O8b tests-first interfaces live on the existing RecordingConnectivity owner.
// The adapter replaces WC file/receipt delivery only. Native delegate callbacks must
// use the same receivePracticeFile / receiveUserInfo paths exercised below.
// No O9 deletion implementation is assumed here; its tombstone/cleanup races remain O9.
@Suite(.serialized) struct OwnerPracticeTransferTests {
    @Test(arguments: [false, true])
    func offlineWholePracticeQueueSurvivesRestartAndKeepsOriginals(heartRate: Bool) async throws {
        try await o8bWithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"), heartRate: heartRate)
            let (bundle, receipt) = try source.write(), link = O8BFileLink()
            let first = o8bConnection(source.paths, link: link)
            first.queuePractice(from: bundle)
            _ = try await o8bWait(first, receipt, state: .queued)
            #expect(link.files.isEmpty)
            #expect(try o8bSourceRetained(source, bundle: bundle))

            let restarted = o8bConnection(source.paths, link: link)
            link.available = true
            restarted.resumePracticeTransfers()
            _ = try await o8bWait(restarted, receipt, state: .transferring)
            let sent = try #require(link.files.first)
            #expect(sent.metadata["kind"] == "PSLOwnerPractice1")
            #expect(sent.metadata["practiceID"] == receipt.practiceID.uuidString)
            #expect(sent.metadata["revision"] == String(receipt.revision))
            #expect(sent.metadata["sha256"] == receipt.bundleSHA256)
            #expect(try Data(contentsOf: sent.url) == Data(contentsOf: bundle))
            sent.complete(.success(()))
            _ = try await o8bWait(restarted, receipt, state: .sent)
            #expect(try o8bSourceRetained(source, bundle: bundle))
        }
    }

    @Test(arguments: [false, true])
    func onlyExactFullReceiptAcknowledgesWholeInventoryAndLostAckCanReplay(interrupted: Bool) async throws {
        try await o8bWithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"), interrupted: interrupted)
            let (bundle, receipt) = try source.write(), outgoing = O8BFileLink(available: true)
            let sender = o8bConnection(source.paths, link: outgoing)
            sender.queuePractice(from: bundle)
            _ = try await o8bWait(sender, receipt, state: .transferring)
            let file = try #require(outgoing.files.first)
            file.complete(.success(()))
            _ = try await o8bWait(sender, receipt, state: .sent)

            let target = try o8Directory(base, "phone"), acknowledgments = O8BFileLink(available: true)
            let receiver = o8bConnection(try RecordingPaths(base: target), link: acknowledgments)
            receiver.onOwnerPracticePublication = { prepared in
                try prepared.renameForPublication()
                return try prepared.confirmPublication()
            }
            #expect(try await o8bReceive(receiver, file: file) == receipt)
            let stored = try OwnerPracticeReceiptStore(base: target).open(practiceID: receipt.practiceID, revision: receipt.revision)
            #expect(stored.receipt == receipt)
            #expect(stored.status == (interrupted ? .interrupted : .ended))
            #expect(stored.sets.map(\.context.recordingID) == source.contexts.map(\.recordingID))
            #expect(acknowledgments.receipts.count == 1)
            #expect(await o8bStatus(sender, receipt)?.state == .sent, "Transport success and a lost acknowledgment are not verified.")

            sender.receiveUserInfo(["kind": "PSLReceipt1", "recordingID": source.contexts[0].recordingID.uuidString,
                                    "sha256": receipt.bundleSHA256])
            sender.receiveUserInfo(["kind": "PSLOwnerPracticeReceipt1", "payload": Data("invalid".utf8)])
            #expect(await o8bStatus(sender, receipt)?.state == .sent)
            // Restart the sender after the receiver durably committed but its acknowledgment was lost.
            let restarted = o8bConnection(source.paths, link: outgoing)
            restarted.receiveUserInfo(["kind": "PSLOwnerPracticeReceipt1", "payload": try receipt.encoded()])
            _ = try await o8bWait(restarted, receipt, state: .verified)
            restarted.receiveUserInfo(["kind": "PSLOwnerPracticeReceipt1", "payload": try receipt.encoded()])
            #expect(await o8bStatus(restarted, receipt)?.state == .verified)
            #expect(try o8bSourceRetained(source, bundle: bundle))
        }
    }

    @Test func duplicateAndNewRevisionRemainDistinctAndConflictNeverOverwrites() async throws {
        try await o8bWithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (original, first) = try source.write()
            let (conflict, other) = try source.write("conflict.pslpractice", heartRate: .excludedByOwner)
            let (revision, second) = try source.write("revision.pslpractice", revision: 2, heartRate: .excludedByOwner)
            #expect(first.practiceID == second.practiceID && first.bundleSHA256 != other.bundleSHA256)
            let target = try o8Directory(base, "target"), link = O8BFileLink(available: true)
            let receiver = o8bConnection(try RecordingPaths(base: target), link: link)
            receiver.onOwnerPracticePublication = { prepared in
                try prepared.renameForPublication()
                return try prepared.confirmPublication()
            }
            #expect(try await o8bReceive(receiver, url: original, receipt: first) == first)
            #expect(try await o8bReceive(receiver, url: original, receipt: first) == first)
            let acknowledgments = link.receipts.count
            await o8bReject { _ = try await o8bReceive(receiver, url: conflict, receipt: other) }
            #expect(link.receipts.count == acknowledgments)
            #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: first.practiceID, revision: 1) == first)
            #expect(try await o8bReceive(receiver, url: revision, receipt: second) == second)
            let reader = try OwnerPracticeReceiptStore(base: target)
            #expect(try reader.receipt(practiceID: first.practiceID, revision: 1) == first)
            #expect(try reader.receipt(practiceID: second.practiceID, revision: 2) == second)

            let sender = o8bConnection(source.paths, link: O8BFileLink())
            sender.queuePractice(from: original); sender.queuePractice(from: revision)
            _ = try await o8bWait(sender, first, state: .queued)
            _ = try await o8bWait(sender, second, state: .queued)
            sender.receiveUserInfo(["kind": "PSLOwnerPracticeReceipt1", "payload": try first.encoded()])
            _ = try await o8bWait(sender, first, state: .verified)
            #expect(await o8bStatus(sender, second)?.state == .queued)
            sender.receiveUserInfo(["kind": "PSLOwnerPracticeReceipt1", "payload": try other.encoded()])
            #expect(await o8bStatus(sender, first)?.state == .verified)
            #expect(await o8bStatus(sender, second)?.state == .queued)
        }
    }

    @Test func failedDeliveryNeedsExplicitRetryAndRetainsEverySourceCopy() async throws {
        try await o8bWithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, receipt) = try source.write(), link = O8BFileLink(available: true)
            let sender = o8bConnection(source.paths, link: link)
            sender.queuePractice(from: bundle)
            _ = try await o8bWait(sender, receipt, state: .transferring)
            try #require(link.files.first).complete(.failure(.unavailable))
            _ = try await o8bWait(sender, receipt, state: .failed)
            #expect(try o8bSourceRetained(source, bundle: bundle))
            sender.resumePracticeTransfers()
            #expect(await o8bStatus(sender, receipt)?.state == .failed)
            #expect(link.files.count == 1, "Activation is not an automatic retry of a failed transfer.")
            sender.queuePractice(from: bundle)
            _ = try await o8bWait(sender, receipt, state: .transferring)
            #expect(link.files.count == 2)
            let retry = try #require(link.files.last)
            #expect(try Data(contentsOf: retry.url) == Data(contentsOf: bundle))
            retry.complete(.success(()))
            _ = try await o8bWait(sender, receipt, state: .sent)
            #expect(try o8bSourceRetained(source, bundle: bundle))
        }
    }

    @Test(arguments: ["missingPublisher", "metadata", "truncated"])
    func failedIncomingInventoryNeverEmitsCompleteReceipt(failure: String) async throws {
        try await o8bWithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, receipt) = try source.write(), target = try o8Directory(base, "target")
            let link = O8BFileLink(available: true), receiver = o8bConnection(try RecordingPaths(base: target), link: link)
            if failure != "missingPublisher" {
                receiver.onOwnerPracticePublication = { prepared in
                    try prepared.renameForPublication()
                    return try prepared.confirmPublication()
                }
            }
            var metadata = o8bMetadata(receipt)
            if failure == "metadata" { metadata["revision"] = "99" }
            if failure == "truncated" { try Data(Data(contentsOf: bundle).dropLast()).write(to: bundle) }
            await o8bReject {
                _ = try await o8bReceive(receiver, file: .init(url: bundle, metadata: metadata, complete: { _ in }))
            }
            #expect(link.receipts.isEmpty)
            #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: receipt.practiceID, revision: 1) == nil)
            #expect(FileManager.default.fileExists(atPath: source.paths.rawRoot.path))
        }
    }

    @Test func receiverOwnsEphemeralIncomingBytesBeforeItsDelegateReturns() async throws {
        try await o8bWithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, receipt) = try source.write(), target = try o8Directory(base, "target")
            let ephemeral = base.appendingPathComponent("wc-temporary.pslpractice")
            try FileManager.default.copyItem(at: bundle, to: ephemeral)
            let receiver = o8bConnection(try RecordingPaths(base: target), link: O8BFileLink(available: true))
            let boundary = O8BPublicationBarrier()
            receiver.onOwnerPracticePublication = { prepared in
                await boundary.hold()
                try prepared.renameForPublication()
                return try prepared.confirmPublication()
            }
            let result = O8BReceiveResult()
            receiver.receivePracticeFile(from: ephemeral, metadata: o8bMetadata(receipt)) { result.set($0) }
            // WC's delivered URL may disappear as soon as its delegate returns.
            try FileManager.default.removeItem(at: ephemeral)
            try await o8bEventually { await boundary.entered }
            #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: receipt.practiceID, revision: 1) == nil)
            await boundary.release()
            try await o8bEventually { result.value != nil }
            #expect(try #require(result.value).get() == receipt)
        }
    }
}

private func o8bConnection(_ paths: RecordingPaths, link: O8BFileLink) -> RecordingConnectivity {
    RecordingConnectivity(paths: paths, backgroundStateProvider: { .init(activated: true, hasContentPending: false) },
        backgroundTimeout: 2, practiceTransportAdapter: link.adapter)
}
private func o8bMetadata(_ receipt: OwnerPracticeReceipt) -> [String: String] {
    ["kind": "PSLOwnerPractice1", "practiceID": receipt.practiceID.uuidString,
     "revision": String(receipt.revision), "sha256": receipt.bundleSHA256]
}
private func o8bStatus(_ connection: RecordingConnectivity, _ receipt: OwnerPracticeReceipt) async -> OwnerPracticeTransferSnapshot? {
    await withCheckedContinuation { continuation in
        connection.practiceStatus(practiceID: receipt.practiceID, revision: receipt.revision,
            bundleSHA256: receipt.bundleSHA256) { continuation.resume(returning: $0) }
    }
}
@discardableResult private func o8bWait(_ connection: RecordingConnectivity, _ receipt: OwnerPracticeReceipt,
                                      state: RecordingTransferState) async throws -> OwnerPracticeTransferSnapshot {
    for _ in 0..<200 {
        if let value = await o8bStatus(connection, receipt), value.state == state { return value }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Actual practice transfer did not reach \(state)")
    throw O8Injected.stop
}
private func o8bReceive(_ connection: RecordingConnectivity, url: URL, receipt: OwnerPracticeReceipt) async throws -> OwnerPracticeReceipt {
    try await o8bReceive(connection, file: .init(url: url, metadata: o8bMetadata(receipt), complete: { _ in }))
}
private func o8bReceive(_ connection: RecordingConnectivity, file: O8BFileLink.File) async throws -> OwnerPracticeReceipt {
    try await withCheckedThrowingContinuation { continuation in
        connection.receivePracticeFile(from: file.url, metadata: file.metadata) { continuation.resume(with: $0) }
    }
}
private func o8bReject(_ operation: () async throws -> Void) async {
    do { try await operation(); Issue.record("The actual transfer unexpectedly succeeded") } catch {}
}
private func o8bSourceRetained(_ source: O8Fixture, bundle: URL) throws -> Bool {
    guard FileManager.default.fileExists(atPath: bundle.path) else { return false }
    let notes = try SessionAnnotationsStore(root: source.paths.notesRoot)
    return try source.contexts.allSatisfy {
        try RecordingStore.inspect(root: source.paths.rawRoot, recordingID: $0.recordingID).metadata == $0.metadata
            && notes.loadTimeline(recordingID: $0.recordingID) != nil
            && notes.loadLabels(recordingID: $0.recordingID) == source.labels[source.contexts.firstIndex(of: $0)!]
    }
}
private func o8bWithDirectory(_ body: (URL) async throws -> Void) async throws {
    // Resolve only the trusted system root; every owned/hostile child retains its original path.
    guard let resolved = realpath(FileManager.default.temporaryDirectory.path, nil) else {
        throw CocoaError(.fileReadUnknown)
    }
    defer { free(resolved) }
    let trustedRoot = URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
    let base = trustedRoot.appendingPathComponent("O8B-Core-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: base) }
    try await body(base)
}
private func o8bEventually(_ condition: () async -> Bool) async throws {
    for _ in 0..<200 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out observing the actual transport boundary")
    throw O8Injected.stop
}
private actor O8BPublicationBarrier {
    private(set) var entered = false
    private var released = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func hold() async {
        entered = true
        if !released { await withCheckedContinuation { waiters.append($0) } }
    }
    func release() { released = true; let pending = waiters; waiters.removeAll(); pending.forEach { $0.resume() } }
}
private final class O8BReceiveResult: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Result<OwnerPracticeReceipt, OwnerTransportFailure>?
    var value: Result<OwnerPracticeReceipt, OwnerTransportFailure>? { lock.withLock { stored } }
    func set(_ value: Result<OwnerPracticeReceipt, OwnerTransportFailure>) { lock.withLock { stored = value } }
}
private final class O8BFileLink: @unchecked Sendable {
    struct File: Sendable {
        let url: URL, metadata: [String: String]
        let complete: @Sendable (Result<Void, OwnerTransportFailure>) -> Void
    }
    private let lock = NSLock()
    private var online: Bool
    private var delivered: [File] = [], acknowledged: [Data] = []
    init(available: Bool = false) { online = available }
    var available: Bool { get { lock.withLock { online } } set { lock.withLock { online = newValue } } }
    var files: [File] { lock.withLock { delivered } }
    var receipts: [Data] { lock.withLock { acknowledged } }
    var adapter: OwnerPracticeTransportAdapter {
        .init(available: { [self] in available },
              transferFile: { [self] url, metadata, completion in
                  lock.withLock { delivered.append(.init(url: url, metadata: metadata, complete: completion)) }
              }, transferReceipt: { [self] data in lock.withLock { acknowledged.append(data) } })
    }
}

