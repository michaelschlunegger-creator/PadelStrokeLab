import Foundation
import Observation
import PadelCore
import WatchKit

/// One transport owner for foreground UI and background-only process launches.
@MainActor @Observable
final class WatchRecordingServices {
    static let shared = WatchRecordingServices()
    let paths: RecordingPaths?
    let connectivity: RecordingConnectivity?
    let storageError: String?
    private(set) var transfers: [UUID: String] = [:]

    private init() {
        do {
            let paths = try RecordingPaths()
            self.paths = paths; storageError = nil
            let connection = RecordingConnectivity(paths: paths)
            connectivity = connection
            connection.onChange = { [weak self] transfer in
                Task { @MainActor [weak self] in
                    self?.transfers[transfer.recordingID] = "\(transfer.state.rawValue.capitalized)\(transfer.detail.map { ": " + $0 } ?? "")"
                }
            }
            connection.activate()
        } catch {
            paths = nil; connectivity = nil
            storageError = "Recording storage is unavailable: \(error.localizedDescription)"
        }
    }

    func removeTransfer(_ id: UUID) { transfers.removeValue(forKey: id) }

    func handleConnectivityRefresh(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        let gate = WatchBackgroundCompletionGate {
            task.expirationHandler = nil
            task.setTaskCompletedWithSnapshot(false)
        }
        task.expirationHandler = { @Sendable in gate.finish(cancelDrain: true) }
        guard let connectivity else { gate.finish(cancelDrain: true); return }
        connectivity.activate()
        let token = connectivity.drainForBackground { _ in gate.finish(cancelDrain: false) }
        gate.installCancellation { connectivity.cancelBackgroundDrain(token) }
    }
}

/// No MainActor assumption: expiration and drain callbacks can race on arbitrary framework executors.
nonisolated final class WatchBackgroundCompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private var cancellationRequested = false
    private var cancel: (@Sendable () -> Void)?
    private let completion: @Sendable () -> Void

    init(completion: @escaping @Sendable () -> Void) { self.completion = completion }

    func installCancellation(_ action: @escaping @Sendable () -> Void) {
        let shouldCancel = lock.withLock {
            if completed { return cancellationRequested }
            cancel = action; return false
        }
        if shouldCancel { action() }
    }

    func finish(cancelDrain: Bool) {
        let result: (Bool, (@Sendable () -> Void)?) = lock.withLock {
            guard !completed else { return (false, nil) }
            completed = true; cancellationRequested = cancelDrain
            let action = cancelDrain ? cancel : nil
            cancel = nil
            return (true, action)
        }
        guard result.0 else { return }
        result.1?()
        completion()
    }
}
