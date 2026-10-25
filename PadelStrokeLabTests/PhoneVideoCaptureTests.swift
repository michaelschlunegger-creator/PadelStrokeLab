import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import Testing
@testable import PadelStrokeLab

/// Permission/device operations alone are substituted. Timing tests use real
/// Core Media buffers and the production gate used by the native callback path.
@Suite(.serialized) @MainActor
struct PhoneVideoCaptureTests {
    @Test func permissionsDeniedNeverStartPreviewOrMicrophone() async {
        for denied in [AVMediaType.video, .audio] {
            let hardware = CaptureHardwareFixture()
            hardware.permissions[denied] = .denied
            let capture = PhoneVideoCapture(hardware: hardware, idleTimer: CaptureIdleFixture())
            await capture.setSceneActive(true)
            await #expect(throws: (any Error).self) { try await capture.preparePreview() }
            #expect(hardware.previewStarts == 0 && hardware.captureStarts == 0)
            #expect(!capture.isPreviewReady && !capture.isAcquiring)
            await capture.close()
        }
    }

    @Test func previewNeverAddsMicrophone() async throws {
        let hardware = CaptureHardwareFixture(), idle = CaptureIdleFixture()
        let capture = PhoneVideoCapture(hardware: hardware, idleTimer: idle)
        await capture.setSceneActive(true)
        try await capture.preparePreview()
        #expect(capture.isPreviewReady && !capture.isAcquiring)
        #expect(hardware.previewStarts == 1 && hardware.captureStarts == 0)
        #expect(hardware.requestedPermissions.isEmpty)
        #expect(capture.format == .init(width: 1_920, height: 1_080,
                                       framesPerSecond: 30, rotationDegrees: 0))
        await capture.close()
    }

    @Test func stalePermissionReplyCannotRestartAfterClose() async {
        let hardware = CaptureHardwareFixture()
        hardware.permissions[.video] = .notDetermined
        hardware.holdPermission = true
        let idle = CaptureIdleFixture()
        let capture = PhoneVideoCapture(hardware: hardware, idleTimer: idle)
        await capture.setSceneActive(true)
        let preparing = Task { try? await capture.preparePreview() }
        await hardware.waitUntilPermissionRequested()
        await capture.close()
        hardware.resolvePermission(true)
        await preparing.value
        #expect(hardware.previewStarts == 0 && hardware.captureStarts == 0)
        #expect(!capture.isPreviewReady && !capture.isAcquiring && !idle.isIdleTimerDisabled)
    }

    @Test func captureRequiresForegroundPreviewAndBothPermissions() async throws {
        let hardware = CaptureHardwareFixture()
        let capture = PhoneVideoCapture(hardware: hardware, idleTimer: CaptureIdleFixture())
        await #expect(throws: (any Error).self) {
            try await capture.beginCapture(generation: UUID(), sampleSink: { _ in })
        }
        await #expect(throws: (any Error).self) { try await capture.preparePreview() }
        await capture.setSceneActive(true)
        try await capture.preparePreview()
        hardware.permissions[.audio] = .denied
        await #expect(throws: (any Error).self) {
            try await capture.beginCapture(generation: UUID(), sampleSink: { _ in })
        }
        #expect(hardware.captureStarts == 0)
        await capture.close()

        #expect(!PhoneVideoCaptureHardwarePolicy.allowsCamera(arguments: [], environment: [:], isSimulator: true))
        #expect(!PhoneVideoCaptureHardwarePolicy.allowsCamera(arguments: [],
            environment: ["XCTestConfigurationFilePath": "/isolated/test"], isSimulator: false))
        #expect(!PhoneVideoCaptureHardwarePolicy.allowsCamera(arguments: ["--owner-phone-fixture=test"],
            environment: [:], isSimulator: false))
        #expect(PhoneVideoCaptureHardwarePolicy.allowsCamera(arguments: [], environment: [:], isSimulator: false))
    }

    @Test func backgroundInterruptionClosesAndDoesNotResume() async throws {
        for background in [true, false] {
            let hardware = CaptureHardwareFixture(), idle = CaptureIdleFixture()
            let capture = PhoneVideoCapture(hardware: hardware, idleTimer: idle)
            await capture.setSceneActive(true)
            try await capture.preparePreview()
            try await capture.beginCapture(generation: UUID(), sampleSink: { _ in })
            #expect(hardware.captureStarts == 1)
            if background { await capture.setSceneActive(false) }
            else { await capture.interrupt(reason: "Audio device became unavailable") }
            #expect(hardware.stops >= 1)
            #expect(!capture.isPreviewReady && !capture.isAcquiring && !idle.isIdleTimerDisabled)
            await capture.setSceneActive(true)
            #expect(hardware.previewStarts == 1 && hardware.captureStarts == 1)
            #expect(!capture.isPreviewReady)
            await capture.close()
        }
    }

    @Test func deadlineStopsWithoutPeer() async throws {
        let hardware = CaptureHardwareFixture(), idle = CaptureIdleFixture()
        var uptime = 100.0
        let capture = PhoneVideoCapture(hardware: hardware, idleTimer: idle, uptime: { uptime })
        await capture.setSceneActive(true)
        try await capture.preparePreview()
        await #expect(throws: (any Error).self) {
            try await capture.beginCapture(generation: UUID(), maximumDuration: 133, sampleSink: { _ in })
        }
        try await capture.beginCapture(generation: UUID(), sampleSink: { _ in })
        #expect(hardware.requestedMaximumDuration == 132)
        uptime = 231.99
        await capture.enforceDeadline()
        #expect(hardware.stops == 0)
        uptime = 232
        await capture.enforceDeadline()
        #expect(hardware.stops == 1 && !capture.isAcquiring && !idle.isIdleTimerDisabled)
        #expect(capture.stopReason == .durationLimit)
        await capture.close()
    }

    @Test func stopRejectsLateGenerationSamples() throws {
        let generation = UUID(), clockEpoch = UUID()
        let gate = PhoneVideoSampleGate(generation: generation, clockEpoch: clockEpoch)
        let buffer = try captureFixtureBuffer(pts: CMTime(value: 6_000, timescale: 600))
        let clock = CMClockGetHostTimeClock()
        #expect(try gate.accept(buffer, track: .video, synchronizationClock: clock,
                               clockEpoch: clockEpoch, generation: UUID()) == nil)
        #expect(try gate.accept(buffer, track: .video, synchronizationClock: clock,
                               clockEpoch: clockEpoch, generation: generation) != nil)
        gate.close()
        #expect(try gate.accept(buffer, track: .audio, synchronizationClock: clock,
                               clockEpoch: clockEpoch, generation: generation) == nil)
        #expect(gate.snapshot.videoSamples == 1 && gate.snapshot.audioSamples == 0)
        #expect(!gate.snapshot.hasBothTracks)
    }

    @Test func sampleTimingUsesActualPTSAndHostClockConversion() throws {
        // The deliberately irregular PTS is unrelated to callback time/frame number.
        let pts = CMTime(value: 6_137, timescale: 600), epoch = UUID()
        let buffer = try captureFixtureBuffer(pts: pts)
        let timing = try PhoneVideoSampleTiming.read(buffer, synchronizationClock: CMClockGetHostTimeClock(),
                                                     clockEpoch: epoch)
        #expect(CMTimeCompare(timing.presentationTime, pts) == 0)
        #expect(timing.presentationTime.value == 6_137 && timing.presentationTime.timescale == 600)
        #expect(timing.presentationTime.epoch == pts.epoch && timing.clockEpoch == epoch)
        #expect(CMTimeCompare(timing.hostTime, pts) == 0)
        #expect(CMTimeCompare(timing.duration, CMTime(value: 1, timescale: 30)) == 0)
        #expect(timing.hostBracket.lowerBound <= timing.hostBracket.upperBound)
        #expect(timing.uptimeBracket.lowerBound <= timing.uptimeBracket.upperBound)
        #expect(timing.hostBracket.lowerBound.isFinite && timing.uptimeBracket.lowerBound.isFinite)
    }

    @Test func invalidOrDiscontinuousClockCannotConfirmAcquisition() throws {
        let generation = UUID(), clockEpoch = UUID(), clock = CMClockGetHostTimeClock()
        let gate = PhoneVideoSampleGate(generation: generation, clockEpoch: clockEpoch)
        let first = try captureFixtureBuffer(pts: CMTime(value: 6_000, timescale: 600))
        _ = try gate.accept(first, track: .video, synchronizationClock: clock,
                            clockEpoch: clockEpoch, generation: generation)
        #expect(throws: (any Error).self) {
            try gate.accept(first, track: .audio, synchronizationClock: clock,
                            clockEpoch: UUID(), generation: generation)
        }
        #expect(!gate.snapshot.hasBothTracks)
        #expect(try gate.accept(first, track: .audio, synchronizationClock: clock,
                               clockEpoch: clockEpoch, generation: generation) == nil)

        let regression = PhoneVideoSampleGate(generation: generation, clockEpoch: clockEpoch)
        _ = try regression.accept(first, track: .video, synchronizationClock: clock,
                                  clockEpoch: clockEpoch, generation: generation)
        let earlier = try captureFixtureBuffer(pts: CMTime(value: 5_999, timescale: 600))
        #expect(throws: (any Error).self) {
            try regression.accept(earlier, track: .video, synchronizationClock: clock,
                                  clockEpoch: clockEpoch, generation: generation)
        }
        let invalid = try captureFixtureBuffer(pts: .invalid)
        #expect(throws: (any Error).self) {
            try PhoneVideoSampleTiming.read(invalid, synchronizationClock: clock, clockEpoch: clockEpoch)
        }
    }

    @Test func previewExitRestoresIdleTimer() async throws {
        for initiallyDisabled in [false, true] {
            let idle = CaptureIdleFixture(); idle.isIdleTimerDisabled = initiallyDisabled
            let capture = PhoneVideoCapture(hardware: CaptureHardwareFixture(), idleTimer: idle)
            await capture.setSceneActive(true)
            try await capture.preparePreview()
            #expect(idle.isIdleTimerDisabled)
            await capture.close()
            #expect(idle.isIdleTimerDisabled == initiallyDisabled)
        }
        let failing = CaptureHardwareFixture(); failing.failPreview = true
        let idle = CaptureIdleFixture()
        let capture = PhoneVideoCapture(hardware: failing, idleTimer: idle)
        await capture.setSceneActive(true)
        await #expect(throws: (any Error).self) { try await capture.preparePreview() }
        #expect(!idle.isIdleTimerDisabled && !capture.isPreviewReady)
        await capture.close()
    }
}

@MainActor private final class CaptureIdleFixture: PhoneVideoIdleTimer {
    var isIdleTimerDisabled = false
}

@MainActor private final class CaptureHardwareFixture: PhoneVideoCaptureHardware {
    enum Failure: Error { case unavailable }
    var permissions: [AVMediaType: AVAuthorizationStatus] = [.video: .authorized, .audio: .authorized]
    var requestedPermissions: [AVMediaType] = []
    var previewSession: AVCaptureSession? { nil }
    var isAvailable = true
    var previewStarts = 0, captureStarts = 0, stops = 0
    var failPreview = false, holdPermission = false
    var requestedMaximumDuration: Double?
    var onInterruption: (@MainActor @Sendable (String) -> Void)?
    private var permissionReply: CheckedContinuation<Bool, Never>?
    private var requestWaiter: CheckedContinuation<Void, Never>?

    func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        permissions[mediaType] ?? .denied
    }
    func requestAccess(for mediaType: AVMediaType) async -> Bool {
        requestedPermissions.append(mediaType)
        requestWaiter?.resume(); requestWaiter = nil
        if holdPermission {
            return await withCheckedContinuation { permissionReply = $0 }
        }
        permissions[mediaType] = .authorized
        return true
    }
    func waitUntilPermissionRequested() async {
        if !requestedPermissions.isEmpty { return }
        await withCheckedContinuation { requestWaiter = $0 }
    }
    func resolvePermission(_ granted: Bool) {
        permissions[.video] = granted ? .authorized : .denied
        permissionReply?.resume(returning: granted); permissionReply = nil
    }
    func startPreview() async throws -> PhoneVideoFormat {
        if failPreview { throw Failure.unavailable }
        previewStarts += 1
        return .init(width: 1_920, height: 1_080, framesPerSecond: 30, rotationDegrees: 0)
    }
    func startCapture(generation: UUID, maximumDuration: Double,
                      sampleSink: @escaping @Sendable (PhoneVideoSample) -> Void) async throws {
        captureStarts += 1; requestedMaximumDuration = maximumDuration
    }
    func stop() async { stops += 1 }
}

private func captureFixtureBuffer(pts: CMTime) throws -> CMSampleBuffer {
    var pixel: CVPixelBuffer?
    try #require(CVPixelBufferCreate(kCFAllocatorDefault, 16, 16, kCVPixelFormatType_32BGRA,
                                    nil, &pixel) == kCVReturnSuccess)
    let image = try #require(pixel)
    var format: CMVideoFormatDescription?
    try #require(CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                            imageBuffer: image,
                                                            formatDescriptionOut: &format) == noErr)
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                   presentationTimeStamp: pts, decodeTimeStamp: .invalid)
    var sample: CMSampleBuffer?
    try #require(CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
        imageBuffer: image, formatDescription: try #require(format), sampleTiming: &timing,
        sampleBufferOut: &sample) == noErr)
    return try #require(sample)
}
