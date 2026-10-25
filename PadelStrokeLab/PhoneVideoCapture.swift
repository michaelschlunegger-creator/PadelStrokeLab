@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import Observation
import UIKit

nonisolated struct PhoneVideoFormat: Equatable, Sendable {
    let width: Int
    let height: Int
    let framesPerSecond: Int
    let rotationDegrees: Int
}

nonisolated enum PhoneVideoTrack: Equatable, Sendable { case video, audio }
nonisolated enum PhoneVideoStopReason: Equatable, Sendable {
    case user, closed, background, durationLimit, interrupted(String)
}
nonisolated enum PhoneVideoCaptureError: Error, Equatable {
    case unavailable, permission, inactive, busy, cancelled, unsupportedFormat, invalidTiming
}

/// Source observations only: neither accepted writer input nor retained/playable media.
nonisolated struct PhoneVideoSampleTiming: Sendable {
    let presentationTime: CMTime
    let duration: CMTime
    let hostTime: CMTime
    let clockEpoch: UUID
    let hostBracket: ClosedRange<Double>
    let uptimeBracket: ClosedRange<Double>

    static func read(_ sample: CMSampleBuffer, synchronizationClock: CMClock,
                     clockEpoch: UUID) throws -> Self {
        guard CMSampleBufferIsValid(sample), CMSampleBufferDataIsReady(sample) else {
            throw PhoneVideoCaptureError.invalidTiming
        }
        let pts = CMSampleBufferGetPresentationTimeStamp(sample)
        let duration = CMSampleBufferGetDuration(sample)
        let hostClock = CMClockGetHostTimeClock()
        let host = CMSyncConvertTime(pts, from: synchronizationClock, to: hostClock)
        // Preserve a bracket rather than assuming uptime and Core Media host time
        // are numerically interchangeable. PTS remains the source measurement time.
        let uptimeBefore = ProcessInfo.processInfo.systemUptime
        let hostBefore = CMTimeGetSeconds(CMClockGetTime(hostClock))
        let hostAfter = CMTimeGetSeconds(CMClockGetTime(hostClock))
        let uptimeAfter = ProcessInfo.processInfo.systemUptime
        let durationKnown = duration.isNumeric && duration.timescale > 0 && CMTimeCompare(duration, .zero) >= 0
        guard valid(pts), valid(host), durationKnown || !duration.isValid,
              [uptimeBefore, uptimeAfter, hostBefore, hostAfter].allSatisfy({ $0.isFinite && $0 >= 0 }),
              uptimeBefore <= uptimeAfter, hostBefore <= hostAfter else {
            throw PhoneVideoCaptureError.invalidTiming
        }
        return Self(presentationTime: pts, duration: duration, hostTime: host, clockEpoch: clockEpoch,
                    hostBracket: hostBefore...hostAfter, uptimeBracket: uptimeBefore...uptimeAfter)
    }

    private static func valid(_ time: CMTime) -> Bool {
        time.isNumeric && time.timescale > 0 && CMTimeGetSeconds(time).isFinite
    }
}

/// This immutable buffer is borrowed synchronously on the capture serial queue.
/// A sink must not mutate it, start a Task per buffer, or retain an unbounded queue.
nonisolated struct PhoneVideoSample: @unchecked Sendable {
    let buffer: CMSampleBuffer
    let track: PhoneVideoTrack
    let timing: PhoneVideoSampleTiming
    let generation: UUID
}

nonisolated struct PhoneVideoCaptureSnapshot: Sendable {
    var generation: UUID?
    var firstVideo: PhoneVideoSampleTiming?
    var lastVideo: PhoneVideoSampleTiming?
    var firstAudio: PhoneVideoSampleTiming?
    var lastAudio: PhoneVideoSampleTiming?
    var videoSamples = 0
    var audioSamples = 0
    var droppedVideoSamples = 0
    var inferredAudioGaps = 0
    var largestVideoInterval = 0.0
    var hasBothTracks: Bool { firstVideo != nil && firstAudio != nil }
}

/// Serialized production callback gate. Closing or corrupt timing is irreversible.
/// It bounds its memory to first/last observations, counts and one current buffer.
nonisolated final class PhoneVideoSampleGate {
    private let generation: UUID, clockEpoch: UUID
    private var closed = false
    private(set) var snapshot: PhoneVideoCaptureSnapshot

    init(generation: UUID, clockEpoch: UUID) {
        self.generation = generation; self.clockEpoch = clockEpoch
        snapshot = PhoneVideoCaptureSnapshot(generation: generation)
    }

    func accept(_ buffer: CMSampleBuffer, track: PhoneVideoTrack, synchronizationClock: CMClock,
                clockEpoch: UUID, generation: UUID) throws -> PhoneVideoSample? {
        guard !closed, generation == self.generation else { return nil }
        do {
            guard clockEpoch == self.clockEpoch else { throw PhoneVideoCaptureError.invalidTiming }
            guard CMSampleBufferGetNumSamples(buffer) > 0, let description = CMSampleBufferGetFormatDescription(buffer),
                  CMFormatDescriptionGetMediaType(description) == (track == .video ? kCMMediaType_Video : kCMMediaType_Audio)
            else { throw PhoneVideoCaptureError.invalidTiming }
            let timing = try PhoneVideoSampleTiming.read(buffer, synchronizationClock: synchronizationClock,
                                                        clockEpoch: clockEpoch)
            let otherTrack = track == .video ? snapshot.firstAudio : snapshot.firstVideo
            if let otherTrack {
                guard timing.presentationTime.epoch == otherTrack.presentationTime.epoch,
                      timing.hostTime.epoch == otherTrack.hostTime.epoch else { throw PhoneVideoCaptureError.invalidTiming }
            }
            let previous = track == .video ? snapshot.lastVideo : snapshot.lastAudio
            if let previous {
                guard timing.presentationTime.epoch == previous.presentationTime.epoch,
                      timing.hostTime.epoch == previous.hostTime.epoch,
                      CMTimeCompare(timing.presentationTime, previous.presentationTime) > 0,
                      CMTimeCompare(timing.hostTime, previous.hostTime) > 0 else {
                    throw PhoneVideoCaptureError.invalidTiming
                }
                let interval = CMTimeGetSeconds(CMTimeSubtract(timing.presentationTime, previous.presentationTime))
                if track == .video { snapshot.largestVideoInterval = max(snapshot.largestVideoInterval, interval) }
                else if interval > CMTimeGetSeconds(previous.duration) + 0.001 { snapshot.inferredAudioGaps += 1 }
            }
            if track == .video {
                if snapshot.firstVideo == nil { snapshot.firstVideo = timing }
                snapshot.lastVideo = timing; snapshot.videoSamples += 1
            } else {
                if snapshot.firstAudio == nil { snapshot.firstAudio = timing }
                snapshot.lastAudio = timing; snapshot.audioSamples += 1
            }
            return PhoneVideoSample(buffer: buffer, track: track, timing: timing, generation: generation)
        } catch { closed = true; throw error }
    }

    func noteVideoDrop() { if !closed { snapshot.droppedVideoSamples += 1 } }
    func close() { closed = true }
}

nonisolated enum PhoneVideoCaptureHardwarePolicy {
    static func allowsCamera(arguments: [String], environment: [String: String], isSimulator: Bool) -> Bool {
        !isSimulator && !arguments.contains(where: { $0.contains("fixture") || $0.contains("uitest") }) &&
            !environment.keys.contains(where: { $0.hasPrefix("XCTest") || $0.hasPrefix("XCInject") }) &&
            environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    }
}

@MainActor protocol PhoneVideoIdleTimer: AnyObject { var isIdleTimerDisabled: Bool { get set } }
@MainActor private final class NativePhoneVideoIdleTimer: PhoneVideoIdleTimer {
    var isIdleTimerDisabled: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
}

@MainActor protocol PhoneVideoCaptureHardware: AnyObject {
    var isAvailable: Bool { get }
    var previewSession: AVCaptureSession? { get }
    var onInterruption: (@MainActor @Sendable (String) -> Void)? { get set }
    var onAcquisition: (@MainActor @Sendable (PhoneVideoCaptureSnapshot) -> Void)? { get set }
    var onStopped: (@MainActor @Sendable (PhoneVideoStopReason) -> Void)? { get set }
    func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus
    func requestAccess(for mediaType: AVMediaType) async -> Bool
    func startPreview() async throws -> PhoneVideoFormat
    func startCapture(generation: UUID, maximumDuration: Double,
                      sampleSink: @escaping @Sendable (PhoneVideoSample) -> Void) async throws
    func snapshot() async -> PhoneVideoCaptureSnapshot
    func stop() async
}

// Lifecycle-only test hardware has no sample source and cannot report acquisition.
extension PhoneVideoCaptureHardware {
    var onAcquisition: (@MainActor @Sendable (PhoneVideoCaptureSnapshot) -> Void)? {
        get { nil }
        set {}
    }
    var onStopped: (@MainActor @Sendable (PhoneVideoStopReason) -> Void)? {
        get { nil }
        set {}
    }
    func snapshot() async -> PhoneVideoCaptureSnapshot { .init() }
}

@MainActor @Observable final class PhoneVideoCapture {
    private(set) var isPreviewReady = false
    private(set) var isCaptureRequested = false
    private(set) var isAcquiring = false
    private(set) var format: PhoneVideoFormat?
    private(set) var acquisition = PhoneVideoCaptureSnapshot()
    private(set) var stopReason: PhoneVideoStopReason?
    private(set) var lastError: String?
    private(set) var busy = false
    var isStopping: Bool { closuresInFlight > 0 }
    var previewSession: AVCaptureSession? { hardware.previewSession }
    private let hardware: any PhoneVideoCaptureHardware
    private let idleTimer: any PhoneVideoIdleTimer
    private let uptime: () -> Double
    private var sceneActive = false
    private var closed = false
    private var closuresInFlight = 0
    private var operation = UUID()
    private var generation: UUID?
    private var previousIdleTimer: Bool?
    private var deadline: Double?
    private var deadlineTask: Task<Void, Never>?

    convenience init() {
        self.init(hardware: NativePhoneVideoHardware(), idleTimer: NativePhoneVideoIdleTimer())
    }

    init(hardware: any PhoneVideoCaptureHardware, idleTimer: any PhoneVideoIdleTimer,
         uptime: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.hardware = hardware; self.idleTimer = idleTimer; self.uptime = uptime
        hardware.onInterruption = { [weak self] reason in
            Task { await self?.interrupt(reason: reason) }
        }
        hardware.onStopped = { [weak self] reason in Task { await self?.stop(reason: reason) } }
        hardware.onAcquisition = { [weak self] facts in
            guard let self, self.isCaptureRequested, self.generation == facts.generation else { return }
            self.acquisition = facts; self.isAcquiring = facts.hasBothTracks
        }
    }

    isolated deinit {
        deadlineTask?.cancel()
        let hardware = hardware, idle = idleTimer, previous = previousIdleTimer
        Task { @MainActor in
            await hardware.stop()
            if let previous { idle.isIdleTimerDisabled = previous }
        }
    }

    func setSceneActive(_ active: Bool) async {
        sceneActive = active
        if !active { await stop(reason: .background) }
        // Returning to the foreground never prepares or restarts the camera.
    }

    func preparePreview() async throws {
        guard sceneActive, !closed else { throw PhoneVideoCaptureError.inactive }
        guard !busy, !isStopping, !isCaptureRequested, !isPreviewReady else { throw PhoneVideoCaptureError.busy }
        guard hardware.isAvailable else { throw PhoneVideoCaptureError.unavailable }
        busy = true; let ticket = UUID(); operation = ticket
        defer { busy = false }
        do {
            for type in [AVMediaType.video, .audio] {
                let status = hardware.authorizationStatus(for: type)
                if status == .notDetermined {
                    guard await hardware.requestAccess(for: type) else { throw PhoneVideoCaptureError.permission }
                } else if status != .authorized { throw PhoneVideoCaptureError.permission }
                try requireCurrent(ticket)
            }
            retainIdleTimer()
            let configured = try await hardware.startPreview()
            try requireCurrent(ticket)
            format = configured; isPreviewReady = true; lastError = nil; stopReason = nil
        } catch {
            await hardware.stop(); isPreviewReady = false; restoreIdleTimer()
            if operation == ticket { lastError = Self.message(error) }
            throw error
        }
    }

    func beginCapture(generation: UUID, maximumDuration: Double = 132,
                      sampleSink: @escaping @Sendable (PhoneVideoSample) -> Void) async throws {
        guard sceneActive, !closed, isPreviewReady else { throw PhoneVideoCaptureError.inactive }
        guard !busy, !isStopping, !isCaptureRequested else { throw PhoneVideoCaptureError.busy }
        guard hardware.authorizationStatus(for: .video) == .authorized,
              hardware.authorizationStatus(for: .audio) == .authorized else { throw PhoneVideoCaptureError.permission }
        guard maximumDuration.isFinite, maximumDuration > 0, maximumDuration <= 132,
              uptime().isFinite else { throw PhoneVideoCaptureError.invalidTiming }
        busy = true; let ticket = UUID(); operation = ticket
        defer { busy = false }
        self.generation = generation; isCaptureRequested = true; isAcquiring = false
        acquisition = PhoneVideoCaptureSnapshot(generation: generation)
        deadline = uptime() + maximumDuration
        do {
            try await hardware.startCapture(generation: generation, maximumDuration: maximumDuration, sampleSink: sampleSink)
            try requireCurrent(ticket)
            deadlineTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(maximumDuration)) } catch { return }
                await self?.enforceDeadline()
            }
        } catch {
            await stop(reason: .interrupted(Self.message(error)))
            lastError = Self.message(error); throw error
        }
    }

    func enforceDeadline() async {
        guard let deadline, isCaptureRequested, uptime() >= deadline else { return }
        await stop(reason: .durationLimit)
    }

    func snapshot() async -> PhoneVideoCaptureSnapshot { await hardware.snapshot() }
    func interrupt(reason: String) async { await stop(reason: .interrupted(String(reason.prefix(256)))) }

    func stop(reason: PhoneVideoStopReason = .user) async {
        closuresInFlight += 1
        defer { closuresInFlight -= 1 }
        operation = UUID(); deadlineTask?.cancel(); deadlineTask = nil; deadline = nil
        let needsClosure = isPreviewReady || isCaptureRequested || busy
        generation = nil; isCaptureRequested = false; isAcquiring = false; isPreviewReady = false
        stopReason = reason
        if needsClosure {
            await hardware.stop()
            acquisition = await hardware.snapshot()
        }
        restoreIdleTimer()
    }

    func close() async { closed = true; sceneActive = false; await stop(reason: .closed) }

    private func requireCurrent(_ ticket: UUID) throws {
        guard ticket == operation, sceneActive, !closed else { throw PhoneVideoCaptureError.cancelled }
    }
    private func retainIdleTimer() {
        if previousIdleTimer == nil { previousIdleTimer = idleTimer.isIdleTimerDisabled }
        idleTimer.isIdleTimerDisabled = true
    }
    private func restoreIdleTimer() {
        if let previousIdleTimer { idleTimer.isIdleTimerDisabled = previousIdleTimer }
        previousIdleTimer = nil
    }
    private static func message(_ error: any Error) -> String {
        switch error as? PhoneVideoCaptureError {
        case .permission: "Allow camera and microphone access in Settings to prepare video."
        case .unsupportedFormat: "The rear camera cannot provide the required 1080p at 30 frames per second."
        case .invalidTiming: "Capture timing could not be verified."
        case .cancelled, .inactive: "Keep Padel Master open and active to prepare the camera."
        default: "Camera capture is unavailable. Prepare again when the camera and microphone are free."
        }
    }
}

@MainActor private final class NativePhoneVideoHardware: PhoneVideoCaptureHardware {
    private let worker = NativePhoneVideoPipeline()
    private var runID: UUID?
    let isAvailable: Bool
    var previewSession: AVCaptureSession? { isAvailable ? worker.session : nil }
    var onInterruption: (@MainActor @Sendable (String) -> Void)?
    var onAcquisition: (@MainActor @Sendable (PhoneVideoCaptureSnapshot) -> Void)?
    var onStopped: (@MainActor @Sendable (PhoneVideoStopReason) -> Void)?

    init() {
        #if targetEnvironment(simulator)
        let simulated = true
        #else
        let simulated = false
        #endif
        isAvailable = PhoneVideoCaptureHardwarePolicy.allowsCamera(arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment, isSimulator: simulated)
        worker.setEventHandler { [weak self] event in
            // At most the first-both-streams and terminal events cross to the UI.
            Task { @MainActor [weak self] in
                switch event {
                case .acquisition(let facts): self?.onAcquisition?(facts)
                case .stopped(let reason, let runID):
                    guard let self, self.runID == runID else { return }
                    self.onStopped?(reason)
                }
            }
        }
    }
    deinit { worker.shutdown() }
    func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        isAvailable ? AVCaptureDevice.authorizationStatus(for: mediaType) : .denied
    }
    func requestAccess(for mediaType: AVMediaType) async -> Bool {
        guard isAvailable else { return false }
        return await AVCaptureDevice.requestAccess(for: mediaType)
    }
    func startPreview() async throws -> PhoneVideoFormat {
        guard isAvailable else { throw PhoneVideoCaptureError.unavailable }
        let runID = UUID(); self.runID = runID
        return try await worker.perform { try $0.preparePreview(runID: runID) }
    }
    func startCapture(generation: UUID, maximumDuration: Double,
                      sampleSink: @escaping @Sendable (PhoneVideoSample) -> Void) async throws {
        guard isAvailable else { throw PhoneVideoCaptureError.unavailable }
        runID = generation
        try await worker.perform { try $0.begin(generation: generation, duration: maximumDuration, sink: sampleSink) }
    }
    func snapshot() async -> PhoneVideoCaptureSnapshot {
        (try? await worker.perform { $0.gate?.snapshot ?? $0.lastSnapshot }) ?? .init()
    }
    func stop() async { runID = nil; _ = try? await worker.perform { $0.stop() } }
}

nonisolated private enum PhoneVideoNativeEvent: Sendable {
    case acquisition(PhoneVideoCaptureSnapshot), stopped(PhoneVideoStopReason, UUID)
}

/// All session mutations, delegate callbacks and synchronous sink calls use queue.
/// AVFoundation drops late video (and sufficiently late audio) instead of building
/// an application-owned sample queue. No sample is dispatched into a Task.
nonisolated private final class NativePhoneVideoPipeline: NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.padelmaster.phone-video-capture", qos: .userInitiated)
    private var videoOutput: AVCaptureVideoDataOutput?, audioOutput: AVCaptureAudioDataOutput?
    private var videoInput: AVCaptureDeviceInput?, audioInput: AVCaptureDeviceInput?
    fileprivate var gate: PhoneVideoSampleGate?
    fileprivate var lastSnapshot = PhoneVideoCaptureSnapshot()
    private var sink: (@Sendable (PhoneVideoSample) -> Void)?
    private var eventHandler: (@Sendable (PhoneVideoNativeEvent) -> Void)?
    private var sourceClock: CMClock?, generation: UUID?, clockEpoch = UUID()
    private var runID: UUID?
    private var deadline: Double?, deadlineTimer: DispatchSourceTimer?
    private var announced = false
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        let center = NotificationCenter.default
        for name in [AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification] {
            observers.append(center.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
                self?.scheduleInterruption(.interrupted("Camera or microphone was interrupted"))
            })
        }
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                             object: nil, queue: nil) { [weak self] _ in
            self?.scheduleInterruption(.background)
        })
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    func setEventHandler(_ handler: @escaping @Sendable (PhoneVideoNativeEvent) -> Void) {
        queue.async { self.eventHandler = handler }
    }
    func perform<T: Sendable>(_ operation: @escaping @Sendable (NativePhoneVideoPipeline) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation(self)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
    func shutdown() { queue.async { self.stop() } }
    private func scheduleInterruption(_ reason: PhoneVideoStopReason) {
        queue.async { self.interrupt(reason) }
    }

    func preparePreview(runID: UUID) throws -> PhoneVideoFormat {
        dispatchPrecondition(condition: .onQueue(queue))
        guard videoInput == nil, gate == nil,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
              let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw PhoneVideoCaptureError.unavailable
        }
        guard let format = camera.formats.first(where: {
            let size = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            return size.width == 1_920 && size.height == 1_080 && $0.videoSupportedFrameRateRanges.contains {
                $0.minFrameRate <= 30 && $0.maxFrameRate >= 30
            }
        }) else { throw PhoneVideoCaptureError.unsupportedFormat }
        self.runID = runID
        do {
            session.beginConfiguration()
            do {
                guard session.canSetSessionPreset(.inputPriority) else { throw PhoneVideoCaptureError.unsupportedFormat }
                session.sessionPreset = .inputPriority
                let input = try AVCaptureDeviceInput(device: camera)
                guard session.canAddInput(input) else { throw PhoneVideoCaptureError.unavailable }
                session.addInput(input); videoInput = input
                try camera.lockForConfiguration()
                camera.activeFormat = format
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                camera.unlockForConfiguration()
                try addVideoOutput()
                session.commitConfiguration()
            } catch { session.commitConfiguration(); throw error }
            session.startRunning()
            guard session.isRunning else { throw PhoneVideoCaptureError.unavailable }
            return PhoneVideoFormat(width: 1_920, height: 1_080, framesPerSecond: 30, rotationDegrees: 0)
        } catch { stop(); throw error }
    }

    func begin(generation: UUID, duration: Double, sink: @escaping @Sendable (PhoneVideoSample) -> Void) throws {
        dispatchPrecondition(condition: .onQueue(queue))
        guard session.isRunning, videoInput != nil, audioInput == nil, gate == nil,
              duration.isFinite, duration > 0, duration <= 132,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
              let microphone = AVCaptureDevice.default(for: .audio) else { throw PhoneVideoCaptureError.unavailable }
        // Audio may change synchronizationClock. Establish its identity only from
        // actual callbacks after this configuration, never from the preview clock.
        let cutoff = ProcessInfo.processInfo.systemUptime + duration
        runID = generation
        session.stopRunning()
        do {
            session.beginConfiguration()
            do {
                let input = try AVCaptureDeviceInput(device: microphone), output = AVCaptureAudioDataOutput()
                guard session.canAddInput(input), session.canAddOutput(output) else { throw PhoneVideoCaptureError.unavailable }
                // Replace the preview output so a late preview callback can never
                // be mapped using the post-microphone capture clock.
                if let videoOutput {
                    videoOutput.setSampleBufferDelegate(nil, queue: nil); session.removeOutput(videoOutput)
                    self.videoOutput = nil
                }
                session.addInput(input); audioInput = input
                output.setSampleBufferDelegate(self, queue: queue)
                session.addOutput(output); audioOutput = output
                try addVideoOutput()
                session.commitConfiguration()
            } catch { session.commitConfiguration(); throw error }
            self.generation = generation; clockEpoch = UUID(); sourceClock = nil
            gate = PhoneVideoSampleGate(generation: generation, clockEpoch: clockEpoch)
            self.sink = sink; announced = false
            let remaining = cutoff - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw PhoneVideoCaptureError.invalidTiming }
            deadline = cutoff
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + remaining)
            timer.setEventHandler { [weak self] in self?.interrupt(.durationLimit) }
            deadlineTimer = timer; timer.resume()
            session.startRunning()
            guard session.isRunning else { throw PhoneVideoCaptureError.unavailable }
        } catch { stop(); throw error }
    }

    private func addVideoOutput() throws {
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.automaticallyConfiguresOutputBufferDimensions = false
        output.deliversPreviewSizedOutputBuffers = false
        guard session.canAddOutput(output) else { throw PhoneVideoCaptureError.unsupportedFormat }
        session.addOutput(output); videoOutput = output
        let pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        guard output.availableVideoPixelFormatTypes.contains(pixelFormat) else { throw PhoneVideoCaptureError.unsupportedFormat }
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: pixelFormat]
        output.setSampleBufferDelegate(self, queue: queue)
        guard let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(0) else {
            throw PhoneVideoCaptureError.unsupportedFormat
        }
        connection.videoRotationAngle = 0
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = false
        }
    }

    func stop() {
        dispatchPrecondition(condition: .onQueue(queue))
        gate?.close(); if let gate { lastSnapshot = gate.snapshot }
        gate = nil; generation = nil; sink = nil; sourceClock = nil; deadline = nil; runID = nil
        deadlineTimer?.cancel(); deadlineTimer = nil
        // Explicitly clear Apple's preserved start request even during interruption.
        session.stopRunning()
        videoOutput?.setSampleBufferDelegate(nil, queue: nil)
        audioOutput?.setSampleBufferDelegate(nil, queue: nil)
        session.beginConfiguration()
        for output in session.outputs { session.removeOutput(output) }
        for input in session.inputs { session.removeInput(input) }
        session.commitConfiguration()
        videoOutput = nil; audioOutput = nil; videoInput = nil; audioInput = nil
    }

    private func interrupt(_ reason: PhoneVideoStopReason) {
        guard videoInput != nil || gate != nil, let runID else { return }
        stop(); eventHandler?(.stopped(reason, runID))
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let gate, let generation else { return }
        if let deadline, ProcessInfo.processInfo.systemUptime >= deadline { interrupt(.durationLimit); return }
        guard let clock = session.synchronizationClock else {
            interrupt(.interrupted("Capture clock is unavailable")); return
        }
        if let sourceClock, Unmanaged.passUnretained(sourceClock).toOpaque() != Unmanaged.passUnretained(clock).toOpaque() {
            interrupt(.interrupted("Capture clock changed")); return
        }
        sourceClock = clock
        let track: PhoneVideoTrack
        if output === videoOutput { track = .video }
        else if output === audioOutput { track = .audio }
        else { return }
        if track == .video {
            guard let image = CMSampleBufferGetImageBuffer(sampleBuffer),
                  CVPixelBufferGetWidth(image) == 1_920, CVPixelBufferGetHeight(image) == 1_080 else {
                interrupt(.interrupted("Video format changed")); return
            }
        }
        do {
            guard let sample = try gate.accept(sampleBuffer, track: track, synchronizationClock: clock,
                                                clockEpoch: clockEpoch, generation: generation) else { return }
            sink?(sample)
            if !announced, gate.snapshot.hasBothTracks {
                announced = true; eventHandler?(.acquisition(gate.snapshot))
            }
        } catch { interrupt(.interrupted("Capture timing could not be verified")) }
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        dispatchPrecondition(condition: .onQueue(queue))
        if output === videoOutput { gate?.noteVideoDrop() }
    }
}
