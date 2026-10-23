import CoreMotion
import Foundation
import Testing
@testable import PadelCore
@testable import PadelStrokeLab_Watch_App

/// O7 prerequisite: exercise the real wrapper with isolated hardware observations.
/// A source witness is neither a callback-drain acknowledgement nor permission to capture.
@MainActor
struct WatchMotionClosureTests {
    @Test func stopCallsBothNativeStopsAndWaitsForBothObservedFlags() throws {
        let fixture = try MotionClosureFixture()
        let hardware = fixture.hardware
        hardware.isAccelerometerActive = true
        hardware.isDeviceMotionActive = true
        let epoch = fixture.source.stop()
        #expect(hardware.accelerometerStops == 1)
        #expect(hardware.deviceMotionStops == 1)
        #expect(fixture.source.closureWitness(for: epoch) == nil)
        hardware.isAccelerometerActive = false
        #expect(fixture.source.closureWitness(for: epoch) == nil)
        hardware.isDeviceMotionActive = false
        #expect(fixture.source.closureWitness(for: epoch) != nil)
    }

    @Test(arguments: [RecordingStream.accelerometer, .deviceMotion])
    func eitherLiveFlagRevokesAnOtherwiseCurrentWitness(stream: RecordingStream) throws {
        let fixture = try MotionClosureFixture()
        let epoch = fixture.source.stop()
        #expect(fixture.source.closureWitness(for: epoch) != nil)
        fixture.hardware.setActive(true, stream: stream)
        #expect(fixture.source.closureWitness(for: epoch) == nil)
        fixture.hardware.setActive(false, stream: stream)
        #expect(fixture.source.closureWitness(for: epoch) != nil)
        #expect(fixture.hardware.accelerometerStops == 1)
        #expect(fixture.hardware.deviceMotionStops == 1)
    }

    @Test func repeatedStopCallsBothMethodsAndSupersedesThePreviousEpoch() throws {
        let fixture = try MotionClosureFixture()
        let first = fixture.source.stop()
        #expect(fixture.source.closureWitness(for: first) != nil)
        let second = fixture.source.stop()
        #expect(fixture.source.closureWitness(for: first) == nil)
        #expect(fixture.source.closureWitness(for: second) != nil)
        #expect(fixture.hardware.accelerometerStops == 2)
        #expect(fixture.hardware.deviceMotionStops == 2)
    }

    @Test func oneSourcesEpochCannotWitnessAnotherSource() throws {
        let first = try MotionClosureFixture()
        let second = try MotionClosureFixture()
        let firstEpoch = first.source.stop()
        let secondEpoch = second.source.stop()
        #expect(first.source.closureWitness(for: firstEpoch) != nil)
        #expect(second.source.closureWitness(for: secondEpoch) != nil)
        #expect(first.source.closureWitness(for: secondEpoch) == nil)
        #expect(second.source.closureWitness(for: firstEpoch) == nil)
    }

    @Test(arguments: [CMAuthorizationStatus.notDetermined, .authorized, .denied, .restricted])
    func authorizationAlwaysInvalidatesPreviousStopEpoch(status: CMAuthorizationStatus) throws {
        let fixture = try MotionClosureFixture(status: status)
        fixture.hardware.activatesAccelerometerOnStart = false
        defer { fixture.source.stop() }
        let oldEpoch = fixture.source.stop()
        #expect(fixture.source.closureWitness(for: oldEpoch) != nil)
        var completions: [String?] = []
        fixture.source.authorize { completions.append($0) }
        #expect(!fixture.hardware.isAccelerometerActive)
        #expect(!fixture.hardware.isDeviceMotionActive)
        #expect(fixture.source.closureWitness(for: oldEpoch) == nil)
        if status == .notDetermined {
            #expect(completions.isEmpty)
            #expect(fixture.hardware.accelerometerStarts == 1)
        } else {
            #expect(completions.count == 1)
            #expect(fixture.hardware.accelerometerStarts == 0)
            if status == .authorized { #expect(completions == [nil]) }
            else { #expect(completions.count == 1 && completions[0] != nil) }
        }
        #expect(fixture.hardware.deviceMotionStarts == 0)
    }

    @Test(arguments: MotionAvailabilityCase.allCases)
    fileprivate func everyStartAttemptInvalidatesPreviousEpoch(availability: MotionAvailabilityCase) throws {
        let fixture = try MotionClosureFixture()
        availability.apply(to: fixture.hardware)
        fixture.hardware.activatesAccelerometerOnStart = false
        fixture.hardware.activatesDeviceMotionOnStart = false
        defer { fixture.source.stop() }
        let oldEpoch = fixture.source.stop()
        #expect(fixture.source.closureWitness(for: oldEpoch) != nil)
        let engine = try fixture.engine()
        fixture.source.start(engine: engine, generation: UUID())
        #expect(fixture.source.closureWitness(for: oldEpoch) == nil)
        #expect(!fixture.hardware.isAccelerometerActive)
        #expect(!fixture.hardware.isDeviceMotionActive)
        let expectedStarts = availability == .available ? 1 : 0
        #expect(fixture.hardware.accelerometerStarts == expectedStarts)
        #expect(fixture.hardware.deviceMotionStarts == expectedStarts)
    }

    @Test func adapterSupportAndReportedRatesRemainTruthful() throws {
        let fixture = try MotionClosureFixture()
        fixture.hardware.isAccelerometerSupported = false
        fixture.hardware.accelerometerDataFrequency = 0
        fixture.hardware.deviceMotionDataFrequency = 200
        let configurations = try fixture.source.configurations
        #expect(configurations.count == 2)
        #expect(configurations[0].stream == .accelerometer)
        #expect(!configurations[0].supported)
        #expect(configurations[1].stream == .deviceMotion)
        #expect(configurations[1].supported)
        let ratesAreUnrequested = configurations.allSatisfy { $0.requestedRateHz == nil }
        #expect(ratesAreUnrequested)
        #expect(fixture.source.frequencyDescription.contains("unknown until available"))
        #expect(fixture.source.frequencyDescription.contains("200 Hz"))
        #expect(fixture.source.capabilityReport.contains("accel=unknownHz"))
        #expect(fixture.source.capabilityReport.contains("motion=200Hz"))
        #expect(fixture.source.unavailableReason != nil)
    }

    @Test(arguments: [false, true])
    func stopCancelsAuthorizationBeforeOrAfterItsCallbackIsQueued(callbackBeforeStop: Bool) async throws {
        let fixture = try MotionClosureFixture(status: .notDetermined)
        var completions = 0
        fixture.source.authorize { _ in completions += 1 }
        let callback = try #require(fixture.hardware.accelerometerHandlers.first)
        #expect(fixture.hardware.isAccelerometerActive)
        fixture.hardware.authorizationStatus = .authorized
        if callbackBeforeStop { callback(nil, nil) }
        let epoch = fixture.source.stop()
        #expect(fixture.hardware.accelerometerStops == 1)
        #expect(fixture.hardware.deviceMotionStops == 1)
        #expect(fixture.source.closureWitness(for: epoch) == nil)
        fixture.hardware.isAccelerometerActive = false
        #expect(fixture.source.closureWitness(for: epoch) != nil)
        if !callbackBeforeStop { callback(nil, nil) }
        try await settleMotionAuthorizationCallbacks()
        #expect(completions == 0)
        #expect(fixture.hardware.accelerometerStarts == 1)
        #expect(fixture.hardware.deviceMotionStarts == 0)
        #expect(fixture.hardware.accelerometerStops == 1)
        #expect(fixture.hardware.deviceMotionStops == 1)
        #expect(fixture.source.closureWitness(for: epoch) != nil)
    }

    @Test func staleAuthorizationCannotCompleteOrStopAReplacementRequest() async throws {
        let fixture = try MotionClosureFixture(status: .notDetermined)
        defer { fixture.source.stop() }
        var oldCompletions = 0
        var currentCompletions = 0
        fixture.source.authorize { _ in oldCompletions += 1 }
        let oldCallback = try #require(fixture.hardware.accelerometerHandlers.first)
        let retiredEpoch = fixture.source.stop()
        fixture.hardware.isAccelerometerActive = false
        #expect(fixture.source.closureWitness(for: retiredEpoch) != nil)
        fixture.source.authorize { _ in currentCompletions += 1 }
        let currentCallback = try #require(fixture.hardware.accelerometerHandlers.last)
        oldCallback(nil, MotionProbeError.accelerometer)
        try await settleMotionAuthorizationCallbacks()
        #expect(oldCompletions == 0 && currentCompletions == 0)
        #expect(fixture.hardware.isAccelerometerActive)
        #expect(fixture.hardware.accelerometerStarts == 2)
        #expect(fixture.hardware.accelerometerStops == 1)
        #expect(fixture.hardware.deviceMotionStops == 1)
        #expect(fixture.source.closureWitness(for: retiredEpoch) == nil)
        fixture.hardware.authorizationStatus = .authorized
        currentCallback(nil, nil)
        try await waitForMotionAuthorization { currentCompletions == 1 }
        #expect(oldCompletions == 0)
        #expect(fixture.hardware.accelerometerStops == 2)
        #expect(fixture.hardware.deviceMotionStops == 1)
    }

    @Test func startInvalidatesAnOutstandingAuthorizationCallback() async throws {
        let fixture = try MotionClosureFixture(status: .notDetermined)
        defer { fixture.source.stop() }
        var authorizationCompletions = 0
        fixture.source.authorize { _ in authorizationCompletions += 1 }
        let callback = try #require(fixture.hardware.accelerometerHandlers.first)
        fixture.hardware.authorizationStatus = .authorized
        fixture.source.start(engine: try fixture.engine(), generation: UUID())
        callback(nil, MotionProbeError.accelerometer)
        try await settleMotionAuthorizationCallbacks()
        #expect(authorizationCompletions == 0)
        #expect(fixture.hardware.accelerometerStarts == 2)
        #expect(fixture.hardware.deviceMotionStarts == 1)
        #expect(fixture.hardware.accelerometerStops == 0)
        #expect(fixture.hardware.deviceMotionStops == 0)
        #expect(fixture.hardware.isAccelerometerActive)
        #expect(fixture.hardware.isDeviceMotionActive)
    }

    @Test(arguments: [RecordingStream.accelerometer, .deviceMotion])
    func partialStartErrorStillRequiresBothObservedFlagsToClose(failedStream: RecordingStream) async throws {
        let fixture = try MotionClosureFixture()
        fixture.hardware.activatesAccelerometerOnStart = failedStream != .accelerometer
        fixture.hardware.activatesDeviceMotionOnStart = failedStream != .deviceMotion
        let (engine, generation) = try await fixture.runningEngine()
        fixture.source.start(engine: engine, generation: generation)
        #expect(fixture.hardware.accelerometerStarts == 1)
        #expect(fixture.hardware.deviceMotionStarts == 1)
        fixture.hardware.deliverError(stream: failedStream)
        let interrupted = await engine.snapshot()
        #expect(interrupted.state == .interrupted)
        #expect(interrupted.detail?.contains(failedStream == .accelerometer ? "Accelerometer error:" : "Device motion error:") == true)
        let epoch = fixture.source.stop()
        #expect(fixture.hardware.accelerometerStops == 1)
        #expect(fixture.hardware.deviceMotionStops == 1)
        #expect(fixture.source.closureWitness(for: epoch) == nil)
        fixture.hardware.isAccelerometerActive = false
        fixture.hardware.isDeviceMotionActive = false
        #expect(fixture.source.closureWitness(for: epoch) != nil)
    }

    @Test func witnessDoesNotClaimThatAlreadyDeliveredCallbacksHaveDrained() async throws {
        let fixture = try MotionClosureFixture()
        let (engine, generation) = try await fixture.runningEngine()
        fixture.source.start(engine: engine, generation: generation)
        let epoch = fixture.source.stop()
        fixture.hardware.isAccelerometerActive = false
        fixture.hardware.isDeviceMotionActive = false
        #expect(fixture.source.closureWitness(for: epoch) != nil)
        // A retained native handler can still reach the real engine after this observation.
        fixture.hardware.deliverError(stream: .accelerometer)
        let interrupted = await engine.snapshot()
        #expect(interrupted.state == .interrupted)
        #expect(fixture.source.closureWitness(for: epoch) != nil)
    }

    @Test(arguments: InvalidMotionFixture.allCases)
    fileprivate func injectedHardwareRejectsAnUntrustedEnvironmentBeforeAnyNativeOperation(invalid: InvalidMotionFixture) throws {
        try requireIsolatedMotionTestHost()
        let valid = try WatchRuntimeEnvironment.resolve(
            arguments: ["--owner-watch-fixture=\(UUID().uuidString)"], environment: [:])
        let hardware = MotionHardwareProbe()
        #expect(throws: OwnerCaptureFailure.self) {
            _ = try WatchMotionSource(hardware: hardware, environment: invalid.environment(from: valid))
        }
        #expect(hardware.accelerometerStarts == 0 && hardware.deviceMotionStarts == 0)
        #expect(hardware.accelerometerStops == 0 && hardware.deviceMotionStops == 0)
    }

    #if targetEnvironment(simulator)
    @Test func nativeDefaultStillRejectsSimulatorCaptureWithoutRequestingPermission() async throws {
        let fixture = try MotionClosureFixture()
        let nativeSource = WatchMotionSource()
        #expect(nativeSource.unavailableReason?.contains("simulator") == true)
        let (engine, generation) = try await fixture.runningEngine()
        // Never invoke native authorize in a test, including the tests-first red phase.
        nativeSource.start(engine: engine, generation: generation)
        let interrupted = await engine.snapshot()
        #expect(interrupted.state == .interrupted)
        #expect(interrupted.detail?.contains("simulator") == true)
        nativeSource.stop()
    }
    #endif
}

@MainActor
private final class MotionHardwareProbe: WatchMotionHardware {
    var isAccelerometerSupported = true
    var isDeviceMotionSupported = true
    var authorizationStatus: CMAuthorizationStatus = .authorized
    var accelerometerDataFrequency = 800
    var deviceMotionDataFrequency = 200
    var isAccelerometerActive = false
    var isDeviceMotionActive = false
    var activatesAccelerometerOnStart = true
    var activatesDeviceMotionOnStart = true
    private(set) var accelerometerHandlers: [@Sendable ([CMAccelerometerData]?, (any Error)?) -> Void] = []
    private(set) var deviceMotionHandlers: [@Sendable ([CMDeviceMotion]?, (any Error)?) -> Void] = []
    private(set) var accelerometerStops = 0
    private(set) var deviceMotionStops = 0
    var accelerometerStarts: Int { accelerometerHandlers.count }
    var deviceMotionStarts: Int { deviceMotionHandlers.count }

    func startAccelerometerUpdates(handler: @escaping @Sendable ([CMAccelerometerData]?, (any Error)?) -> Void) {
        accelerometerHandlers.append(handler)
        if activatesAccelerometerOnStart { isAccelerometerActive = true }
    }
    func startDeviceMotionUpdates(handler: @escaping @Sendable ([CMDeviceMotion]?, (any Error)?) -> Void) {
        deviceMotionHandlers.append(handler)
        if activatesDeviceMotionOnStart { isDeviceMotionActive = true }
    }
    // Stop deliberately does not falsify SDK observations. Each test advances these flags.
    func stopAccelerometerUpdates() { accelerometerStops += 1 }
    func stopDeviceMotionUpdates() { deviceMotionStops += 1 }
    func setActive(_ active: Bool, stream: RecordingStream) {
        if stream == .accelerometer { isAccelerometerActive = active }
        else { isDeviceMotionActive = active }
    }
    func deliverError(stream: RecordingStream) {
        if stream == .accelerometer { accelerometerHandlers.last?(nil, MotionProbeError.accelerometer) }
        else { deviceMotionHandlers.last?(nil, MotionProbeError.deviceMotion) }
    }
}

private enum MotionProbeError: Error { case accelerometer, deviceMotion }

@MainActor
private struct MotionClosureFixture {
    let environment: WatchRuntimeEnvironment
    let hardware: MotionHardwareProbe
    let source: WatchMotionSource

    init(status: CMAuthorizationStatus = .authorized) throws {
        try requireIsolatedMotionTestHost()
        environment = try .resolve(arguments: ["--owner-watch-fixture=\(UUID().uuidString)"], environment: [:])
        hardware = MotionHardwareProbe()
        hardware.authorizationStatus = status
        source = try WatchMotionSource(hardware: hardware, environment: environment)
    }

    func engine() throws -> MotionCaptureEngine {
        try environment.prepareFixtureDirectory()
        let paths = try RecordingPaths(base: try #require(environment.base))
        let metadata = try RecordingMetadata(recordingID: UUID(),
            clock: .init(domainID: UUID(), monotonicAnchorSeconds: 100, wallAnchorUnixSeconds: 1_800_000_000),
            appBuild: "O7-motion-closure-fixture", protocolVersion: RecordingDrill.protocolVersion,
            deviceModel: "isolated-hardware-probe", operatingSystem: "watchOS 27", handedness: .right,
            playingArm: .right, watchWrist: .right, watchOrientation: "Crown right", playingArmConfirmed: true,
            drill: RecordingDrill.forehandGroundstroke.rawValue, capabilityReport: "injected SDK activity observations",
            streams: RecordingStream.allCases.map {
                try .init(stream: $0, supported: true, requestedRateHz: nil, knownSensorLimit: nil)
            })
        return MotionCaptureEngine(metadata: metadata, rawRoot: paths.rawRoot, notesRoot: paths.notesRoot,
                                   clock: { 100 }, onChange: { _ in })
    }

    func runningEngine() async throws -> (MotionCaptureEngine, UUID) {
        let engine = try engine()
        let generation = await withCheckedContinuation { continuation in
            engine.begin { continuation.resume(returning: $0) }
        }
        return (engine, try #require(generation))
    }
}

@MainActor
private func requireIsolatedMotionTestHost() throws {
    let host = WatchRuntimeEnvironment.current
    try #require(host.fixtureID != nil, "Use the existing UUID-isolated Watch app-host launch pipeline")
    try #require(!host.allowsHardware && host.failure == nil)
}

@MainActor
private func settleMotionAuthorizationCallbacks() async throws {
    // Yield to callbacks already submitted to MainActor; this is not a source-drain claim.
    try await Task.sleep(for: .milliseconds(50))
}

@MainActor
private func waitForMotionAuthorization(_ completed: @MainActor () -> Bool) async throws {
    for _ in 0..<500 {
        if completed() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(completed(), "Injected authorization callback did not complete within five seconds")
}

private enum MotionAvailabilityCase: CaseIterable, Sendable {
    case available, unsupportedAccelerometer, unsupportedDeviceMotion, denied, restricted
    @MainActor func apply(to hardware: MotionHardwareProbe) {
        switch self {
        case .available: break
        case .unsupportedAccelerometer: hardware.isAccelerometerSupported = false
        case .unsupportedDeviceMotion: hardware.isDeviceMotionSupported = false
        case .denied: hardware.authorizationStatus = .denied
        case .restricted: hardware.authorizationStatus = .restricted
        }
    }
}

private enum InvalidMotionFixture: CaseIterable, Sendable {
    case missingIdentity, hardwareEnabled, failed, missingBase, foreignBase, wrongPreferenceSuite
    @MainActor func environment(from valid: WatchRuntimeEnvironment) -> WatchRuntimeEnvironment {
        WatchRuntimeEnvironment(
            fixtureID: self == .missingIdentity ? nil : valid.fixtureID,
            base: self == .missingBase ? nil : (self == .foreignBase ? FileManager.default.temporaryDirectory : valid.base),
            preferenceSuite: self == .wrongPreferenceSuite ? "not-the-isolated-fixture" : valid.preferenceSuite,
            allowsHardware: self == .hardwareEnabled,
            failure: self == .failed ? "Fixture initialization failed" : nil)
    }
}
