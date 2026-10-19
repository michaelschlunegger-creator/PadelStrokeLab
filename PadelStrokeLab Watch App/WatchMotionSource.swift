import CoreMotion
import Foundation
import PadelCore

@MainActor
final class WatchMotionSource {
    private let manager = CMBatchedSensorManager()
    private var authorizationID: UUID?
    private var authorizationTimeout: Task<Void, Never>?

    var unavailableReason: String? {
        #if targetEnvironment(simulator)
        return "Batched motion requires a supported physical Apple Watch. The simulator cannot record shots."
        #else
        guard CMBatchedSensorManager.isAccelerometerSupported, CMBatchedSensorManager.isDeviceMotionSupported else {
            return "This Watch does not support both required batched motion streams."
        }
        switch CMBatchedSensorManager.authorizationStatus {
        case .denied: return "Motion access is denied. Enable Motion & Fitness access in Settings."
        case .restricted: return "Motion access is restricted on this Watch."
        default: return nil
        }
        #endif
    }

    var configurations: [RecordingStreamConfiguration] {
        get throws {
            try [RecordingStreamConfiguration(stream: .accelerometer,
                  supported: CMBatchedSensorManager.isAccelerometerSupported, requestedRateHz: nil,
                  knownSensorLimit: nil),
                 RecordingStreamConfiguration(stream: .deviceMotion,
                  supported: CMBatchedSensorManager.isDeviceMotionSupported, requestedRateHz: nil,
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
        guard CMBatchedSensorManager.authorizationStatus == .notDetermined else {
            completion(unavailableReason); return
        }
        let request = UUID(); authorizationID = request
        let gate = MotionAuthorizationGate()
        manager.startAccelerometerUpdates { @Sendable [weak self] _, error in
            let status = CMBatchedSensorManager.authorizationStatus
            guard error != nil || status != .notDetermined, gate.take() else { return }
            let reason = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, self.authorizationID == request else { return }
                self.authorizationID = nil; self.authorizationTimeout?.cancel(); self.authorizationTimeout = nil
                self.manager.stopAccelerometerUpdates()
                completion(reason ?? self.unavailableReason)
            }
        }
        authorizationTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, self.authorizationID == request else { return }
            self.authorizationID = nil; self.manager.stopAccelerometerUpdates()
            completion("Motion permission was not resolved within 30 seconds. Allow access, then start a new set.")
        }
    }

    func start(engine: MotionCaptureEngine, generation: UUID) {
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

    func stop() {
        authorizationID = nil; authorizationTimeout?.cancel(); authorizationTimeout = nil
        manager.stopAccelerometerUpdates()
        manager.stopDeviceMotionUpdates()
    }
}

nonisolated private final class MotionAuthorizationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    func take() -> Bool { lock.withLock { guard !completed else { return false }; completed = true; return true } }
}
