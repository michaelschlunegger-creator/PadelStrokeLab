import CoreMotion
import Foundation
import PadelCore

@MainActor
protocol WatchMotionHardware: AnyObject {
    var isAccelerometerSupported: Bool { get }
    var isDeviceMotionSupported: Bool { get }
    var authorizationStatus: CMAuthorizationStatus { get }
    var accelerometerDataFrequency: Int { get }
    var deviceMotionDataFrequency: Int { get }
    var isAccelerometerActive: Bool { get }
    var isDeviceMotionActive: Bool { get }
    func startAccelerometerUpdates(handler: @escaping @Sendable ([CMAccelerometerData]?, (any Error)?) -> Void)
    func startDeviceMotionUpdates(handler: @escaping @Sendable ([CMDeviceMotion]?, (any Error)?) -> Void)
    func stopAccelerometerUpdates()
    func stopDeviceMotionUpdates()
}

@MainActor
private final class NativeWatchMotionHardware: WatchMotionHardware {
    private let manager = CMBatchedSensorManager()
    var isAccelerometerSupported: Bool { CMBatchedSensorManager.isAccelerometerSupported }
    var isDeviceMotionSupported: Bool { CMBatchedSensorManager.isDeviceMotionSupported }
    var authorizationStatus: CMAuthorizationStatus { CMBatchedSensorManager.authorizationStatus }
    var accelerometerDataFrequency: Int { manager.accelerometerDataFrequency }
    var deviceMotionDataFrequency: Int { manager.deviceMotionDataFrequency }
    var isAccelerometerActive: Bool { manager.isAccelerometerActive }
    var isDeviceMotionActive: Bool { manager.isDeviceMotionActive }
    func startAccelerometerUpdates(handler: @escaping @Sendable ([CMAccelerometerData]?, (any Error)?) -> Void) {
        manager.startAccelerometerUpdates(handler: handler)
    }
    func startDeviceMotionUpdates(handler: @escaping @Sendable ([CMDeviceMotion]?, (any Error)?) -> Void) {
        manager.startDeviceMotionUpdates(handler: handler)
    }
    func stopAccelerometerUpdates() { manager.stopAccelerometerUpdates() }
    func stopDeviceMotionUpdates() { manager.stopDeviceMotionUpdates() }
}

struct WatchMotionStopEpoch {
    fileprivate let id = UUID()
    fileprivate init() {}
}

/// Only an observation of this source's current SDK activity, never callback or writer drain.
struct WatchMotionClosureWitness {
    fileprivate let epoch: WatchMotionStopEpoch
}

@MainActor
final class WatchMotionSource {
    private let manager: any WatchMotionHardware
    private let isInjected: Bool
    private var stopEpoch: WatchMotionStopEpoch?
    private var authorizationID: UUID?
    private var authorizationTimeout: Task<Void, Never>?

    init() {
        manager = NativeWatchMotionHardware()
        isInjected = false
    }

    init(hardware: any WatchMotionHardware, environment: WatchRuntimeEnvironment) throws {
        guard let id = environment.fixtureID, !environment.allowsHardware, environment.failure == nil else {
            throw OwnerCaptureFailure.unavailable
        }
        let expected = try WatchRuntimeEnvironment.resolve(arguments: ["--owner-watch-fixture=\(id.uuidString)"], environment: [:])
        guard expected.fixtureID == id, !expected.allowsHardware,
              environment.base == expected.base, environment.preferenceSuite == expected.preferenceSuite else {
            throw OwnerCaptureFailure.unavailable
        }
        manager = hardware
        isInjected = true
    }

    var unavailableReason: String? {
        #if targetEnvironment(simulator)
        if !isInjected { return "Batched motion requires a supported physical Apple Watch. The simulator cannot record shots." }
        #endif
        guard isInjected || WatchRuntimeEnvironment.current.allowsHardware else {
            return "Motion is disabled for this isolated test process."
        }
        guard manager.isAccelerometerSupported, manager.isDeviceMotionSupported else {
            return "This Watch does not support both required batched motion streams."
        }
        switch manager.authorizationStatus {
        case .denied: return "Motion access is denied. Enable Motion & Fitness access in Settings."
        case .restricted: return "Motion access is restricted on this Watch."
        default: return nil
        }
    }

    var configurations: [RecordingStreamConfiguration] {
        get throws {
            try [RecordingStreamConfiguration(stream: .accelerometer,
                  supported: manager.isAccelerometerSupported, requestedRateHz: nil,
                  knownSensorLimit: nil),
                 RecordingStreamConfiguration(stream: .deviceMotion,
                  supported: manager.isDeviceMotionSupported, requestedRateHz: nil,
                  knownSensorLimit: nil)]
        }
    }

    var frequencyDescription: String {
        "Reported acceleration \(reported(manager.accelerometerDataFrequency)); motion \(reported(manager.deviceMotionDataFrequency)). Rates are not configurable."
    }

    private func reported(_ frequency: Int) -> String { frequency > 0 ? "\(frequency) Hz" : "unknown until available" }

    var capabilityReport: String {
        "Batched; reported accel=\(manager.accelerometerDataFrequency > 0 ? String(manager.accelerometerDataFrequency) : "unknown")Hz motion=\(manager.deviceMotionDataFrequency > 0 ? String(manager.deviceMotionDataFrequency) : "unknown")Hz; no rate request; tail unknown"
    }

    /// This explicit setup stage runs only after the workout is running. Samples used to request
    /// Motion permission are discarded before the recording clock window opens, never reported as captured.
    func authorize(completion: @escaping @MainActor (String?) -> Void) {
        stopEpoch = nil
        if authorizationID != nil { manager.stopAccelerometerUpdates() }
        cancelAuthorization()
        guard unavailableReason == nil else { completion(unavailableReason); return }
        guard manager.authorizationStatus == .notDetermined else {
            completion(unavailableReason); return
        }
        let request = UUID(); authorizationID = request
        let gate = MotionAuthorizationGate()
        manager.startAccelerometerUpdates { @Sendable [weak self] _, error in
            let reason = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, self.authorizationID == request,
                      reason != nil || self.manager.authorizationStatus != .notDetermined, gate.take() else { return }
                self.cancelAuthorization()
                self.manager.stopAccelerometerUpdates()
                completion(reason ?? self.unavailableReason)
            }
        }
        authorizationTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, self.authorizationID == request else { return }
            self.cancelAuthorization(); self.manager.stopAccelerometerUpdates()
            completion("Motion permission was not resolved within 30 seconds. Allow access, then start a new set.")
        }
    }

    func start(engine: MotionCaptureEngine, generation: UUID) {
        stopEpoch = nil
        cancelAuthorization()
        guard unavailableReason == nil else { engine.interrupt(unavailableReason!); return }
        manager.startAccelerometerUpdates(handler: Self.accelerometerHandler(engine: engine, generation: generation))
        manager.startDeviceMotionUpdates(handler: Self.deviceMotionHandler(engine: engine, generation: generation))
    }

    // Construct framework handlers in a nonisolated context. Core Motion does not promise MainActor delivery.
    nonisolated private static func accelerometerHandler(engine: MotionCaptureEngine, generation: UUID)
        -> @Sendable ([CMAccelerometerData]?, (any Error)?) -> Void {
        { data, error in
            if let error { engine.interrupt("Accelerometer error: \(error.localizedDescription)", generation: generation); return }
            guard let data, !data.isEmpty else { return }
            guard data.count <= MotionCaptureEngine.maximumBatchSamples else {
                engine.interrupt("Accelerometer batch exceeded the bounded conversion limit.", generation: generation); return
            }
            let samples = data.map { sample in
                RecordingSample(timestamp: sample.timestamp,
                                values: [sample.acceleration.x, sample.acceleration.y, sample.acceleration.z])
            }
            engine.receive(.init(generation: generation, stream: .accelerometer, samples: samples))
        }
    }

    nonisolated private static func deviceMotionHandler(engine: MotionCaptureEngine, generation: UUID)
        -> @Sendable ([CMDeviceMotion]?, (any Error)?) -> Void {
        { data, error in
            if let error { engine.interrupt("Device motion error: \(error.localizedDescription)", generation: generation); return }
            guard let data, !data.isEmpty else { return }
            guard data.count <= MotionCaptureEngine.maximumBatchSamples else {
                engine.interrupt("Device motion batch exceeded the bounded conversion limit.", generation: generation); return
            }
            let samples = data.map { sample in
                let q = sample.attitude.quaternion
                return RecordingSample(timestamp: sample.timestamp, values: [
                    sample.rotationRate.x, sample.rotationRate.y, sample.rotationRate.z,
                    sample.gravity.x, sample.gravity.y, sample.gravity.z,
                    sample.userAcceleration.x, sample.userAcceleration.y, sample.userAcceleration.z,
                    q.x, q.y, q.z, q.w])
            }
            engine.receive(.init(generation: generation, stream: .deviceMotion, samples: samples))
        }
    }

    @discardableResult
    func stop() -> WatchMotionStopEpoch {
        cancelAuthorization()
        let epoch = WatchMotionStopEpoch()
        stopEpoch = epoch
        manager.stopAccelerometerUpdates()
        manager.stopDeviceMotionUpdates()
        return epoch
    }

    func closureWitness(for epoch: WatchMotionStopEpoch) -> WatchMotionClosureWitness? {
        guard stopEpoch?.id == epoch.id, authorizationID == nil,
              !manager.isAccelerometerActive, !manager.isDeviceMotionActive else { return nil }
        return WatchMotionClosureWitness(epoch: epoch)
    }

    private func cancelAuthorization() {
        authorizationID = nil
        authorizationTimeout?.cancel()
        authorizationTimeout = nil
    }
}

nonisolated private final class MotionAuthorizationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    func take() -> Bool { lock.withLock { guard !completed else { return false }; completed = true; return true } }
}
