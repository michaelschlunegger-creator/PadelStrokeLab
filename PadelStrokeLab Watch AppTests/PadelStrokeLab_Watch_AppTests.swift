import Foundation
import Testing
import PadelCore
@testable import PadelStrokeLab_Watch_App

@MainActor
struct PadelStrokeLab_Watch_AppTests {
    @Test func freshModelRequiresPlacementConfirmationAndNeverAutoStarts() {
        let settings = PreparationSettingsFixture()
        let model = WatchRecorderModel(preferences: settings.preferences)
        #expect(model.state == .ready)
        #expect(!model.armConfirmed)
        #expect(model.snapshot == nil)
        #expect(!model.canStart(arm: .left))
        #expect(!model.canStart(arm: .right))
    }

    @Test func configuredWristMismatchCannotStart() {
        let settings = PreparationSettingsFixture()
        let model = WatchRecorderModel(preferences: settings.preferences)
        model.armConfirmed = true
        let wrongArm: PlayingArm = model.configuredWrist == .left ? .right : .left
        #expect(!model.canStart(arm: wrongArm))
        model.start(arm: wrongArm, handedness: .right)
        #expect(model.state == .ready && model.snapshot == nil)
    }

    @Test func simulatorHasHonestCapabilityError() {
        #if targetEnvironment(simulator)
        let settings = PreparationSettingsFixture()
        let model = WatchRecorderModel(preferences: settings.preferences)
        model.armConfirmed = true
        #expect(model.capabilityIssue?.contains("physical Apple Watch") == true)
        model.refreshPreparation()
        #expect(model.capabilityIssue?.contains("physical Apple Watch") == true)
        #expect(!model.canStart(arm: model.configuredWrist))
        model.start(arm: model.configuredWrist, handedness: .right)
        #expect(model.state == .ready && model.snapshot == nil)
        #endif
    }

    @Test func preparationRecoversFromMotionDenialWithoutRecreatingModel() {
        let settings = PreparationSettingsFixture()
        settings.value.unavailableReason = "Motion access is denied. Enable Motion & Fitness access in Settings."
        let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, preferences: settings.preferences)
        model.armConfirmed = true
        #expect(!model.canStart(arm: .right))

        settings.value.unavailableReason = nil
        settings.value.frequencyDescription = "Newly available reported frequencies"
        model.refreshPreparation()

        #expect(settings.readCount == 2)
        #expect(model.capabilityIssue == nil)
        #expect(model.frequencyDescription == settings.value.frequencyDescription)
        #expect(model.armConfirmed && model.canStart(arm: .right))
        #expect(model.state == .ready && model.snapshot == nil && model.message == nil)
    }

    @Test func preparationRecoversFromWristMismatchWithFreshConfirmation() {
        let settings = PreparationSettingsFixture()
        let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, preferences: settings.preferences)
        model.armConfirmed = true
        #expect(!model.canStart(arm: .left))

        settings.value.wrist = .left
        model.refreshPreparation()

        #expect(model.configuredWrist == .left)
        #expect(!model.armConfirmed && !model.canStart(arm: .left))
        model.armConfirmed = true
        #expect(model.canStart(arm: .left))
        #expect(model.state == .ready && model.snapshot == nil && model.message == nil)
    }

    @Test func crownChangeInvalidatesPlacementConfirmation() {
        let settings = PreparationSettingsFixture()
        let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, preferences: settings.preferences)
        model.armConfirmed = true
        settings.value.crownDescription = "Crown left"
        model.refreshPreparation()
        #expect(model.configuredWrist == .right && model.crownDescription == "Crown left")
        #expect(!model.armConfirmed && !model.canStart(arm: .right))
        #expect(model.state == .ready && model.snapshot == nil)
    }

    @Test func unchangedConfigurationPreservesReadyAndTerminalState() {
        for state: MotionCaptureState in [.ready, .saved, .interrupted, .failed] {
            let settings = PreparationSettingsFixture()
            let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, initialState: state, preferences: settings.preferences)
            model.armConfirmed = true
            settings.value.frequencyDescription = "Refreshed reported frequencies"
            model.refreshPreparation()
            #expect(settings.readCount == 2)
            #expect(model.armConfirmed)
            #expect(model.state == state && model.snapshot == nil && model.message == nil)
            #expect(model.frequencyDescription == settings.value.frequencyDescription)
            #expect(model.canStart(arm: .right) == (state == .ready))
        }
    }

    @Test func preparationRefreshDoesNotReadOrChangeSettingsInAnyActivePhase() {
        for state: MotionCaptureState in [.starting, .recording, .pausing, .paused, .resuming, .stopping] {
            let settings = PreparationSettingsFixture()
            let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, initialState: state, preferences: settings.preferences)
            model.armConfirmed = true
            settings.value = WatchPreparationSettings(wrist: .left, crownDescription: "Crown left",
                unavailableReason: "Motion access is denied.", frequencyDescription: "Changed frequencies")
            model.refreshPreparation()
            model.start(arm: .right, handedness: .right)
            #expect(settings.readCount == 1)
            #expect(model.state == state && model.snapshot == nil && model.message == nil)
            #expect(model.configuredWrist == .right && model.crownDescription == "Crown right")
            #expect(model.frequencyDescription == "Initial reported frequencies")
            #expect(model.capabilityIssue == nil && model.armConfirmed)
            #expect(!model.canStart(arm: .right))
        }
    }

    @Test func preparationRefreshPreservesBlockingCapabilityReasons() {
        for reason in ["Motion access is denied. Enable Motion & Fitness access in Settings.",
                       "Motion access is restricted on this Watch.",
                       "This Watch does not support both required batched motion streams."] {
            let settings = PreparationSettingsFixture()
            let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, preferences: settings.preferences)
            model.armConfirmed = true
            settings.value.unavailableReason = reason
            model.refreshPreparation()
            #expect(model.capabilityIssue == reason)
            #expect(!model.canStart(arm: .right))
            model.start(arm: .right, handedness: .right)
            #expect(model.state == .ready && model.snapshot == nil && model.message == nil)
        }
    }

    @Test func startRechecksConfigurationBeforeAnyWorkoutOrCapture() {
        for change in ["wrist", "crown", "permission"] {
            let settings = PreparationSettingsFixture()
            let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, preferences: settings.preferences)
            model.armConfirmed = true
            #expect(model.canStart(arm: .right))
            switch change {
            case "wrist": settings.value.wrist = .left
            case "crown": settings.value.crownDescription = "Crown left"
            default: settings.value.unavailableReason = "Motion access is denied."
            }
            model.start(arm: .right, handedness: .right)
            #expect(settings.readCount == 2)
            #expect(!model.canStart(arm: .right))
            #expect(model.state == .ready && model.snapshot == nil && model.message == nil)
            if change != "permission" { #expect(!model.armConfirmed) }
        }
    }

    @Test func newSetRefreshesPreparationAndRequiresConfirmation() {
        let settings = PreparationSettingsFixture()
        settings.value.unavailableReason = "Motion access is denied."
        let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, initialState: .interrupted, preferences: settings.preferences)
        settings.value = WatchPreparationSettings(wrist: .left, crownDescription: "Crown left",
            unavailableReason: nil, frequencyDescription: "Refreshed reported frequencies")
        model.armConfirmed = true
        model.newSet()
        #expect(settings.readCount == 2)
        #expect(model.state == .ready && model.snapshot == nil && model.message == nil)
        #expect(model.configuredWrist == .left && model.crownDescription == "Crown left")
        #expect(model.capabilityIssue == nil && model.frequencyDescription == settings.value.frequencyDescription)
        #expect(!model.armConfirmed && !model.canStart(arm: .left))
    }

    @Test func missingAndUnknownPreferencesBlockMetadataAndStartWithoutCoercion() {
        for raw: String? in [nil, "", "futureDrill"] {
            let settings = PreparationSettingsFixture()
            settings.preferences.set(raw, forKey: WatchRecorderModel.drillPreferenceKey)
            let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, preferences: settings.preferences)
            #expect(model.selectedDrill == nil)
            #expect(model.drillSelectionMessage == (raw == nil ?
                "Choose shot type" : "Saved shot type unavailable—choose again"))
            model.armConfirmed = true
            #expect(!model.canStart(arm: .right))
            #expect(throws: (any Error).self) { try model.makeMetadata(arm: .right, handedness: .right) }
            model.start(arm: .right, handedness: .right)
            #expect(model.state == .ready && model.capturedMetadata == nil && model.snapshot == nil)
            #expect(settings.preferences.string(forKey: WatchRecorderModel.drillPreferenceKey) == raw)
        }
    }

    @Test func validChoicePersistsButConfirmationDoesNotAndChangesResetIt() {
        let settings = PreparationSettingsFixture()
        let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, preferences: settings.preferences)
        model.armConfirmed = true
        model.selectDrill(.backhandVolley)
        #expect(!model.armConfirmed && model.selectedDrill == .backhandVolley)
        #expect(settings.preferences.string(forKey: WatchRecorderModel.drillPreferenceKey) == "backhandVolley")
        model.armConfirmed = true
        model.selectDrill(.backhandVolley)
        #expect(model.armConfirmed) // The same value is not an input change.
        model.selectDrill(.otherUnclassified)
        #expect(!model.armConfirmed && model.selectedDrill == .otherUnclassified)
        #expect(model.drillSelectionMessage == "Other / unclassified")
        model.armConfirmed = true
        model.preparationInputChanged()
        #expect(!model.armConfirmed) // Shared handler used by both arm and handedness changes.
        model.armConfirmed = true
        let relaunched = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, preferences: settings.preferences)
        #expect(relaunched.selectedDrill == .otherUnclassified && !relaunched.armConfirmed)
        #expect(relaunched.capturedMetadata == nil && relaunched.state == .ready)
    }

    @Test(arguments: RecordingDrill.allCases)
    func actualSynchronousStartMetadataUsesSelectedTypeAndNewProtocol(_ drill: RecordingDrill) throws {
        let settings = PreparationSettingsFixture()
        let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, preferences: settings.preferences)
        model.selectDrill(drill); model.armConfirmed = true
        let metadata = try model.makeMetadata(arm: .right, handedness: .left)
        let bytes = try RecordingChunkCodec.encodeMetadata(metadata)
        #expect(metadata.drill == drill.rawValue && metadata.protocolVersion == "owner-manual-training-logger-1")
        #expect(metadata.playingArm == .right && metadata.handedness == .left && metadata.watchWrist == .right)
        #expect(metadata.playingArmConfirmed && metadata.watchOrientation == "Crown right")
        #expect(model.state == .ready && model.snapshot == nil && model.capturedMetadata == nil)
        model.selectDrill(drill == .lob ? .serve : .lob)
        settings.value.wrist = .left; model.refreshPreparation()
        #expect(try RecordingChunkCodec.encodeMetadata(metadata) == bytes)
        #expect(throws: (any Error).self) { try model.makeMetadata(arm: .left, handedness: .left) }
        model.armConfirmed = true
        #expect(throws: (any Error).self) { try model.makeMetadata(arm: .right, handedness: .left) }
    }

    @Test func allActiveAndTerminalStatesRejectChoiceChangesAndPreserveCapturedIntent() throws {
        let settings = PreparationSettingsFixture()
        let preparation = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, preferences: settings.preferences)
        preparation.selectDrill(.bandeja); preparation.armConfirmed = true
        let metadata = try preparation.makeMetadata(arm: .right, handedness: .right)
        let original = try RecordingChunkCodec.encodeMetadata(metadata)
        for state: MotionCaptureState in [.starting, .recording, .pausing, .paused, .resuming, .stopping, .saved, .interrupted, .failed] {
            // The existing state seam supplies a truthful immutable header, without pretending sensors ran.
            let model = WatchRecorderModel(preparationSettingsProvider: { settings.read() }, initialState: state,
                preferences: settings.preferences, initialMetadata: metadata)
            model.armConfirmed = true
            model.selectDrill(.smash)
            #expect(model.selectedDrill == .bandeja && model.displayedDrillTitle == "Bandeja")
            #expect(model.capturedMetadata == metadata && model.armConfirmed)
            #expect(settings.preferences.string(forKey: WatchRecorderModel.drillPreferenceKey) == "bandeja")
            #expect(!model.canSelectDrill && !model.canStart(arm: .right))
            #expect(throws: (any Error).self) { try model.makeMetadata(arm: .right, handedness: .right) }
            if state.isTerminal {
                settings.value.crownDescription = "Crown left"
                model.refreshPreparation()
                #expect(model.capturedMetadata == metadata && model.displayedDrillTitle == "Bandeja")
                model.newSet()
                #expect(model.state == .ready && model.canSelectDrill && model.capturedMetadata == nil)
                #expect(model.selectedDrill == .bandeja && !model.armConfirmed)
                model.selectDrill(.serve)
                #expect(model.selectedDrill == .serve)
                settings.preferences.set("bandeja", forKey: WatchRecorderModel.drillPreferenceKey)
            } else {
                model.newSet()
                #expect(model.state == state && model.capturedMetadata == metadata)
                if state == .starting {
                    model.stop()
                    #expect(model.state == .interrupted && model.capturedMetadata == metadata)
                    #expect(model.displayedDrillTitle == "Bandeja")
                }
            }
            #expect(try RecordingChunkCodec.encodeMetadata(metadata) == original)
        }
    }

    @Test func rapidResumeWaitsForBothPauseAcknowledgements() {
        var gate = WatchPauseGate()
        let unexpectedPauseAccepted = gate.workoutDidPause()
        #expect(!unexpectedPauseAccepted)
        gate.request()
        #expect(!gate.canResume)
        let shouldPauseWorkout = gate.engineDidPause()
        #expect(shouldPauseWorkout)
        #expect(!gate.canResume)
        let expectedPauseAccepted = gate.workoutDidPause()
        #expect(expectedPauseAccepted)
        #expect(gate.canResume)
        gate.reset()
        let pauseAfterResetAccepted = gate.workoutDidPause()
        #expect(!gate.canResume && !pauseAfterResetAccepted)
    }

    @Test func terminalSetResetsPauseAcknowledgementsBeforeNewSet() {
        var gate = WatchPauseGate()
        gate.request(); _ = gate.engineDidPause(); _ = gate.workoutDidPause()
        #expect(gate.canResume)
        gate.reset() // The model uses this at terminal, new-set and start boundaries.
        let unexpectedPauseAccepted = gate.workoutDidPause()
        #expect(!unexpectedPauseAccepted)
        #expect(!gate.canResume)
    }

    @Test func activeRecordingCannotBeManuallyTransferredEvenWhilePaused() {
        let id = UUID()
        for state: MotionCaptureState in [.starting, .recording, .pausing, .paused, .resuming, .stopping] {
            #expect(!WatchRecorderModel.canTransfer(recordingID: id, activeRecordingID: id, state: state))
            #expect(WatchRecorderModel.canTransfer(recordingID: UUID(), activeRecordingID: id, state: state))
        }
        #expect(WatchRecorderModel.canTransfer(recordingID: id, activeRecordingID: id, state: .saved))
    }

    @Test func deletionRejectsEveryActivePhaseAndConcurrentRequest() {
        let id = UUID(), other = UUID()
        for state: MotionCaptureState in [.starting, .recording, .pausing, .paused, .resuming, .stopping] {
            #expect(!WatchRecorderModel.canDelete(recordingID: id, activeRecordingID: id, state: state, deletionInProgress: false))
            #expect(WatchRecorderModel.canDelete(recordingID: other, activeRecordingID: id, state: state, deletionInProgress: false))
        }
        for state: MotionCaptureState in [.saved, .interrupted, .failed] {
            #expect(WatchRecorderModel.canDelete(recordingID: id, activeRecordingID: id, state: state, deletionInProgress: false))
            #expect(!WatchRecorderModel.canDelete(recordingID: id, activeRecordingID: id, state: state, deletionInProgress: true))
        }
    }

    @Test func backgroundDrainCompletionWinsOverLaterExpirationExactlyOnce() {
        let evidence = BackgroundCompletionEvidence()
        let gate = WatchBackgroundCompletionGate { evidence.complete() }
        gate.installCancellation { evidence.cancel() }
        gate.finish(cancelDrain: false)
        gate.finish(cancelDrain: true)
        #expect(evidence.snapshot().completed == 1)
        #expect(evidence.snapshot().cancelled == 0)
    }

    @Test func backgroundExpirationBeforeTokenRegistrationCancelsExactlyOnce() {
        let evidence = BackgroundCompletionEvidence()
        let gate = WatchBackgroundCompletionGate { evidence.complete() }
        gate.finish(cancelDrain: true)
        gate.installCancellation { evidence.cancel() }
        gate.finish(cancelDrain: false)
        #expect(evidence.snapshot().completed == 1)
        #expect(evidence.snapshot().cancelled == 1)
    }

    @Test func concurrentBackgroundCompletionSignalsCompleteOnlyOnce() async {
        let evidence = BackgroundCompletionEvidence()
        let gate = WatchBackgroundCompletionGate { evidence.complete() }
        gate.installCancellation { evidence.cancel() }
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<32 { group.addTask { gate.finish(cancelDrain: index.isMultiple(of: 2)) } }
        }
        #expect(evidence.snapshot().completed == 1)
        #expect(evidence.snapshot().cancelled <= 1)
    }

    @Test func productionContainerPathsAcceptActualAppStorage() throws {
        let paths = try RecordingPaths()
        #expect(FileManager.default.fileExists(atPath: paths.rawRoot.path))
        #expect(FileManager.default.fileExists(atPath: paths.notesRoot.path))
        _ = try SessionAnnotationsStore(root: paths.notesRoot)
    }
}

@MainActor
private final class PreparationSettingsFixture {
    let preferences: UserDefaults
    private let suiteName = "PadelStrokeLab.WatchTests.\(UUID().uuidString)"
    init() {
        preferences = UserDefaults(suiteName: suiteName)!
        preferences.set("forehandGroundstroke", forKey: WatchRecorderModel.drillPreferenceKey)
    }
    isolated deinit { preferences.removePersistentDomain(forName: suiteName) }

    var value = WatchPreparationSettings(wrist: .right, crownDescription: "Crown right",
        unavailableReason: nil, frequencyDescription: "Initial reported frequencies")
    private(set) var readCount = 0
    func read() -> WatchPreparationSettings {
        readCount += 1
        return value
    }
}

nonisolated private final class BackgroundCompletionEvidence: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = 0, cancelled = 0
    func complete() { lock.withLock { completed += 1 } }
    func cancel() { lock.withLock { cancelled += 1 } }
    func snapshot() -> (completed: Int, cancelled: Int) { lock.withLock { (completed, cancelled) } }
}
