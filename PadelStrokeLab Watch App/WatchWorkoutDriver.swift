import Foundation
import HealthKit
import WatchKit

@MainActor protocol WatchWorkoutSessionHandle: AnyObject {
    var id: UUID { get }
    var onState: ((WatchWorkoutDriver.Kind) -> Void)? { get set }
    func start()
    func pause()
    func resume()
    func end()
}
@MainActor protocol WatchWorkoutBackend: AnyObject {
    func authorize(_ completion: @escaping @MainActor (String?) -> Void)
    func makeSession() throws -> any WatchWorkoutSessionHandle
}

@MainActor
final class WatchWorkoutDriver {
    enum Kind: Equatable { case running, paused, ended, closedWithoutSession, shutdownTimedOut, failed(String) }
    struct Event { let attemptID: UUID; let sessionID: UUID?; let kind: Kind }
    var onEvent: ((Event) -> Void)?
    private var backend: (any WatchWorkoutBackend)?
    private let allowsHardware: Bool
    private var request: (id: UUID, attempt: UUID)?
    private var session: (any WatchWorkoutSessionHandle)?
    private var sessionAttempt: UUID?
    private var ending = false
    private var usedAttempts: Set<UUID> = []
    private var stateTimer: Task<Void, Never>?
    private var shutdownTimer: Task<Void, Never>?
    var isClosed: Bool { request == nil && session == nil }

    init(backend: (any WatchWorkoutBackend)? = nil, allowsHardware: Bool = WatchRuntimeEnvironment.current.allowsHardware) {
        self.backend = backend; self.allowsHardware = allowsHardware
    }
    convenience init(backend: any WatchWorkoutBackend, environment: WatchRuntimeEnvironment) {
        self.init(backend: environment.isCoherentFixture ? backend : nil, allowsHardware: false)
    }
    isolated deinit { stateTimer?.cancel(); shutdownTimer?.cancel() }

    func start(attemptID: UUID) {
        guard isClosed, usedAttempts.insert(attemptID).inserted else { return }
        guard allowsHardware || backend != nil else {
            emit(.failed("Synthetic fixtures cannot request Health access."), attempt: attemptID)
            emit(.closedWithoutSession, attempt: attemptID); return
        }
        let provider = backend ?? NativeWatchWorkoutBackend()
        backend = provider
        let requestID = UUID(); request = (requestID, attemptID)
        provider.authorize { [weak self] error in
            guard let self, self.request?.id == requestID, self.request?.attempt == attemptID else { return }
            self.request = nil
            if let error {
                self.emit(.failed(error), attempt: attemptID); self.emit(.closedWithoutSession, attempt: attemptID); return
            }
            do {
                let handle = try provider.makeSession()
                self.install(handle, attempt: attemptID)
                self.armStateDeadline(attempt: attemptID, sessionID: handle.id); handle.start()
            } catch {
                self.emit(.failed("Workout could not start: \(error.localizedDescription)"), attempt: attemptID)
                self.emit(.closedWithoutSession, attempt: attemptID)
            }
        }
    }
    private func install(_ handle: any WatchWorkoutSessionHandle, attempt: UUID) {
        session = handle; sessionAttempt = attempt; ending = false
        let id = handle.id
        handle.onState = { [weak self] kind in self?.receive(kind, attempt: attempt, sessionID: id) }
    }
    func pause() {
        guard !ending, let session, let attempt = sessionAttempt else { return }
        armStateDeadline(attempt: attempt, sessionID: session.id); session.pause()
    }
    func resume() {
        guard !ending, let session, let attempt = sessionAttempt else { return }
        armStateDeadline(attempt: attempt, sessionID: session.id); session.resume()
    }
    func end() {
        stateTimer?.cancel(); stateTimer = nil
        if let request { self.request = nil; emit(.closedWithoutSession, attempt: request.attempt) }
        guard let session, let attempt = sessionAttempt, !ending else { return }
        ending = true; session.end()
        let id = session.id
        shutdownTimer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            self?.shutdownDeadline(attempt: attempt, sessionID: id)
        }
    }
    private func receive(_ kind: Kind, attempt: UUID, sessionID: UUID) {
        guard session?.id == sessionID, sessionAttempt == attempt else { return }
        switch kind {
        case .ended:
            let expected = ending
            stateTimer?.cancel(); shutdownTimer?.cancel(); stateTimer = nil; shutdownTimer = nil
            session = nil; sessionAttempt = nil; ending = false
            if !expected { emit(.failed("Workout ended unexpectedly."), attempt: attempt, sessionID: sessionID) }
            emit(.ended, attempt: attempt, sessionID: sessionID)
        case let .failed(reason):
            end(); emit(.failed(reason), attempt: attempt, sessionID: sessionID)
        case .running, .paused:
            guard !ending else { return }
            stateTimer?.cancel(); stateTimer = nil
            emit(kind, attempt: attempt, sessionID: sessionID)
        default: break
        }
    }
    private func armStateDeadline(attempt: UUID, sessionID: UUID) {
        stateTimer?.cancel()
        stateTimer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard let self, self.session?.id == sessionID, self.sessionAttempt == attempt, !self.ending else { return }
            self.end(); self.emit(.failed("Workout did not confirm its requested state within 5 seconds."), attempt: attempt, sessionID: sessionID)
        }
    }
    private func shutdownDeadline(attempt: UUID, sessionID: UUID) {
        guard ending, session?.id == sessionID, sessionAttempt == attempt else { return }
        // A timeout is not an ended acknowledgement. Keep the native resource retained.
        emit(.shutdownTimedOut, attempt: attempt, sessionID: sessionID)
    }
    func checkShutdownDeadlineForTesting() {
        if let session, let attempt = sessionAttempt { shutdownDeadline(attempt: attempt, sessionID: session.id) }
    }
    private func emit(_ kind: Kind, attempt: UUID, sessionID: UUID? = nil) {
        onEvent?(.init(attemptID: attempt, sessionID: sessionID, kind: kind))
    }
    func endRecovered(_ native: HKWorkoutSession) {
        guard isClosed, allowsHardware else { return }
        install(NativeWatchWorkoutSession(session: native), attempt: UUID())
        end()
    }
}

@MainActor private final class NativeWatchWorkoutBackend: WatchWorkoutBackend {
    private let health = HKHealthStore()
    func authorize(_ completion: @escaping @MainActor (String?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { completion("HealthKit is unavailable on this Watch."); return }
        let workout = HKObjectType.workoutType()
        // O5 requests workout sharing only. O7 owns optional live heart-rate acquisition.
        health.requestAuthorization(toShare: [workout], read: []) { [weak self] success, error in
            let message = error?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                completion(success && self.health.authorizationStatus(for: workout) == .sharingAuthorized
                    ? nil : message ?? "Workout permission was not granted.")
            }
        }
    }
    func makeSession() throws -> any WatchWorkoutSessionHandle {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other; configuration.locationType = .unknown
        return NativeWatchWorkoutSession(session: try HKWorkoutSession(healthStore: health, configuration: configuration))
    }
}
@MainActor private final class NativeWatchWorkoutSession: NSObject, WatchWorkoutSessionHandle, HKWorkoutSessionDelegate {
    let id = UUID()
    var onState: ((WatchWorkoutDriver.Kind) -> Void)?
    private let native: HKWorkoutSession
    init(session: HKWorkoutSession) { native = session; super.init(); native.delegate = self }
    func start() { native.startActivity(with: Date()) }
    func pause() { native.pause() }
    func resume() { native.resume() }
    func end() { native.end() }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                   from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor [weak self] in
            guard let self, self.native === workoutSession else { return }
            switch toState {
            case .running: self.onState?(.running)
            case .paused: self.onState?(.paused)
            case .ended: self.onState?(.ended)
            case .stopped: self.native.end()
            default: break
            }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, self.native === workoutSession else { return }
            self.onState?(.failed("Workout error: \(message)"))
        }
    }
}

@MainActor
final class WatchApplicationDelegate: NSObject, WKApplicationDelegate {
    private var recoveryDriver: WatchWorkoutDriver?
    private var recoveryRequestID: UUID?
    private var recoveryStore: HKHealthStore?
    func applicationDidFinishLaunching() { _ = WatchRecordingServices.shared }
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        let services = WatchRecordingServices.shared
        for task in backgroundTasks {
            if let connectivityTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                services.handleConnectivityRefresh(connectivityTask)
            } else if let snapshot = task as? WKSnapshotRefreshBackgroundTask {
                snapshot.setTaskCompleted(restoredDefaultState: false, estimatedSnapshotExpiration: .distantFuture, userInfo: nil)
            } else { task.setTaskCompletedWithSnapshot(false) }
        }
    }
    func handleActiveWorkoutRecovery() {
        let services = WatchRecordingServices.shared
        guard recoveryRequestID == nil, services.environment.allowsHardware, let coordinator = services.coordinator else { return }
        let requestID = UUID(); recoveryRequestID = requestID
        coordinator.beginRecovery()
        services.preferences.set("An active workout was recovered after interruption. Capture was not resumed.", forKey: "recording.recoveryNotice")
        let store = HKHealthStore(); recoveryStore = store
        store.recoverActiveWorkoutSession { [weak self, weak coordinator] session, error in
            let message = error?.localizedDescription
            Task { @MainActor in
                guard let self, self.recoveryRequestID == requestID, let coordinator else { return }
                if let message {
                    services.preferences.set("Workout recovery failed: \(message)", forKey: "recording.recoveryNotice")
                    return
                }
                guard let session else {
                    self.recoveryRequestID = nil; self.recoveryStore = nil; coordinator.recoveryEnded(); return
                }
                let driver = WatchWorkoutDriver()
                self.recoveryDriver = driver
                driver.onEvent = { [weak self, weak coordinator] event in
                    guard let self, self.recoveryRequestID == requestID else { return }
                    if event.kind == .ended {
                        self.recoveryDriver = nil; self.recoveryStore = nil; self.recoveryRequestID = nil
                        coordinator?.recoveryEnded()
                    } else if event.kind == .shutdownTimedOut {
                        services.preferences.set("Waiting for the recovered workout to end. A new set is blocked.", forKey: "recording.recoveryNotice")
                    }
                }
                driver.endRecovered(session)
            }
        }
    }
}
