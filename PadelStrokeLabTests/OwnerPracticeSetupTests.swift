import Foundation
import Testing
@testable import PadelCore
@testable import PadelStrokeLab

/// All phone writes use the real bootstrap, P1 and owner journal in an owned temporary root.
/// The existing transport adapter substitutes only the remote Watch and framework delivery.
@Suite(.serialized) @MainActor struct OwnerPracticeSetupTests {
    @Test func freshLoadAndStatusNeverSupplyConsentOrAcceptance() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let model = f.model()
        await model.load()
        #expect(model.channel?.authority == nil && model.channel?.phonePractice == nil)
        #expect(!model.ownerConfirmed && !model.motionConsent && !model.heartRateConsent)
        let phone = try #require(model.stored?.localInstallationEpoch)
        try f.enrollWatchOnly(phone: phone)
        await model.refreshWatch()
        #expect(model.observation?.authority != nil)
        #expect(model.channel?.authority == nil)
        #expect(model.acceptedCurrent == nil && model.acceptedNext == nil)
        #expect(model.status == .reviewRequired)
        await model.closeForTesting()
    }

    @Test(arguments: [(false, false), (true, false), (false, true)])
    func affirmativeOwnerAndMotionChoicesAreBothRequired(owner: Bool, motion: Bool) async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let model = f.model(); await model.load(); await model.refreshWatch()
        model.setConsent(ownerConfirmed: owner, motion: motion, heartRate: false)
        await model.reviewAndPrepare()
        #expect(f.mutations.isEmpty && f.preparations.isEmpty)
        #expect(model.channel?.phonePractice == nil && model.acceptedCurrent == nil)
        await model.closeForTesting()
    }

    @Test func lifecycleAndDraftAreDurableBeforePreparationDelivery() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let model = try await prepared(f)
        let life = try #require(model.channel?.phonePractice)
        let sent = try #require(f.preparations.last)
        #expect(life.practiceID != life.preparationID)
        #expect(sent.practiceID == life.practiceID && sent.draft.identity.preparationID == life.preparationID)
        #expect(f.durableBeforePrepare == [true])
        #expect(model.stored?.highWater == sent.draft.identity)
        #expect(model.status == .acceptedCurrent && model.acceptedCurrent == sent)
        #expect(model.channel?.authority?.isCollectionAllowed == true)
        #expect(model.channel?.authority?.heartRateConsent == false)
        #expect(f.controls.contains { if case .acknowledge = $0 { true } else { false } })
        await model.closeForTesting()
    }

    @Test func editsKeepIndependentIDsAndAdvanceGlobalRevision() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let model = try await prepared(f)
        let first = try #require(model.acceptedCurrent)
        model.updateChoices(backhand)
        #expect(model.acceptedCurrent == nil && model.acceptedNext == nil)
        #expect(model.status != .acceptedCurrent)
        await model.reviewAndPrepare()
        let second = try #require(model.acceptedCurrent)
        #expect(second.practiceID == first.practiceID)
        #expect(second.draft.identity.preparationID == first.draft.identity.preparationID)
        #expect(second.draft.identity.revision > first.draft.identity.revision)
        #expect(second.draft.preferences == backhand)
        await model.endPractice().value
        #expect(model.channel?.phonePractice == nil)
        await model.refreshWatch()
        model.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
        await model.reviewAndPrepare()
        let third = try #require(model.acceptedCurrent)
        #expect(third.practiceID != first.practiceID)
        #expect(third.draft.identity.preparationID != first.draft.identity.preparationID)
        #expect(third.practiceID != third.draft.identity.preparationID)
        #expect(third.draft.identity.revision > second.draft.identity.revision)
        await model.closeForTesting()
    }

    @Test func recordingSelectionIsImmutableAndNextNeverPromotesFromStatus() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let model = try await prepared(f)
        let current = try #require(model.acceptedCurrent)
        f.setWatchState(.recording); await model.refreshWatch()
        model.updateChoices(backhand)
        #expect(model.acceptedCurrent == current && model.acceptedNext == nil)
        await model.reviewAndPrepare()
        let next = try #require(model.acceptedNext)
        #expect(model.status == .acceptedNext)
        #expect(model.acceptedCurrent == current && next.draft.preferences == backhand)
        f.setWatchState(.saved); await model.refreshWatch()
        #expect(model.acceptedCurrent != next)
        #expect(model.status != .acceptedCurrent)
        await model.closeForTesting()
    }

    @Test func relaunchRestoresSuggestionsButNeedsReviewAndFreshExchange() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let original = try await prepared(f)
        let before = try #require(original.acceptedCurrent)
        await original.closeForTesting()
        let model = f.model(); await model.load(); await model.refreshWatch()
        #expect(model.choices == before.draft.preferences)
        #expect(!model.ownerConfirmed && !model.motionConsent && !model.heartRateConsent)
        #expect(model.acceptedCurrent == nil && model.acceptedNext == nil)
        #expect(model.status == .reviewRequired)
        #expect(f.preparations.count == 1)
        model.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
        await model.reviewAndPrepare()
        let after = try #require(model.acceptedCurrent)
        #expect(after.practiceID == before.practiceID)
        #expect(after.draft.identity.preparationID == before.draft.identity.preparationID)
        #expect(after.draft.identity.revision > before.draft.identity.revision)
        #expect(f.preparations.count == 2)
        await model.closeForTesting()
    }

    @Test func lifecycleWithoutDraftRequiresReviewAndReconstructsSameMapping() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let expected = try f.seedLifecycleWithoutDraft()
        let model = f.model(); await model.load(); await model.refreshWatch()
        #expect(model.stored?.latestDraft == nil && model.acceptedCurrent == nil)
        #expect(model.status == .reviewRequired && f.preparations.isEmpty)
        model.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
        model.updateChoices(backhand)
        await model.reviewAndPrepare()
        let accepted = try #require(model.acceptedCurrent)
        #expect(accepted.practiceID == expected.0)
        #expect(accepted.draft.identity.preparationID == expected.1)
        #expect(accepted.draft.preferences == backhand)
        #expect(f.durableBeforePrepare == [true])
        await model.closeForTesting()
    }

    @Test(arguments: ["edit", "end", "withdraw", "heartRate"])
    func heldPreparationCannotUndoImmediatePresentationFence(action: String) async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let model = f.model(); await model.load(); await model.refreshWatch()
        model.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
        f.holdPreparation = true
        let preparing = Task { await model.reviewAndPrepare() }
        try #require(await eventually { f.heldPreparationCount == 1 })
        var restriction: Task<Void, Never>?
        switch action {
        case "edit": model.updateChoices(backhand)
        case "end": restriction = model.endPractice()
        case "heartRate": model.setConsent(ownerConfirmed: true, motion: true, heartRate: true)
        default: restriction = model.withdrawMotionConsent()
        }
        #expect(model.acceptedCurrent == nil && model.acceptedNext == nil)
        #expect(model.status != .acceptedCurrent && model.status != .acceptedNext)
        f.releasePreparations()
        await preparing.value; await restriction?.value
        #expect(model.acceptedCurrent == nil && model.acceptedNext == nil)
        if action == "withdraw" { #expect(model.channel?.motionAccessBlocked == true) }
        if action == "edit" { #expect(model.choices == backhand) }
        await model.closeForTesting()
    }

    @Test(arguments: [OwnerAuthorityMutation.Kind.enroll, .heartRate])
    func endDuringOccupiedIntentPreservesIntentAndIndependentEndID(kind: OwnerAuthorityMutation.Kind) async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let model: PracticeSetupModel
        if kind == .heartRate { model = try await prepared(f) }
        else { model = f.model(); await model.load(); await model.refreshWatch() }
        let beforeMutation = try #require(model.observation)
        f.holdMutations = [kind, .retirePractice]
        model.setConsent(ownerConfirmed: true, motion: true, heartRate: kind == .heartRate)
        let preparing = Task { await model.reviewAndPrepare() }
        try #require(await eventually { f.hasHeld(kind) })
        let occupied = try #require(model.channel?.pending?.mutation)
        let ending = model.endPractice()
        #expect(model.status == .endPending && model.acceptedCurrent == nil && model.acceptedNext == nil)
        await ending.value
        let latched = try #require(model.channel?.phonePractice)
        let localEnd = try #require(latched.endRequestID)
        #expect(model.channel?.pending?.mutation == occupied)
        #expect(model.channel?.admissionBlocked == true)
        f.releaseMutation(kind)
        await preparing.value
        await model.refreshWatch()
        let afterMutation = try #require(model.observation)
        #expect(afterMutation.authority == model.channel?.authority)
        #expect(afterMutation.acceptedCurrent == nil && afterMutation.acceptedNext == nil)
        if kind == .heartRate {
            #expect(afterMutation.authority?.heartRateConsent == true)
            #expect(afterMutation.generations.runtimeGeneration == beforeMutation.generations.runtimeGeneration)
            #expect(afterMutation.generations.preparationGeneration != beforeMutation.generations.preparationGeneration)
        }
        let retry = Task { await model.retryPending() }
        try #require(await eventually { f.hasHeld(.retirePractice) })
        let wire = try #require(model.channel?.pending?.mutation)
        #expect(wire.kind == .retirePractice && wire.id != localEnd)
        #expect(wire.retiredPracticeID == latched.practiceID)
        #expect(model.channel?.phonePractice?.endRequestID == localEnd)
        f.releaseMutation(.retirePractice); await retry.value
        #expect(model.channel?.phonePractice == nil)
        #expect(model.channel?.authority?.isCollectionAllowed == true)
        #expect(model.acceptedCurrent == nil && model.acceptedNext == nil)
        await model.closeForTesting()
    }

    @Test func offlineEndSurvivesRelaunchAndDoesNotClaimWatchStopped() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let original = try await prepared(f)
        f.setWatchState(.recording); await original.refreshWatch()
        f.offline = true
        await original.endPractice().value
        let life = try #require(original.channel?.phonePractice)
        #expect(life.endRequestID != nil && original.status == .endPending)
        #expect(original.statusText.localizedCaseInsensitiveContains("pending"))
        #expect(!original.statusText.localizedCaseInsensitiveContains("Watch stopped"))
        await original.closeForTesting()
        let model = f.model(); await model.load()
        #expect(model.status == .endPending && model.channel?.phonePractice == life)
        #expect(model.acceptedCurrent == nil && !model.motionConsent)
        f.offline = false; await model.refreshWatch(); await model.retryPending()
        #expect(model.channel?.phonePractice == nil)
        #expect(model.channel?.authority?.isCollectionAllowed == true)
        await model.closeForTesting()
    }

    @Test func obsoleteIntentNeedsExplicitResolutionBeforeDurableEndCanQueue() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let expected = try f.seedObsoleteEnd()
        let model = f.model(); await model.load(); await model.refreshWatch()
        await model.retryPending()
        #expect(model.channel?.pending?.requiresResolution == true)
        #expect(model.channel?.pending?.mutation.id == expected.0)
        #expect(model.channel?.phonePractice?.endRequestID == expected.1)
        #expect(!f.mutations.contains { $0.kind == .retirePractice })
        await model.resolveObsoleteIntent()
        #expect(model.channel?.phonePractice == nil)
        #expect(model.channel?.authority?.isCollectionAllowed == true)
        #expect(model.channel?.authority?.heartRateConsent == false)
        await model.closeForTesting()
    }

    @Test func obsoleteDispatchedRetirementAfterRelaunchNeedsFreshExactPracticeWire() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let original = try await prepared(f)
        f.offline = true
        await original.endPractice().value
        let life = try #require(original.channel?.phonePractice)
        let localEnd = try #require(life.endRequestID)
        let old = try #require(original.channel?.pending)
        #expect(old.dispatched && old.mutation.kind == .retirePractice)
        #expect(old.mutation.retiredPracticeID == life.practiceID && old.mutation.id != localEnd)

        f.offline = false
        let advanced = try f.advanceAuthority()
        let message = try OwnerPreparationCodec.encode(.transition(advanced))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            f.connection.receiveOwnerData(message, delivery: .control) {
                continuation.resume(with: $0.map { _ in () }.mapError { $0 as any Error })
            }
        }
        #expect(original.channel?.pending?.requiresResolution == true)
        #expect(original.channel?.phonePractice?.endRequestID == localEnd)
        await original.closeForTesting()

        let model = f.model(); await model.load(); await model.refreshWatch()
        #expect(model.channel?.phonePractice == life && model.status == .endPending)
        await model.retryPending()
        #expect(model.channel?.pending?.mutation == old.mutation)
        #expect(model.channel?.pending?.requiresResolution == true)
        #expect(!f.mutations.contains { $0.kind == .retirePractice })

        f.holdMutations = [.retirePractice]
        let resolving = Task { await model.resolveObsoleteIntent() }
        let queued = await eventually { f.hasHeld(.retirePractice) }
        #expect(queued, "Explicit resolution must replace the obsolete End wire with a fresh exact-practice retirement")
        if queued {
            let replacement = model.channel?.pending?.mutation
            #expect(replacement?.kind == .retirePractice)
            #expect(replacement?.retiredPracticeID == life.practiceID)
            #expect(replacement?.id != old.mutation.id && replacement?.id != localEnd)
            #expect(model.channel?.phonePractice == life)
            #expect(model.status == .endPending && model.acceptedCurrent == nil && model.acceptedNext == nil)
            f.releaseMutation(.retirePractice)
        }
        await resolving.value
        #expect(model.channel?.phonePractice == nil && model.channel?.pending == nil)
        #expect(model.channel?.authority?.isCollectionAllowed == true)
        await model.closeForTesting()
    }

    @Test func lostAppliedReplyReconcilesExactCommandWithoutRestoringConsentOnRelaunch() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let original = f.model(); await original.load(); await original.refreshWatch()
        original.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
        f.dropNextAppliedReply = true
        await original.reviewAndPrepare()
        let pending = try #require(original.channel?.pending?.mutation)
        let life = try #require(original.channel?.phonePractice)
        #expect(original.acceptedCurrent == nil)
        await original.closeForTesting()
        let model = f.model(); await model.load(); await model.refreshWatch()
        #expect(model.channel?.authority == nil && model.acceptedCurrent == nil)
        await model.retryPending()
        #expect(model.channel?.authority != nil && model.channel?.pending == nil)
        #expect(model.channel?.phonePractice == life)
        #expect(f.mutations.filter { $0.id == pending.id }.count == 2)
        #expect(!model.motionConsent && !model.ownerConfirmed && model.acceptedCurrent == nil)
        #expect(f.preparations.isEmpty)
        await model.closeForTesting()
    }

    @Test func awaitingReplyCommitRemainsCountedAndCancellationFenceWins() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let gate = SetupReplyGate()
        let model = f.model { message in if case .receipt = message { await gate.hold() } }
        await model.load(); await model.refreshWatch()
        model.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
        let preparing = Task { await model.reviewAndPrepare() }
        defer { Task { await gate.open() } }
        try #require(await eventually { await gate.entered })
        let drained = SetupSignal()
        f.connection.drainForBackground { value in drained.append(value) }
        try await Task.sleep(for: .milliseconds(100))
        #expect(drained.values.isEmpty)
        model.updateChoices(backhand)
        #expect(model.acceptedCurrent == nil && model.status != .acceptedCurrent)
        await gate.open(); await preparing.value
        try #require(await eventually { !drained.values.isEmpty })
        #expect(drained.values == [true])
        #expect(model.acceptedCurrent == nil && model.choices == backhand)
        await model.closeForTesting()
    }

    @Test(arguments: [true, false])
    func independentlyChangedGenerationCannotPublishHeldAcceptance(runtime: Bool) async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let model = f.model(); await model.load(); await model.refreshWatch()
        model.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
        f.holdPreparation = true
        let preparing = Task { await model.reviewAndPrepare() }
        try #require(await eventually { f.heldPreparationCount == 1 })
        let before = try #require(model.observation?.generations)
        f.rotateGeneration(runtime: runtime); await model.refreshWatch()
        let after = try #require(model.observation?.generations)
        #expect((after.runtimeGeneration != before.runtimeGeneration) == runtime)
        #expect((after.preparationGeneration != before.preparationGeneration) == !runtime)
        f.releasePreparations(); await preparing.value
        #expect(model.acceptedCurrent == nil && model.acceptedNext == nil)
        #expect(model.status != .acceptedCurrent && model.status != .acceptedNext)
        await model.closeForTesting()
    }

    @Test(arguments: ["prepare", "refresh"])
    func journalIntegrityFailureCannotBeReportedAsSavedOrDispatched(action: String) async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let model = f.model(); await model.load(); await model.refreshWatch()
        let journal = f.phone.appendingPathComponent("OwnerChannel-v2/journal.json")
        let corrupt = Data("preserved synthetic corrupt journal".utf8)
        try corrupt.write(to: journal)
        model.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
        if action == "refresh" { await model.refreshWatch() }
        else { await model.reviewAndPrepare() }
        #expect(model.status == .failed && model.lastError != nil)
        #expect(model.lastError?.isEmpty == false)
        #expect(model.acceptedCurrent == nil && f.mutations.isEmpty && f.preparations.isEmpty)
        #expect(try Data(contentsOf: journal) == corrupt)
        await model.closeForTesting()
    }

    @Test func exhaustedGlobalRevisionReportsFailureWithoutPreparationOrLostLifecycle() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        try f.seedMaximumDraft()
        let model = f.model(); await model.load(); await model.refreshWatch()
        model.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
        await model.reviewAndPrepare()
        #expect(model.status == .failed && model.lastError != nil)
        #expect(model.stored?.highWater?.revision == PracticeSetupIdentity.maximumRevision)
        #expect(model.channel?.phonePractice != nil && model.canEnd)
        #expect(model.acceptedCurrent == nil && f.preparations.isEmpty && f.mutations.isEmpty)
        await model.closeForTesting()
    }

    @Test func failedEndPersistenceKeepsImmediateDenialAndReportsFailureHonestly() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let model = try await prepared(f)
        let before = f.mutations.count
        let journal = f.phone.appendingPathComponent("OwnerChannel-v2/journal.json")
        let corrupt = Data("synthetic End persistence failure".utf8)
        try corrupt.write(to: journal)
        let ending = model.endPractice()
        #expect(model.status == .endPending && model.acceptedCurrent == nil && model.acceptedNext == nil)
        #expect(!model.canPrepare)
        await ending.value
        #expect(model.status == .failed && model.lastError != nil && !model.canPrepare)
        #expect(model.channel?.phonePractice?.endRequestID == nil)
        #expect(!model.statusText.contains("End saved") && !model.statusText.contains("Watch stopped"))
        #expect(f.mutations.count == before)
        #expect(try Data(contentsOf: journal) == corrupt)
        await model.closeForTesting()
    }

    @Test func existingRawChangeCallbackSurvivesOwnerHandlerRegistration() async throws {
        let f = try SetupFixture(); defer { f.remove() }
        let raw = SetupSignal()
        f.connection.onChange = { _ in raw.append(true) }
        let model = f.model(); await model.load()
        #expect(f.connection.onOwnerPreparation != nil && f.connection.onChange != nil)
        let missingSyntheticRecording = UUID()
        f.connection.queue(recordingID: missingSyntheticRecording,
            timeline: CaptureTimeline(recordingID: missingSyntheticRecording, clockDomainID: UUID()))
        try #require(await eventually { !raw.values.isEmpty })
        await model.refreshWatch()
        #expect(model.observation?.watchEpoch == f.watchEpoch)
        await model.closeForTesting()
    }

    @Test func defaultHostRemainsSyntheticAndOwnerSetupStartsWithoutAuthority() async throws {
        #expect(ProcessInfo.processInfo.arguments.contains("--motion-statistics-fixture=unavailable"))
        let library = RecordingLibraryModel()
        #expect(library.isSyntheticUIReview)
        let model = try #require(library.practiceSetup)
        await model.load()
        #expect(model.channel?.authority == nil && model.acceptedCurrent == nil)
        #expect(!model.motionConsent && !model.ownerConfirmed)
        await model.closeForTesting()
    }

    private var backhand: PracticeSetupPreferences {
        .init(currentRacketArm: .right, usualHand: .right, intendedDrill: .backhandGroundstroke)
    }
    private func prepared(_ f: SetupFixture) async throws -> PracticeSetupModel {
        let model = f.model(); await model.load(); await model.refreshWatch()
        model.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
        await model.reviewAndPrepare()
        try #require(model.status == .acceptedCurrent)
        return model
    }
    private func eventually(_ predicate: @MainActor () async -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline {
            if await predicate() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return await predicate()
    }
}

private nonisolated final class SetupFixture: @unchecked Sendable {
    typealias Reply = @Sendable (Result<Data, OwnerTransportFailure>) -> Void
    let root: URL
    let phone: URL
    let watchEpoch = UUID()
    private let queue = DispatchQueue(label: "PadelStrokeLab.tests.owner-setup-watch")
    private var watch: PracticeSetupChannel!
    private var runtime = PracticeSetupGenerations(runtimeGeneration: UUID(), preparationGeneration: UUID())
    private var watchState = PracticeSetupWatchState.idle
    private var current: OwnerPreparation?
    private var next: OwnerPreparation?
    private var sent: [OwnerPreparationMessage] = []
    private var durable: [Bool] = []
    private var held: [(OwnerPreparationMessage, Data, Reply)] = []
    private var heldKinds: Set<OwnerAuthorityMutation.Kind> = []
    private var holdPrepare = false
    private var unavailable = false
    private var dropApplied = false
    private var link: RecordingConnectivity!
    var connection: RecordingConnectivity { link }
    var mutations: [OwnerAuthorityMutation] { queue.sync { sent.compactMap(\.mutation) } }
    var controls: [OwnerPreparationMessage] { queue.sync { sent.filter { if case .acknowledge = $0 { true } else { false } } } }
    var preparations: [OwnerPreparation] { queue.sync { sent.compactMap { if case let .prepare(_, p) = $0 { p } else { nil } } } }
    var durableBeforePrepare: [Bool] { queue.sync { durable } }
    var heldPreparationCount: Int { queue.sync { held.filter { if case .prepare = $0.0 { true } else { false } }.count } }
    var holdMutations: Set<OwnerAuthorityMutation.Kind> { get { queue.sync { heldKinds } } set { queue.sync { heldKinds = newValue } } }
    var holdPreparation: Bool { get { queue.sync { holdPrepare } } set { queue.sync { holdPrepare = newValue } } }
    var offline: Bool { get { queue.sync { unavailable } } set { queue.sync { unavailable = newValue } } }
    var dropNextAppliedReply: Bool { get { queue.sync { dropApplied } } set { queue.sync { dropApplied = newValue } } }

    init() throws {
        let temporary = FileManager.default.temporaryDirectory
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        root = temporary.resolvingSymlinksInPath()
            .appendingPathComponent("O4bFixtures-" + UUID().uuidString, isDirectory: true)
        phone = root.appendingPathComponent("phone")
        try FileManager.default.createDirectory(at: phone, withIntermediateDirectories: true)
        let watchBase = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: watchBase, withIntermediateDirectories: true)
        watch = try queue.sync { try PracticeSetupChannel(base: watchBase,
            localInstallationEpoch: watchEpoch, device: .watch, intent: .createNew) }
        link = RecordingConnectivity(paths: try RecordingPaths(base: phone),
            backgroundStateProvider: { .init(activated: true, hasContentPending: false) }, backgroundTimeout: 5,
            ownerTransportAdapter: .init(request: { [weak self] data, reply in self?.request(data, reply: reply) },
                control: { [weak self] data in try self?.control(data) }, draft: { _ in }))
    }
    @MainActor func model(beforeReplyCommit: (@Sendable (OwnerPreparationMessage) async -> Void)? = nil) -> PracticeSetupModel {
        PracticeSetupModel(base: phone, connectivity: link, beforeReplyCommit: beforeReplyCommit)
    }
    func remove() {
        let callbacks = queue.sync { let values = held; held = []; watch = nil; return values }
        callbacks.forEach { $0.2(.failure(.cancelled)) }
        link = nil
        try? FileManager.default.removeItem(at: root)
    }
    func setWatchState(_ state: PracticeSetupWatchState) { queue.sync { watchState = state } }
    func rotateGeneration(runtime changeRuntime: Bool) { queue.sync {
        runtime = .init(runtimeGeneration: changeRuntime ? UUID() : runtime.runtimeGeneration,
            preparationGeneration: changeRuntime ? runtime.preparationGeneration : UUID())
        current = nil; next = nil
    } }
    func hasHeld(_ kind: OwnerAuthorityMutation.Kind) -> Bool { queue.sync { held.contains { $0.0.mutation?.kind == kind } } }
    func releaseMutation(_ kind: OwnerAuthorityMutation.Kind) { release { $0.mutation?.kind == kind } }
    func releasePreparations() { release { if case .prepare = $0 { true } else { false } } }
    private func release(_ matches: (OwnerPreparationMessage) -> Bool) {
        let callbacks = queue.sync { let values = held.filter { matches($0.0) }; held.removeAll { matches($0.0) }; return values }
        callbacks.forEach { $0.2(.success($0.1)) }
    }
    private func request(_ data: Data, reply: @escaping Reply) {
        queue.async { [self] in
            do {
                guard !unavailable else { reply(.failure(.unavailable)); return }
                let message = try OwnerPreparationCodec.decode(data); sent.append(message)
                let response: OwnerPreparationMessage
                switch message {
                case let .statusRequest(id, phone):
                    response = .status(requestID: id, phoneEpoch: phone, observation: try observation())
                case let .mutate(id, generations, mutation):
                    let priorRevision = try watch.readSnapshot().authority?.revision ?? 0
                    let transition = try watch.sequence(mutation)
                    if mutation.kind == .retirePractice || mutation.kind == .withdraw
                        || (mutation.kind == .heartRate && transition.sequence > priorRevision) {
                        current = nil; next = nil; watchState = .saved
                        runtime = .init(runtimeGeneration: runtime.runtimeGeneration, preparationGeneration: UUID())
                    }
                    response = .applied(requestID: id, generations: generations, transition: transition)
                    if dropApplied { dropApplied = false; reply(.failure(.unavailable)); return }
                case let .prepare(correlation, preparation):
                    let p1Envelope = try JSONSerialization.jsonObject(with: Data(contentsOf:
                        phone.appendingPathComponent("PracticeSetup-v1/state.json"))) as? [String: Any]
                    let p1 = try JSONDecoder().decode(PracticeSetupPersistentState.self,
                        from: JSONSerialization.data(withJSONObject: p1Envelope?["state"] ?? [:]))
                    let envelope = try JSONSerialization.jsonObject(with: Data(contentsOf:
                        phone.appendingPathComponent("OwnerChannel-v2/journal.json"))) as? [String: Any]
                    let journal = envelope?["body"] as? [String: Any]
                    let life = journal?["phonePractice"] as? [String: Any]
                    durable.append(p1.latestDraft == preparation.draft && p1.highWater == preparation.draft.identity
                        && life?["practiceID"] as? String == preparation.practiceID.uuidString
                        && life?["preparationID"] as? String == preparation.draft.identity.preparationID.uuidString)
                    if watchState == .recording { next = preparation } else { current = preparation; next = nil }
                    response = .receipt(correlation: correlation, disposition: watchState == .recording ? .acceptedNext : .acceptedCurrent,
                        observation: try observation())
                case let .replay(id, cursor):
                    response = .replayResult(requestID: id, cursor: cursor, transition: try watch.nextTransition(after: cursor))
                default: reply(.failure(.invalidMessage)); return
                }
                let bytes = try OwnerPreparationCodec.encode(response)
                if message.mutation.map({ heldKinds.contains($0.kind) }) == true || (message.correlation != nil && holdPrepare) {
                    held.append((message, bytes, reply))
                } else { reply(.success(bytes)) }
            } catch { reply(.failure(.handlerFailure)) }
        }
    }
    private func control(_ data: Data) throws { try queue.sync {
        guard !unavailable else { throw OwnerTransportFailure.unavailable }
        let message = try OwnerPreparationCodec.decode(data); sent.append(message)
        if case let .acknowledge(value) = message { try watch.acknowledge(value) }
    } }
    private func observation() throws -> OwnerPreparationObservation {
        try .init(watchEpoch: watchEpoch, generations: runtime, observedAtUnixSeconds: 10, state: watchState,
            authority: watch.readSnapshot().authority, acceptedCurrent: current?.identity, acceptedNext: next?.identity,
            wrist: .right, crown: .right, capability: .supported, storage: .available)
    }
    func enrollWatchOnly(phone: UUID) throws { try queue.sync {
        let owner = try identity(phone: phone)
        _ = try watch.sequence(.enrollment(owner))
    } }
    func advanceAuthority() throws -> OwnerAuthorityTransition { try queue.sync {
        guard let owner = try watch.readSnapshot().authority else { throw OwnerTransportFailure.invalidMessage }
        let transition = try watch.sequence(.advance(from: owner, mutationID: UUID()))
        current = nil; next = nil
        return transition
    } }
    private func identity(phone: UUID) throws -> OwnerPracticeIdentity {
        try .enrolled(ownerID: UUID(), phoneInstallationEpoch: phone, watchInstallationEpoch: watchEpoch,
            attestsWatchAccountOwner: true, acceptsMotionStudy: true, includesHeartRate: false,
            decisionID: UUID(), confirmedAtUnixSeconds: 1, policyDigest: OwnerPracticePolicy.digest)
    }
    func seedLifecycleWithoutDraft() throws -> (UUID, UUID) { try queue.sync {
        let bootstrap = try OwnerPhoneBootstrap(base: phone)
        return try bootstrap.withStores { setup, channel in
            let owner = try identity(phone: setup.checkedSnapshot().localInstallationEpoch)
            let enrollment = try OwnerAuthorityMutation.enrollment(owner)
            try channel.request(enrollment)
            let practice = UUID(), preparation = UUID()
            try channel.beginPhonePractice(practiceID: practice, preparationID: preparation, owner: owner)
            return (practice, preparation)
        }
    } }
    func seedMaximumDraft() throws { try queue.sync {
        let bootstrap = try OwnerPhoneBootstrap(base: phone)
        try bootstrap.withStores { setup, _ in
            let epoch = try setup.checkedSnapshot().localInstallationEpoch
            _ = try setup.recordExplicitPreparation(.init(originInstallationEpoch: epoch, preparationID: UUID(),
                revision: PracticeSetupIdentity.maximumRevision,
                preferences: .init(currentRacketArm: .right, usualHand: .right, intendedDrill: .forehandGroundstroke)))
        }
    } }
    func seedObsoleteEnd() throws -> (UUID, UUID) { try queue.sync {
        let bootstrap = try OwnerPhoneBootstrap(base: phone)
        return try bootstrap.withStores { setup, channel in
            let owner = try identity(phone: setup.checkedSnapshot().localInstallationEpoch)
            let enrollment = try OwnerAuthorityMutation.enrollment(owner)
            try channel.request(enrollment)
            let enrolled = try watch.sequence(channel.dispatchPending())
            try watch.acknowledge(channel.mirror(enrolled))
            let practice = UUID(), preparation = UUID(), end = UUID()
            try channel.beginPhonePractice(practiceID: practice, preparationID: preparation, owner: owner)
            let obsolete = try OwnerAuthorityMutation.heartRate(from: owner, allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)
            try channel.request(obsolete)
            let advanced = try watch.sequence(.advance(from: owner, mutationID: UUID()))
            try watch.acknowledge(channel.mirror(advanced))
            try channel.requestPhoneEnd(practiceID: practice, requestID: end)
            return (obsolete.id, end)
        }
    } }
}

private actor SetupReplyGate {
    private(set) var entered = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var opened = false
    func hold() async {
        entered = true
        if opened { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func open() { opened = true; continuation?.resume(); continuation = nil }
}
private nonisolated final class SetupSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Bool] = []
    var values: [Bool] { lock.withLock { stored } }
    func append(_ value: Bool) { lock.withLock { stored.append(value) } }
}
