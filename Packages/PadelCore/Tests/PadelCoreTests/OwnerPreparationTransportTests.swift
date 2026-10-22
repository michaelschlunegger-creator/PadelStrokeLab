import Foundation
import Testing
@testable import PadelCore

private final class TransportValues<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Value] = []
    private var waiters: [UUID: (Int, CheckedContinuation<Bool, Never>)] = [:]
    var values: [Value] { lock.withLock { stored } }
    func append(_ value: Value) {
        let ready = lock.withLock {
            stored.append(value)
            let ready = waiters.filter { stored.count >= $0.value.0 }
            for key in ready.keys { waiters.removeValue(forKey: key) }
            return ready.values.map(\.1)
        }
        ready.forEach { $0.resume(returning: true) }
    }
    func wait(_ count: Int, timeout: TimeInterval = 5,
              diagnostic: (@Sendable (String, UInt64) -> Void)? = nil) async -> Bool {
        await withCheckedContinuation { continuation in
            let id = UUID()
            let done = lock.withLock {
                if stored.count >= count { return true }
                waiters[id] = (count, continuation); return false
            }
            diagnostic?(done ? "probe-already-ready" : "probe-register", DispatchTime.now().uptimeNanoseconds)
            if done { continuation.resume(returning: true); return }
            let deadline = DispatchTime.now() + timeout
            diagnostic?("probe-planned-timeout", deadline.uptimeNanoseconds)
            DispatchQueue.global().asyncAfter(deadline: deadline) { [self] in
                let firedAt = DispatchTime.now().uptimeNanoseconds
                lock.withLock { waiters.removeValue(forKey: id)?.1 }?.resume(returning: false)
                diagnostic?("probe-timer-fire", firedAt)
            }
        }
    }
}

private final class CancellationProbeTimingTrace: @unchecked Sendable {
    private let lock = NSLock()
    private let origin = DispatchTime.now().uptimeNanoseconds
    private var events: [(String, UInt64)] = []
    private var emitted = false

    func mark(_ phase: String, at time: UInt64 = DispatchTime.now().uptimeNanoseconds,
              emitEvent: Bool = false) {
        lock.withLock { events.append((phase, time)) }
        if emitEvent { print("Cancellation probe event: \(entry(phase, time))") }
    }

    func emitOnce(_ reason: String) {
        let snapshot: [(String, UInt64)]? = lock.withLock {
            guard !emitted else { return nil }
            emitted = true
            return events
        }
        guard let snapshot else { return }
        let summary = snapshot.sorted { $0.1 < $1.1 }.map { entry($0.0, $0.1) }.joined(separator: ", ")
        print("Cancellation probe timing [\(reason)]: \(summary)")
    }

    private func entry(_ phase: String, _ time: UInt64) -> String {
        let milliseconds = Double(time - origin) / 1_000_000
        return "\(phase)=\(String(format: "%.3f", milliseconds))ms"
    }
}

private final class TransportGate: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        await withCheckedContinuation { continuation in
            let ready = lock.withLock {
                if opened { return true }; waiters.append(continuation); return false
            }
            if ready { continuation.resume() }
        }
    }
    func open() {
        let ready = lock.withLock { opened = true; defer { waiters = [] }; return waiters }
        ready.forEach { $0.resume() }
    }
}

private struct TransportFixture {
    let root: URL
    let paths: RecordingPaths
    init() throws {
        guard let resolved = realpath(FileManager.default.temporaryDirectory.path, nil) else { throw CocoaError(.fileReadUnknown) }
        defer { free(resolved) }
        root = URL(fileURLWithPath: String(cString: resolved), isDirectory: true).appendingPathComponent("O3c-Core-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        paths = try RecordingPaths(base: root)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
    func connection(adapter: OwnerTransportAdapter? = nil) -> RecordingConnectivity {
        let connection = RecordingConnectivity(paths: paths,
            backgroundStateProvider: { RecordingBackgroundState(activated: true, hasContentPending: false) },
            backgroundTimeout: 5, ownerTransportAdapter: adapter)
        connection.onOwnerPreparation = { _, _ in nil }
        return connection
    }
}

private func transportRequest() -> OwnerPreparationMessage {
    .statusRequest(requestID: UUID(), phoneEpoch: ownerTestPhone)
}
private func transportDraft() throws -> OwnerPreparation {
    try OwnerPreparation(authority: ownerTestIdentity(), practiceID: UUID(), draft: ownerTestDraft())
}

// Each case exercises concurrent work explicitly; avoid multiplying real blocked owner queues
// across unrelated cases and starving the other suites' existing deadline/receipt barriers.
@Suite(.serialized) struct OwnerPreparationTransportTests {
    @Test func callerCancellationDoesNotReleaseSixteenRealAsyncHandlersOrDrain() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let connection = f.connection(), gate = TransportGate(); defer { gate.open() }
        let started = TransportValues<OwnerPreparationWork>(), responses = TransportValues<OwnerTransportFailure>()
        let commits = TransportValues<Int>(), drained = TransportValues<Bool>()
        connection.onOwnerPreparation = { message, work in
            started.append(work); await gate.wait()
            try work.commit { commits.append(1) }
            return try .failure(replyingTo: message, code: .unavailable)
        }
        var ids: [UUID] = []
        for _ in 0..<16 {
            ids.append(connection.receiveOwnerData(try OwnerPreparationCodec.encode(transportRequest()), delivery: .interactive) {
                if case let .failure(value) = $0 { responses.append(value) }
            })
        }
        #expect(await started.wait(16))
        ids.forEach { connection.cancelOwnerOperation($0) }
        #expect(await responses.wait(16))
        #expect(responses.values.allSatisfy { $0 == .cancelled })
        #expect(!connection.submit(id: nil) {})
        _ = connection.receiveOwnerData(try OwnerPreparationCodec.encode(transportRequest()), delivery: .interactive) {
            if case let .failure(value) = $0 { responses.append(value) }
        }
        #expect(await responses.wait(17)); #expect(responses.values.last == .busy)
        _ = connection.drainForBackground { drained.append($0) }
        #expect(!(await drained.wait(1, timeout: 0.1)))
        gate.open()
        #expect(await drained.wait(1)); #expect(drained.values == [true])
        #expect(commits.values.isEmpty)
        #expect(connection.submit(id: nil) {})
    }

    @Test func timeoutCompletesCallerButNotSuspendedHandlerLease() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let connection = f.connection(), gate = TransportGate(); defer { gate.open() }
        let started = TransportValues<Bool>(), results = TransportValues<OwnerTransportFailure>(), drained = TransportValues<Bool>()
        connection.onOwnerPreparation = { message, work in
            started.append(true); await gate.wait()
            _ = try work.commit { Issue.record("Expired handler committed") }
            return try .failure(replyingTo: message, code: .unavailable)
        }
        _ = connection.receiveOwnerData(try OwnerPreparationCodec.encode(transportRequest()), delivery: .interactive, timeout: 0.05) {
            if case let .failure(value) = $0 { results.append(value) }
        }
        #expect(await started.wait(1)); #expect(await results.wait(1)); #expect(results.values == [.timedOut])
        _ = connection.drainForBackground { drained.append($0) }
        #expect(!(await drained.wait(1, timeout: 0.1)))
        gate.open(); #expect(await drained.wait(1)); #expect(drained.values == [true])
        #expect(results.values == [.timedOut])
    }

    @Test func expiredCommitFailsEvenWhenOwnerQueueDelaysTimeoutCallback() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let connection = f.connection(), gate = TransportGate(); defer { gate.open() }
        let started = TransportValues<Bool>(), denied = TransportValues<Bool>(), responses = TransportValues<OwnerTransportFailure>()
        let rawGate = DispatchSemaphore(value: 0); defer { rawGate.signal() }
        let rawStarted = TransportValues<Bool>()
        #expect(connection.submit(id: nil) { rawStarted.append(true); _ = rawGate.wait(timeout: .now() + 5) })
        #expect(await rawStarted.wait(1))
        connection.onOwnerPreparation = { _, work in
            started.append(true); await gate.wait()
            do { _ = try work.commit { Issue.record("Deadline passed inside commit gate") } }
            catch { denied.append(true); throw error }
            return nil
        }
        _ = connection.receiveOwnerData(try OwnerPreparationCodec.encode(transportRequest()), delivery: .interactive, timeout: 0.05) {
            if case let .failure(value) = $0 { responses.append(value) }
        }
        #expect(await started.wait(1))
        try await Task.sleep(for: .milliseconds(80)); gate.open()
        #expect(await denied.wait(1)); rawGate.signal()
        #expect(await responses.wait(1)); #expect(responses.values == [.timedOut])
    }

    @Test func cancelledOutboundLateDuplicateCallbacksCannotReleaseAnotherLease() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let callbacks = TransportValues<@Sendable (Result<Data, OwnerTransportFailure>) -> Void>()
        let adapter = OwnerTransportAdapter(request: { _, completion in callbacks.append(completion) },
            control: { _ in }, draft: { _ in })
        let connection = f.connection(adapter: adapter), results = TransportValues<OwnerTransportFailure>()
        let request = transportRequest()
        let id = connection.sendOwnerRequest(request) { if case let .failure(value) = $0 { results.append(value) } }
        #expect(await callbacks.wait(1)); connection.cancelOwnerOperation(id)
        #expect(await results.wait(1)); #expect(results.values == [.cancelled])
        let reply = try OwnerPreparationCodec.encode(OwnerPreparationMessage.failure(replyingTo: request, code: .unavailable))
        let callback = try #require(callbacks.values.first)
        callback(.success(reply)); callback(.success(reply)); callback(.failure(.unavailable))
        let drained = TransportValues<Bool>()
        _ = connection.drainForBackground { drained.append($0) }
        #expect(await drained.wait(1)); #expect(drained.values == [true])
        let rawGate = DispatchSemaphore(value: 0); defer { rawGate.signal() }
        #expect(connection.submit(id: nil) { _ = rawGate.wait(timeout: .now() + 5) })
        for _ in 0..<15 { #expect(connection.submit(id: nil) {}) }
        #expect(!connection.submit(id: nil) {})
        rawGate.signal()
        #expect(results.values == [.cancelled])
    }

    @Test func outboundReplyMustMatchExactRequestAndUnsupportedPeerDoesNotFallback() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let request = transportRequest(), wrong = transportRequest()
        let badReply = try OwnerPreparationCodec.encode(OwnerPreparationMessage.failure(replyingTo: wrong, code: .unavailable))
        let adapter = OwnerTransportAdapter(request: { _, completion in completion(.success(badReply)) }, control: { _ in }, draft: { _ in })
        let connection = f.connection(adapter: adapter), failures = TransportValues<OwnerTransportFailure>()
        _ = connection.sendOwnerRequest(request) { if case let .failure(value) = $0 { failures.append(value) } }
        #expect(await failures.wait(1)); #expect(failures.values == [.mismatchedReply])
        let invalid = Data("{\"version\":1,\"kind\":\"PSLSetup1.statusRequest\"}".utf8)
        _ = connection.receiveOwnerData(invalid, delivery: .interactive) { if case let .failure(value) = $0 { failures.append(value) } }
        #expect(await failures.wait(2)); #expect(failures.values.last == .invalidMessage)
    }

    @Test func applicationContextCoalescesLatestDraftAndCannotPrepareOrMutate() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let connection = f.connection(), gate = TransportGate(); defer { gate.open() }
        let started = TransportValues<OwnerPreparationMessage>(), commits = TransportValues<OwnerPreparationMessage>()
        connection.onOwnerPreparation = { message, work in
            started.append(message); if started.values.count == 1 { await gate.wait() }
            try work.commit { commits.append(message) }; return nil
        }
        let first = try OwnerPreparationMessage.draft(transportDraft())
        let middle = try OwnerPreparationMessage.draft(transportDraft())
        let latest = try OwnerPreparationMessage.draft(transportDraft())
        _ = connection.receiveOwnerData(try OwnerPreparationCodec.encode(first), delivery: .draft) { _ in }
        #expect(await started.wait(1))
        _ = connection.receiveOwnerData(try OwnerPreparationCodec.encode(middle), delivery: .draft) { _ in }
        _ = connection.receiveOwnerData(try OwnerPreparationCodec.encode(latest), delivery: .draft) { _ in }
        let rejected = TransportValues<OwnerTransportFailure>()
        _ = connection.receiveOwnerData(try OwnerPreparationCodec.encode(transportRequest()), delivery: .draft) {
            if case let .failure(value) = $0 { rejected.append(value) }
        }
        #expect(await rejected.wait(1)); #expect(rejected.values == [.invalidMessage])
        gate.open(); #expect(await commits.wait(1)); #expect(commits.values == [latest])
        #expect(started.values == [first, latest])
    }

    @Test func queuedControlAndDraftSubmissionDoNotClaimAuthorityApplication() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let queued = TransportValues<Data>(), contexts = TransportValues<Data>(), completed = TransportValues<Bool>()
        let adapter = OwnerTransportAdapter(request: { _, result in result(.failure(.unavailable)) },
            control: { queued.append($0) }, draft: { contexts.append($0) })
        let connection = f.connection(adapter: adapter)
        let transition = try OwnerAuthorityTransition(sequence: 1, mutation: .enrollment(ownerTestIdentity()))
        connection.queueOwnerControl(.transition(transition)) { if case .success = $0 { completed.append(true) } }
        let draft = try transportDraft()
        connection.updateOwnerDraft(draft) { if case .success = $0 { completed.append(true) } }
        #expect(await completed.wait(2))
        #expect(try queued.values.map(OwnerPreparationCodec.decode) == [.transition(transition)])
        #expect(try contexts.values.map(OwnerPreparationCodec.decode) == [.draft(draft)])
        let rejected = TransportValues<OwnerTransportFailure>()
        connection.queueOwnerControl(transportRequest()) { if case let .failure(value) = $0 { rejected.append(value) } }
        #expect(await rejected.wait(1)); #expect(rejected.values == [.invalidMessage])
    }

    @Test func rawReceiptProductionRouteStillVerifiesOnlyMatchingRetainedArchive() async throws {
        let (fixture, paths, timeline, bundle) = try archiveFixture(); defer { withExtendedLifetime(fixture) {} }
        let receipt = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: bundle)
        let ledger = try RecordingTransferLedger(root: paths.outboxRoot)
        try ledger.save(RecordingTransferRecord(schemaVersion: 1, receipt: receipt, fileName: bundle.lastPathComponent, state: .sent))
        let connection = RecordingConnectivity(paths: paths)
        connection.receiveUserInfo(["kind": "PSLReceipt1", "recordingID": recordingTestID.uuidString, "sha256": receipt.bundleSHA256])
        let state = await withCheckedContinuation { continuation in
            connection.status(recordingID: recordingTestID) { continuation.resume(returning: $0) }
        }
        #expect(state?.state == .verified)
        #expect(try Data(contentsOf: bundle).count == receipt.byteCount)
        connection.receiveUserInfo(["kind": "PSLOwnerSetup1.control", "payload": Data()])
        #expect(try ledger.load(recordingTestID)?.state == .verified)
    }

    @Test(arguments: [false, true])
    func appliedReplyPersistenceKeepsOriginalLeaseThroughCancellationOrTimeout(timeout: Bool) async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let callbacks = TransportValues<@Sendable (Result<Data, OwnerTransportFailure>) -> Void>()
        let adapter = OwnerTransportAdapter(request: { _, completion in callbacks.append(completion) }, control: { _ in }, draft: { _ in })
        let connection = f.connection(adapter: adapter), gate = TransportGate(); defer { gate.open() }
        let command = try OwnerAuthorityMutation.advance(from: ownerTestIdentity(), mutationID: UUID())
        let requestID = UUID()
        let request = OwnerPreparationMessage.mutate(requestID: requestID, generations: ownerTestGenerations, mutation: command)
        let reply = OwnerPreparationMessage.applied(requestID: requestID, generations: ownerTestGenerations,
            transition: try OwnerAuthorityTransition(sequence: 2, mutation: command))
        let started = TransportValues<OwnerPreparationMessage>(), results = TransportValues<OwnerTransportFailure>()
        let committed = TransportValues<Bool>(), drained = TransportValues<Bool>()
        connection.onOwnerPreparation = { message, work in
            started.append(message); await gate.wait()
            try work.commit { committed.append(true) }; return nil
        }
        let operation = connection.sendOwnerRequest(request, timeout: timeout ? 0.08 : 5) {
            if case let .failure(value) = $0 { results.append(value) }
        }
        #expect(await callbacks.wait(1)); let callback = try #require(callbacks.values.first)
        let bytes = try OwnerPreparationCodec.encode(reply)
        callback(.success(bytes)); #expect(await started.wait(1))
        callback(.success(bytes)); callback(.failure(.unavailable))
        if !timeout { connection.cancelOwnerOperation(operation) }
        #expect(await results.wait(1)); #expect(results.values == [timeout ? .timedOut : .cancelled])
        let rawGate = DispatchSemaphore(value: 0); defer { rawGate.signal() }
        #expect(connection.submit(id: nil) { _ = rawGate.wait(timeout: .now() + 5) })
        for _ in 0..<14 { #expect(connection.submit(id: nil) {}) }
        #expect(!connection.submit(id: nil) {})
        rawGate.signal()
        _ = connection.drainForBackground { drained.append($0) }
        #expect(!(await drained.wait(1, timeout: 0.1)))
        gate.open(); #expect(await drained.wait(1)); #expect(drained.values == [true])
        #expect(started.values == [reply]); #expect(committed.values.isEmpty)
        #expect(results.values.count == 1)
    }

    @Test func appliedReplyCompletesObserverOnlyAfterPersistenceAndRejectsEscapedCommit() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let command = try OwnerAuthorityMutation.advance(from: ownerTestIdentity(), mutationID: UUID())
        let requestID = UUID()
        let request = OwnerPreparationMessage.mutate(requestID: requestID, generations: ownerTestGenerations, mutation: command)
        let reply = OwnerPreparationMessage.applied(requestID: requestID, generations: ownerTestGenerations,
            transition: try OwnerAuthorityTransition(sequence: 2, mutation: command))
        let bytes = try OwnerPreparationCodec.encode(reply)
        let adapter = OwnerTransportAdapter(request: { _, completion in completion(.success(bytes)) }, control: { _ in }, draft: { _ in })
        let connection = f.connection(adapter: adapter), gate = TransportGate(); defer { gate.open() }
        let works = TransportValues<OwnerPreparationWork>(), events = TransportValues<String>()
        connection.onOwnerPreparation = { message, work in
            #expect(message == reply); works.append(work); await gate.wait()
            try work.commit { events.append("persisted") }; return nil
        }
        _ = connection.sendOwnerRequest(request) { result in
            if case .success(let value) = result {
                #expect(value == reply); events.append("observer")
                #expect(connection.submit(id: nil) { events.append("reentered") })
            }
        }
        #expect(await works.wait(1)); #expect(events.values.isEmpty)
        gate.open(); #expect(await events.wait(3)); #expect(events.values == ["persisted", "observer", "reentered"])
        let work = try #require(works.values.first)
        #expect(throws: OwnerTransportFailure.alreadyCommitted) { try work.commit { Issue.record("Escaped mutation") } }
    }

    @Test func commitRejectsReentryAndDefersReentrantCancellationCallbackUntilCommitExits() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let connection = f.connection(), gate = TransportGate(); defer { gate.open() }
        let exitGate = TransportGate(); defer { exitGate.open() }
        let ids = TransportValues<UUID>(), completions = TransportValues<OwnerTransportFailure>(), events = TransportValues<String>()
        let drained = TransportValues<Bool>()
        connection.onOwnerPreparation = { message, work in
            await gate.wait()
            try work.commit {
                #expect(throws: OwnerTransportFailure.alreadyCommitted) { try work.commit { Issue.record("Reentrant commit") } }
                if let id = ids.values.first { connection.cancelOwnerOperation(id) }
                #expect(completions.values.isEmpty)
                events.append("committed")
            }
            events.append("commit exited"); await exitGate.wait()
            return try .failure(replyingTo: message, code: .unavailable)
        }
        let id = connection.receiveOwnerData(try OwnerPreparationCodec.encode(transportRequest()), delivery: .interactive) {
            if case .failure(let value) = $0 { completions.append(value) }
        }
        ids.append(id); gate.open()
        #expect(await completions.wait(1)); #expect(completions.values == [.cancelled])
        #expect(events.values == ["committed", "commit exited"])
        _ = connection.drainForBackground { drained.append($0) }
        #expect(!(await drained.wait(1, timeout: 0.1)))
        exitGate.open(); #expect(await drained.wait(1)); #expect(drained.values == [true])
    }

    @Test func concurrentCancellationWaitsUntilSynchronousCommitFinishes() async throws {
        let trace = CancellationProbeTimingTrace()
        trace.mark("test-start")
        defer { trace.emitOnce("test-exit") }
        let f = try TransportFixture(); defer { f.remove() }
        let connection = f.connection(), exitGate = TransportGate(); defer { exitGate.open() }
        let commitGate = DispatchSemaphore(value: 0); defer { commitGate.signal() }
        let events = TransportValues<String>(), cancellationReturned = TransportValues<Bool>(), responses = TransportValues<OwnerTransportFailure>()
        let drained = TransportValues<Bool>()
        let commitWaitSucceeded = TransportValues<Bool>(), cancellationStarted = TransportValues<Bool>()
        connection.onOwnerPreparation = { message, work in
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let commitWorker = Thread {
                    let result = Result<Void, any Error> {
                        try work.commit {
                            trace.mark("commit-enter")
                            events.append("entered")
                            let gateResult = commitGate.wait(timeout: .now() + 5)
                            trace.mark(gateResult == .success ? "commit-gate-signalled" : "commit-gate-timeout")
                            commitWaitSucceeded.append(gateResult == .success)
                            events.append("committed")
                        }
                        trace.mark("commit-exit")
                    }
                    continuation.resume(with: result)
                }
                commitWorker.qualityOfService = .userInitiated
                commitWorker.start()
            }
            await exitGate.wait()
            return try .failure(replyingTo: message, code: .unavailable)
        }
        let id = connection.receiveOwnerData(try OwnerPreparationCodec.encode(transportRequest()), delivery: .interactive) {
            if case .failure(let value) = $0 { responses.append(value) }
        }
        #expect(await events.wait(1))
        let cancellationWorker = Thread {
            trace.mark("cancel-start")
            cancellationStarted.append(true)
            connection.cancelOwnerOperation(id)
            trace.mark("cancel-return")
            cancellationReturned.append(true)
        }
        defer { withExtendedLifetime(cancellationWorker) {} }
        cancellationWorker.qualityOfService = .userInitiated
        trace.mark("cancel-submit")
        cancellationWorker.start()
        #expect(await cancellationStarted.wait(1))
        let probeResult = await cancellationReturned.wait(1, timeout: 0.1, diagnostic: { phase, time in
            // The timer retains this trace and emits even after the main summary has been printed.
            trace.mark(phase, at: time, emitEvent: phase == "probe-timer-fire")
        })
        trace.mark(probeResult ? "probe-return-true" : "probe-return-false")
        #expect(!probeResult)
        trace.mark("main-release")
        commitGate.signal(); #expect(await cancellationReturned.wait(1)); #expect(await responses.wait(1))
        #expect(commitWaitSucceeded.values == [true])
        #expect(events.values == ["entered", "committed"]); #expect(responses.values == [.cancelled])
        _ = connection.drainForBackground { drained.append($0) }
        #expect(!(await drained.wait(1, timeout: 0.1)))
        exitGate.open(); #expect(await drained.wait(1)); #expect(drained.values == [true])
    }

    @Test func mixedRawAndOwnerWorkShareExactlySixteenSlots() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let connection = f.connection(), gate = TransportGate(); defer { gate.open() }
        let rawGate = DispatchSemaphore(value: 0); defer { rawGate.signal() }
        let started = TransportValues<Bool>(), responses = TransportValues<OwnerTransportFailure>(), drained = TransportValues<Bool>()
        #expect(connection.submit(id: nil) { _ = rawGate.wait(timeout: .now() + 5) })
        for _ in 0..<7 { #expect(connection.submit(id: nil) {}) }
        connection.onOwnerPreparation = { message, _ in
            started.append(true); await gate.wait(); return try .failure(replyingTo: message, code: .unavailable)
        }
        var ids: [UUID] = []
        for _ in 0..<8 {
            ids.append(connection.receiveOwnerData(try OwnerPreparationCodec.encode(transportRequest()), delivery: .interactive) {
                if case .failure(let value) = $0 { responses.append(value) }
            })
        }
        #expect(await started.wait(8)); ids.forEach { connection.cancelOwnerOperation($0) }
        #expect(await responses.wait(8)); #expect(!connection.submit(id: nil) {})
        rawGate.signal(); gate.open()
        _ = connection.drainForBackground { drained.append($0) }
        #expect(await drained.wait(1)); #expect(drained.values == [true])
    }

    @Test func outboundDraftFloodRetainsOnlyLatestWhileAllSixteenRawSlotsAreOccupied() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let submitted = TransportValues<Data>(), results = TransportValues<Bool>()
        let adapter = OwnerTransportAdapter(request: { _, completion in completion(.failure(.unavailable)) }, control: { _ in }, draft: { submitted.append($0) })
        let connection = f.connection(adapter: adapter), rawGate = DispatchSemaphore(value: 0); defer { rawGate.signal() }
        #expect(connection.submit(id: nil) { _ = rawGate.wait(timeout: .now() + 5) })
        for _ in 0..<15 { #expect(connection.submit(id: nil) {}) }
        var latest = try transportDraft()
        for _ in 0..<40 {
            latest = try transportDraft()
            connection.updateOwnerDraft(latest) { result in
                switch result { case .success: results.append(true); case .failure(let failure):
                    #expect(failure == .cancelled); results.append(false) }
            }
        }
        #expect(results.values == Array(repeating: false, count: 39)); #expect(submitted.values.isEmpty)
        rawGate.signal(); #expect(await results.wait(40))
        #expect(results.values.last == true)
        #expect(try submitted.values.map(OwnerPreparationCodec.decode) == [.draft(latest)])
    }

    @Test func inboundDraftFloodRetainsOnlyLatestWhileAllSlotsAreOccupied() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let connection = f.connection(), rawGate = DispatchSemaphore(value: 0); defer { rawGate.signal() }
        let handled = TransportValues<OwnerPreparationMessage>(), completions = TransportValues<Bool>()
        connection.onOwnerPreparation = { message, work in try work.commit { handled.append(message) }; return nil }
        #expect(connection.submit(id: nil) { _ = rawGate.wait(timeout: .now() + 5) })
        for _ in 0..<15 { #expect(connection.submit(id: nil) {}) }
        var latest = try OwnerPreparationMessage.draft(transportDraft())
        for _ in 0..<40 {
            latest = try .draft(transportDraft())
            _ = connection.receiveOwnerData(try OwnerPreparationCodec.encode(latest), delivery: .draft) { result in
                switch result { case .success: completions.append(true); case .failure(let failure):
                    #expect(failure == .cancelled); completions.append(false) }
            }
        }
        #expect(completions.values == Array(repeating: false, count: 39)); #expect(handled.values.isEmpty)
        rawGate.signal(); #expect(await completions.wait(40))
        #expect(handled.values == [latest]); #expect(completions.values.last == true)
    }

    @Test func outboundRequestsRequireCountedHandlerAndNeverLaunchUntrackedObserverWork() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let sent = TransportValues<Bool>(), failures = TransportValues<OwnerTransportFailure>()
        let adapter = OwnerTransportAdapter(request: { _, _ in sent.append(true) }, control: { _ in }, draft: { _ in })
        let connection = f.connection(adapter: adapter); connection.onOwnerPreparation = nil
        _ = connection.sendOwnerRequest(transportRequest()) { if case .failure(let value) = $0 { failures.append(value) } }
        #expect(await failures.wait(1)); #expect(failures.values == [.unavailable]); #expect(sent.values.isEmpty)
    }

    @Test(arguments: [false, true])
    func absentOutboundCallbackRetainsLeaseAfterCallerFinishesUntilLateDelivery(timeout: Bool) async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let callbacks = TransportValues<@Sendable (Result<Data, OwnerTransportFailure>) -> Void>()
        let adapter = OwnerTransportAdapter(request: { _, completion in callbacks.append(completion) }, control: { _ in }, draft: { _ in })
        let connection = f.connection(adapter: adapter), results = TransportValues<OwnerTransportFailure>()
        let handlers = TransportValues<Bool>(), drained = TransportValues<Bool>()
        connection.onOwnerPreparation = { _, _ in handlers.append(true); return nil }
        let request = transportRequest()
        let id = connection.sendOwnerRequest(request, timeout: timeout ? 0.05 : 5) {
            if case .failure(let value) = $0 { results.append(value) }
        }
        #expect(await callbacks.wait(1))
        if !timeout { connection.cancelOwnerOperation(id) }
        #expect(await results.wait(1)); #expect(results.values == [timeout ? .timedOut : .cancelled])
        let rawGate = DispatchSemaphore(value: 0); defer { rawGate.signal() }
        #expect(connection.submit(id: nil) { _ = rawGate.wait(timeout: .now() + 5) })
        for _ in 0..<14 { #expect(connection.submit(id: nil) {}) }
        #expect(!connection.submit(id: nil) {})
        rawGate.signal()
        _ = connection.drainForBackground { drained.append($0) }
        #expect(!(await drained.wait(1, timeout: 0.1)))
        let callback = try #require(callbacks.values.first)
        let bytes = try OwnerPreparationCodec.encode(OwnerPreparationMessage.failure(replyingTo: request, code: .unavailable))
        callback(.success(bytes))
        #expect(await drained.wait(1)); #expect(drained.values == [true]); #expect(handlers.values.isEmpty)
        let secondRawGate = DispatchSemaphore(value: 0); defer { secondRawGate.signal() }
        #expect(connection.submit(id: nil) { _ = secondRawGate.wait(timeout: .now() + 5) })
        for _ in 0..<15 { #expect(connection.submit(id: nil) {}) }
        callback(.success(bytes)); callback(.failure(.unavailable))
        #expect(!connection.submit(id: nil) {})
        secondRawGate.signal(); #expect(results.values.count == 1); #expect(handlers.values.isEmpty)
    }

    @Test func nativeUserInfoBridgeAdmitsOnlyWireTwoOwnerControlKinds() async throws {
        let f = try TransportFixture(); defer { f.remove() }
        let connection = f.connection(), handled = TransportValues<OwnerPreparationMessage>(), drained = TransportValues<Bool>()
        connection.onOwnerPreparation = { message, work in try work.commit { handled.append(message) }; return nil }
        let mutation = try OwnerAuthorityMutation.enrollment(ownerTestIdentity())
        let transition = try OwnerAuthorityTransition(sequence: 1, mutation: mutation)
        let controls: [OwnerPreparationMessage] = [
            .mutate(requestID: UUID(), generations: ownerTestGenerations, mutation: mutation),
            .transition(transition), .acknowledge(try OwnerAuthorityAcknowledgement(transition: transition))
        ]
        for invalid in [transportRequest(), try .draft(transportDraft())] {
            connection.receiveUserInfo(["kind": "PSLOwnerSetup2.control", "payload": try OwnerPreparationCodec.encode(invalid)])
        }
        connection.receiveUserInfo(["kind": "PSLOwnerSetup1.control", "payload": try OwnerPreparationCodec.encode(controls[0])])
        connection.receiveUserInfo(["kind": "PSLOwnerSetup2.control", "payload": "wrong payload type"])
        connection.receiveUserInfo(["kind": "PSLOwnerSetup2.control", "payload": Data()])
        #expect(handled.values.isEmpty)
        for message in controls {
            connection.receiveUserInfo(["kind": "PSLOwnerSetup2.control", "payload": try OwnerPreparationCodec.encode(message)])
        }
        #expect(await handled.wait(3))
        _ = connection.drainForBackground { drained.append($0) }
        #expect(await drained.wait(1)); #expect(drained.values == [true])
        #expect(handled.values.count == 3); #expect(controls.allSatisfy { handled.values.contains($0) })
    }
}
