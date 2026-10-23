import CoreMotion
import Foundation
import Testing
import PadelCore
@testable import PadelStrokeLab_Watch_App

/// O5 tests use real owner persistence and the production admission closure, never sensors or Health.
@MainActor
struct OwnerCaptureAdmissionTests {
    @Test func absentOwnerAndUnacceptedDraftNeverAdmitCapture() async throws {
        let fixture = try OwnerAdmissionFixture()
        let coordinator = fixture.coordinator()
        try await coordinator.load()
        #expect(coordinator.acceptedPreparation == nil)
        #expect(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true) == nil)
        await rejected { _ = try await coordinator.prepareCapture(metadata: fixture.metadata(), confirmation: nil) }
        let preparation = try await fixture.enrollAndDraft(coordinator)
        _ = try await coordinator.receive(.draft(preparation))
        #expect(coordinator.acceptedPreparation == nil)
        #expect(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true) == nil)
        await rejected { _ = try await coordinator.prepareCapture(metadata: fixture.metadata(), confirmation: nil) }
        await coordinator.closeForTesting()
    }

    @Test func revokedPreparationAndWrongPhysicalPlacementNeverAdmitCapture() async throws {
        let fixture = try OwnerAdmissionFixture(), coordinator = fixture.coordinator()
        let preparation = try await fixture.prepare(coordinator)
        #expect(coordinator.confirmPhysical(wrist: nil, crown: "Crown right", fit: true) == nil)
        #expect(coordinator.confirmPhysical(wrist: .left, crown: "Crown right", fit: true) == nil)
        #expect(coordinator.confirmPhysical(wrist: .right, crown: "", fit: true) == nil)
        #expect(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: false) == nil)
        let confirmation = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        let mutation = try OwnerAuthorityMutation.withdraw(from: preparation.authority, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_800_000_001)
        _ = try await coordinator.receive(.mutate(requestID: UUID(), generations: coordinator.generations, mutation: mutation))
        await rejected { _ = try await coordinator.prepareCapture(metadata: fixture.metadata(), confirmation: confirmation) }
        #expect(coordinator.acceptedPreparation == nil)
        await coordinator.closeForTesting()
    }

    @Test(arguments: [RecordingDrill.forehandGroundstroke, .backhandGroundstroke])
    func freshPublicationBindsTheExactSetAndAdmitsOnlyOnce(_ drill: RecordingDrill) async throws {
        let fixture = try OwnerAdmissionFixture(), coordinator = fixture.coordinator()
        let preparation = try await fixture.prepare(coordinator, drill: drill)
        let confirmation = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        let metadata = try fixture.metadata(drill: drill)
        let attempt = try await coordinator.prepareCapture(metadata: metadata, confirmation: confirmation)
        var admissions = 0
        try await coordinator.admit(attempt) { admissions += 1 }
        #expect(admissions == 1 && coordinator.isAdmitted(attempt))
        await rejected { try await coordinator.admit(attempt) { admissions += 1 } }
        #expect(admissions == 1)
        let stored = try await coordinator.inspectContext(recordingID: metadata.recordingID)
        guard case let .valid(context) = stored else { Issue.record("Fresh admitted set has no valid context"); return }
        #expect(context.practiceID == preparation.practiceID && context.acceptedSetup == preparation.draft)
        #expect(context.metadata == metadata && context.manualStroke == drill)
        coordinator.retireCapture(attempt)
        coordinator.engineDrained(attempt)
        coordinator.workoutClosed(attempt)
        await coordinator.closeForTesting()
    }

    @Test func publicationThenWithdrawalCannotResumeIntoAdmission() async throws {
        let fixture = try OwnerAdmissionFixture(), pause = OwnerAdmissionPause()
        let coordinator = fixture.coordinator(afterPublication: { _ in await pause.suspend() })
        let preparation = try await fixture.prepare(coordinator)
        let confirmation = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        let metadata = try fixture.metadata()
        let publishing = Task { try await coordinator.prepareCapture(metadata: metadata, confirmation: confirmation) }
        await pause.waitUntilReached()
        let withdrawal = try OwnerAuthorityMutation.withdraw(from: preparation.authority, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_800_000_002)
        _ = try await coordinator.receive(.mutate(requestID: UUID(), generations: coordinator.generations, mutation: withdrawal))
        pause.release()
        await rejected { _ = try await publishing.value }
        // Publication happened, but a context alone must never become a runtime permission.
        guard case .valid = try await coordinator.inspectContext(recordingID: metadata.recordingID) else {
            Issue.record("The controlled pause did not follow actual durable publication"); return
        }
        #expect(coordinator.acceptedPreparation == nil)
        await coordinator.closeForTesting()
    }

    @Test func physicalInvalidationWhilePublicationIsSuspendedRejectsTheAttempt() async throws {
        let fixture = try OwnerAdmissionFixture(), pause = OwnerAdmissionPause()
        let coordinator = fixture.coordinator(afterPublication: { _ in await pause.suspend() })
        _ = try await fixture.prepare(coordinator)
        let confirmation = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        let publishing = Task { try await coordinator.prepareCapture(metadata: fixture.metadata(), confirmation: confirmation) }
        await pause.waitUntilReached()
        coordinator.invalidatePhysical()
        pause.release()
        await rejected { _ = try await publishing.value }
        await coordinator.closeForTesting()
    }

    @Test func authorityMutationAfterPublicationStillBlocksTheActualAdmissionClosure() async throws {
        let fixture = try OwnerAdmissionFixture(), coordinator = fixture.coordinator()
        let preparation = try await fixture.prepare(coordinator)
        let confirmation = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        let attempt = try await coordinator.prepareCapture(metadata: fixture.metadata(), confirmation: confirmation)
        let end = try OwnerAuthorityMutation.retirePractice(from: preparation.authority,
            practiceID: preparation.practiceID, mutationID: UUID())
        _ = try await coordinator.receive(.mutate(requestID: UUID(), generations: coordinator.generations, mutation: end))
        var admissions = 0
        await rejected { try await coordinator.admit(attempt) { admissions += 1 } }
        #expect(admissions == 0)
        await coordinator.closeForTesting()
    }

    @Test func nativeClosureAndActualWriterDrainAreBothRequiredForAnotherSet() async throws {
        for nativeFirst in [false, true] {
            let fixture = try OwnerAdmissionFixture(), coordinator = fixture.coordinator()
            _ = try await fixture.prepare(coordinator)
            let confirmation = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
            let attempt = try await coordinator.prepareCapture(metadata: fixture.metadata(), confirmation: confirmation)
            try await coordinator.admit(attempt) {}
            coordinator.retireCapture(attempt)
            #expect(!coordinator.canBeginNextSet)
            if nativeFirst { coordinator.workoutClosed(attempt) } else { coordinator.engineDrained(attempt) }
            #expect(!coordinator.canBeginNextSet)
            coordinator.shutdownTimedOut(attempt)
            #expect(!coordinator.canBeginNextSet)
            if nativeFirst { coordinator.engineDrained(attempt) } else { coordinator.workoutClosed(attempt) }
            #expect(coordinator.canBeginNextSet)
            await rejected { _ = try await coordinator.prepareCapture(metadata: fixture.metadata(), confirmation: confirmation) }
            await coordinator.closeForTesting()
        }
    }

    @Test func oldAttemptDrainAndEndCallbacksCannotCloseTheNextAttempt() async throws {
        let fixture = try OwnerAdmissionFixture(), coordinator = fixture.coordinator()
        _ = try await fixture.prepare(coordinator)
        let firstPhysical = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        let first = try await coordinator.prepareCapture(metadata: fixture.metadata(), confirmation: firstPhysical)
        try await coordinator.admit(first) {}
        coordinator.retireCapture(first); coordinator.engineDrained(first); coordinator.workoutClosed(first)
        let nextPhysical = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        let next = try await coordinator.prepareCapture(metadata: fixture.metadata(), confirmation: nextPhysical)
        try await coordinator.admit(next) {}
        coordinator.engineDrained(first); coordinator.workoutClosed(first); coordinator.shutdownTimedOut(first)
        #expect(coordinator.isAdmitted(next) && !coordinator.canBeginNextSet)
        coordinator.retireCapture(next); coordinator.engineDrained(next); coordinator.workoutClosed(next)
        await coordinator.closeForTesting()
    }

    @Test func duplicatePublishedIDAndRelaunchCannotRestoreAdmission() async throws {
        let fixture = try OwnerAdmissionFixture()
        let coordinator = fixture.coordinator()
        let preparation = try await fixture.prepare(coordinator)
        let metadata = try fixture.metadata()
        let confirmation = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        let attempt = try await coordinator.prepareCapture(metadata: metadata, confirmation: confirmation)
        coordinator.retireCapture(attempt); coordinator.engineDrained(attempt); coordinator.workoutClosed(attempt)
        await coordinator.closeForTesting()
        let reopened = fixture.coordinator()
        try await reopened.load()
        #expect(reopened.acceptedPreparation == nil)
        await rejected { _ = try await reopened.prepareCapture(metadata: metadata, confirmation: confirmation) }
        try await fixture.accept(preparation, on: reopened)
        let newPhysical = try #require(reopened.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        await rejected { _ = try await reopened.prepareCapture(metadata: metadata, confirmation: newPhysical) }
        await reopened.closeForTesting()
    }

    @Test func nextSetupAndPhoneStatusDoNotRebindAnAlreadyAdmittedSet() async throws {
        let fixture = try OwnerAdmissionFixture(), coordinator = fixture.coordinator()
        let preparation = try await fixture.prepare(coordinator)
        let confirmation = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        let metadata = try fixture.metadata()
        let attempt = try await coordinator.prepareCapture(metadata: metadata, confirmation: confirmation)
        try await coordinator.admit(attempt) {}
        let nextDraft = try PracticeSetupDraft(originInstallationEpoch: fixture.phoneEpoch,
            preparationID: preparation.draft.identity.preparationID, revision: 2,
            preferences: .init(currentRacketArm: .right, usualHand: .right, intendedDrill: .backhandGroundstroke))
        let next = try OwnerPreparation(authority: preparation.authority, practiceID: preparation.practiceID, draft: nextDraft)
        try await fixture.accept(next, on: coordinator)
        _ = try await coordinator.receive(.statusRequest(requestID: UUID(), phoneEpoch: fixture.phoneEpoch))
        #expect(coordinator.isAdmitted(attempt))
        guard case let .valid(context) = try await coordinator.inspectContext(recordingID: metadata.recordingID) else {
            Issue.record("The running context disappeared"); return
        }
        #expect(context.manualStroke == .forehandGroundstroke && context.acceptedSetup == preparation.draft)
        coordinator.retireCapture(attempt); coordinator.engineDrained(attempt); coordinator.workoutClosed(attempt)
        #expect(coordinator.acceptedPreparation?.draft == nextDraft)
        await coordinator.closeForTesting()
    }

    @Test func namespaceReplacementAfterPublicationNeverReachesEngineAdmission() async throws {
        let fixture = try OwnerAdmissionFixture(), coordinator = fixture.coordinator()
        _ = try await fixture.prepare(coordinator)
        let physical = try #require(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
        let attempt = try await coordinator.prepareCapture(metadata: fixture.metadata(), confirmation: physical)
        let directory = fixture.base.appendingPathComponent(PracticeSetupChannel.directoryName)
        try FileManager.default.moveItem(at: directory, to: fixture.base.appendingPathComponent("held-channel"))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        var admissions = 0
        await rejected { try await coordinator.admit(attempt) { admissions += 1 } }
        #expect(admissions == 0)
        await coordinator.closeForTesting()
    }

    @Test func missingNamespaceDoesNotReconstructAnExistingWatchInstall() async throws {
        let fixture = try OwnerAdmissionFixture(), first = fixture.coordinator()
        try await first.load()
        await first.closeForTesting()
        let directory = fixture.base.appendingPathComponent(OwnerPracticeStore.directoryName)
        try FileManager.default.moveItem(at: directory, to: fixture.base.appendingPathComponent("held-owner"))
        let reopened = fixture.coordinator()
        await rejected { try await reopened.load() }
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        await reopened.closeForTesting()
    }

    @Test func explicitMalformedFixtureIdentityCannotFallBackToProduction() throws {
        for raw in ["", "not-a-uuid", "../shared", UUID().uuidString + "/child"] {
            #expect(throws: (any Error).self) {
                _ = try WatchRuntimeEnvironment.resolve(arguments: ["--owner-watch-fixture=\(raw)"], environment: [:])
            }
        }
        let id = UUID()
        let first = try WatchRuntimeEnvironment.resolve(arguments: ["--owner-watch-fixture=\(id.uuidString)"], environment: [:])
        let second = try WatchRuntimeEnvironment.resolve(arguments: ["--owner-watch-fixture=\(id.uuidString)"], environment: [:])
        #expect(first.fixtureID == id && first.base == second.base && !first.allowsHardware)
        #expect(first.preferenceSuite == second.preferenceSuite)
        #expect(first.base?.standardizedFileURL.path.hasPrefix(FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path) == true)
    }

    @Test func explicitlyRetiredPreparationCannotBeReplayedLaterInSameRuntime() async throws {
        let fixture = try OwnerAdmissionFixture(), coordinator = fixture.coordinator()
        let prepared = try await fixture.enrollAndDraft(coordinator)
        try await fixture.accept(prepared, on: coordinator)
        let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: coordinator.generations,
            preparation: prepared.identity)
        _ = try await coordinator.receive(.retire(correlation: correlation, reason: .cancelPreparation))
        await rejected { _ = try await coordinator.receive(.prepare(correlation: correlation, preparation: prepared)) }
        #expect(coordinator.acceptedPreparation == nil)
        #expect(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true) == nil)
        await coordinator.closeForTesting()
    }

    private func rejected(_ operation: () async throws -> Void) async {
        do { try await operation(); Issue.record("An ineligible operation succeeded") } catch {}
    }
}

@MainActor
private final class OwnerAdmissionFixture {
    let base: URL
    let phoneEpoch = UUID()
    init() throws {
        base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("O5OwnerAdmission-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
    }
    isolated deinit { try? FileManager.default.removeItem(at: base) }
    func coordinator(afterPublication: (@MainActor (OwnerContextPublication) async -> Void)? = nil) -> OwnerCaptureCoordinator {
        OwnerCaptureCoordinator(base: base, afterPublication: afterPublication)
    }
    func enrollAndDraft(_ coordinator: OwnerCaptureCoordinator,
                        drill: RecordingDrill = .forehandGroundstroke,
                        includesHeartRate: Bool = false) async throws -> OwnerPreparation {
        try await coordinator.load()
        let epoch = try #require(coordinator.watchEpoch)
        let owner = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: phoneEpoch,
            watchInstallationEpoch: epoch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
            includesHeartRate: includesHeartRate, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000,
            policyDigest: OwnerPracticePolicy.digest)
        _ = try await coordinator.receive(.mutate(requestID: UUID(), generations: coordinator.generations,
            mutation: .enrollment(owner)))
        let draft = try PracticeSetupDraft(originInstallationEpoch: phoneEpoch, preparationID: UUID(), revision: 1,
            preferences: .init(currentRacketArm: .right, usualHand: .right, intendedDrill: drill))
        return try OwnerPreparation(authority: owner, practiceID: UUID(), draft: draft)
    }
    func accept(_ preparation: OwnerPreparation, on coordinator: OwnerCaptureCoordinator) async throws {
        let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: coordinator.generations,
            preparation: preparation.identity)
        let optionalReply = try await coordinator.receive(.prepare(correlation: correlation, preparation: preparation))
        let reply = try #require(optionalReply)
        guard case let .receipt(received, _, observation, reason) = reply else {
            Issue.record("Explicit preparation did not receive a Watch receipt"); return
        }
        #expect(received == correlation && reason == nil)
        #expect(observation.acceptedCurrent == preparation.identity || observation.acceptedNext == preparation.identity)
    }
    func prepare(_ coordinator: OwnerCaptureCoordinator, drill: RecordingDrill = .forehandGroundstroke) async throws -> OwnerPreparation {
        let preparation = try await enrollAndDraft(coordinator, drill: drill)
        try await accept(preparation, on: coordinator)
        return preparation
    }
    func metadata(drill: RecordingDrill = .forehandGroundstroke) throws -> RecordingMetadata {
        try RecordingMetadata(recordingID: UUID(),
            clock: .init(domainID: UUID(), monotonicAnchorSeconds: 10, wallAnchorUnixSeconds: 1_800_000_000),
            appBuild: "O5-synthetic", protocolVersion: RecordingDrill.protocolVersion,
            deviceModel: "synthetic-watch", operatingSystem: "watchOS 27", handedness: .right,
            playingArm: .right, watchWrist: .right, watchOrientation: "Crown right", playingArmConfirmed: true,
            drill: drill.rawValue, capabilityReport: "synthetic test capture boundary",
            streams: RecordingStream.allCases.map {
                try .init(stream: $0, supported: true, requestedRateHz: nil, knownSensorLimit: nil)
            })
    }
}

@MainActor
private final class OwnerAdmissionPause {
    private var arrived = false
    private var waiting: CheckedContinuation<Void, Never>?
    private var paused: CheckedContinuation<Void, Never>?
    func suspend() async {
        await withCheckedContinuation { continuation in
            paused = continuation; arrived = true; waiting?.resume(); waiting = nil
        }
    }
    func waitUntilReached() async {
        if arrived { return }
        await withCheckedContinuation { waiting = $0 }
    }
    func release() { paused?.resume(); paused = nil }
}

@MainActor
struct OwnerWorkoutIdentityTests {
    @Test func practiceEndCancelsPendingAuthorizationBeforeAnyRawCapture() async throws {
        let fixture = try await OwnerLifecycleFixture()
        fixture.practice.begin()
        try await fixture.wait { fixture.workout.authorizations.count == 1 }
        let authorization = try #require(fixture.workout.authorizations.first)
        fixture.practice.end(); authorization(nil)
        try await fixture.wait { fixture.driver.isClosed }
        #expect(fixture.workout.sessions.isEmpty)
        #expect(fixture.motion.starts.isEmpty && fixture.model.capturedMetadata == nil)
        #expect(!fixture.model.canStart)
        await fixture.close()
    }

    @Test func practiceEndWaitsForNativeEndedAfterActualWriterDrain() async throws {
        let fixture = try await OwnerLifecycleFixture()
        try await fixture.beginAndRun(); try await fixture.startSet()
        fixture.practice.end()
        try await fixture.wait { fixture.model.snapshot?.state.isTerminal == true }
        #expect(!fixture.practice.canBeginPractice && !fixture.driver.isClosed)
        fixture.driver.checkShutdownDeadlineForTesting()
        #expect(!fixture.practice.canBeginPractice)
        fixture.session.emit(.ended)
        try await fixture.wait { fixture.driver.isClosed }
        #expect(!fixture.model.canStart)
        await fixture.close()
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "The production lifecycle did not reach the expected state within five seconds")
    }

    @Test func cancelledAuthorizationCannotCreateAResourceForALaterAttempt() {
        let backend = OwnerWorkoutBackendFixture(), driver = WatchWorkoutDriver(backend: nil, allowsHardware: false)
        var blocked: [WatchWorkoutDriver.Event] = []; driver.onEvent = { blocked.append($0) }
        driver.start(attemptID: UUID())
        #expect(driver.isClosed && blocked.contains { $0.kind == .closedWithoutSession })
        let isolated = WatchWorkoutDriver(backend: backend, allowsHardware: false)
        let first = UUID(), second = UUID()
        var events: [WatchWorkoutDriver.Event] = []; isolated.onEvent = { events.append($0) }
        isolated.start(attemptID: first); isolated.end(); isolated.start(attemptID: second)
        backend.authorizations[0](nil)
        #expect(backend.sessions.isEmpty && !isolated.isClosed)
        backend.authorizations[1](nil)
        #expect(backend.sessions.count == 1)
        #expect(events.filter { $0.kind == .closedWithoutSession }.map(\.attemptID) == [first])
        isolated.end(); backend.sessions[0].emit(.ended)
        #expect(isolated.isClosed)
    }
    @Test func endAndTimeoutCannotAcknowledgeNativeClosure() {
        let backend = OwnerWorkoutBackendFixture(), attempt = UUID()
        let driver = WatchWorkoutDriver(backend: backend, allowsHardware: false)
        var events: [WatchWorkoutDriver.Event] = []; driver.onEvent = { events.append($0) }
        driver.start(attemptID: attempt); backend.authorizations[0](nil)
        let session = backend.sessions[0]; session.emit(.running)
        driver.end(); driver.checkShutdownDeadlineForTesting()
        #expect(!driver.isClosed && session.endCount == 1)
        #expect(events.last?.kind == .shutdownTimedOut)
        driver.start(attemptID: UUID()); #expect(backend.authorizations.count == 1)
        #expect(!events.contains { $0.kind == .closedWithoutSession || $0.kind == .ended })
        session.emit(.ended)
        #expect(driver.isClosed && events.last?.kind == .ended)
        #expect(events.last?.sessionID == session.id && events.last?.attemptID == attempt)
    }
    @Test func staleNativeCallbacksCannotCloseOrResumeNextAttempt() {
        let backend = OwnerWorkoutBackendFixture()
        let driver = WatchWorkoutDriver(backend: backend, allowsHardware: false)
        var events: [WatchWorkoutDriver.Event] = []; driver.onEvent = { events.append($0) }
        let first = UUID(), second = UUID()
        driver.start(attemptID: first); backend.authorizations[0](nil)
        let old = backend.sessions[0]; old.emit(.running); driver.end(); old.emit(.ended)
        driver.start(attemptID: second); backend.authorizations[1](nil)
        let current = backend.sessions[1]; current.emit(.running)
        let count = events.count
        old.emit(.running); old.emit(.ended); old.emit(.failed("old delegate error"))
        #expect(events.count == count && !driver.isClosed && current.endCount == 0)
        #expect(events.last?.attemptID == second && events.last?.sessionID == current.id)
        driver.end(); current.emit(.ended)
    }
    @Test func authorizationFailureHasNoSessionButNativeFailureRetainsIt() {
        let backend = OwnerWorkoutBackendFixture()
        let driver = WatchWorkoutDriver(backend: backend, allowsHardware: false)
        let first = UUID(); driver.start(attemptID: first); backend.authorizations[0]("Denied")
        #expect(driver.isClosed && backend.sessions.isEmpty)
        driver.start(attemptID: first); #expect(backend.authorizations.count == 1)
        driver.start(attemptID: UUID()); backend.authorizations[1](nil)
        let native = backend.sessions[0]; native.emit(.failed("Native error"))
        #expect(!driver.isClosed && native.endCount == 1)
        native.emit(.ended); #expect(driver.isClosed)
    }
}
@MainActor
private final class OwnerWorkoutBackendFixture: WatchWorkoutBackend {
    var authorizations: [@MainActor (String?) -> Void] = []
    var sessions: [OwnerWorkoutSessionFixture] = []
    func authorize(_ completion: @escaping @MainActor (String?) -> Void) { authorizations.append(completion) }
    func makeSession() throws -> any WatchWorkoutSessionHandle {
        let session = OwnerWorkoutSessionFixture(); sessions.append(session); return session
    }
}
@MainActor
private final class OwnerWorkoutSessionFixture: WatchWorkoutSessionHandle {
    let id = UUID()
    var onState: ((WatchWorkoutDriver.Kind) -> Void)?
    var endCount = 0
    func start() {}
    func pause() {}
    func resume() {}
    func end() { endCount += 1 }
    func emit(_ kind: WatchWorkoutDriver.Kind) { onState?(kind) }
}

@MainActor
struct OwnerActualRecorderPathTests {
    @Test(arguments: [RecordingDrill.forehandGroundstroke, .backhandGroundstroke], [false, true])
    func realBeginPauseResumeAndPracticeClosureOrders(drill: RecordingDrill, nativeEndsFirst: Bool) async throws {
        let fixture = try await OwnerActualRecorderFixture(drill: drill)
        try await fixture.startRunning()
        let metadata = try #require(fixture.model.capturedMetadata)
        let first = try #require(fixture.motion.starts.first)
        try await fixture.assertContext(metadata)
        let beforePause = try #require(fixture.model.snapshot)
        #expect(beforePause.accelerometerCount == 1 && beforePause.deviceMotionCount == 1)
        fixture.model.pause(); fixture.session.emit(.paused)
        await fixture.wait { fixture.model.state == .paused }
        #expect(!fixture.motion.running && fixture.motion.stopCount > 0)
        fixture.model.resume(); fixture.session.emit(.running)
        await fixture.wait { fixture.motion.starts.count == 2 }
        fixture.motion.emitPair(using: try #require(fixture.motion.starts.last))
        await fixture.wait {
            fixture.model.state == .recording && fixture.model.snapshot?.accelerometerCount == 2 &&
            fixture.model.snapshot?.deviceMotionCount == 2
        }
        #expect(fixture.model.capturedMetadata == metadata)
        let resumedContext = try fixture.contextPayload(metadata)
        try await fixture.assertLateMotionIgnored(first)
        #expect(fixture.model.state == .recording && fixture.motion.running)
        #expect(fixture.model.capturedMetadata == metadata)
        let afterStaleGeneration = try fixture.contextPayload(metadata)
        #expect(afterStaleGeneration.context == resumedContext.context && afterStaleGeneration.metadata == resumedContext.metadata)
        fixture.model.stop(); fixture.lifecycle.practice.end()
        if nativeEndsFirst { fixture.session.emit(.ended) }
        await fixture.wait { fixture.model.snapshot?.state.isTerminal == true }
        if !nativeEndsFirst {
            #expect(!fixture.driver.isClosed && !fixture.lifecycle.practice.canBeginPractice)
            fixture.driver.checkShutdownDeadlineForTesting()
            #expect(!fixture.lifecycle.practice.canBeginPractice)
            fixture.session.emit(.ended)
        }
        await fixture.wait { fixture.driver.isClosed }
        let report = try RecordingStore.inspect(root: fixture.paths.rawRoot, recordingID: metadata.recordingID)
        #expect(report.status == .finalized && report.metadata == metadata && report.issues.isEmpty)
        #expect(report.finalization?.reason == .userStopped)
        #expect(report.chunks.filter { $0.stream == .accelerometer }.reduce(0) { $0 + $1.sampleCount } == 2)
        #expect(report.chunks.filter { $0.stream == .deviceMotion }.reduce(0) { $0 + $1.sampleCount } == 2)
        try await fixture.assertLateMotionIgnored(first)
        await fixture.wait {
            fixture.lifecycle.practice.state == .ended || fixture.lifecycle.practice.state == .interrupted
        }
        let telemetry = try await fixture.lifecycle.practice.telemetrySnapshot()
        let finalization = try #require(telemetry.finalization)
        if nativeEndsFirst {
            #expect(fixture.lifecycle.practice.state == .ended && finalization.status == .ended)
        } else {
            #expect(fixture.lifecycle.practice.state == .interrupted && finalization.status == .interrupted)
            #expect(finalization.absenceReasons.contains(.interrupted))
        }
        let retired = try await fixture.coordinator.inspectContext(recordingID: metadata.recordingID)
        try #require(retired == .retired)
        let endedContext = try fixture.contextPayload(metadata)
        #expect(endedContext.context == resumedContext.context && endedContext.metadata == resumedContext.metadata)
        #expect(!fixture.model.canStart && !fixture.model.canBeginNextSet)
        await fixture.close()
    }

    @Test(arguments: OwnerActualRecorderMutation.allCases)
    fileprivate func heldMotionAuthorizationCannotAdmitAfterOwnerMutation(mutation: OwnerActualRecorderMutation) async throws {
        let fixture = try await OwnerActualRecorderFixture()
        try await fixture.reachMotionAuthorization()
        let metadata = try #require(fixture.model.capturedMetadata)
        let retained = try fixture.contextPayload(metadata)
        #expect(fixture.motion.starts.isEmpty && fixture.model.state == .starting)
        try await fixture.mutate(mutation)
        fixture.motion.authorizations[0](nil) // The actual captured model callback resumes late.
        await fixture.wait { fixture.model.snapshot?.state.isTerminal == true }
        #expect(fixture.motion.starts.isEmpty && !fixture.motion.running && fixture.motion.stopCount > 0)
        #expect(fixture.model.snapshot?.hasLocalRecording == false && fixture.model.capturedMetadata == metadata)
        #expect(!fixture.model.canBeginNextSet && !fixture.driver.isClosed)
        fixture.session.emit(.ended)
        await fixture.wait { fixture.driver.isClosed }
        try await fixture.assertContextAfterMutation(metadata, mutation: mutation, before: retained)
        #expect(!FileManager.default.fileExists(atPath: fixture.paths.rawRoot.appendingPathComponent(metadata.recordingID.uuidString).path))
        await fixture.close()
    }

    @Test(arguments: OwnerActualRecorderMutation.allCases)
    fileprivate func heldRealPublicationCannotStartWorkoutAfterOwnerMutation(mutation: OwnerActualRecorderMutation) async throws {
        let gate = OwnerAdmissionPause()
        let fixture = try await OwnerActualRecorderFixture(afterPublication: { _ in await gate.suspend() })
        try await fixture.begin()
        await gate.waitUntilReached()
        let metadata = try #require(fixture.model.capturedMetadata)
        let retained = try fixture.contextPayload(metadata)
        try await fixture.assertContext(metadata)
        try await fixture.mutate(mutation)
        gate.release()
        await fixture.wait { fixture.model.state.isTerminal }
        #expect(fixture.backend.authorizations.count == 1 && fixture.backend.sessions.count == 1)
        #expect(fixture.motion.authorizations.isEmpty && fixture.motion.starts.isEmpty && !fixture.motion.running)
        #expect(fixture.model.snapshot == nil && fixture.model.capturedMetadata == metadata)
        try await fixture.assertContextAfterMutation(metadata, mutation: mutation, before: retained)
        await fixture.close()
    }

    @Test func oldWorkoutAndMotionCallbacksCannotAffectTheNextRealCapture() async throws {
        let fixture = try await OwnerActualRecorderFixture()
        try await fixture.startRunning()
        let firstMetadata = try #require(fixture.model.capturedMetadata)
        let firstPreparation = fixture.preparation
        let firstPayload = try fixture.contextPayload(firstMetadata)
        let oldSession = fixture.session, oldStart = try #require(fixture.motion.starts.first)
        let oldAuthorization = try #require(fixture.motion.authorizations.first)
        fixture.model.stop(); fixture.lifecycle.practice.end(); oldSession.emit(.ended)
        await fixture.wait { fixture.driver.isClosed && fixture.lifecycle.practice.state == .ended }
        let firstReport = try RecordingStore.inspect(root: fixture.paths.rawRoot, recordingID: firstMetadata.recordingID)
        #expect(firstReport.chunks.filter { $0.stream == .accelerometer }.reduce(0) { $0 + $1.sampleCount } == 1)
        #expect(firstReport.chunks.filter { $0.stream == .deviceMotion }.reduce(0) { $0 + $1.sampleCount } == 1)
        _ = try await fixture.lifecycle.acceptReplacementPractice()
        fixture.model.newSet()
        try await fixture.startRunning()
        let secondMetadata = try #require(fixture.model.capturedMetadata)
        #expect(firstMetadata.recordingID != secondMetadata.recordingID && oldSession.id != fixture.session.id)
        let before = try #require(fixture.model.snapshot)
        #expect(before.accelerometerCount == 1 && before.deviceMotionCount == 1)
        oldSession.emit(.running); oldSession.emit(.paused); oldSession.emit(.ended); oldSession.emit(.failed("late prior-session error"))
        oldAuthorization("late prior-authorization error")
        try await fixture.assertLateMotionIgnored(oldStart)
        let after = try #require(fixture.model.snapshot)
        #expect(fixture.model.state == .recording && fixture.motion.running && fixture.session.endCount == 0)
        #expect(after.recordingID == secondMetadata.recordingID && after.accelerometerCount == before.accelerometerCount)
        #expect(after.deviceMotionCount == before.deviceMotionCount)
        let retainedPayload = try fixture.contextPayload(firstMetadata, expectedPreparation: firstPreparation)
        #expect(retainedPayload.context == firstPayload.context && retainedPayload.metadata == firstPayload.metadata)
        try await fixture.assertContext(secondMetadata)
        fixture.model.stop(); fixture.lifecycle.practice.end(); fixture.session.emit(.ended)
        await fixture.wait { fixture.driver.isClosed }
        await fixture.close()
    }
    @Test func deniedMotionAuthorizationNeverStartsRawCaptureAndWaitsForNativeEnd() async throws {
        let fixture = try await OwnerActualRecorderFixture()
        try await fixture.reachMotionAuthorization()
        let metadata = try #require(fixture.model.capturedMetadata)
        fixture.motion.authorizations[0]("Synthetic motion authorization denied")
        await fixture.wait { fixture.model.snapshot?.state.isTerminal == true }
        #expect(fixture.motion.startAttempts == 0 && fixture.motion.starts.isEmpty && !fixture.motion.running)
        #expect(fixture.model.snapshot?.hasLocalRecording == false && fixture.model.capturedMetadata == metadata)
        #expect(fixture.motion.stopCount > 0 && fixture.session.endCount == 1)
        #expect(!fixture.driver.isClosed && !fixture.model.canBeginNextSet)
        #expect(!FileManager.default.fileExists(atPath: fixture.paths.rawRoot.appendingPathComponent(metadata.recordingID.uuidString).path))
        fixture.session.emit(.ended)
        await fixture.wait { fixture.driver.isClosed }
        #expect(fixture.driver.isClosed)
        try await fixture.assertContext(metadata)
        await fixture.close()
    }

    @Test func acquisitionStartupFailureClosesRealWriterButRetainsNativeSessionUntilEnded() async throws {
        let fixture = try await OwnerActualRecorderFixture()
        fixture.motion.startFailure = "Synthetic acquisition failed to start"
        try await fixture.reachMotionAuthorization()
        let metadata = try #require(fixture.model.capturedMetadata)
        fixture.motion.authorizations[0](nil)
        await fixture.wait { fixture.model.snapshot?.state.isTerminal == true }
        #expect(fixture.motion.startAttempts == 1 && fixture.motion.starts.isEmpty && !fixture.motion.running)
        #expect(fixture.model.snapshot?.hasLocalRecording == true && fixture.model.state != .saved)
        #expect(fixture.motion.stopCount > 0 && fixture.session.endCount == 1 && !fixture.driver.isClosed)
        #expect(!fixture.model.canBeginNextSet)
        fixture.session.emit(.ended)
        await fixture.wait { fixture.driver.isClosed }
        let report = try RecordingStore.inspect(root: fixture.paths.rawRoot, recordingID: metadata.recordingID)
        #expect(report.metadata == metadata && report.finalization?.reason == .interrupted)
        #expect(report.chunks.isEmpty)
        try await fixture.assertContext(metadata)
        await fixture.close()
    }

    @Test func actualWriterStartupFailureNeverStartsMotionOrAcknowledgesNativeEnd() async throws {
        let fixture = try await OwnerActualRecorderFixture()
        try await fixture.reachMotionAuthorization()
        let metadata = try #require(fixture.model.capturedMetadata)
        // This is exclusively the UUID child fixture raw root. Core writer remains real and unchanged.
        let preserved = fixture.paths.rawRoot.appendingPathExtension("before-startup-fault")
        try FileManager.default.moveItem(at: fixture.paths.rawRoot, to: preserved)
        try Data("not a recording directory".utf8).write(to: fixture.paths.rawRoot, options: .withoutOverwriting)
        fixture.motion.authorizations[0](nil)
        await fixture.wait { fixture.model.snapshot?.state == .failed }
        #expect(fixture.motion.startAttempts == 0 && fixture.motion.starts.isEmpty && !fixture.motion.running)
        #expect(fixture.model.snapshot?.hasLocalRecording == false && fixture.model.capturedMetadata == metadata)
        #expect(fixture.motion.stopCount > 0 && !fixture.driver.isClosed && !fixture.model.canBeginNextSet)
        fixture.session.emit(.ended)
        await fixture.wait { fixture.driver.isClosed }
        try await fixture.assertContext(metadata)
        await fixture.close()
    }

    @Test func incompleteSyntheticDependenciesFailClosedWithoutHardwareFallback() async throws {
        let noMotion = try await OwnerActualRecorderFixture(injectMotion: false)
        try await noMotion.begin()
        try await noMotion.lifecycle.wait { noMotion.model.capabilityIssue != nil && !noMotion.model.canStart }
        #expect(noMotion.model.capabilityIssue != nil && noMotion.model.snapshot == nil)
        #expect(noMotion.model.capturedMetadata == nil && !noMotion.model.canStart)
        #expect(noMotion.motion.authorizations.isEmpty && noMotion.motion.starts.isEmpty && !noMotion.motion.running)
        #expect(noMotion.backend.sessions.count == 1, "Begin practice may own its workout before set is admissible")
        try noMotion.assertIsolatedEnvironment()
        await noMotion.close()

        let noWorkout = try await OwnerActualRecorderFixture(injectWorkout: false)
        try await noWorkout.begin()
        try await noWorkout.lifecycle.wait { noWorkout.lifecycle.practice.state == .interrupted }
        #expect(noWorkout.lifecycle.practice.state == .interrupted && !noWorkout.lifecycle.practice.canBeginPractice)
        #expect(noWorkout.backend.authorizations.isEmpty && noWorkout.backend.sessions.isEmpty)
        #expect(noWorkout.motion.authorizations.isEmpty && noWorkout.motion.starts.isEmpty)
        #expect(noWorkout.model.snapshot == nil && noWorkout.model.capturedMetadata == nil && !noWorkout.model.canStart)
        try noWorkout.assertIsolatedEnvironment()
        await noWorkout.close()
    }

}

private enum OwnerActualRecorderMutation: CaseIterable, Sendable { case endPractice, withdraw, editSetup }

@MainActor
private final class OwnerActualRecorderFixture {
    let lifecycle: OwnerLifecycleFixture
    var services: WatchRecordingServices { lifecycle.services }
    var coordinator: OwnerCaptureCoordinator { lifecycle.owner }
    var preparation: OwnerPreparation { lifecycle.preparation }
    var backend: OwnerLifecycleWorkoutBackend { lifecycle.workout }
    var driver: WatchWorkoutDriver { lifecycle.driver }
    var motion: OwnerLifecycleMotionHardware { lifecycle.motion }
    var model: WatchRecorderModel { lifecycle.model }
    var paths: RecordingPaths { services.paths! }
    var session: OwnerLifecycleWorkoutSession { lifecycle.session }
    private let injectWorkout: Bool
    init(drill: RecordingDrill = .forehandGroundstroke,
         afterPublication: (@MainActor (OwnerContextPublication) async -> Void)? = nil,
         injectMotion: Bool = true, injectWorkout: Bool = true) async throws {
        lifecycle = try await OwnerLifecycleFixture(drill: drill, injectMotion: injectMotion,
            injectWorkout: injectWorkout, afterPublication: afterPublication)
        self.injectWorkout = injectWorkout
    }
    func begin() async throws {
        if lifecycle.practice.canBeginPractice {
            lifecycle.practice.begin()
            guard injectWorkout else { return }
            try await lifecycle.makeWorkoutRunning()
        }
        motion.authorizationStatus = .notDetermined
        lifecycle.preparePhysical()
        guard model.canStart else { return }
        model.start()
    }
    func reachMotionAuthorization() async throws {
        let before = motion.authorizations.count
        try await begin()
        await wait { self.motion.authorizations.count == before + 1 }
        try #require(motion.authorizations.count == before + 1)
    }
    func startRunning() async throws {
        let before = motion.starts.count
        try await reachMotionAuthorization()
        let authorization = try #require(motion.authorizations.last)
        authorization(nil)
        await wait { self.motion.starts.count == before + 1 }
        motion.emitPair(using: try #require(motion.starts.last))
        await wait { self.model.state == .recording }
        try #require(model.state == .recording)
    }
    func assertIsolatedEnvironment() throws {
        let environment = services.environment
        let fixtureID = try #require(environment.fixtureID)
        let expected = try WatchRuntimeEnvironment.resolve(arguments: ["--owner-watch-fixture=\(fixtureID.uuidString)"], environment: [:])
        #expect(!environment.allowsHardware && environment.failure == nil && services.connectivity == nil)
        #expect(environment.base == expected.base && environment.preferenceSuite == expected.preferenceSuite)
    }
    func assertLateMotionIgnored(_ start: OwnerLifecycleMotionHardware.Start) async throws {
        let before = model.snapshot
        motion.emitPair(using: start)
        try await lifecycle.settle()
        #expect(model.snapshot?.recordingID == before?.recordingID)
        #expect(model.snapshot?.accelerometerCount == before?.accelerometerCount)
        #expect(model.snapshot?.deviceMotionCount == before?.deviceMotionCount)
    }
    func mutate(_ mutation: OwnerActualRecorderMutation) async throws {
        switch mutation {
        case .endPractice:
            let command = try OwnerAuthorityMutation.retirePractice(from: preparation.authority,
                practiceID: preparation.practiceID, mutationID: UUID())
            _ = try await coordinator.receive(.mutate(requestID: UUID(), generations: coordinator.generations, mutation: command))
        case .withdraw:
            let command = try OwnerAuthorityMutation.withdraw(from: preparation.authority, decisionID: UUID(),
                confirmedAtUnixSeconds: 1_800_000_001)
            _ = try await coordinator.receive(.mutate(requestID: UUID(), generations: coordinator.generations, mutation: command))
        case .editSetup:
            let draft = try PracticeSetupDraft(originInstallationEpoch: preparation.authority.phoneInstallationEpoch,
                preparationID: UUID(), revision: preparation.draft.identity.revision + 1,
                preferences: .init(currentRacketArm: .right, usualHand: .right, intendedDrill: .backhandGroundstroke))
            let edited = try OwnerPreparation(authority: preparation.authority, practiceID: preparation.practiceID, draft: draft)
            _ = try await coordinator.receive(.draft(edited))
        }
    }
    func contextPayload(_ metadata: RecordingMetadata, expectedPreparation: OwnerPreparation? = nil) throws -> (context: Data, metadata: Data) {
        let preparation = expectedPreparation ?? self.preparation
        let base = try #require(services.environment.base)
        let directory = base.appendingPathComponent(OwnerPracticeStore.directoryName)
            .appendingPathComponent("contexts").appendingPathComponent(metadata.recordingID.uuidString)
        let contextBytes = try Data(contentsOf: directory.appendingPathComponent("context.json"))
        let metadataBytes = try Data(contentsOf: directory.appendingPathComponent("metadata.json"))
        let context = try OwnerRecordingContext.decode(contextBytes, rawMetadataBytes: metadataBytes)
        #expect(try context.encoded() == contextBytes)
        #expect(try RecordingChunkCodec.decodeMetadata(metadataBytes) == metadata)
        #expect(try RecordingChunkCodec.encodeMetadata(metadata) == metadataBytes)
        #expect(context.metadata == metadata && context.recordingID == metadata.recordingID)
        #expect(context.practiceID == preparation.practiceID && context.acceptedSetup == preparation.draft)
        #expect(context.ownerID == preparation.authority.ownerID && context.authorityRevision == preparation.authority.revision)
        return (contextBytes, metadataBytes)
    }
    func assertContextAfterMutation(_ metadata: RecordingMetadata, mutation: OwnerActualRecorderMutation,
                                    before: (context: Data, metadata: Data)) async throws {
        switch mutation {
        case .endPractice:
            #expect(try await coordinator.inspectContext(recordingID: metadata.recordingID) == .retired)
        case .withdraw, .editSetup:
            try await assertContext(metadata)
        }
        let after = try contextPayload(metadata)
        #expect(after.context == before.context && after.metadata == before.metadata)
    }
    func assertContext(_ metadata: RecordingMetadata) async throws {
        guard case let .valid(context) = try await coordinator.inspectContext(recordingID: metadata.recordingID) else {
            Issue.record("The actual recorder path lost its immutable validated context"); return
        }
        #expect(context.metadata == metadata && context.recordingID == metadata.recordingID)
        #expect(context.practiceID == preparation.practiceID && context.acceptedSetup == preparation.draft)
        #expect(context.ownerID == preparation.authority.ownerID && context.authorityRevision == preparation.authority.revision)
    }
    func wait(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "Actual recorder callback path did not reach its required state within five seconds")
    }
    func close() async { await lifecycle.finish() }
}

@MainActor
struct OwnerRetirementWireRegressionTests {
    @Test(arguments: [PracticeSetupRetirementReason.cancelPreparation, .endPractice], [false, true])
    func retirementReplyRoundTripsAndPersistsExactlyOneCheckedTransition(
        reason: PracticeSetupRetirementReason, heartRate: Bool
    ) async throws {
        let fixture = try OwnerAdmissionFixture()
        let coordinator = fixture.coordinator()
        do {
            let prepared = try await fixture.enrollAndDraft(coordinator, includesHeartRate: heartRate)
            try await fixture.accept(prepared, on: coordinator)
            let correlation = OwnerPreparationCorrelation(requestID: UUID(),
                generations: coordinator.generations, preparation: prepared.identity)
            let reply = try await coordinator.receive(.retire(correlation: correlation, reason: reason))
            let observation = try retiredObservation(reply, correlation: correlation, reason: reason)
            let owner = try #require(observation.authority)
            let expected = try prepared.authority.advancingRevision(expectedRevision: prepared.authority.revision)
            #expect(owner == expected && coordinator.authority == expected)
            #expect(owner.consentGeneration == prepared.authority.consentGeneration)
            #expect(owner.withdrawalBarrier == prepared.authority.withdrawalBarrier)
            #expect(owner.isCollectionAllowed && owner.heartRateConsent == heartRate)
            #expect(coordinator.generations == observation.generations)
            #expect(coordinator.acceptedPreparation == nil && coordinator.nextPreparation == nil)
            #expect(coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true) == nil)
            await rejects { _ = try await coordinator.receive(.retire(correlation: correlation, reason: reason)) }
            await rejects { _ = try await coordinator.receive(.prepare(correlation: correlation, preparation: prepared)) }
            let rebound = OwnerPreparationCorrelation(requestID: UUID(),
                generations: coordinator.generations, preparation: prepared.identity)
            await rejects { _ = try await coordinator.receive(.prepare(correlation: rebound, preparation: prepared)) }
            await rejects { _ = try await coordinator.receive(.retire(correlation: rebound, reason: reason)) }
            #expect(coordinator.authority == expected)
            await coordinator.closeForTesting()
            try persistedRetirement(base: fixture.base, prepared: prepared, expected: expected,
                correlation: correlation, reason: reason)
            let reopened = fixture.coordinator()
            do {
                try await reopened.load()
                #expect(reopened.authority == expected)
                #expect(reopened.acceptedPreparation == nil && reopened.nextPreparation == nil)
                #expect(reopened.confirmPhysical(wrist: .right, crown: "Crown right", fit: true) == nil)
                await rejects { _ = try await reopened.receive(.prepare(correlation: correlation, preparation: prepared)) }
                await rejects { try await fixture.accept(prepared, on: reopened) }
                await rejects { _ = try await reopened.prepareCapture(metadata: fixture.metadata(), confirmation: nil) }
                await reopened.closeForTesting()
            } catch {
                await reopened.closeForTesting()
                throw error
            }
        } catch {
            await coordinator.closeForTesting()
            throw error
        }
    }

    @Test(arguments: [PracticeSetupRetirementReason.cancelPreparation, .endPractice])
    func retirementFencesPublishedButUnadmittedActualRecorder(
        reason: PracticeSetupRetirementReason
    ) async throws {
        let gate = OwnerAdmissionPause()
        let fixture = try await OwnerActualRecorderFixture(afterPublication: { _ in await gate.suspend() })
        defer { gate.release() }
        do {
            try await fixture.begin()
            await gate.waitUntilReached()
            let metadata = try #require(fixture.model.capturedMetadata)
            let before = try fixture.contextPayload(metadata)
            let correlation = OwnerPreparationCorrelation(requestID: UUID(),
                generations: fixture.coordinator.generations, preparation: fixture.preparation.identity)
            let reply = try await fixture.coordinator.receive(.retire(correlation: correlation, reason: reason))
            gate.release()
            await fixture.wait { fixture.model.state.isTerminal }
            #expect(fixture.backend.authorizations.count == 1 && fixture.backend.sessions.count == 1)
            #expect(fixture.motion.authorizations.isEmpty && fixture.motion.starts.isEmpty && !fixture.motion.running)
            #expect(fixture.model.snapshot == nil && fixture.model.capturedMetadata == metadata)
            #expect(fixture.coordinator.acceptedPreparation == nil && fixture.coordinator.nextPreparation == nil)
            #expect(fixture.coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true) == nil)
            await rejects { _ = try await fixture.coordinator.prepareCapture(metadata: metadata, confirmation: nil) }
            let after = try fixture.contextPayload(metadata)
            #expect(after.context == before.context && after.metadata == before.metadata)
            if reason == .endPractice {
                #expect(try await fixture.coordinator.inspectContext(recordingID: metadata.recordingID) == .retired)
            } else {
                try await fixture.assertContext(metadata)
            }
            _ = try retiredObservation(reply, correlation: correlation, reason: reason)
            await fixture.close()
        } catch {
            gate.release()
            await fixture.close()
            throw error
        }
    }

    @Test(arguments: [PracticeSetupRetirementReason.cancelPreparation, .endPractice], [false, true])
    func retirementOfAdmittedRecorderRequiresActualWriterDrainAndNativeEnded(
        reason: PracticeSetupRetirementReason, nativeEndsFirst: Bool
    ) async throws {
        let fixture = try await OwnerActualRecorderFixture()
        let originalInvalidation = fixture.coordinator.onInvalidation
        defer { fixture.coordinator.onInvalidation = originalInvalidation }
        do {
            try await fixture.startRunning()
            let metadata = try #require(fixture.model.capturedMetadata)
            let start = try #require(fixture.motion.starts.last)
            let before = try fixture.contextPayload(metadata)
            let correlation = OwnerPreparationCorrelation(requestID: UUID(),
                generations: fixture.coordinator.generations, preparation: fixture.preparation.identity)
            var observedInvalidation = false
            fixture.coordinator.onInvalidation = { message in
                originalInvalidation?(message) // Keep the actual recorder's stop/drain path.
                if !observedInvalidation {
                    observedInvalidation = true
                    #expect(!fixture.motion.running && !fixture.model.canBeginNextSet)
                    if nativeEndsFirst {
                        fixture.session.emit(.ended)
                        // No real writer continuation can finish in this same MainActor turn.
                        #expect(!fixture.model.canBeginNextSet && !fixture.coordinator.canBeginNextSet)
                    }
                }
            }
            let reply = try await fixture.coordinator.receive(.retire(correlation: correlation, reason: reason))
            #expect(observedInvalidation && fixture.coordinator.acceptedPreparation == nil)
            if !nativeEndsFirst {
                await fixture.wait { fixture.model.snapshot?.state.isTerminal == true }
                #expect(!fixture.driver.isClosed && !fixture.model.canBeginNextSet)
                #expect(!fixture.coordinator.canBeginNextSet)
                fixture.driver.checkShutdownDeadlineForTesting()
                #expect(!fixture.model.canBeginNextSet)
                fixture.session.emit(.ended)
            }
            await fixture.wait { fixture.driver.isClosed }
            #expect(fixture.driver.isClosed && !fixture.model.canBeginNextSet && !fixture.model.canStart)
            try await fixture.assertLateMotionIgnored(start)
            let report = try RecordingStore.inspect(root: fixture.paths.rawRoot, recordingID: metadata.recordingID)
            #expect(report.metadata == metadata && report.finalization != nil && report.issues.isEmpty)
            #expect(report.finalization?.reason == .interrupted)
            #expect(report.chunks.filter { $0.stream == .accelerometer }.reduce(0) { $0 + $1.sampleCount } == 1)
            #expect(report.chunks.filter { $0.stream == .deviceMotion }.reduce(0) { $0 + $1.sampleCount } == 1)
            let after = try fixture.contextPayload(metadata)
            #expect(after.context == before.context && after.metadata == before.metadata)
            await rejects { _ = try await fixture.coordinator.receive(.prepare(correlation: correlation,
                preparation: fixture.preparation)) }
            #expect(fixture.coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true) == nil)
            _ = try retiredObservation(reply, correlation: correlation, reason: reason)
            await fixture.close()
        } catch {
            if !fixture.backend.sessions.isEmpty { fixture.session.emit(.ended) }
            await fixture.close()
            throw error
        }
    }

    @Test(arguments: [PracticeSetupRetirementReason.cancelPreparation, .endPractice],
          ["corruptJournal", "replacedChannel"])
    func retirementStoreFailureCannotReturnSuccessOrRestoreCapture(
        reason: PracticeSetupRetirementReason, damage: String
    ) async throws {
        let fixture = try await OwnerActualRecorderFixture()
        do {
            try await fixture.startRunning()
            let metadata = try #require(fixture.model.capturedMetadata)
            let start = try #require(fixture.motion.starts.last)
            let base = try #require(fixture.services.environment.base)
            let channel = base.appendingPathComponent(PracticeSetupChannel.directoryName)
            if damage == "corruptJournal" {
                try Data("corrupt synthetic owner journal".utf8).write(to: channel.appendingPathComponent("journal.json"))
            } else {
                try FileManager.default.moveItem(at: channel, to: base.appendingPathComponent("held-retirement-channel"))
                try FileManager.default.createDirectory(at: channel, withIntermediateDirectories: false)
            }
            let correlation = OwnerPreparationCorrelation(requestID: UUID(),
                generations: fixture.coordinator.generations, preparation: fixture.preparation.identity)
            // The coordinator itself must reject, not merely return an unencodable success.
            await rejects { _ = try await fixture.coordinator.receive(.retire(correlation: correlation, reason: reason)) }
            #expect(fixture.coordinator.acceptedPreparation == nil && fixture.coordinator.nextPreparation == nil)
            #expect(fixture.coordinator.confirmPhysical(wrist: .right, crown: "Crown right", fit: true) == nil)
            await fixture.wait { fixture.model.snapshot?.state.isTerminal == true }
            #expect(!fixture.motion.running && !fixture.driver.isClosed && !fixture.model.canBeginNextSet)
            try await fixture.assertLateMotionIgnored(start)
            fixture.session.emit(.ended)
            await fixture.wait { fixture.driver.isClosed }
            #expect(!fixture.model.canStart)
            await rejects { _ = try await fixture.coordinator.prepareCapture(metadata: metadata, confirmation: nil) }
            await fixture.close()
            let reopened = OwnerCaptureCoordinator(base: base)
            await rejects { try await reopened.load() }
            #expect(reopened.acceptedPreparation == nil && reopened.nextPreparation == nil)
            #expect(reopened.confirmPhysical(wrist: .right, crown: "Crown right", fit: true) == nil)
            await reopened.closeForTesting()
        } catch {
            if !fixture.backend.sessions.isEmpty { fixture.session.emit(.ended) }
            await fixture.close()
            throw error
        }
    }

    private func retiredObservation(_ reply: OwnerPreparationMessage?,
                                    correlation: OwnerPreparationCorrelation,
                                    reason: PracticeSetupRetirementReason) throws -> OwnerPreparationObservation {
        let actual = try #require(reply)
        let bytes = try OwnerPreparationCodec.encode(actual)
        let decoded = try OwnerPreparationCodec.decode(bytes)
        #expect(try OwnerPreparationCodec.encode(decoded) == bytes)
        guard case let .receipt(received, disposition, observation, receivedReason) = decoded else {
            throw OwnerCaptureFailure.invalidMessage
        }
        #expect(received == correlation && disposition == .retired && receivedReason == reason)
        #expect(observation.generations.runtimeGeneration == correlation.generations.runtimeGeneration)
        #expect(observation.generations.preparationGeneration != correlation.generations.preparationGeneration)
        #expect(observation.authority?.revision == correlation.preparation.authorityRevision + 1)
        #expect(observation.acceptedCurrent == nil && observation.acceptedNext == nil)
        return observation
    }

    private func persistedRetirement(base: URL, prepared: OwnerPreparation, expected: OwnerPracticeIdentity,
                                     correlation: OwnerPreparationCorrelation,
                                     reason: PracticeSetupRetirementReason) throws {
        let owner = prepared.authority
        let channel = try PracticeSetupChannel(base: base, localInstallationEpoch: owner.watchInstallationEpoch,
            device: .watch, intent: .openExisting)
        #expect(try channel.readSnapshot().authority == expected)
        #expect(try channel.readSnapshot().retainedTransitionCount == 2)
        let firstCursor = try OwnerAuthorityReplayCursor(ownerID: owner.ownerID,
            phoneEpoch: owner.phoneInstallationEpoch, watchEpoch: owner.watchInstallationEpoch)
        let firstOptional = try channel.nextTransition(after: firstCursor)
        let first = try #require(firstOptional)
        let cursor = try OwnerAuthorityReplayCursor(ownerID: owner.ownerID, phoneEpoch: owner.phoneInstallationEpoch,
            watchEpoch: owner.watchInstallationEpoch, after: OwnerAuthorityAcknowledgement(transition: first))
        let retirementOptional = try channel.nextTransition(after: cursor)
        let retirement = try #require(retirementOptional)
        #expect(first.mutation.kind == .enroll && retirement.mutation.id == correlation.requestID)
        #expect(retirement.mutation.kind == (reason == .endPractice ? .retirePractice : .advance))
        #expect(!retirement.mutation.isFullWithdrawal && retirement.mutation.isRevisionOnly)
        #expect(retirement.mutation.retiredPracticeID == (reason == .endPractice ? prepared.practiceID : nil))
        #expect(try channel.hasReplayGuard(scope: .practice, id: prepared.practiceID) == (reason == .endPractice))
        #expect(try !channel.hasReplayGuard(scope: .practice, id: UUID()))
        let end = try OwnerAuthorityReplayCursor(ownerID: owner.ownerID, phoneEpoch: owner.phoneInstallationEpoch,
            watchEpoch: owner.watchInstallationEpoch, after: OwnerAuthorityAcknowledgement(transition: retirement))
        #expect(try channel.nextTransition(after: end) == nil)
    }

    private func rejects(_ operation: () async throws -> Void) async {
        do { try await operation(); Issue.record("Retired or failed owner authority unexpectedly succeeded") } catch {}
    }
}
