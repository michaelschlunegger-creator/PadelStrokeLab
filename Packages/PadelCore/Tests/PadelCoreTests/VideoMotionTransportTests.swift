import Foundation
import Testing
@testable import PadelCore

private final class VMTransportValues<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Value] = []
    private var waiters: [UUID: (Int, CheckedContinuation<Bool, Never>)] = [:]
    var values: [Value] { lock.withLock { stored } }
    func append(_ value: Value) {
        let ready = lock.withLock {
            stored.append(value)
            let ready = waiters.filter { stored.count >= $0.value.0 }
            for id in ready.keys { waiters.removeValue(forKey: id) }
            return ready.values.map(\.1)
        }
        ready.forEach { $0.resume(returning: true) }
    }
    func wait(_ count: Int, timeout: TimeInterval = 5) async -> Bool {
        await withCheckedContinuation { continuation in
            let id = UUID()
            let done = lock.withLock {
                if stored.count >= count { return true }
                waiters[id] = (count, continuation); return false
            }
            if done { continuation.resume(returning: true); return }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [self] in
                lock.withLock { waiters.removeValue(forKey: id)?.1 }?.resume(returning: false)
            }
        }
    }
}
private actor VMTransportGate {
    private var open = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if open { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() { open = true; let ready = waiters; waiters = []; ready.forEach { $0.resume() } }
}
private final class VMTransportClock: @unchecked Sendable {
    private let lock = NSLock()
    private var times: [Double]
    init(_ times: [Double]) { self.times = times }
    func now() -> Double { lock.withLock { times.count > 1 ? times.removeFirst() : times[0] } }
}
private final class VMReachability: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set(_ next: Bool) { lock.withLock { value = next } }
    func get() -> Bool { lock.withLock { value } }
}

@Suite(.serialized) struct VideoMotionTransportTests {
    private func scope(_ binding: VideoMotionBinding) throws -> VideoMotionTransportScope {
        try .init(binding: binding, armGeneration: videoTestArm,
                  phoneEpoch: videoTestPhoneRun, watchEpoch: videoTestWatchRun)
    }
    private func start(_ binding: VideoMotionBinding) throws -> VideoMotionControlEnvelope {
        try .init(operationID: UUID(), binding: binding, armGeneration: videoTestArm,
                  phoneEpoch: videoTestPhoneRun, watchEpoch: videoTestWatchRun,
                  sender: .watch, sequence: 1, message: .start)
    }
    private func connection(_ paths: RecordingPaths, device: VideoMotionDevice = .phone,
                            adapter: VideoMotionTransportAdapter? = nil,
                            clock: @escaping @Sendable () -> Double = { 0 }) -> RecordingConnectivity {
        RecordingConnectivity(paths: paths,
            backgroundStateProvider: { RecordingBackgroundState(activated: true, hasContentPending: false) },
            backgroundTimeout: 5, videoMotionDevice: device, videoMotionClock: clock, videoMotionAdapter: adapter)
    }
    private func receipt(_ request: VideoMotionTransportRequest) throws -> VideoMotionControlReceipt {
        let control = try #require(request.control)
        return VideoMotionControlReceipt(operationID: control.operationID,
            messageDigest: RecordingChunkCodec.digest(try control.encoded()), phase: .starting, acceptedAt: 1)
    }

    @Test func distinctBoundedFamilyRetainsExactBindingAndRejectsUnsupportedBytes() throws {
        let control = try start(videoTestBinding()), request = try VideoMotionTransportRequest(control: control)
        let bytes = try request.encoded()
        #expect(VideoMotionTransportRequest.recognizes(bytes))
        #expect(!VideoMotionTransportRequest.recognizes(try control.encoded()))
        #expect(try VideoMotionTransportRequest.decode(bytes) == request)
        #expect(request.scope.binding == control.binding && request.scope.armGeneration == videoTestArm)
        #expect(throws: (any Error).self) { try VideoMotionTransportRequest.decode(Data([32]) + bytes) }
        #expect(throws: (any Error).self) {
            try VideoMotionTransportRequest.decode(Data(repeating: 0, count: VideoMotionTransportRequest.maximumBytes + 1))
        }
        let reply = try VideoMotionTransportReply(request: request, sender: .phone, receipt: receipt(request))
        #expect(try VideoMotionTransportReply.decode(reply.encoded()) == reply)
        #expect(throws: (any Error).self) {
            try reply.requireReply(to: VideoMotionTransportRequest(control: start(videoTestBinding())), localDevice: .watch)
        }
        #expect(throws: (any Error).self) { try reply.requireReply(to: request, localDevice: .phone) }
    }

    @Test func outboundExactReplyCompletesOnceAndWrongRoleCannotReachAdapter() async throws {
        let fixture = try RecordingDirectoryFixture(), paths = try RecordingPaths(base: fixture.root)
        let sent = VMTransportValues<Data>(), results = VMTransportValues<VideoMotionControlReceipt>()
        let adapter = VideoMotionTransportAdapter(reachable: { true }, request: { data, callback in
            sent.append(data)
            do {
                let request = try VideoMotionTransportRequest.decode(data)
                let reply = try VideoMotionTransportReply(request: request, sender: .phone, receipt: receipt(request)).encoded()
                callback(.success(reply)); callback(.success(reply)); callback(.failure(.unavailable))
            } catch { callback(.failure(.invalidMessage)) }
        })
        let watch = connection(paths, device: .watch, adapter: adapter), control = try start(videoTestBinding())
        watch.sendVideoMotion(control) { if case let .success(value) = $0 { results.append(value) } }
        #expect(await results.wait(1)); #expect(results.values.count == 1 && sent.values.count == 1)
        let phone = connection(paths, adapter: adapter), failures = VMTransportValues<OwnerTransportFailure>()
        phone.sendVideoMotion(control) { if case let .failure(value) = $0 { failures.append(value) } }
        #expect(await failures.wait(1)); #expect(failures.values == [.invalidMessage] && sent.values.count == 1)
    }

    @Test func offlineStartIsNotQueuedOrReplayedAfterReachabilityReturns() async throws {
        let fixture = try RecordingDirectoryFixture(), paths = try RecordingPaths(base: fixture.root)
        let reachable = VMReachability(), sent = VMTransportValues<Data>(), failures = VMTransportValues<OwnerTransportFailure>()
        let adapter = VideoMotionTransportAdapter(reachable: { reachable.get() }, request: { bytes, reply in
            sent.append(bytes); reply(.failure(.unavailable))
        })
        let watch = connection(paths, device: .watch, adapter: adapter)
        watch.sendVideoMotion(try start(videoTestBinding())) { if case let .failure(value) = $0 { failures.append(value) } }
        #expect(await failures.wait(1)); #expect(failures.values == [.unavailable])
        reachable.set(true)
        let drained = VMTransportValues<Bool>(); watch.drainForBackground { drained.append($0) }
        #expect(await drained.wait(1)); #expect(drained.values == [true] && sent.values.isEmpty)
        // Internal fixture construction without an adapter cannot escape to a native WC session.
        connection(paths, device: .watch).sendVideoMotion(try start(videoTestBinding())) {
            if case let .failure(value) = $0 { failures.append(value) }
        }
        #expect(await failures.wait(2)); #expect(failures.values == [.unavailable, .unavailable])
    }

    @Test func mismatchedOperationEpochAndReceiptDigestAreRejected() async throws {
        let fixture = try RecordingDirectoryFixture(), paths = try RecordingPaths(base: fixture.root)
        let other = try VideoMotionTransportRequest(control: start(videoTestBinding()))
        let unrelated = try VideoMotionTransportReply(request: other, sender: .phone, receipt: receipt(other)).encoded()
        let adapter = VideoMotionTransportAdapter(reachable: { true }, request: { _, callback in callback(.success(unrelated)) })
        let failures = VMTransportValues<OwnerTransportFailure>()
        connection(paths, device: .watch, adapter: adapter).sendVideoMotion(try start(videoTestBinding())) {
            if case let .failure(value) = $0 { failures.append(value) }
        }
        #expect(await failures.wait(1)); #expect(failures.values == [.mismatchedReply])
        let request = try VideoMotionTransportRequest(control: start(videoTestBinding()))
        let bad = VideoMotionControlReceipt(operationID: request.control!.operationID,
            messageDigest: String(repeating: "a", count: 64), phase: .capturing, acceptedAt: 1)
        #expect(throws: (any Error).self) { try VideoMotionTransportReply(request: request, sender: .phone, receipt: bad) }
        var altered = try scope(request.scope.binding)
        altered = try .init(binding: altered.binding, armGeneration: altered.armGeneration,
                            phoneEpoch: UUID(), watchEpoch: altered.watchEpoch)
        #expect(altered != request.scope)
    }

    @Test func incomingRoleAndCurrentCoordinatorScopeAreCheckedBeforeCommit() async throws {
        let fixture = try RecordingDirectoryFixture(), paths = try RecordingPaths(base: fixture.root)
        let current = try start(videoTestBinding()), expected = try scope(current.binding)
        let phone = connection(paths), commits = VMTransportValues<Bool>(), failures = VMTransportValues<OwnerTransportFailure>()
        phone.onVideoMotionRequest = { request, work in
            guard request.scope == expected else { throw OwnerTransportFailure.invalidMessage }
            return try work.commit { commits.append(true); return try receipt(request) }
        }
        phone.receiveVideoMotionData(try VideoMotionTransportRequest(control: start(videoTestBinding())).encoded()) {
            if case let .failure(value) = $0 { failures.append(value) }
        }
        #expect(await failures.wait(1)); #expect(commits.values.isEmpty)
        let watch = connection(paths, device: .watch)
        watch.onVideoMotionRequest = { _, _ in Issue.record("Wrong sender reached handler"); return nil }
        watch.receiveVideoMotionData(try VideoMotionTransportRequest(control: current).encoded()) {
            if case let .failure(value) = $0 { failures.append(value) }
        }
        #expect(await failures.wait(2)); #expect(failures.values.last == .invalidMessage)
    }

    @Test func sixteenCancelledSuspendedHandlersKeepSharedCapacityAndDrainUntilExit() async throws {
        let fixture = try RecordingDirectoryFixture(), paths = try RecordingPaths(base: fixture.root)
        let phone = connection(paths), gate = VMTransportGate()
        let started = VMTransportValues<Bool>(), failures = VMTransportValues<OwnerTransportFailure>()
        let commits = VMTransportValues<Bool>(), drained = VMTransportValues<Bool>()
        phone.onVideoMotionRequest = { request, work in
            started.append(true); await gate.wait()
            return try work.commit { commits.append(true); return try receipt(request) }
        }
        var ids: [UUID] = []
        for _ in 0..<16 {
            ids.append(phone.receiveVideoMotionData(try VideoMotionTransportRequest(control: start(videoTestBinding())).encoded()) {
                if case let .failure(value) = $0 { failures.append(value) }
            })
        }
        #expect(await started.wait(16)); ids.forEach { phone.cancelVideoMotionOperation($0) }
        #expect(await failures.wait(16)); #expect(failures.values.allSatisfy { $0 == .cancelled })
        #expect(!phone.submit(id: nil) {})
        phone.receiveVideoMotionData(try VideoMotionTransportRequest(control: start(videoTestBinding())).encoded()) {
            if case let .failure(value) = $0 { failures.append(value) }
        }
        #expect(await failures.wait(17)); #expect(failures.values.last == .busy)
        phone.drainForBackground { drained.append($0) }
        #expect(!(await drained.wait(1, timeout: 0.1)))
        await gate.release(); #expect(await drained.wait(1)); #expect(drained.values == [true])
        #expect(commits.values.isEmpty && phone.submit(id: nil) {})
    }

    @Test func timeoutBlocksLateCommitAndKeepsIncomingLeaseUntilHandlerExits() async throws {
        let fixture = try RecordingDirectoryFixture(), paths = try RecordingPaths(base: fixture.root)
        let phone = connection(paths), gate = VMTransportGate(), started = VMTransportValues<Bool>()
        let failures = VMTransportValues<OwnerTransportFailure>(), drained = VMTransportValues<Bool>()
        phone.onVideoMotionRequest = { request, work in
            started.append(true); await gate.wait()
            return try work.commit { Issue.record("Expired capture effect"); return try receipt(request) }
        }
        phone.receiveVideoMotionData(try VideoMotionTransportRequest(control: start(videoTestBinding())).encoded(), timeout: 0.05) {
            if case let .failure(value) = $0 { failures.append(value) }
        }
        #expect(await started.wait(1)); #expect(await failures.wait(1)); #expect(failures.values == [.timedOut])
        phone.drainForBackground { drained.append($0) }; #expect(!(await drained.wait(1, timeout: 0.1)))
        await gate.release(); #expect(await drained.wait(1)); #expect(failures.values.count == 1)
    }

    @Test(arguments: [false, true]) func cancelledOrTimedOutOutboundLateCallbackNeverReleasesAnotherLease(timeout: Bool) async throws {
        let fixture = try RecordingDirectoryFixture(), paths = try RecordingPaths(base: fixture.root)
        let callbacks = VMTransportValues<@Sendable (Result<Data, OwnerTransportFailure>) -> Void>()
        let requests = VMTransportValues<Data>(), failures = VMTransportValues<OwnerTransportFailure>()
        let adapter = VideoMotionTransportAdapter(reachable: { true }, request: { data, callback in
            requests.append(data); callbacks.append(callback)
        })
        let watch = connection(paths, device: .watch, adapter: adapter)
        let id = watch.sendVideoMotion(try start(videoTestBinding()), timeout: timeout ? 0.05 : 5) {
            if case let .failure(value) = $0 { failures.append(value) }
        }
        #expect(await callbacks.wait(1)); if !timeout { watch.cancelVideoMotionOperation(id) }
        #expect(await failures.wait(1)); #expect(failures.values == [timeout ? .timedOut : .cancelled])
        let drained = VMTransportValues<Bool>(); watch.drainForBackground { drained.append($0) }
        #expect(await drained.wait(1)); #expect(drained.values == [true])
        let gate = DispatchSemaphore(value: 0); defer { gate.signal() }
        #expect(watch.submit(id: nil) { _ = gate.wait(timeout: .now() + 5) })
        for _ in 0..<15 { #expect(watch.submit(id: nil) {}) }
        let request = try VideoMotionTransportRequest.decode(requests.values[0])
        let reply = try VideoMotionTransportReply(request: request, sender: .phone, receipt: receipt(request)).encoded()
        callbacks.values[0](.success(reply)); callbacks.values[0](.failure(.unavailable))
        #expect(!watch.submit(id: nil) {}); #expect(failures.values.count == 1)
    }

    @Test func clockProbeCapturesAllFourBoundariesAndRequiresWatchAuthorization() async throws {
        let fixture = try RecordingDirectoryFixture(), paths = try RecordingPaths(base: fixture.root)
        let phoneClock = VMTransportClock([10, 10.06]), watchClock = VMTransportClock([10.12, 10.14])
        let watch = connection(paths, device: .watch, clock: { watchClock.now() })
        let expected = try scope(videoTestBinding()), authorized = VMTransportValues<Bool>()
        watch.onVideoMotionRequest = { request, work in
            guard request.scope == expected, request.control == nil else { throw OwnerTransportFailure.invalidMessage }
            try work.commit { authorized.append(true) }; return nil
        }
        let adapter = VideoMotionTransportAdapter(reachable: { true }, request: { bytes, callback in
            watch.receiveVideoMotionData(bytes, completion: callback)
        })
        let phone = connection(paths, adapter: adapter, clock: { phoneClock.now() }), observations = VMTransportValues<VideoMotionClockExchange>()
        phone.probeVideoMotionClock(expected) { if case let .success(value) = $0 { observations.append(value) } }
        #expect(await observations.wait(1)); let value = try #require(observations.values.first)
        #expect(value.phoneSent == 10 && value.watchReceived == 10.12 && value.watchSent == 10.14 && value.phoneReceived == 10.06)
        #expect(abs(value.networkRoundTrip - 0.04) < 0.000_001 && authorized.values == [true])
        #expect(value.phoneEpoch == expected.phoneEpoch && value.watchEpoch == expected.watchEpoch)
    }
}
