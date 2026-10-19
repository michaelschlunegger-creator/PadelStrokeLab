import Foundation
import HealthKit
import WatchKit

@MainActor
final class WatchWorkoutDriver: NSObject, HKWorkoutSessionDelegate {
    enum Event { case running, paused, ended, failed(String) }
    var onEvent: ((Event) -> Void)?
    private let health = HKHealthStore()
    private var session: HKWorkoutSession?
    private var requestID: UUID?
    private var expectedEnd = false
    private var startingTimer: Task<Void, Never>?

    func start() {
        guard session == nil, requestID == nil else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            onEvent?(.failed("HealthKit is unavailable on this Watch.")); return
        }
        expectedEnd = false
        let request = UUID(); requestID = request
        let workout = HKObjectType.workoutType()
        // Zero Health read types. No builder is created and no workout summary is saved.
        health.requestAuthorization(toShare: [workout], read: []) { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self, self.requestID == request else { return }
                self.requestID = nil
                guard success, self.health.authorizationStatus(for: workout) == .sharingAuthorized else {
                    self.onEvent?(.failed(error?.localizedDescription ?? "Workout permission was not granted.")); return
                }
                do {
                    let configuration = HKWorkoutConfiguration()
                    configuration.activityType = .other
                    configuration.locationType = .unknown
                    let session = try HKWorkoutSession(healthStore: self.health, configuration: configuration)
                    self.session = session; session.delegate = self
                    session.startActivity(with: Date())
                    self.armStartupWatchdog()
                } catch { self.end(); self.onEvent?(.failed("Workout could not start: \(error.localizedDescription)")) }
            }
        }
    }

    func pause() { session?.pause(); armStartupWatchdog() }
    func resume() { session?.resume(); armStartupWatchdog() }
    func end() {
        expectedEnd = true; requestID = nil
        startingTimer?.cancel(); startingTimer = nil
        session?.end()
        session = nil
    }

    private func armStartupWatchdog() {
        startingTimer?.cancel()
        startingTimer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard let self else { return }
            self.end(); self.onEvent?(.failed("Workout did not confirm its requested state within 5 seconds."))
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                   from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor [weak self] in
            guard let self, self.session === workoutSession else { return }
            switch toState {
            case .running:
                self.startingTimer?.cancel(); self.startingTimer = nil; self.onEvent?(.running)
            case .paused:
                self.startingTimer?.cancel(); self.startingTimer = nil; self.onEvent?(.paused)
            case .ended:
                self.startingTimer?.cancel(); self.startingTimer = nil; self.session = nil
                self.onEvent?(self.expectedEnd ? .ended : .failed("The workout ended unexpectedly; recording was interrupted."))
            case .stopped:
                if !self.expectedEnd { self.end(); self.onEvent?(.failed("The workout stopped unexpectedly.")) }
            default: break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, self.session === workoutSession else { return }
            self.end(); self.onEvent?(.failed("Workout error: \(message)"))
        }
    }
}

/// watchOS may relaunch after a crash with the prior owned workout still active.
/// End that resource; never reconnect a new sensor generation to old raw files.
@MainActor
final class WatchApplicationDelegate: NSObject, WKApplicationDelegate {
    private let health = HKHealthStore()

    func applicationDidFinishLaunching() { _ = WatchRecordingServices.shared }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        let services = WatchRecordingServices.shared
        for task in backgroundTasks {
            if let connectivityTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                services.handleConnectivityRefresh(connectivityTask)
            } else if let snapshot = task as? WKSnapshotRefreshBackgroundTask {
                snapshot.setTaskCompleted(restoredDefaultState: false, estimatedSnapshotExpiration: .distantFuture, userInfo: nil)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    func handleActiveWorkoutRecovery() {
        UserDefaults.standard.set("An active workout was recovered after interruption. Its capture was not resumed.",
                                  forKey: "recording.recoveryNotice")
        health.recoverActiveWorkoutSession { session, error in
            session?.end()
            if let error {
                UserDefaults.standard.set("Workout recovery failed: \(error.localizedDescription)",
                                          forKey: "recording.recoveryNotice")
            }
        }
    }
}
