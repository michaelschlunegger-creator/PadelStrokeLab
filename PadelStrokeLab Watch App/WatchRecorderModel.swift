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
    var wrist: PlayingArm?
    var crownDescription: String
    var unavailableReason: String?
    var frequencyDescription: String

    @MainActor static func current(source: WatchMotionSource) -> Self {
        let device = WKInterfaceDevice.current()
        let wrist: PlayingArm?
        switch device.wristLocation {
        case .left: wrist = .left
        case .right: wrist = .right
        @unknown default: wrist = nil
        }
        return Self(wrist: wrist,
                    crownDescription: device.crownOrientation == .left ? "Crown left" : "Crown right",
                    unavailableReason: source.unavailableReason,
                    frequencyDescription: source.frequencyDescription)
    }
}

/// Cohesive synthetic input for UUID-isolated recorder tests. Native adapters do not conform.
/// Supplying this never replaces the coordinator, capture engine, writer, or admission checks.
@MainActor
protocol WatchRecorderSyntheticMotion: AnyObject {
    var capabilityReport: String { get }
    var configurations: [RecordingStreamConfiguration] { get throws }
    func authorize(completion: @escaping @MainActor (String?) -> Void)
    func start(engine: MotionCaptureEngine, generation: UUID) throws
    func stop()
}

@MainActor @Observable
final class WatchRecorderModel {
    static let deletionConfirmationMessage = "Deletes the entire owner practice from this Watch and requests paired-device deletion, including all sets, motion, heart rate and notes. Legacy recordings delete only this Watch copy. Independent exports remain. Unverified owner data is kept."
    static let drillPreferenceKey = "recording.intendedDrill"
    static let armPreferenceKey = "practice.playingArm"
    static let handPreferenceKey = "practice.handedness"
    private let preferences: UserDefaults
    private(set) var preparation = WatchPreparationState()
    private(set) var capturedMetadata: RecordingMetadata?
    var selectedDrillRawValue: String? { preparation.drillRawValue }
    var selectedDrill: RecordingDrill? { preparation.drill }
    var displayedDrillTitle: String {
        capturedMetadata.map { RecordingDrill.recordedTitle(for: $0.drill) }
            ?? selectedDrill?.title ?? "Prepare this Watch on iPhone"
    }
    private(set) var state: MotionCaptureState = .ready { didSet { publishObservation() } }
    private(set) var snapshot: MotionCaptureSnapshot?
    private(set) var message: String?
    private(set) var retained: [WatchRetainedRecording] = []
    var transfers: [UUID: String] { services.transfers }
    private(set) var refreshing = false
    private(set) var deletingRecordingID: UUID?
    private(set) var deletionStatus: String?
    private(set) var capabilityIssue: String?
    private(set) var frequencyDescription = ""
    private(set) var configuredWrist: PlayingArm?
    private(set) var crownDescription = ""
    var recoveryNotice: String {
        get { preferences.string(forKey: "recording.recoveryNotice") ?? "" }
        set { preferences.set(newValue, forKey: "recording.recoveryNotice") }
    }
    var isSyntheticFixture: Bool { !services.environment.allowsHardware }
    var ownerIssue: String? { services.storageError ?? coordinator?.lastError }
    var hasAcceptedPreparation: Bool { preparation.accepted != nil }
    var ownerStatus: String {
        guard services.ownerLoaded else { return ownerIssue ?? "Checking owner preparation…" }
        return hasAcceptedPreparation ? "Phone setup accepted. Check wrist, crown and fit before Start."
            : "Prepare this Watch on your iPhone before starting a set."
    }
    private let storageValidation: (@MainActor () -> String?)?
    private let services: WatchRecordingServices
    private var coordinator: OwnerCaptureCoordinator? { services.coordinator }
    let source: WatchMotionSource
    private let workout: WatchWorkoutDriver
    private let syntheticMotion: (any WatchRecorderSyntheticMotion)?
    private var allowsMotionInput: Bool { initializationIssue == nil && (services.environment.allowsHardware || hasInjectedSource || syntheticMotion != nil) }
    enum InitializationIssue { case untrustedInjectedDependencies }
    let initializationIssue: InitializationIssue?
    private let hasInjectedSource: Bool
    private let beforeWriterDrain: (@MainActor () async -> Void)?
    private var stopEpoch: WatchMotionStopEpoch?
    private var rawStopTime: Double?
    private var drainRequestID: UUID?
    var practice: OwnerPracticeCoordinator? { services.practice }
    private let preparationSettingsProvider: @MainActor () -> WatchPreparationSettings
    private var engine: MotionCaptureEngine?
    private var attempt: OwnerCaptureAttempt?
    private var pendingAdmissionID: UUID?
    private var activeRecordingID: UUID?
    private var paths: RecordingPaths?
    private var connectivity: RecordingConnectivity?
    private var observationTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private var drainTask: Task<Void, Never>?
    private var drainDeadline: Task<Void, Never>?
    private var writerDrainComplete = false
    private var drainingAttemptID: UUID?
    private var changes: AsyncStream<MotionCaptureSnapshot>.Continuation?
    private var completed: Set<UUID> = []
    private var deletedRecordings: Set<UUID> = []
    private var pauseGate = WatchPauseGate()

    init(preparationSettingsProvider: (@MainActor () -> WatchPreparationSettings)? = nil,
         initialState: MotionCaptureState = .ready, preferences: UserDefaults? = nil,
         initialMetadata: RecordingMetadata? = nil, services: WatchRecordingServices? = nil,
         workout: WatchWorkoutDriver? = nil,
         syntheticMotion: (any WatchRecorderSyntheticMotion)? = nil,
         motionSource: WatchMotionSource? = nil,
         beforeWriterDrain: (@MainActor () async -> Void)? = nil,
         storageValidation: (@MainActor () -> String?)? = nil) {
        let services = services ?? WatchRecordingServices.shared
        self.services = services
        self.preferences = preferences ?? services.preferences
        self.workout = workout ?? services.practice?.workout ?? WatchWorkoutDriver(allowsHardware: false)
        let trusted = services.environment.isCoherentFixture
        initializationIssue = (motionSource != nil || beforeWriterDrain != nil) && !trusted ? .untrustedInjectedDependencies : nil
        hasInjectedSource = trusted && motionSource != nil
        self.beforeWriterDrain = trusted ? beforeWriterDrain : nil
        self.syntheticMotion = services.environment.fixtureID != nil && !services.environment.allowsHardware
            && services.environment.failure == nil ? syntheticMotion : nil
        self.storageValidation = storageValidation
        capturedMetadata = initialState == .ready ? nil : initialMetadata
        activeRecordingID = initialState == .ready ? nil : initialMetadata?.recordingID
        let source = trusted ? motionSource ?? WatchMotionSource() : WatchMotionSource()
        self.source = source
        self.preparationSettingsProvider = preparationSettingsProvider ?? { .current(source: source) }
        paths = services.paths; connectivity = services.connectivity; state = initialState
        if allowsMotionInput { stopEpoch = source.stop() }
        services.practice?.onNativeState = { [weak self] kind in self?.workoutChanged(kind) }
        services.practice?.onStopSet = { [weak self] reason in self?.shutdown(reason: reason) }
        services.practice?.onClosureCheck = { [weak self] in self?.acknowledgeClosure() }
        services.practice?.sourceClosed = { [weak self] in
            guard let self else { return true }
            return (!self.allowsMotionInput && self.engine == nil) || self.liveSourceWitness != nil
        }
        services.practice?.recorderClosed = { [weak self] in
            guard let self else { return true }
            return self.engine == nil || (self.writerDrainComplete && self.snapshot?.state.isTerminal == true)
        }
        coordinator?.onChange = { [weak self] in self?.ownerChanged() }
        coordinator?.onInvalidation = { [weak self] reason in self?.shutdown(reason: reason) }
        services.onPracticeDeleted = { [weak self] ids in
            guard let self else { return }
            self.deletedRecordings.formUnion(ids)
            self.retained.removeAll { self.deletedRecordings.contains($0.id) }
            if let metadata = self.capturedMetadata, ids.contains(metadata.recordingID) { self.capturedMetadata = nil }
        }
        ownerChanged()
        let stream = AsyncStream<MotionCaptureSnapshot>(bufferingPolicy: .bufferingNewest(1)) { changes = $0 }
        observationTask = Task { [weak self] in
            for await snapshot in stream { self?.update(snapshot) }
        }
        refreshRetained()
    }
    isolated deinit {
        observationTask?.cancel(); startupTask?.cancel(); drainTask?.cancel(); drainDeadline?.cancel(); changes?.finish()
    }
    var canPrepare: Bool { state == .ready && hasAcceptedPreparation && coordinator?.canBeginNextSet == true }
    var canStart: Bool {
        canPrepare && preparation.isComplete && preparation.arm == configuredWrist &&
            configuredWrist != nil && capabilityIssue == nil && paths != nil && practice?.canStartSet == true
    }
    var canBeginNextSet: Bool { state.isTerminal && coordinator?.canBeginNextSet == true && practice?.canStartSet == true }
    private var liveSourceWitness: WatchMotionClosureWitness? { stopEpoch.flatMap { source.closureWitness(for: $0) } }
    private func ownerChanged() {
        if state == .ready { preparation.adopt(coordinator?.acceptedPreparation); refreshPreparation() }
    }
    func beginPreparation() {
        guard canPrepare else { return }
        refreshPreparation(); preparation.begin(); publishObservation()
    }
    func cancelPreparation() {
        guard state == .ready else { return }
        preparation.reset(); coordinator?.invalidatePhysical(); publishObservation()
    }
    func confirmPlacement() { guard state == .ready else { return }; preparation.confirmPlacement() }
    func confirmOrientation() {
        guard state == .ready, preparation.step == .check else { return }
        let wrist = configuredWrist, crown = crownDescription
        refreshPreparation()
        guard configuredWrist == wrist, crownDescription == crown else { return }
        preparation.confirmOrientation(wrist: configuredWrist)
    }
    func confirmFit() { guard state == .ready else { return }; preparation.confirmFit() }
    func preparationLeftForeground() {
        if state == .ready { preparation.invalidatePhysical() }
        // An admitted local set survives phone loss/background; an unadmitted start does not.
        if state == .ready || state == .starting { coordinator?.invalidatePhysical() }
    }
    func refreshPreparation() {
        guard state == .ready else { return }
        let settings = preparationSettingsProvider()
        let changed = configuredWrist != settings.wrist || crownDescription != settings.crownDescription
        configuredWrist = settings.wrist; crownDescription = settings.crownDescription
        if changed { preparation.orientationChanged(); coordinator?.invalidatePhysical() }
        frequencyDescription = settings.frequencyDescription
        capabilityIssue = initializationIssue != nil ? "Injected dependencies require a coherent isolated fixture."
            : !allowsMotionInput ? "An isolated motion source is required for this fixture."
            : currentStorageIssue() ?? settings.unavailableReason
        if configuredWrist == nil { capabilityIssue = "Watch wrist setting unavailable. Check Watch Orientation settings." }
        publishObservation()
    }
    private func publishObservation() {
        let observed: PracticeSetupWatchState
        switch state {
        case .ready: observed = preparation.step == nil ? .idle : .awaitingConfirmation
        case .starting: observed = .awaitingConfirmation
        case .recording, .resuming: observed = .recording
        case .pausing, .paused: observed = .paused
        case .stopping: observed = .stopping
        case .saved: observed = .saved
        case .interrupted: observed = .interrupted
        case .failed: observed = .failed
        }
        coordinator?.updateObservation(state: observed,
            wrist: configuredWrist == .left ? .left : configuredWrist == .right ? .right : .unknown,
            crown: crownDescription == "Crown left" ? .left : crownDescription == "Crown right" ? .right : .unknown,
            capability: capabilityIssue == nil ? .supported : .unsupported)
    }
    private func currentStorageIssue() -> String? {
        if let storageValidation { return storageValidation() }
        if let error = services.storageError { return error }
        guard let paths, FileManager.default.isWritableFile(atPath: paths.rawRoot.path),
              FileManager.default.isWritableFile(atPath: paths.notesRoot.path) else {
            return "Recording storage unavailable. Restart the app and check free Watch storage."
        }
        return nil
    }
    func start() {
        guard state == .ready else { return }
        refreshPreparation()
        guard canStart, let coordinator, let paths, let changes else { return }
        do {
            guard let practice else { throw OwnerCaptureFailure.unavailable }
            try practice.setWillStart()
            let rawBefore = ProcessInfo.processInfo.systemUptime
            let metadata = try makeMetadata()
            let calibrationInstant = try practice.now()
            let rawAfter = ProcessInfo.processInfo.systemUptime
            let confirmation = coordinator.confirmPhysical(wrist: configuredWrist, crown: crownDescription,
                fit: preparation.isComplete)
            guard let confirmation, preparation.consume() else { return }
            capturedMetadata = metadata; activeRecordingID = metadata.recordingID
            pauseGate.reset(); state = .starting; message = "Checking accepted phone preparation."
            startupTask = Task { [weak self] in
                do {
                    let attempt = try await coordinator.prepareCapture(metadata: metadata, confirmation: confirmation)
                    guard let self else { coordinator.retireCapture(attempt); coordinator.engineDrained(attempt); coordinator.workoutClosed(attempt); return }
                    self.attempt = attempt
                    guard self.state == .starting, self.activeRecordingID == attempt.recordingID,
                          coordinator.isCurrent(attempt), !Task.isCancelled else {
                        self.shutdown(reason: "Preparation changed before capture admission."); return
                    }
                    try await practice.admitSet(context: attempt.context, before: rawBefore, after: rawAfter, instant: calibrationInstant)
                    guard self.attempt == attempt, self.state == .starting, coordinator.isCurrent(attempt) else { throw OwnerCaptureFailure.stale }
                    self.engine = MotionCaptureEngine(metadata: metadata, rawRoot: paths.rawRoot,
                        notesRoot: paths.notesRoot, onChange: { changes.yield($0) })
                    self.message = "Allow motion access to begin the set."
                    guard let engine = self.engine else { throw OwnerCaptureFailure.unavailable }
                    self.pendingAdmissionID = attempt.id
                    self.authorizeMotion { [weak self] error in
                        guard let self, self.attempt == attempt, self.engine === engine,
                            self.state == .starting, coordinator.isCurrent(attempt) else { return }
                        if let error { self.shutdown(reason: error) }
                        else { self.stopEpoch = self.source.stop(); self.admit(engine: engine, attempt: attempt, resuming: false) }
                    }
                } catch {
                    guard let self, self.activeRecordingID == metadata.recordingID else { return }
                    self.shutdown(reason: "Capture preparation failed: \(error.localizedDescription)")
                }
            }
        } catch { shutdown(reason: "Setup failed: \(error.localizedDescription)") }
    }
    func makeMetadata() throws -> RecordingMetadata {
        guard canStart, let arm = preparation.arm, let handedness = preparation.usualHand,
              let configuredWrist, let selectedDrill else { throw OwnerCaptureFailure.unprepared }
        let device = WKInterfaceDevice.current()
        return try RecordingMetadata(recordingID: UUID(),
            clock: RecordingClock(domainID: UUID(), monotonicAnchorSeconds: ProcessInfo.processInfo.systemUptime,
                wallAnchorUnixSeconds: Date().timeIntervalSince1970),
            appBuild: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"))",
            protocolVersion: RecordingDrill.protocolVersion, deviceModel: hardwareModel(device: device),
            operatingSystem: "\(device.systemName) \(device.systemVersion)", handedness: handedness,
            playingArm: arm, watchWrist: configuredWrist, watchOrientation: crownDescription,
            playingArmConfirmed: preparation.finalConfirmed, drill: selectedDrill.rawValue,
            capabilityReport: syntheticMotion?.capabilityReport ?? source.capabilityReport,
            streams: syntheticMotion?.configurations ?? source.configurations)
    }
    func pause() {
        guard state == .recording else { return }
        state = .pausing; pauseGate.request()
        engine?.pause(at: ProcessInfo.processInfo.systemUptime); stopMotion()
    }
    func resume() {
        guard state == .paused, pauseGate.canResume, let attempt, coordinator?.isAdmitted(attempt) == true else { return }
        pauseGate.reset(); state = .resuming; practice?.resume()
    }
    func stop() {
        guard [.starting, .recording, .pausing, .paused, .resuming].contains(state) else { return }
        shutdown(reason: nil)
    }
    private func shutdown(reason: String?) {
        guard state != .ready, state != .stopping || attempt != nil else { return }
        if let attempt, drainingAttemptID == attempt.id { return }
        let wasAdmitted = attempt.map { coordinator?.isAdmitted($0) == true } ?? false
        state = .stopping; pendingAdmissionID = nil; startupTask?.cancel(); stopMotion(); pauseGate.reset()
        let boundary = ProcessInfo.processInfo.systemUptime
        rawStopTime = boundary; practice?.setWillClose()
        if let attempt { coordinator?.retireCapture(attempt); drainingAttemptID = attempt.id }
        else { coordinator?.invalidatePhysical() }
        if let engine {
            if let reason { engine.interrupt(reason) }
            else if !wasAdmitted { engine.interrupt("Stopped before capture began.") }
            else { engine.stop(at: boundary) }
        } else { state = .interrupted }
        if let reason { message = reason }
        if let reason { practice?.fail(reason) }
        guard let attempt, let coordinator else { return }
        if workout.isClosed { coordinator.workoutClosed(attempt) }
        guard let engine else { coordinator.engineDrained(attempt); writerDrainComplete = true; acknowledgeClosure(); return }
        writerDrainComplete = false
        drainDeadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            self?.checkWriterShutdownDeadlineForTesting()
        }
        let request = UUID(), practiceID = attempt.context.practiceID
        drainRequestID = request
        drainTask = Task { [weak self] in
            await self?.beforeWriterDrain?()
            let drained = await engine.snapshot()
            guard let self, self.attempt == attempt, self.engine === engine, self.drainRequestID == request,
                self.practice?.currentPracticeID == practiceID else { return }
            guard drained.state.isTerminal else {
                coordinator.shutdownTimedOut(attempt); self.message = "Writer shutdown is incomplete. A new set is blocked."; return
            }
            self.writerDrainComplete = true; self.drainDeadline?.cancel()
            coordinator.engineDrained(attempt); self.acknowledgeClosure()
        }
    }
    private func acknowledgeClosure() {
        guard let attempt, drainingAttemptID == attempt.id, writerDrainComplete, let witness = liveSourceWitness else { return }
        coordinator?.motionClosed(attempt, witness: witness)
        if workout.isClosed { coordinator?.workoutClosed(attempt) }
        if let rawStopTime { practice?.setStopped(rawTime: rawStopTime) }
    }
    func checkWriterShutdownDeadlineForTesting() {
        guard let attempt, drainingAttemptID == attempt.id, !writerDrainComplete else { return }
        coordinator?.shutdownTimedOut(attempt)
        message = "Waiting for writer shutdown. A new set is blocked."
    }
    func newSet() {
        guard canBeginNextSet || (state.isTerminal && practice?.canBeginPractice == true && writerDrainComplete && liveSourceWitness != nil) else { return }
        rawStopTime = nil; drainRequestID = nil; writerDrainComplete = false
        engine = nil; attempt = nil; snapshot = nil; activeRecordingID = nil; drainingAttemptID = nil
        state = .ready; preparation.reset(); capturedMetadata = nil; message = nil; pauseGate.reset()
        ownerChanged()
    }
    private func hardwareModel(device: WKInterfaceDevice) -> String {
        var system = utsname()
        guard uname(&system) == 0 else { return device.model }
        let bytes = Mirror(reflecting: system.machine).children.compactMap { $0.value as? Int8 }
            .prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return "\(device.model) \(String(decoding: bytes, as: UTF8.self))"
    }
    private func workoutChanged(_ kind: WatchWorkoutDriver.Kind) {
        guard let attempt else { return }
        switch kind {
        case .running:
            guard state == .resuming, pendingAdmissionID != attempt.id, let engine, coordinator?.isCurrent(attempt) == true else { return }
            pendingAdmissionID = attempt.id; admit(engine: engine, attempt: attempt, resuming: true)
        case .paused:
            if [.starting, .recording, .resuming].contains(state) {
                shutdown(reason: "Workout paused without an acknowledged capture pause."); return
            }
            guard state == .pausing || state == .paused else { return }
            if pauseGate.workoutDidPause(), pauseGate.canResume { state = .paused }
        case .ended, .closedWithoutSession:
            if drainingAttemptID != attempt.id { shutdown(reason: "Workout ended before capture was stopped.") }
            coordinator?.workoutClosed(attempt)
        case .shutdownTimedOut:
            coordinator?.shutdownTimedOut(attempt); message = "Waiting for actual workout end."
        case let .failed(reason): shutdown(reason: reason)
        }
    }
    private func admit(engine: MotionCaptureEngine, attempt: OwnerCaptureAttempt, resuming: Bool) {
        guard let coordinator else { return }
        Task { [weak self] in
            defer { if self?.pendingAdmissionID == attempt.id { self?.pendingAdmissionID = nil } }
            do {
                let operation: @MainActor () throws -> Void = { [weak self] in
                    guard let self, self.attempt == attempt, self.engine === engine,
                          self.state == (resuming ? .resuming : .starting),
                          let metadata = self.capturedMetadata else { throw OwnerCaptureFailure.stale }
                    let settings = self.preparationSettingsProvider()
                    guard settings.wrist == metadata.watchWrist, settings.crownDescription == metadata.watchOrientation,
                          settings.unavailableReason == nil, self.currentStorageIssue() == nil,
                          self.allowsMotionInput, self.practice?.permitsResume == true,
                          self.liveSourceWitness != nil else { throw OwnerCaptureFailure.physicalCheck }
                    let completion: @Sendable (UUID?) -> Void = { [weak self] generation in
                        Task { @MainActor [weak self] in
                            guard let self, self.attempt == attempt, self.engine === engine,
                                  [.starting, .resuming, .recording].contains(self.state),
                                  coordinator.isAdmitted(attempt), let generation else { return }
                            guard self.liveSourceWitness != nil, self.practice?.permitsResume == true else {
                                self.shutdown(reason: "Motion closure changed before native acquisition."); return
                            }
                            self.startMotion(engine: engine, generation: generation)
                        }
                    }
                    if resuming { engine.resume(completion: completion) }
                    else { engine.begin(completion: completion) }
                }
                if resuming { try await coordinator.resume(attempt, operation: operation) }
                else { try await coordinator.admit(attempt, operation: operation) }
            } catch {
                guard let self, self.attempt == attempt else { return }
                self.shutdown(reason: "Capture admission denied: \(error.localizedDescription)")
            }
        }
    }
    private func authorizeMotion(completion: @escaping @MainActor (String?) -> Void) {
        if let syntheticMotion { syntheticMotion.authorize(completion: completion) }
        else if allowsMotionInput { source.authorize(completion: completion) }
        else { completion("Synthetic fixtures cannot request native motion access.") }
    }
    private func startMotion(engine: MotionCaptureEngine, generation: UUID) {
        do {
            if let syntheticMotion { try syntheticMotion.start(engine: engine, generation: generation) }
            else {
                guard allowsMotionInput else { throw OwnerCaptureFailure.unavailable }
                source.start(engine: engine, generation: generation)
            }
        } catch { shutdown(reason: "Motion acquisition failed: \(error.localizedDescription)") }
    }
    private func stopMotion() {
        if let syntheticMotion { syntheticMotion.stop() }
        else if allowsMotionInput { stopEpoch = source.stop() }
    }
    private func update(_ value: MotionCaptureSnapshot) {
        guard engine != nil, activeRecordingID == value.recordingID else { return }
        snapshot = value
        if state == .stopping && !value.state.isTerminal { return }
        if state == .pausing && value.state != .paused && !value.state.isTerminal { return }
        state = value.state; message = value.detail
        if value.state == .paused {
            let shouldPauseWorkout = pauseGate.engineDidPause()
            state = pauseGate.canResume ? .paused : .pausing
            if shouldPauseWorkout { practice?.pause() }
        }
        if value.state.isTerminal {
            shutdown(reason: value.detail)
            state = value.state; message = value.detail
            if value.hasLocalRecording, !deletedRecordings.contains(value.recordingID), completed.insert(value.recordingID).inserted {
                refreshRetained(); services.queueRecording(value.recordingID, timeline: value.timeline)
            }
        }
    }

    nonisolated static func canTransfer(recordingID: UUID, activeRecordingID: UUID?, state: MotionCaptureState) -> Bool {
        recordingID != activeRecordingID || state.isTerminal
    }

    func retryTransfer(_ entry: WatchRetainedRecording) {
        guard entry.canTransfer, Self.canTransfer(recordingID: entry.id, activeRecordingID: activeRecordingID, state: state), let timeline = entry.timeline else { return }
        services.queueRecording(entry.id, timeline: timeline)
    }

    nonisolated static func canDelete(recordingID: UUID, activeRecordingID: UUID?, state: MotionCaptureState,
                                      deletionInProgress: Bool) -> Bool {
        !deletionInProgress && (recordingID != activeRecordingID || state.isTerminal)
    }

    func canDelete(_ entry: WatchRetainedRecording) -> Bool {
        Self.canDelete(recordingID: entry.id, activeRecordingID: activeRecordingID, state: state,
                       deletionInProgress: deletingRecordingID != nil)
    }

    /// The visible confirmation covers whole owner practices; only checked legacy data uses copy deletion.
    @discardableResult func deleteWatchCopy(_ entry: WatchRetainedRecording) -> Task<Void, Never>? {
        guard canDelete(entry), retained.contains(where: { $0.id == entry.id }) else { return nil }
        deletingRecordingID = entry.id
        deletionStatus = "Checking retained data…"
        return Task { [weak self] in
            guard let self else { return }
            do {
                if let practiceID = try await services.deletionPracticeID(recordingID: entry.id) {
                    await services.deletePractice(practiceID).value
                    deletionStatus = services.practiceDeletionMessage
                    deletingRecordingID = nil
                    if let activeRecordingID, deletedRecordings.contains(activeRecordingID), state.isTerminal { newSet() }
                } else {
                    guard let connectivity else { throw OwnerCaptureFailure.unavailable }
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
            } catch {
                deletingRecordingID = nil
                deletionStatus = "Deletion failed: owner scope could not be verified. Retained data kept."
            }
        }
    }

    var canRefreshRetained: Bool { deletingRecordingID == nil && (state == .ready || state.isTerminal) }

    func refreshRetained() {
        guard !refreshing, canRefreshRetained, let paths else { return }
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
