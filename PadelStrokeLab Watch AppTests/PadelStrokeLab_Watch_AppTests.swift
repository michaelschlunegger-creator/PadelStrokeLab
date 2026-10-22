import Foundation
import Testing
import PadelCore
@testable import PadelStrokeLab_Watch_App

@MainActor
struct PadelStrokeLab_Watch_AppTests {
    @Test func savedWatchPreferencesCannotReplaceAcceptedPhonePreparation() async throws {
        let fixture = try PreparationSettingsFixture()
        let coordinator = try #require(fixture.services.coordinator)
        try await coordinator.load()
        fixture.preferences.set("right", forKey: WatchRecorderModel.armPreferenceKey)
        fixture.preferences.set("right", forKey: WatchRecorderModel.handPreferenceKey)
        fixture.preferences.set("forehandGroundstroke", forKey: WatchRecorderModel.drillPreferenceKey)
        let model = fixture.model()
        model.beginPreparation(); model.confirmPlacement(); model.confirmOrientation(); model.confirmFit(); model.start()
        #expect(!model.hasAcceptedPreparation && !model.canStart && model.preparation.step == nil)
        #expect(model.state == .ready && model.capturedMetadata == nil)
        #expect(throws: (any Error).self) { try model.makeMetadata() }
        await coordinator.closeForTesting()
    }
    @Test(arguments: [RecordingDrill.forehandGroundstroke, .backhandGroundstroke])
    func phonePreparationOwnsShotAndArm(drill: RecordingDrill) async throws {
        let fixture = try await OwnerLifecycleFixture(drill: drill)
        let prepared = fixture.preparation
        let model = fixture.model
        try await fixture.beginAndRun()
        #expect(model.preparation.accepted == prepared && model.selectedDrill == drill)
        #expect(!model.canStart)
        fixture.preparePhysical()
        #expect(model.canStart)
        let metadata = try model.makeMetadata()
        #expect(metadata.drill == drill.rawValue && metadata.playingArm == .right && metadata.watchWrist == .right)
        #expect(metadata.playingArmConfirmed && metadata.protocolVersion == RecordingDrill.protocolVersion)
        await fixture.finish()
    }
    @Test func draftAloneCannotOpenWatchCheck() async throws {
        let fixture = try PreparationSettingsFixture()
        let preparation = try await fixture.enroll()
        let coordinator = try #require(fixture.services.coordinator)
        _ = try await coordinator.receive(.draft(preparation))
        let model = fixture.model(); model.beginPreparation()
        #expect(!model.canPrepare && !model.canStart && model.preparation.step == nil)
        await fixture.close()
    }
    @Test func wristAndCrownChangeRequireFreshPhysicalChecks() async throws {
        let fixture = try await OwnerLifecycleFixture()
        var settings = WatchPreparationSettings(wrist: .right, crownDescription: "Crown right",
            unavailableReason: nil, frequencyDescription: "Injected native motion")
        let source = try WatchMotionSource(hardware: fixture.motion, environment: fixture.services.environment)
        let model = WatchRecorderModel(preparationSettingsProvider: { settings }, services: fixture.services,
            motionSource: source, storageValidation: { nil })
        try await fixture.beginAndRun()
        model.beginPreparation(); model.confirmPlacement(); model.confirmOrientation(); model.confirmFit()
        #expect(model.canStart)
        settings.crownDescription = "Crown left"
        model.refreshPreparation()
        #expect(!model.canStart && !model.preparation.orientationConfirmed && !model.preparation.fitConfirmed)
        model.beginPreparation(); model.confirmPlacement(); model.confirmOrientation(); model.confirmFit()
        #expect(model.canStart)
        settings.wrist = .left; model.refreshPreparation()
        model.confirmPlacement(); model.confirmOrientation(); model.confirmFit()
        #expect(!model.canStart && !model.preparation.orientationConfirmed)
        await fixture.finish()
    }
    @Test func orientationTapCannotAcknowledgeSettingsChangedSinceDisplay() async throws {
        let fixture = try PreparationSettingsFixture(); _ = try await fixture.accept()
        let model = fixture.model(); model.beginPreparation(); model.confirmPlacement()
        fixture.value.crownDescription = "Crown left"
        model.confirmOrientation()
        #expect(!model.preparation.orientationConfirmed && !model.canStart)
        await fixture.close()
    }
    @Test func backgroundAndCancellationRequireFreshCheck() async throws {
        let fixture = try PreparationSettingsFixture(); _ = try await fixture.accept()
        let model = fixture.model(); fixture.complete(model)
        model.preparationLeftForeground()
        #expect(!model.canStart && model.hasAcceptedPreparation)
        fixture.complete(model); model.cancelPreparation()
        #expect(!model.canStart && model.preparation.step == nil)
        model.beginPreparation()
        #expect(!model.preparation.placementConfirmed && !model.preparation.fitConfirmed)
        await fixture.close()
    }
    @Test func capabilityAndStorageFailuresDenyLocalStart() async throws {
        let fixture = try PreparationSettingsFixture(); _ = try await fixture.accept()
        let model = fixture.model(); fixture.complete(model)
        fixture.value.unavailableReason = "A physical Apple Watch is required."
        model.start()
        #expect(model.state == .ready && model.capturedMetadata == nil && !model.canStart)
        fixture.value.unavailableReason = nil; fixture.storageIssue = "Storage denied"
        model.start()
        #expect(model.state == .ready && model.capturedMetadata == nil && !model.canStart)
        await fixture.close()
    }
    @Test func cancelPhonePreparationSynchronouslyRemovesLocalAdmission() async throws {
        let fixture = try PreparationSettingsFixture(); let prepared = try await fixture.accept()
        let model = fixture.model(); fixture.complete(model)
        let coordinator = try #require(fixture.services.coordinator)
        _ = try await coordinator.receive(.retire(correlation: .init(requestID: UUID(),
            generations: coordinator.generations, preparation: prepared.identity), reason: .cancelPreparation))
        #expect(!model.hasAcceptedPreparation && !model.canStart)
        model.start(); #expect(model.capturedMetadata == nil)
        await fixture.close()
    }
    @Test func syntheticServiceOwnsOnlyItsChildNamespace() async throws {
        let fixture = try PreparationSettingsFixture()
        let paths = try #require(fixture.services.paths)
        #expect(!fixture.services.environment.allowsHardware && fixture.services.connectivity == nil)
        #expect(paths.rawRoot.path.hasPrefix(try #require(fixture.services.environment.base).path + "/"))
        #expect(fixture.services.environment.preferenceSuite?.contains(fixture.id.uuidString) == true)
        let coordinator = try #require(fixture.services.coordinator); try await coordinator.load()
        await fixture.close()
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
    let id = UUID()
    let services: WatchRecordingServices
    var preferences: UserDefaults { services.preferences }
    var value = WatchPreparationSettings(wrist: .right, crownDescription: "Crown right",
        unavailableReason: nil, frequencyDescription: "Synthetic settings; no hardware acquisition")
    var storageIssue: String?
    init() throws {
        services = WatchRecordingServices(environment: try .resolve(arguments: ["--owner-watch-fixture=\(id.uuidString)"], environment: [:]))
    }
    func model() -> WatchRecorderModel {
        WatchRecorderModel(preparationSettingsProvider: { self.value }, services: services,
            storageValidation: { self.storageIssue })
    }
    func enroll(drill: RecordingDrill = .forehandGroundstroke) async throws -> OwnerPreparation {
        let coordinator = try #require(services.coordinator); try await coordinator.load()
        let owner = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: UUID(),
            watchInstallationEpoch: #require(coordinator.watchEpoch), attestsWatchAccountOwner: true,
            acceptsMotionStudy: true, includesHeartRate: false, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000,
            policyDigest: OwnerPracticePolicy.digest)
        _ = try await coordinator.receive(.mutate(requestID: UUID(), generations: coordinator.generations, mutation: .enrollment(owner)))
        let draft = try PracticeSetupDraft(originInstallationEpoch: owner.phoneInstallationEpoch,
            preparationID: UUID(), revision: 1, preferences: .init(currentRacketArm: .right, usualHand: .right, intendedDrill: drill))
        return try OwnerPreparation(authority: owner, practiceID: UUID(), draft: draft)
    }
    func accept(drill: RecordingDrill = .forehandGroundstroke) async throws -> OwnerPreparation {
        let preparation = try await enroll(drill: drill)
        let coordinator = try #require(services.coordinator)
        _ = try await coordinator.receive(.prepare(correlation: .init(requestID: UUID(), generations: coordinator.generations,
            preparation: preparation.identity), preparation: preparation))
        #expect(coordinator.acceptedPreparation == preparation)
        return preparation
    }
    func complete(_ model: WatchRecorderModel) {
        model.beginPreparation(); model.confirmPlacement(); model.confirmOrientation(); model.confirmFit()
    }
    func close() async { await services.coordinator?.closeForTesting() }
}

nonisolated private final class BackgroundCompletionEvidence: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = 0, cancelled = 0
    func complete() { lock.withLock { completed += 1 } }
    func cancel() { lock.withLock { cancelled += 1 } }
    func snapshot() -> (completed: Int, cancelled: Int) { lock.withLock { (completed, cancelled) } }
}
