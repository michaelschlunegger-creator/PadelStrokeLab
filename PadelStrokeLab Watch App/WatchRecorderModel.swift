import Foundation
import Darwin
import Observation
import PadelCore
import WatchKit

struct WatchRetainedRecording: Identifiable, Sendable {
    let id: UUID
    let status: String
    let samples: Int
    let intendedDrill: String?
    let timeline: CaptureTimeline?
    let canTransfer: Bool
}

/// Read-only preparation inputs. The production provider always reads the actual Watch.
struct WatchPreparationSettings {
    var wrist: PlayingArm
    var crownDescription: String
    var unavailableReason: String?
    var frequencyDescription: String

    @MainActor static func current(source: WatchMotionSource) -> Self {
        let device = WKInterfaceDevice.current()
        return Self(wrist: device.wristLocation == .left ? .left : .right,
                    crownDescription: device.crownOrientation == .left ? "Crown left" : "Crown right",
                    unavailableReason: source.unavailableReason,
                    frequencyDescription: source.frequencyDescription)
    }
}

@MainActor @Observable
final class WatchRecorderModel {
    static let drillPreferenceKey = "recording.intendedDrill"
    private let preferences: UserDefaults
    private(set) var selectedDrillRawValue: String?
    private(set) var capturedMetadata: RecordingMetadata?
    var selectedDrill: RecordingDrill? { selectedDrillRawValue.flatMap(RecordingDrill.init(rawValue:)) }
    var canSelectDrill: Bool { state == .ready }
    var drillSelectionMessage: String {
        if let selectedDrill { return selectedDrill.title }
        return selectedDrillRawValue == nil ?
            "Choose shot type" : "Saved shot type unavailable—choose again"
    }
    var displayedDrillTitle: String {
        if let capturedMetadata { return RecordingDrill.recordedTitle(for: capturedMetadata.drill) }
        return drillSelectionMessage
    }

    private(set) var state: MotionCaptureState = .ready
    private(set) var snapshot: MotionCaptureSnapshot?
    private(set) var message: String?
    private(set) var retained: [WatchRetainedRecording] = []
    var transfers: [UUID: String] { services.transfers }
    private(set) var refreshing = false
    private(set) var deletingRecordingID: UUID?
    private(set) var deletionStatus: String?
    private(set) var capabilityIssue: String?
    private(set) var frequencyDescription = ""
    private(set) var configuredWrist: PlayingArm = .right
    private(set) var crownDescription = ""
    var armConfirmed = false
    private let services = WatchRecordingServices.shared
    private let source: WatchMotionSource
    private let workout = WatchWorkoutDriver()
    private let preparationSettingsProvider: @MainActor () -> WatchPreparationSettings
    private var engine: MotionCaptureEngine?
    private var activeRecordingID: UUID?
    private var paths: RecordingPaths?
    private var connectivity: RecordingConnectivity?
    private var observationTask: Task<Void, Never>?
    private var changes: AsyncStream<MotionCaptureSnapshot>.Continuation?
    private var completed: Set<UUID> = []
    private var deletedRecordings: Set<UUID> = []
    private var pauseGate = WatchPauseGate()

    // Injection permits lifecycle tests without authorizing or starting hardware. UI uses defaults.
    init(preparationSettingsProvider: (@MainActor () -> WatchPreparationSettings)? = nil,
         initialState: MotionCaptureState = .ready,
         preferences: UserDefaults = .standard, initialMetadata: RecordingMetadata? = nil) {
        self.preferences = preferences
        selectedDrillRawValue = preferences.string(forKey: Self.drillPreferenceKey)
        capturedMetadata = initialState == .ready ? nil : initialMetadata
        activeRecordingID = initialState == .ready ? nil : initialMetadata?.recordingID
        let source = WatchMotionSource()
        self.source = source
        self.preparationSettingsProvider = preparationSettingsProvider ?? { .current(source: source) }
        paths = services.paths
        connectivity = services.connectivity
        refreshPreparation()
        state = initialState
        workout.onEvent = { [weak self] event in self?.workoutChanged(event) }
        let stream = AsyncStream<MotionCaptureSnapshot>(bufferingPolicy: .bufferingNewest(1)) { changes = $0 }
        observationTask = Task { [weak self] in
            for await snapshot in stream { self?.update(snapshot) }
        }
        refreshRetained()
    }

    isolated deinit { observationTask?.cancel(); changes?.finish() }

    var canPrepare: Bool { state == .ready || state.isTerminal }
    func canStart(arm: PlayingArm) -> Bool {
        state == .ready && selectedDrill != nil && armConfirmed && arm == configuredWrist && capabilityIssue == nil && paths != nil
    }

    func selectDrill(_ drill: RecordingDrill) {
        guard canSelectDrill, selectedDrill != drill else { return }
        selectedDrillRawValue = drill.rawValue
        preferences.set(drill.rawValue, forKey: Self.drillPreferenceKey)
        armConfirmed = false
    }

    /// Both playing-arm and handedness changes require a new placement confirmation.
    func preparationInputChanged() {
        guard state == .ready else { return }
        armConfirmed = false
    }

    /// Returning from Settings can recover preparation, but cannot change an active set's inputs.
    func refreshPreparation() {
        guard canPrepare else { return }
        let settings = preparationSettingsProvider()
        if configuredWrist != settings.wrist || crownDescription != settings.crownDescription {
            armConfirmed = false
        }
        configuredWrist = settings.wrist
        crownDescription = settings.crownDescription
        frequencyDescription = settings.frequencyDescription
        capabilityIssue = services.storageError ?? settings.unavailableReason
    }

    func start(arm: PlayingArm, handedness: PlayingArm) {
        guard state == .ready else { return }
        refreshPreparation()
        guard canStart(arm: arm), let paths, let changes else { return }
        do {
            let metadata = try makeMetadata(arm: arm, handedness: handedness)
            // Freeze intent before starting any asynchronous workout, permission or capture work.
            capturedMetadata = metadata
            activeRecordingID = metadata.recordingID
            engine = MotionCaptureEngine(metadata: metadata, rawRoot: paths.rawRoot, notesRoot: paths.notesRoot,
                                         onChange: { changes.yield($0) })
            pauseGate.reset()
            state = .starting; message = "Allow workout and motion access to begin. Waiting for the workout."
            armConfirmed = false; workout.start()
        } catch { state = .failed; message = "Setup failed: \(error.localizedDescription)"; source.stop(); workout.end() }
    }

    /// The synchronous header path used by Start. Construction alone never authorizes or starts hardware.
    /// Start separately rechecks current settings, capability and durable storage before calling this.
    func makeMetadata(arm: PlayingArm, handedness: PlayingArm) throws -> RecordingMetadata {
        guard state == .ready, let selectedDrill, armConfirmed, arm == configuredWrist else {
            throw RecordingError.invalid("Choose a shot type and confirm the Watch on your playing arm.")
        }
        let device = WKInterfaceDevice.current()
        return try RecordingMetadata(recordingID: UUID(),
            clock: RecordingClock(domainID: UUID(), monotonicAnchorSeconds: ProcessInfo.processInfo.systemUptime,
                          wallAnchorUnixSeconds: Date().timeIntervalSince1970),
            appBuild: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"))",
            protocolVersion: RecordingDrill.protocolVersion, deviceModel: hardwareModel(device: device),
            operatingSystem: "\(device.systemName) \(device.systemVersion)", handedness: handedness,
            playingArm: arm, watchWrist: configuredWrist, watchOrientation: crownDescription,
            playingArmConfirmed: armConfirmed, drill: selectedDrill.rawValue,
            capabilityReport: source.capabilityReport,
            streams: source.configurations)
    }

    func pause() {
        guard state == .recording else { return }
        let cutoff = ProcessInfo.processInfo.systemUptime
        state = .pausing; pauseGate.request()
        engine?.pause(at: cutoff)
        source.stop()
    }
    func resume() {
        guard state == .paused, pauseGate.canResume else { return }
        pauseGate.reset()
        state = .resuming; workout.resume()
    }
    func stop() {
        guard [.starting, .recording, .paused, .resuming].contains(state) else { return }
        let cutoff = ProcessInfo.processInfo.systemUptime
        state = .stopping; engine?.stop(at: cutoff); source.stop(); workout.end()
        // Before the workout ever runs, there is no raw recording to seal.
        if snapshot == nil {
            engine?.interrupt("Stopped before motion capture began.")
            state = .interrupted; message = "Stopped before motion capture began."
        }
    }
    func newSet() {
        guard state.isTerminal else { return }
        source.stop(); workout.end(); engine = nil; snapshot = nil; activeRecordingID = nil
        state = .ready; armConfirmed = false; capturedMetadata = nil; message = nil; pauseGate.reset()
        refreshPreparation()
    }

    private func hardwareModel(device: WKInterfaceDevice) -> String {
        var system = utsname()
        guard uname(&system) == 0 else { return device.model }
        let bytes = Mirror(reflecting: system.machine).children.compactMap { $0.value as? Int8 }
            .prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return "\(device.model) \(String(decoding: bytes, as: UTF8.self))"
    }

    private func workoutChanged(_ event: WatchWorkoutDriver.Event) {
        switch event {
        case .running:
            guard let engine, [.starting, .resuming].contains(state) else { workout.end(); return }
            let completion: @Sendable (UUID?) -> Void = { [weak self] generation in
                Task { @MainActor [weak self] in
                    guard let self, self.engine === engine, [.starting, .resuming, .recording].contains(self.state),
                          let generation else { return }
                    self.source.start(engine: engine, generation: generation)
                }
            }
            if state == .resuming { engine.resume(completion: completion) }
            else {
                message = "Preparing motion permission (up to 30 seconds). Setup samples are not recorded."
                source.authorize { [weak self] error in
                    guard let self, self.engine === engine, self.state == .starting else { return }
                    if let error { self.source.stop(); self.workout.end(); engine.interrupt(error); self.message = error; self.state = .interrupted }
                    else { self.frequencyDescription = self.source.frequencyDescription; engine.begin(completion: completion) }
                }
            }
        case .paused:
            guard pauseGate.workoutDidPause() else {
                source.stop(); engine?.interrupt("Workout paused unexpectedly; recording interrupted."); workout.end()
                state = .interrupted; message = "Workout paused unexpectedly."
                return
            }
            if pauseGate.canResume { state = .paused }
        case .ended: break
        case .failed(let reason):
            source.stop(); workout.end(); engine?.interrupt(reason)
            state = .interrupted; message = reason; pauseGate.reset()
        }
    }

    private func update(_ value: MotionCaptureSnapshot) {
        guard engine != nil, activeRecordingID == value.recordingID else { return }
        snapshot = value
        if state == .stopping && !value.state.isTerminal { return }
        if state == .pausing && value.state != .paused && !value.state.isTerminal { return }
        state = value.state
        message = value.detail
        if value.state == .paused {
            let shouldPauseWorkout = pauseGate.engineDidPause()
            state = pauseGate.canResume ? .paused : .pausing
            if shouldPauseWorkout { workout.pause() }
        }
        if value.state.isTerminal {
            pauseGate.reset()
            source.stop(); workout.end()
            if value.hasLocalRecording, completed.insert(value.recordingID).inserted {
                refreshRetained()
                connectivity?.queue(recordingID: value.recordingID, timeline: value.timeline)
            }
        }
    }

    nonisolated static func canTransfer(recordingID: UUID, activeRecordingID: UUID?, state: MotionCaptureState) -> Bool {
        recordingID != activeRecordingID || state.isTerminal
    }

    func retryTransfer(_ entry: WatchRetainedRecording) {
        guard entry.canTransfer, Self.canTransfer(recordingID: entry.id, activeRecordingID: activeRecordingID, state: state), let timeline = entry.timeline else { return }
        connectivity?.queue(recordingID: entry.id, timeline: timeline)
    }

    nonisolated static func canDelete(recordingID: UUID, activeRecordingID: UUID?, state: MotionCaptureState,
                                      deletionInProgress: Bool) -> Bool {
        !deletionInProgress && (recordingID != activeRecordingID || state.isTerminal)
    }

    func canDelete(_ entry: WatchRetainedRecording) -> Bool {
        Self.canDelete(recordingID: entry.id, activeRecordingID: activeRecordingID, state: state,
                       deletionInProgress: deletingRecordingID != nil)
    }

    /// Called only by the explicit destructive confirmation; shared transaction owns files and cancellation.
    func deleteWatchCopy(_ entry: WatchRetainedRecording) {
        guard canDelete(entry), retained.contains(where: { $0.id == entry.id }), let connectivity else { return }
        deletingRecordingID = entry.id
        deletionStatus = "Deleting this Watch copy…"
        connectivity.deleteWatchCopy(recordingID: entry.id) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.deletingRecordingID = nil
                switch result {
                case .success:
                    self.deletedRecordings.insert(entry.id)
                    self.retained.removeAll { $0.id == entry.id }
                    self.services.removeTransfer(entry.id)
                    if self.activeRecordingID == entry.id, self.state.isTerminal { self.newSet() }
                    self.deletionStatus = "Watch copy deleted. Any iPhone copy and independent exports remain."
                case .failure(let error):
                    self.deletionStatus = "Deletion failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func refreshRetained() {
        guard !refreshing, canPrepare, let paths else { return }
        refreshing = true
        Task { [weak self] in
            let entries = await Task.detached(priority: .utility) { Self.inspect(paths: paths) }.value
            guard let self else { return }
            self.retained = entries.filter { !self.deletedRecordings.contains($0.id) }; self.refreshing = false
        }
    }

    nonisolated private static func inspect(paths: RecordingPaths) -> [WatchRetainedRecording] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: paths.rawRoot, includingPropertiesForKeys: nil) else { return [] }
        return urls.filter { UUID(uuidString: $0.lastPathComponent) != nil }.prefix(200).compactMap { url in
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            do {
                let report = try RecordingStore.inspect(root: paths.rawRoot, recordingID: id)
                let timeline = try? SessionAnnotationsStore(root: paths.notesRoot).loadTimeline(recordingID: id)
                let status = report.finalization?.reason == .interrupted ? "Interrupted" : report.status.rawValue.capitalized
                return WatchRetainedRecording(id: id, status: status,
                    samples: report.chunks.reduce(0) { $0 + $1.sampleCount }, intendedDrill: report.metadata?.drill, timeline: timeline,
                    canTransfer: timeline != nil && (report.status == .finalized || report.status == .interrupted))
            } catch {
                return WatchRetainedRecording(id: id, status: "Inspection failed", samples: 0, intendedDrill: nil, timeline: nil, canTransfer: false)
            }
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

/// Resume is valid only after both durable capture pause and HealthKit's actual pause acknowledgement.
struct WatchPauseGate {
    private(set) var requested = false
    private var engineSealed = false
    private var workoutPaused = false
    var canResume: Bool { requested && engineSealed && workoutPaused }
    mutating func request() { requested = true; engineSealed = false; workoutPaused = false }
    mutating func engineDidPause() -> Bool {
        guard requested, !engineSealed else { return false }
        engineSealed = true; return true
    }
    mutating func workoutDidPause() -> Bool {
        guard requested else { return false }
        workoutPaused = true; return true
    }
    mutating func reset() { self = WatchPauseGate() }
}
