import Foundation
import Testing
@testable import PadelCore

private final class CaptureClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Double = 10
    func now() -> Double { lock.withLock { value } }
    func set(_ value: Double) { lock.withLock { self.value = value } }
}
private final class WriterEvidence: @unchecked Sendable {
    let lock = NSLock()
    var stored: [RecordingChunk] = []
    var finalReason: RecordingStopReason?
    var failAppend = false
    var failFinalize = false
    var onAppend: (@Sendable () -> Void)?
    func chunks() -> [RecordingChunk] { lock.withLock { stored } }
}
private final class TestCaptureWriter: MotionCaptureWriter {
    let evidence: WriterEvidence
    let real: RecordingStore?
    init(_ evidence: WriterEvidence, real: RecordingStore? = nil) { self.evidence = evidence; self.real = real }
    func append(_ chunk: RecordingChunk) throws {
        evidence.onAppend?()
        if evidence.failAppend { throw RecordingError.io(operation: "injected append", code: 28) }
        try real?.append(chunk)
        evidence.lock.withLock { evidence.stored.append(chunk) }
    }
    func finalize(at timestamp: Double, reason: RecordingStopReason) throws {
        if evidence.failFinalize { throw RecordingError.io(operation: "injected finalize", code: 28) }
        try real?.finalize(stopRequestTimestamp: timestamp, reason: reason)
        evidence.lock.withLock { evidence.finalReason = reason }
    }
}
private func begin(_ engine: MotionCaptureEngine) async -> UUID? {
    await withCheckedContinuation { continuation in engine.begin { continuation.resume(returning: $0) } }
}
private func resume(_ engine: MotionCaptureEngine) async -> UUID? {
    await withCheckedContinuation { continuation in engine.resume { continuation.resume(returning: $0) } }
}
private func batch(_ generation: UUID, _ stream: RecordingStream, _ times: [Double]) -> MotionCaptureBatch {
    .init(generation: generation, stream: stream, samples: times.map {
        RecordingSample(timestamp: $0, values: (0..<stream.componentCount).map { Double($0) + 0.125 })
    })
}
private func batch(_ generation: UUID, _ times: [Double]) -> MotionCaptureBatch { batch(generation, .accelerometer, times) }
private func engine(_ clock: CaptureClock, _ evidence: WriterEvidence) throws -> MotionCaptureEngine {
    MotionCaptureEngine(metadata: try recordingMetadata(), clock: { clock.now() },
                        makeWriter: { TestCaptureWriter(evidence) })
}

private func waitForWriter(_ semaphore: DispatchSemaphore) async -> Bool {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async { continuation.resume(returning: semaphore.wait(timeout: .now() + 2) == .success) }
    }
}

struct MotionCaptureEngineTests {
    @Test func readinessRequiresBothActualStreamsAndRetainsOriginalValues() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let engine = try engine(clock, evidence)
        let generation = try #require(await begin(engine))
        clock.set(11)
        #expect(engine.receive(batch(generation, [10.125, 10.875])))
        #expect(await engine.snapshot().state == .starting)
        #expect(engine.receive(batch(generation, .deviceMotion, [10.25, 10.9])))
        #expect(await engine.snapshot().state == .recording)
        engine.stop(at: 11)
        let result = await engine.snapshot()
        #expect(result.state == .saved)
        #expect(result.accelerometerCount == 2 && result.deviceMotionCount == 2)
        #expect(evidence.chunks()[0].samples[0].timestamp.bitPattern == 10.125.bitPattern)
        #expect(evidence.chunks()[0].samples[0].values == [0.125, 1.125, 2.125])
        #expect(result.timeline.terminalTailVerified == false)
        #expect(await begin(engine) == nil)
    }

    @Test func pauseResumeFencesGenerationAndExcludesPauseTime() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let engine = try engine(clock, evidence)
        let first = try #require(await begin(engine))
        clock.set(11)
        engine.receive(batch(first, [10.5])); engine.receive(batch(first, .deviceMotion, [10.6]))
        _ = await engine.snapshot()
        engine.pause(at: 11)
        #expect(await engine.snapshot().state == .paused)
        clock.set(101)
        let second = try #require(await resume(engine))
        #expect(first != second)
        #expect(!engine.receive(batch(first, [101])))
        clock.set(102)
        engine.receive(batch(second, [101.5])); engine.receive(batch(second, .deviceMotion, [101.6]))
        _ = await engine.snapshot()
        engine.stop(at: 102)
        let result = await engine.snapshot()
        #expect(result.state == .saved && result.activeSeconds == 2)
        #expect(result.accelerometerCount == 2 && evidence.chunks().count == 4)
        #expect(result.timeline.events.map(\.kind) == [.start, .pauseRequested, .paused, .resumeRequested, .resumed, .stopRequested, .stopped])
    }

    @Test(arguments: [[10.5, 10.5], [10.5, 10.4], [-0.1], [Double.nan], [12]])
    func invalidSourceTimeInterrupts(times: [Double]) async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let engine = try engine(clock, evidence), generation = try #require(await begin(engine))
        clock.set(11); engine.receive(batch(generation, times))
        #expect(await engine.snapshot().state == .interrupted)
        #expect(!engine.receive(batch(generation, [10.9])))
    }

    @Test func missingFirstStreamAndFreshnessHaveOwnerWatchdog() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let engine = try engine(clock, evidence), generation = try #require(await begin(engine))
        clock.set(14); engine.receive(batch(generation, [13.9])); _ = await engine.snapshot()
        clock.set(15); await engine.checkWatchdog()
        let snapshot = await engine.snapshot()
        #expect(snapshot.state == .interrupted)
        #expect(snapshot.detail?.contains("Device motion") == true)
        #expect(snapshot.accelerometerCount == 1)
    }

    @Test func realStoreFinalizationAndRecoveryPreserveCounts() async throws {
        let fixture = try RecordingDirectoryFixture(), clock = CaptureClock(), evidence = WriterEvidence()
        let metadata = try recordingMetadata(), root = fixture.root
        let engine = MotionCaptureEngine(metadata: metadata, clock: { clock.now() }, makeWriter: {
            TestCaptureWriter(evidence, real: try RecordingStore.create(root: root, metadata: metadata))
        })
        let generation = try #require(await begin(engine)); clock.set(12)
        engine.receive(batch(generation, [10.2, 11.9])); engine.receive(batch(generation, .deviceMotion, [10.3, 11.8]))
        _ = await engine.snapshot(); engine.stop(at: 12)
        #expect(await engine.snapshot().state == .saved)
        let report = try fixture.inspect()
        #expect(report.status == .finalized && report.issues.isEmpty)
        #expect(report.chunks.reduce(0) { $0 + $1.sampleCount } == 4)
        #expect(report.finalization?.stopRequestTimestamp == 12)
    }

    @Test func oversizedBatchLatchesOverflowWithoutAdmission() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let engine = try engine(clock, evidence), generation = try #require(await begin(engine))
        let oversized = Array(repeating: 10.0, count: MotionCaptureEngine.maximumBatchSamples + 1)
        #expect(!engine.receive(batch(generation, oversized)))
        let result = await engine.snapshot()
        #expect(result.state == .interrupted && result.accelerometerCount == 0)
        #expect(result.timeline.events.last?.kind == .bufferOverflow)
    }

    @Test func cutoffAppliesBeforeQueuedBatchDrains() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        evidence.onAppend = { entered.signal(); release.wait() }
        let engine = try engine(clock, evidence), generation = try #require(await begin(engine))
        clock.set(14)
        engine.receive(batch(generation, [10, 12]))
        #expect(await waitForWriter(entered))
        engine.receive(batch(generation, .deviceMotion, [12.1, 12.5, 13.5]))
        engine.stop(at: 13)
        // One checkpoint is blocked; tail flush also uses the writer hook.
        release.signal(); release.signal()
        let result = await engine.snapshot()
        #expect(result.state == .saved && result.deviceMotionCount == 2)
        #expect(evidence.chunks().flatMap(\.samples).allSatisfy { $0.timestamp <= 13 })
    }

    @Test func automaticLimitDrainsAlreadyAdmittedOtherStreamBeforeSaved() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        evidence.onAppend = { entered.signal(); release.wait() }
        let engine = try engine(clock, evidence), generation = try #require(await begin(engine))
        clock.set(12); engine.receive(batch(generation, [10, 12]))
        #expect(await waitForWriter(entered))
        clock.set(131)
        #expect(engine.receive(batch(generation, .deviceMotion, [129.5, 130.5])))
        for _ in 0..<4 { release.signal() }
        // The auto-stop is enqueued by the blocked batch after this barrier may already be queued.
        _ = await engine.snapshot()
        let result = await engine.snapshot()
        #expect(result.state == .saved && result.deviceMotionCount == 1)
        #expect(result.excludedAfterCutoff == 1)
        #expect(evidence.chunks().first(where: { $0.stream == .deviceMotion })?.samples.map(\.timestamp) == [129.5])
    }

    @Test func queueBatchLimitFailsClosedUnderSlowWriter() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        evidence.onAppend = { entered.signal(); release.wait() }
        let engine = try engine(clock, evidence), generation = try #require(await begin(engine))
        clock.set(13); engine.receive(batch(generation, [10, 12]))
        #expect(await waitForWriter(entered))
        for index in 0..<7 { #expect(engine.receive(batch(generation, [12.1 + Double(index) / 100]))) }
        #expect(!engine.receive(batch(generation, [12.9])))
        for _ in 0..<10 { release.signal() }
        #expect(await engine.snapshot().state == .interrupted)
    }

    @Test(arguments: [true, false]) func writerFailureNeverReportsSaved(append: Bool) async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        evidence.failAppend = append; evidence.failFinalize = !append
        let engine = try engine(clock, evidence), generation = try #require(await begin(engine))
        clock.set(11); engine.receive(batch(generation, [10.5])); _ = await engine.snapshot()
        engine.stop(at: 11)
        #expect(await engine.snapshot().state == .failed)
    }


    @Test func explicitlyExcludedPrebufferIsCountedWithoutTimestampRewrite() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let engine = try engine(clock, evidence), generation = try #require(await begin(engine))
        clock.set(11); engine.receive(batch(generation, [9.9, 10.1])); _ = await engine.snapshot()
        engine.stop(at: 11)
        let result = await engine.snapshot()
        #expect(result.state == .saved && result.excludedBeforeWindow == 1)
        #expect(evidence.chunks()[0].samples.map(\.timestamp) == [10.1])
        #expect(result.timeline.events.last?.detail?.contains("before=1") == true)
    }

    @Test func frequentPauseChunkReserveStopsWithoutOverflow() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let engine = try engine(clock, evidence)
        var generation = try #require(await begin(engine))
        for index in 0..<127 {
            let time = 10 + Double(index) * 0.1
            clock.set(time)
            engine.receive(batch(generation, [time])); engine.receive(batch(generation, .deviceMotion, [time]))
            _ = await engine.snapshot()
            clock.set(time + 0.01); engine.pause(at: time + 0.01)
            #expect(await engine.snapshot().state == .paused)
            clock.set(time + 0.02)
            if index < 126 { generation = try #require(await resume(engine)) }
        }
        #expect(await resume(engine) == nil)
        let result = await engine.snapshot()
        #expect(result.state == .saved && result.chunks == 254)
        #expect(result.detail?.contains("Chunk limit") == true)
        #expect(abs(result.activeSeconds - 11.35) < 0.000_001)
    }

    @Test func receiveAndStopRaceRetainsEveryAcceptedPrecutoffBatch() async throws {
        for _ in 0..<32 {
            let clock = CaptureClock(), evidence = WriterEvidence()
            let engine = try engine(clock, evidence), generation = try #require(await begin(engine))
            clock.set(11)
            let accepted = await withTaskGroup(of: Bool.self) { group in
                group.addTask { engine.receive(batch(generation, [10.5])) }
                group.addTask { engine.stop(at: 11); return false }
                var accepted = false
                for await value in group { accepted = accepted || value }
                return accepted
            }
            let result = await engine.snapshot()
            #expect(result.state == .saved)
            #expect(result.accelerometerCount == (accepted ? 1 : 0))
            #expect(evidence.chunks().flatMap(\.samples).count == (accepted ? 1 : 0))
        }
    }

    @Test func stopSealsAdmissionWhileResumeIsPersisting() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let engine = MotionCaptureEngine(metadata: try recordingMetadata(), clock: { clock.now() },
            makeWriter: { TestCaptureWriter(evidence) }, persistTimeline: { timeline in
                if timeline.events.last?.kind == .resumed { entered.signal(); release.wait() }
            })
        let first = try #require(await begin(engine))
        clock.set(11); engine.receive(batch(first, [10.5])); _ = await engine.snapshot()
        engine.pause(at: 11); #expect(await engine.snapshot().state == .paused)
        clock.set(12)
        async let nextGeneration = resume(engine)
        #expect(await waitForWriter(entered))
        clock.set(13); engine.stop(at: 13); release.signal()
        #expect(await nextGeneration == nil)
        #expect(await engine.snapshot().state == .saved)
        #expect(!engine.receive(batch(first, [12.5])))
        #expect(evidence.chunks().flatMap(\.samples).map(\.timestamp) == [10.5])
    }

    @Test func lateSourceErrorsCannotInterruptClosedOrNewGeneration() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let engine = try engine(clock, evidence), first = try #require(await begin(engine))
        clock.set(11); engine.receive(batch(first, [10.5])); _ = await engine.snapshot()
        engine.pause(at: 11)
        engine.interrupt("late old callback", generation: first)
        #expect(await engine.snapshot().state == .paused)
        clock.set(12); let second = try #require(await resume(engine))
        engine.interrupt("late old callback after resume", generation: first)
        clock.set(13)
        engine.receive(batch(second, [12.5])); engine.receive(batch(second, .deviceMotion, [12.6]))
        #expect(await engine.snapshot().state == .recording)
        engine.stop(at: 13); #expect(await engine.snapshot().state == .saved)
    }

    @Test func twoChunkReserveHoldsMaximumDeviceMotionTailAndQueuedBatch() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let engine = try engine(clock, evidence)
        var generation = try #require(await begin(engine))
        for index in 0..<126 {
            let time = 10 + Double(index) * 0.1
            clock.set(time)
            engine.receive(batch(generation, [time])); engine.receive(batch(generation, .deviceMotion, [time]))
            _ = await engine.snapshot()
            clock.set(time + 0.01); engine.pause(at: time + 0.01); _ = await engine.snapshot()
            clock.set(time + 0.02); generation = try #require(await resume(engine))
        }
        let start = clock.now()
        clock.set(start + 0.5)
        engine.receive(batch(generation, .deviceMotion, (1...4095).map { start + Double($0) / 10000 }))
        _ = await engine.snapshot()
        clock.set(start + 2.1); engine.receive(batch(generation, [start + 0.01, start + 2.01]))
        #expect(await engine.snapshot().chunks == 253)
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        evidence.onAppend = { entered.signal(); release.wait() }
        clock.set(start + 4.3); engine.receive(batch(generation, [start + 2.1, start + 4.2]))
        #expect(await waitForWriter(entered))
        clock.set(start + 4.8)
        #expect(engine.receive(batch(generation, .deviceMotion, (1...4096).map { start + 4.35 + Double($0) / 10000 })))
        for _ in 0..<4 { release.signal() }
        _ = await engine.snapshot()
        let result = await engine.snapshot()
        #expect(result.state == .saved && result.chunks == 255)
        #expect(evidence.chunks().last?.samples.count == 8191)
        #expect(result.deviceMotionCount == 126 + 8191)
    }

    @Test func realInterruptedStoreRetainsVerifiedDurablePrefix() async throws {
        let fixture = try RecordingDirectoryFixture(), clock = CaptureClock(), evidence = WriterEvidence()
        let metadata = try recordingMetadata(), root = fixture.root
        let engine = MotionCaptureEngine(metadata: metadata, clock: { clock.now() }, makeWriter: {
            TestCaptureWriter(evidence, real: try RecordingStore.create(root: root, metadata: metadata))
        })
        let generation = try #require(await begin(engine)); clock.set(12)
        engine.receive(batch(generation, [10, 12])); _ = await engine.snapshot()
        engine.interrupt("injected hardware failure", generation: generation)
        #expect(await engine.snapshot().state == .interrupted)
        let recovered = try fixture.inspect()
        #expect(recovered.issues.isEmpty && recovered.chunks[0].sampleCount == 2)
        #expect(recovered.finalization?.reason == .interrupted)
    }

    @Test func productionWriterLeaseProtectsActiveAndPausedRecordingUntilSealed() async throws {
        let fixture = try RecordingDirectoryFixture(), paths = try RecordingPaths(base: fixture.root)
        let engine = MotionCaptureEngine(metadata: try recordingMetadata(), rawRoot: paths.rawRoot,
                                         notesRoot: paths.notesRoot, onChange: { _ in })
        let generation = try #require(await begin(engine))
        #expect(throws: (any Error).self) { try RecordingCaptureLease(recordingID: recordingTestID, rawRoot: paths.rawRoot) }
        let timestamp = ProcessInfo.processInfo.systemUptime
        engine.receive(batch(generation, [timestamp])); _ = await engine.snapshot()
        engine.pause(at: ProcessInfo.processInfo.systemUptime)
        #expect(await engine.snapshot().state == .paused)
        #expect(throws: (any Error).self) { try RecordingCaptureLease(recordingID: recordingTestID, rawRoot: paths.rawRoot) }
        engine.stop(at: ProcessInfo.processInfo.systemUptime)
        #expect(await engine.snapshot().state == .saved)
        _ = try RecordingCaptureLease(recordingID: recordingTestID, rawRoot: paths.rawRoot)
        #expect(try RecordingStore.inspect(root: paths.rawRoot, recordingID: recordingTestID).chunks[0].sampleCount == 1)
    }

    @Test func activeTimeCapSealsAtDeadline() async throws {
        let clock = CaptureClock(), evidence = WriterEvidence()
        let engine = try engine(clock, evidence), generation = try #require(await begin(engine))
        for step in 0..<60 {
            let time = 10 + Double(step * 2)
            clock.set(time)
            engine.receive(batch(generation, [time])); engine.receive(batch(generation, .deviceMotion, [time]))
            _ = await engine.snapshot()
        }
        clock.set(131); await engine.checkWatchdog()
        let result = await engine.snapshot()
        #expect(result.state == .saved && result.activeSeconds == 120)
        #expect(result.detail?.contains("120") == true)
        #expect(result.timeline.events.last?.timestamp == 130)
    }
}
