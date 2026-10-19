import Foundation

public enum MotionCaptureState: String, Sendable {
    case ready, starting, recording, pausing, paused, resuming, stopping, saved, interrupted, failed
    public var isTerminal: Bool { self == .saved || self == .interrupted || self == .failed }
}

public struct MotionCaptureBatch: Sendable {
    public let generation: UUID
    public let stream: RecordingStream
    public let samples: [RecordingSample]
    public init(generation: UUID, stream: RecordingStream, samples: [RecordingSample]) {
        self.generation = generation; self.stream = stream; self.samples = samples
    }
}

public struct MotionCaptureSnapshot: Sendable {
    public let recordingID: UUID
    public let hasLocalRecording: Bool
    public let state: MotionCaptureState
    public let activeSeconds: Double
    public let accelerometerCount: Int
    public let deviceMotionCount: Int
    public let chunks: Int
    public let excludedBeforeWindow: Int
    public let excludedAfterCutoff: Int
    public let lastAccelerometerTimestamp: Double?
    public let lastDeviceMotionTimestamp: Double?
    public let detail: String?
    public let timeline: CaptureTimeline
}

/// Every mutable capture/storage field belongs to `worker`. Only admission is shared, under its lock.
/// Queued batches are bounded before dispatch, including the executing batch. No task is spawned per sample.
public final class MotionCaptureEngine: @unchecked Sendable {
    public static let maximumBatchSamples = 4_096
    public static let maximumPendingBatches = 8
    public static let maximumPendingSamples = 16_384
    public static let maximumPendingSamplesPerStream = 4_096
    public static let maximumPendingBytes = 2_097_152
    public static let activeLimit: Double = 120
    public static let freshnessWindow: Double = 5

    private let worker = DispatchQueue(label: "PadelStrokeLab.capture.writer", qos: .userInitiated)
    private let admission = Admission()
    // Makes admission plus dispatch one transaction against control cutoff plus dispatch.
    private let ingressLock = NSLock()
    private let metadata: RecordingMetadata
    private let clock: @Sendable () -> Double
    private let makeWriter: @Sendable () throws -> MotionCaptureWriter
    private let persistTimeline: @Sendable (CaptureTimeline) throws -> Void
    private let onChange: @Sendable (MotionCaptureSnapshot) -> Void
    private var writer: MotionCaptureWriter?
    private var timer: DispatchSourceTimer?
    private var state: MotionCaptureState = .ready
    private var detail: String?
    private var timeline: CaptureTimeline
    private var generation = UUID()
    private var segmentStart: Double?
    private var accumulated: Double = 0
    private var last: [RecordingStream: Double] = [:]
    private var segmentReceived: Set<RecordingStream> = []
    private var pending: [RecordingStream: [RecordingSample]] = [:]
    private var counts: [RecordingStream: Int] = [:]
    private var sequences: [RecordingStream: Int] = [:]
    private var chunks = 0
    private var excludedBeforeWindow = 0, excludedAfterCutoff = 0
    private var endingRequested = false

    public convenience init(metadata: RecordingMetadata, rawRoot: URL, notesRoot: URL,
                            onChange: @escaping @Sendable (MotionCaptureSnapshot) -> Void) {
        self.init(metadata: metadata, clock: { ProcessInfo.processInfo.systemUptime },
                  makeWriter: {
                      let lease = try RecordingCaptureLease(recordingID: metadata.recordingID, rawRoot: rawRoot)
                      return RealMotionCaptureWriter(try RecordingStore.create(root: rawRoot, metadata: metadata), lease: lease)
                  },
                  persistTimeline: { try SessionAnnotationsStore(root: notesRoot).saveTimeline($0) }, onChange: onChange)
    }

    init(metadata: RecordingMetadata, clock: @escaping @Sendable () -> Double,
         makeWriter: @escaping @Sendable () throws -> MotionCaptureWriter,
         persistTimeline: @escaping @Sendable (CaptureTimeline) throws -> Void = { _ in },
         onChange: @escaping @Sendable (MotionCaptureSnapshot) -> Void = { _ in }) {
        self.metadata = metadata; self.clock = clock; self.makeWriter = makeWriter
        self.persistTimeline = persistTimeline; self.onChange = onChange
        timeline = CaptureTimeline(recordingID: metadata.recordingID, clockDomainID: metadata.clock.domainID)
    }

    deinit { timer?.cancel() }

    /// Call only once the workout has actually entered running. Completion starts hardware for this generation.
    public func begin(completion: @escaping @Sendable (UUID?) -> Void) {
        worker.async {
            guard self.state == .ready else { completion(nil); return }
            do {
                try self.metadata.validate()
                guard self.metadata.streams.count == 2, self.metadata.streams.allSatisfy(\.supported) else {
                    throw RecordingError.invalid("both motion streams required")
                }
                self.writer = try self.makeWriter()
                self.state = .starting
                guard try self.openSegment(at: self.clock(), kind: .start) else { completion(nil); return }
                let timer = DispatchSource.makeTimerSource(queue: self.worker)
                timer.schedule(deadline: .now() + 1, repeating: 1)
                timer.setEventHandler { [weak engine = self] in engine?.checkTime() }
                self.timer = timer; timer.resume()
                self.publish(); completion(self.generation)
            } catch { self.fail("Could not start: \(error)", kind: .writeFailure); completion(nil) }
        }
    }

    /// False means stale/closed or overflow. Overflow is latched and terminates capture visibly.
    @discardableResult public func receive(_ batch: MotionCaptureBatch) -> Bool {
        ingressLock.lock()
        defer { ingressLock.unlock() }
        let result = admission.admit(batch)
        switch result {
        case .ignored: return false
        case .overflow:
            worker.async { self.fail("Motion buffer overflow; retained files preserved.", kind: .bufferOverflow) }
            return false
        case .accepted:
            worker.async {
                defer { self.admission.release(batch) }
                self.consume(batch)
            }
            return true
        }
    }

    public func pause(at cutoff: Double) {
        ingressLock.lock()
        defer { ingressLock.unlock() }
        admission.close(at: cutoff)
        worker.async {
            guard [.starting, .recording].contains(self.state) else { return }
            self.state = .pausing; self.publish()
            do {
                try self.event(.pauseRequested, at: cutoff)
                self.closeSegment(at: cutoff)
                try self.flushAll()
                try self.event(.paused, at: cutoff, detail: self.windowExclusions)
                self.state = .paused; self.publish()
            } catch { self.fail("Pause could not be saved: \(error)", kind: .writeFailure) }
        }
    }

    /// Called after the workout returns to running, never merely after the Resume button.
    public func resume(completion: @escaping @Sendable (UUID?) -> Void) {
        worker.async {
            guard self.state == .paused else { completion(nil); return }
            guard self.chunks < RecordingLimits.chunks - 2 else {
                self.finish(at: self.clock(), limit: "Chunk limit reached; begin a new set.")
                completion(nil); return
            }
            do {
                let now = self.clock()
                try self.event(.resumeRequested, at: now)
                self.state = .resuming
                guard try self.openSegment(at: now, kind: .resumed) else { completion(nil); return }
                self.publish(); completion(self.generation)
            } catch { self.fail("Resume could not be saved: \(error)", kind: .writeFailure); completion(nil) }
        }
    }

    public func stop(at cutoff: Double) {
        ingressLock.lock()
        defer { ingressLock.unlock() }
        admission.seal(at: cutoff)
        worker.async { self.finish(at: cutoff, limit: nil) }
    }

    public func interrupt(_ reason: String, generation: UUID? = nil) {
        ingressLock.lock()
        defer { ingressLock.unlock() }
        guard admission.markFailure(at: clock(), generation: generation) else { return }
        worker.async { self.fail(reason, kind: .interruption) }
    }

    public func snapshot() async -> MotionCaptureSnapshot {
        await withCheckedContinuation { continuation in
            worker.async { continuation.resume(returning: self.currentSnapshot()) }
        }
    }

    /// Deterministic watchdog seam; production also uses a dispatch timer owned by the writer.
    func checkWatchdog() async {
        await withCheckedContinuation { continuation in
            worker.async { self.checkTime(); continuation.resume() }
        }
    }

    private func openSegment(at now: Double, kind: RecordingCaptureEventKind) throws -> Bool {
        guard now.isFinite, now >= metadata.clock.monotonicAnchorSeconds else {
            throw RecordingError.invalid("capture clock")
        }
        generation = UUID(); segmentStart = now; segmentReceived.removeAll()
        try event(kind, at: now)
        return admission.open(generation: generation, deadline: now + Self.activeLimit - accumulated)
    }

    private func consume(_ batch: MotionCaptureBatch) {
        guard [.starting, .recording, .resuming].contains(state), batch.generation == generation,
              let start = segmentStart else { return }
        let cutoff = admission.cutoff
        do {
            for sample in batch.samples {
                guard sample.timestamp.isFinite, sample.timestamp >= 0,
                      sample.timestamp <= clock(),
                      sample.values.count == batch.stream.componentCount,
                      sample.values.allSatisfy(\.isFinite) else {
                    throw RecordingError.invalid("invalid or out-of-order source timestamp/components")
                }
                // The original source time is retained; post-control/deadline samples are outside this segment.
                if sample.timestamp < start { excludedBeforeWindow += 1; continue }
                if sample.timestamp > cutoff { excludedAfterCutoff += 1; continue }
                guard last[batch.stream].map({ sample.timestamp > $0 }) ?? true else {
                    throw RecordingError.invalid("duplicate or backwards eligible source timestamp")
                }
                last[batch.stream] = sample.timestamp
                segmentReceived.insert(batch.stream)
                pending[batch.stream, default: []].append(sample)
                counts[batch.stream, default: 0] += 1
                let buffer = pending[batch.stream]!
                if !endingRequested && (sample.timestamp - buffer[0].timestamp >= 2 || buffer.count >= 4_096) {
                    if chunks >= RecordingLimits.chunks - 2 {
                        scheduleFinish(at: min(clock(), cutoff), limit: "Chunk limit reached; frequent pauses can shorten a set.")
                        continue
                    }
                    try flush(batch.stream)
                    if chunks >= RecordingLimits.chunks - 2 {
                        scheduleFinish(at: min(clock(), cutoff), limit: "Chunk limit reached; frequent pauses can shorten a set.")
                        continue
                    }
                }
            }
            if segmentReceived.count == 2 { state = .recording }
            checkTime(); publish()
        } catch { fail("Motion data rejected: \(error)", kind: .interruption) }
    }

    private func checkTime() {
        guard !endingRequested, [.starting, .recording, .resuming].contains(state), let start = segmentStart else { return }
        let now = clock()
        if now - start + accumulated >= Self.activeLimit {
            scheduleFinish(at: start + Self.activeLimit - accumulated, limit: "120 active-second tester limit reached.")
            return
        }
        for stream in RecordingStream.allCases {
            let reference = segmentReceived.contains(stream) ? (last[stream] ?? start) : start
            if now - reference >= Self.freshnessWindow {
                scheduleFailure("\(stream == .accelerometer ? "Accelerometer" : "Device motion") has no fresh data for 5 seconds.")
                return
            }
        }
        publish()
    }

    // A timer/limit is a control boundary too. Enqueue the seal behind EVERY batch admitted
    // before the same ingress transaction; inline finalization would silently lose queued tails.
    private func scheduleFinish(at cutoff: Double, limit: String) {
        guard !endingRequested else { return }
        endingRequested = true
        ingressLock.withLock {
            admission.seal(at: cutoff)
            worker.async { self.finish(at: cutoff, limit: limit) }
        }
    }
    private func scheduleFailure(_ reason: String) {
        guard !endingRequested else { return }
        endingRequested = true
        ingressLock.withLock {
            admission.seal(at: clock())
            worker.async { self.fail(reason, kind: .interruption) }
        }
    }

    private func closeSegment(at cutoff: Double) {
        if let start = segmentStart { accumulated += max(0, cutoff - start) }
        accumulated = min(accumulated, Self.activeLimit); segmentStart = nil
    }

    private func finish(at cutoff: Double, limit: String?) {
        guard !state.isTerminal, state != .ready, state != .stopping else { return }
        admission.close(at: cutoff)
        state = .stopping; detail = limit; publish()
        do {
            try event(limit == nil ? .stopRequested : .limitReached, at: cutoff, detail: limit)
            closeSegment(at: cutoff)
            try flushAll()
            // Save the stop boundary first. A timeline failure must never leave a Saved UI.
            try event(.stopped, at: cutoff, detail: windowExclusions)
            try writer?.finalize(at: cutoff, reason: .userStopped)
            writer?.releaseCapture()
            state = .saved; timer?.cancel(); timer = nil; publish()
        } catch { fail("Finalization failed: \(error)", kind: .writeFailure) }
    }

    private func fail(_ message: String, kind: RecordingCaptureEventKind) {
        guard !state.isTerminal else { return }
        let now = clock()
        admission.close(at: now)
        closeSegment(at: min(now, admission.cutoff))
        detail = String(decoding: message.utf8.prefix(120), as: UTF8.self); state = kind == .writeFailure ? .failed : .interrupted
        // Best effort preserves all already-published chunks. Failure remains visible and never becomes Saved.
        do {
            try event(kind, at: max(now, timeline.events.last?.timestamp ?? 0), detail: detail)
            try flushAll()
            try writer?.finalize(at: now, reason: .interrupted)
        } catch { detail = String((message + " Retained files require recovery inspection.").prefix(220)) }
        writer?.releaseCapture()
        timer?.cancel(); timer = nil; publish()
    }

    private func flush(_ stream: RecordingStream) throws {
        guard let samples = pending[stream], !samples.isEmpty else { return }
        guard chunks < RecordingLimits.chunks else { throw RecordingError.limit("terminal chunk reserve") }
        let chunk = try RecordingChunk(recordingID: metadata.recordingID, clockDomainID: metadata.clock.domainID,
                                       stream: stream, sequence: sequences[stream, default: 0], samples: samples)
        guard let writer else { throw RecordingError.closed }
        do { try writer.append(chunk) }
        catch { throw RecordingError.integrity("writer append failed: \(error)") }
        chunks += 1; sequences[stream, default: 0] += 1; pending[stream] = []
    }

    private var windowExclusions: String {
        "Excluded outside capture windows: before=\(excludedBeforeWindow), after=\(excludedAfterCutoff); tail unverified"
    }

    private func flushAll() throws { for stream in RecordingStream.allCases { try flush(stream) } }

    private func event(_ kind: RecordingCaptureEventKind, at time: Double, detail: String? = nil) throws {
        var updated = timeline
        updated.events.append(try RecordingCaptureEvent(kind: kind, timestamp: time, detail: detail))
        try updated.validate(metadata: metadata)
        try persistTimeline(updated); timeline = updated
    }

    private func currentSnapshot() -> MotionCaptureSnapshot {
        MotionCaptureSnapshot(recordingID: metadata.recordingID, hasLocalRecording: writer != nil, state: state,
            activeSeconds: min(Self.activeLimit, accumulated + (segmentStart.map { max(0, min(clock(), admission.cutoff) - $0) } ?? 0)),
            accelerometerCount: counts[.accelerometer, default: 0], deviceMotionCount: counts[.deviceMotion, default: 0],
            chunks: chunks, excludedBeforeWindow: excludedBeforeWindow, excludedAfterCutoff: excludedAfterCutoff, lastAccelerometerTimestamp: last[.accelerometer], lastDeviceMotionTimestamp: last[.deviceMotion],
            detail: detail, timeline: timeline)
    }
    private func publish() { onChange(currentSnapshot()) }
}

/// Non-Sendable by design: created, used and released only on the capture worker.
protocol MotionCaptureWriter: AnyObject {
    func append(_ chunk: RecordingChunk) throws
    func finalize(at timestamp: Double, reason: RecordingStopReason) throws
    func releaseCapture()
}
extension MotionCaptureWriter { func releaseCapture() {} }
private final class RealMotionCaptureWriter: MotionCaptureWriter {
    let store: RecordingStore
    private var lease: RecordingCaptureLease?
    init(_ store: RecordingStore, lease: RecordingCaptureLease) { self.store = store; self.lease = lease }
    func releaseCapture() { lease = nil }
    func append(_ chunk: RecordingChunk) throws { try store.append(chunk) }
    func finalize(at timestamp: Double, reason: RecordingStopReason) throws {
        try store.finalize(stopRequestTimestamp: timestamp, reason: reason)
    }
}

private final class Admission: @unchecked Sendable {
    enum Result { case accepted, ignored, overflow }
    private let lock = NSLock()
    private var generation: UUID?
    private var accepting = false
    private var sealed = false
    private var overflowed = false
    private var failureScheduled = false
    private var batches = 0, samples = 0, bytes = 0
    private var samplesByStream: [RecordingStream: Int] = [:]
    private var boundary = Double.infinity
    var cutoff: Double { lock.withLock { boundary } }
    func open(generation: UUID, deadline: Double) -> Bool {
        lock.withLock {
            guard !sealed else { return false }
            self.generation = generation; boundary = deadline; accepting = true; return true
        }
    }
    func seal(at cutoff: Double) { lock.withLock { sealed = true; boundary = min(boundary, cutoff); accepting = false } }
    func close(at cutoff: Double) { lock.withLock { boundary = min(boundary, cutoff); accepting = false } }
    func markFailure(at cutoff: Double, generation: UUID?) -> Bool {
        lock.withLock {
            guard !failureScheduled, !overflowed, generation == nil || (accepting && generation == self.generation) else { return false }
            failureScheduled = true; sealed = true; boundary = min(boundary, cutoff); accepting = false; return true
        }
    }
    func admit(_ batch: MotionCaptureBatch) -> Result {
        lock.withLock {
            guard accepting, batch.generation == generation, !batch.samples.isEmpty else { return .ignored }
            let size = batch.samples.count * (batch.stream.componentCount + 1) * 8
            guard batch.samples.count <= MotionCaptureEngine.maximumBatchSamples,
                  batch.samples.allSatisfy({ $0.values.count == batch.stream.componentCount }),
                  batches < MotionCaptureEngine.maximumPendingBatches,
                  samples + batch.samples.count <= MotionCaptureEngine.maximumPendingSamples,
                  samplesByStream[batch.stream, default: 0] + batch.samples.count <= MotionCaptureEngine.maximumPendingSamplesPerStream,
                  bytes + size <= MotionCaptureEngine.maximumPendingBytes else {
                accepting = false; sealed = true
                guard !overflowed else { return .ignored }; overflowed = true
                return .overflow
            }
            batches += 1; samples += batch.samples.count; bytes += size
            samplesByStream[batch.stream, default: 0] += batch.samples.count
            return .accepted
        }
    }
    func release(_ batch: MotionCaptureBatch) {
        lock.withLock {
            batches -= 1; samples -= batch.samples.count
            samplesByStream[batch.stream, default: 0] -= batch.samples.count
            bytes -= batch.samples.count * (batch.stream.componentCount + 1) * 8
        }
    }
}
