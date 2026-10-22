import CoreMotion
import Foundation
import HealthKit
import Testing
@testable import PadelCore
@testable import PadelStrokeLab_Watch_App

/// Tests the retained practice owner, actual recorder/engine, and durable O6 telemetry.
/// Injected adapters supply native observations; they cannot grant capture or closure.
@MainActor
struct OwnerHeartRateLifecycleTests {
    @Test func sameTurnEndCancelsQueuedPracticeBeforeHeaderCreation() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try #require(f.practice.canBeginPractice && f.practice.currentPracticeID == nil)
        // Both calls execute in one MainActor turn: the startup Task has not run.
        f.practice.begin()
        try #require(f.practice.state == .baseline && f.practice.currentPracticeID == nil)
        f.practice.end()
        try await f.settle()
        let lateAuthorizations = f.workout.authorizations
        for completion in lateAuthorizations { completion(nil) }
        try await f.settle()
        for session in f.workout.sessions { session.emit(.running) }
        do {
            try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
        } catch {
            await f.close()
            throw error
        }
        #expect(f.workout.authorizations.isEmpty, "End must latch before the startup Task creates its header")
        #expect(f.workout.sessions.isEmpty)
        #expect(f.heart.requests.isEmpty && f.heart.queries.isEmpty)
        #expect(f.motion.accelerometerStarts == 0 && f.motion.deviceMotionStarts == 0)
        #expect(!f.practice.canStartSet && !f.model.canStart)
        #expect(f.practice.state == .ended || f.practice.state == .interrupted)
        await f.finish()
    }

    @Test(arguments: [false, true])
    func authorityRestrictionFencesQueuedAndAuthorizingPractice(lateAuthorization: Bool) async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try #require(f.practice.canBeginPractice && f.practice.currentPracticeID == nil)
        let previous = try #require(f.owner.authority)
        // This is a non-HR authority change, not evidence of consent withdrawal.
        let restriction = try OwnerAuthorityMutation.advance(from: previous, mutationID: UUID())
        f.practice.begin()
        if lateAuthorization {
            try await f.wait { f.workout.authorizations.count == 1 }
        }
        // receive advances the admission fence before its first store suspension.
        try await f.mutate(restriction)
        try await f.settle()
        let staleAuthorizations = f.workout.authorizations
        for completion in staleAuthorizations { completion(nil) }
        try await f.settle()
        for session in f.workout.sessions { session.emit(.running) }
        do {
            try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
        } catch {
            await f.close()
            throw error
        }
        #expect(f.owner.authority != previous && f.owner.acceptedPreparation == nil)
        #expect(f.workout.sessions.isEmpty, "An old authority cannot create a native session after its authorization returns")
        #expect(f.heart.requests.isEmpty && f.heart.queries.isEmpty)
        #expect(f.motion.accelerometerStarts == 0 && f.motion.deviceMotionStarts == 0)
        #expect(!f.practice.canStartSet && !f.model.canStart)
        if !lateAuthorization {
            #expect(f.workout.authorizations.isEmpty, "Queued startup must recheck the captured authority after suspension")
        }
        await f.finish()
    }


    @Test func startupRechecksDurableAuthorityBeforeRequestingNativeAuthorization() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try #require(f.practice.canBeginPractice && f.practice.currentPracticeID == nil)
        let authority = try #require(f.owner.authority)
        let preparation = try #require(f.owner.acceptedPreparation)
        let fence = f.owner.practiceStartupFence
        let base = try #require(f.services.environment.base)
        let state = base.appendingPathComponent(OwnerPracticeStore.directoryName).appendingPathComponent("state.json")
        try #require(FileManager.default.fileExists(atPath: state.path))
        let poison = Data("corrupt synthetic owner state".utf8)
        // No suspension: poison the isolated durable state after Begin, before its Task can run.
        f.practice.begin()
        try #require(f.practice.state == .baseline && f.practice.currentPracticeID == nil)
        try poison.write(to: state)
        try #require(f.owner.authority == authority && f.owner.acceptedPreparation == preparation)
        try #require(f.owner.practiceStartupFence == fence)
        do { try await f.wait { f.practice.state == .interrupted } }
        catch { await f.close(); throw error }
        #expect(f.workout.authorizations.isEmpty && f.workout.sessions.isEmpty)
        #expect(f.heart.requests.isEmpty && f.heart.queries.isEmpty)
        #expect(f.motion.accelerometerStarts == 0 && f.motion.deviceMotionStarts == 0)
        #expect(!f.practice.canStartSet && !f.model.canStart)
        await f.close()
        #expect(try Data(contentsOf: state) == poison, "Failure must preserve the poisoned namespace for diagnosis")
    }

    @Test(arguments: [false, true])
    func nativePauseClosesRawCaptureAndExplicitResumeReopensObservation(explicitPause: Bool) async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun(); try await f.startSet(); try await f.settle()
        let metadata = try #require(f.model.capturedMetadata)
        let context = try await f.context(metadata.recordingID)
        let initial = try await f.practice.telemetrySnapshot()
        let activeIDs = Set(initial.observations.filter { $0.kind == .active }.map(\.id))
        try #require(!activeIDs.isEmpty)
        let oldMotion = try #require(f.motion.starts.last)
        let starts = f.motion.deviceMotionStarts
        if explicitPause { f.model.pause() }
        f.session.emit(.paused)
        if explicitPause { try await f.wait { f.model.state == .paused } }
        try await f.settle()
        #expect(!f.motion.isAccelerometerActive && !f.motion.isDeviceMotionActive,
                "A native pause must stop actual raw acquisition even without a UI pause request")
        #expect(f.model.state != .recording)
        let count = f.model.snapshot?.accelerometerCount
        f.motion.emitPair(using: oldMotion)
        f.session.emit(.running); f.session.emit(.running)
        try await f.settle()
        #expect(f.motion.deviceMotionStarts == starts, "Delayed or duplicate running is not a resume request")
        #expect(f.model.snapshot?.accelerometerCount == count)
        if explicitPause {
            f.model.resume()
            try await f.settle()
            #expect(f.motion.deviceMotionStarts == starts)
            let waiting = try await f.practice.telemetrySnapshot()
            #expect(!waiting.observations.contains { $0.kind == .active && !activeIDs.contains($0.id) })
            f.session.emit(.running)
            try await f.wait { f.motion.deviceMotionStarts == starts + 1 }
            f.motion.emitPair(at: ProcessInfo.processInfo.systemUptime)
            try await f.wait { f.model.state == .recording }
            try await f.settle()
            let resumed = try await f.practice.telemetrySnapshot()
            #expect(resumed.observations.contains {
                $0.kind == .active && $0.closure == .open && !activeIDs.contains($0.id)
                    && $0.recordingID == metadata.recordingID
            }, "Observed running after explicit resume must reopen HR observation")
        }
        #expect(f.model.capturedMetadata == metadata)
        let retained = try await f.context(metadata.recordingID)
        #expect(try retained.encoded() == context.encoded())
        await f.finish()
    }

    @Test(arguments: [0.0, 3.0, -3.0])
    func endPreservesActualFrozenWallAndMonotonicReadings(wallShift: Double) async throws {
        let f = try await OwnerLifecycleFixture()
        try await f.beginAndRun(); try await f.startSet()
        f.model.stop(); try await f.wait { f.model.canBeginNextSet }
        let before = try await f.practice.telemetrySnapshot()
        let actualEnd = try f.clock.freeze(wallShift: wallShift)
        f.practice.end(); f.session.emit(.ended)
        try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
        let telemetry = try await f.practice.telemetrySnapshot()
        let finalization = try #require(telemetry.finalization)
        #expect(finalization.endedAt == actualEnd, "End evidence must retain actual readings, not projected wall time")
        #expect(telemetry.sets == before.sets, "A wall adjustment after raw stop cannot rewrite raw boundaries")
        if wallShift == 0 {
            #expect(finalization.status == .ended)
        } else {
            #expect(finalization.status == .interrupted)
            #expect(finalization.absenceReasons.contains(.clockDiscontinuity))
            #expect(finalization.absenceReasons.contains(.interrupted))
            #expect(telemetry.events.contains { $0.reason == .clockDiscontinuity && $0.at == actualEnd })
        }
        await f.close()
    }

    @Test(arguments: [OwnerTelemetryReason.bpmOutOfRange, .invalidDate, .unorderedInterval, .outsidePractice])
    func repeatedMalformedHeartRateRejectionsAreDurableBeforeAnchorProgression(reason: OwnerTelemetryReason) async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun(); try await f.settle()
        let telemetry = try await f.practice.telemetrySnapshot()
        let epoch = f.preparation.authority.watchInstallationEpoch
        var samples: [HKSample] = []
        for _ in 0..<2 {
            let sample = f.heart.sample(at: f.clock.wall, watchEpoch: epoch)
            let reading = try #require(f.heart.readings[sample.uuid])
            var start = reading.start, end = reading.end, bpm = reading.bpm
            switch reason {
            case .bpmOutOfRange: bpm = 301
            case .invalidDate: start = Date(timeIntervalSince1970: .nan)
            case .unorderedInterval: start = end.addingTimeInterval(1)
            case .outsidePractice:
                start = Date(timeIntervalSince1970: telemetry.header.clock.wallAnchorUnixSeconds - 1); end = start
            default: Issue.record("Unexpected malformed-reading test argument")
            }
            f.heart.readings[sample.uuid] = OwnerHeartRateNativeReading(id: reading.id, start: start, end: end,
                bpm: bpm, provenance: reading.provenance, isLocalDevice: true, isUserEntered: false)
            samples.append(sample)
        }
        // A full finite page must advance only after all refusal evidence is durable.
        for _ in 0..<254 { samples.append(f.heart.sample(at: f.clock.wall, watchEpoch: epoch, userEntered: true)) }
        let query = try #require(f.heart.queries.first)
        let anchor = HKQueryAnchor(fromValue: 256)
        query.deliver(samples, 0, anchor, nil)
        try await f.wait { f.heartRate.pendingCallbacks == 0 }
        let saved = try await f.practice.telemetrySnapshot()
        let events = saved.events.filter { $0.reason == reason }
        #expect(saved.sampleRecords.isEmpty)
        #expect(saved.exclusionCounts[reason] == 2)
        #expect(events.count == 2 && events.allSatisfy { $0.count == 1 },
                "O6 permits only single-event counts for this malformed-reading reason")
        #expect(saved.exclusionCounts[.userEntered] == 254)
        #expect(f.heart.queries.count == 2)
        #expect(f.heart.queries.last?.anchor?.isEqual(anchor) == true)
        await f.finish()
    }

    @Test(arguments: ["observation", "consent", "callback", "end"])
    func wholeHeartRateIntervalsRespectCapturedObservationAndCallbackBounds(boundary: String) async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun(); try await f.settle()
        if boundary == "consent" { try await f.startSet(); try await f.settle() }
        let initial = try await f.practice.telemetrySnapshot()
        let baseline = try #require(initial.observations.first { $0.kind == .baseline })
        let epoch = f.preparation.authority.watchInstallationEpoch
        var start = f.clock.wall, end = start
        if boundary == "observation" {
            try #require(baseline.start.wallUnixSeconds > initial.header.clock.wallAnchorUnixSeconds)
            start = (initial.header.clock.wallAnchorUnixSeconds + baseline.start.wallUnixSeconds) / 2
        } else if boundary == "consent" {
            start = baseline.start.wallUnixSeconds
            try await f.changeHeartRate(false); try await f.changeHeartRate(true)
            let authorize = try #require(f.heart.requests.last).completion
            authorize(nil)
            try await f.wait { f.heart.queries.count == 2 }
            end = f.clock.wall
        } else {
            end = start + 10
        }
        let sample = f.heart.sample(at: start, watchEpoch: epoch)
        let reading = try #require(f.heart.readings[sample.uuid])
        f.heart.readings[sample.uuid] = OwnerHeartRateNativeReading(id: reading.id,
            start: Date(timeIntervalSince1970: start), end: Date(timeIntervalSince1970: end),
            bpm: reading.bpm, provenance: reading.provenance, isLocalDevice: true, isUserEntered: false)
        let query = try #require(f.heart.queries.last)
        query.deliver([sample], 0, HKQueryAnchor(fromValue: 1), nil)
        if boundary == "end" {
            // The callback entered before End; publication has not executed on MainActor yet.
            _ = try f.clock.freeze(wallShift: 0)
            f.practice.end(); f.session.emit(.ended)
        }
        try await f.wait { f.heartRate.pendingCallbacks == 0 }
        if boundary == "end" {
            try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
        }
        let saved = try await f.practice.telemetrySnapshot()
        #expect(!saved.sampleRecords.contains { $0.sample.id == sample.uuid && $0.isEligible },
                "The whole interval must fit its captured observation, consent, callback-entry and End bounds")
        #expect(saved.exclusionCounts.values.reduce(0, +) == 1, "The interval rejection must remain durable")
        if boundary == "end" { #expect(saved.finalization != nil) }
        await f.finish()
    }

    @Test func localEndDurablyRetiresPracticeAndClearsQueuedPreparation() async throws {
        let f = try await OwnerLifecycleFixture()
        try await f.beginAndRun(); try await f.startSet()
        let original = f.preparation
        let draft = try PracticeSetupDraft(originInstallationEpoch: original.authority.phoneInstallationEpoch,
            preparationID: UUID(), revision: original.draft.identity.revision + 1, preferences: .init(currentRacketArm: .right, usualHand: .right,
                intendedDrill: .backhandGroundstroke))
        let queued = try OwnerPreparation(authority: original.authority, practiceID: original.practiceID, draft: draft)
        let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: f.owner.generations, preparation: queued.identity)
        _ = try await f.owner.receive(.prepare(correlation: correlation, preparation: queued))
        try #require(f.owner.nextPreparation == queued)
        f.practice.end(); f.session.emit(.ended)
        try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
        #expect(f.owner.acceptedPreparation == nil && f.owner.nextPreparation == nil)
        #expect(f.owner.authority?.revision == original.authority.revision + 1)
        let base = try #require(f.services.environment.base)
        await f.close()
        let channel = try PracticeSetupChannel(base: base, localInstallationEpoch: original.authority.watchInstallationEpoch,
            device: .watch, intent: .openExisting)
        #expect(try channel.hasReplayGuard(scope: .practice, id: original.practiceID))
        let cursor = try OwnerAuthorityReplayCursor(ownerID: original.authority.ownerID,
            phoneEpoch: original.authority.phoneInstallationEpoch, watchEpoch: original.authority.watchInstallationEpoch)
        let enrollment = try #require(try channel.nextTransition(after: cursor))
        let afterEnrollment = try OwnerAuthorityReplayCursor(ownerID: original.authority.ownerID,
            phoneEpoch: original.authority.phoneInstallationEpoch, watchEpoch: original.authority.watchInstallationEpoch,
            after: OwnerAuthorityAcknowledgement(transition: enrollment))
        let retirement = try #require(try channel.nextTransition(after: afterEnrollment))
        #expect(retirement.mutation.kind == .retirePractice && retirement.mutation.retiredPracticeID == original.practiceID)
        #expect(try channel.readSnapshot().retainedTransitionCount == 2)
    }

    @Test func partialTelemetryRelaunchStaysInterruptedAndBlocksUnknownNativeClosure() async throws {
        let f = try await OwnerLifecycleFixture()
        try await f.beginAndRun(); try await f.startSet()
        f.model.stop(); try await f.wait { f.model.canBeginNextSet }
        let partial = try await f.practice.telemetrySnapshot()
        try #require(partial.finalization == nil && partial.status == .open && !f.driver.isClosed)
        let base = try #require(f.services.environment.base)
        let environment = f.services.environment
        await f.close() // No native ended callback, no invented closure or clean finalization.
        let backend = OwnerLifecycleWorkoutBackend()
        let driver = WatchWorkoutDriver(backend: backend, allowsHardware: false)
        let services = WatchRecordingServices(environment: environment, workout: driver, practiceClock: { try f.clock.now })
        let owner = try #require(services.coordinator)
        let practice = try #require(services.practice)
        try await owner.load()
        // Production must recover first; opening the O6 store here would perform the missing recovery for it.
        do { try await f.wait { practice.state == .interrupted } }
        catch { await practice.closeForTesting(); await owner.closeForTesting(); throw error }
        let path = base.appendingPathComponent(OwnerTelemetryStore.directoryName)
            .appendingPathComponent(partial.header.practiceID.uuidString.lowercased()).appendingPathComponent("telemetry.json")
        let recovered = try OwnerPracticeTelemetry.decode(Data(contentsOf: path))
        #expect(recovered.status == .interrupted && recovered.incompleteReasons.contains(.reopenedPartial))
        #expect(recovered.finalization == nil && recovered.sets == partial.sets)
        let authority = try #require(owner.authority)
        let draft = try PracticeSetupDraft(originInstallationEpoch: authority.phoneInstallationEpoch,
            preparationID: UUID(), revision: f.preparation.draft.identity.revision + 1, preferences: .init(currentRacketArm: .right, usualHand: .right,
                intendedDrill: .forehandGroundstroke))
        let next = try OwnerPreparation(authority: authority, practiceID: UUID(), draft: draft)
        let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: owner.generations, preparation: next.identity)
        do { _ = try await owner.receive(.prepare(correlation: correlation, preparation: next)) }
        catch { /* A recovered unknown closure may refuse current-authority preparation itself. */ }
        #expect(!practice.canBeginPractice, "A new runtime cannot infer native closure from interrupted partial telemetry")
        practice.begin(); try await f.settle()
        #expect(backend.authorizations.isEmpty && backend.sessions.isEmpty)
        await practice.closeForTesting(); await owner.closeForTesting()
        let reopened = try OwnerTelemetryStore.open(base: base, practiceID: partial.header.practiceID, expectedHeader: partial.header)
        #expect(reopened.snapshot.status == .interrupted && reopened.snapshot.incompleteReasons.contains(.reopenedPartial))
        #expect(reopened.snapshot.finalization == nil && reopened.snapshot.sets == partial.sets)
        var refusedCleanFinalization = false
        do { try reopened.update { try $0.finalize(status: .ended, at: f.clock.now, absenceReasons: []) } }
        catch { refusedCleanFinalization = true }
        #expect(refusedCleanFinalization)
        reopened.close()
    }


    @Test(arguments: ["valid", "namespaceSymlink", "practiceSymlink", "fileSymlink", "hardlinkedPayload", "oversizedPayload", "directoryOverflow"])
    func recoveryReaderChecksDescriptorsAndBoundsBeforeVisiting(kind: String) async throws {
        let f = try await OwnerLifecycleFixture()
        try await f.beginAndRun()
        let original = try await f.practice.telemetrySnapshot()
        let base = try #require(f.services.environment.base)
        await f.close()
        let namespace = base.appendingPathComponent(OwnerTelemetryStore.directoryName)
        let directory = namespace.appendingPathComponent(original.header.practiceID.uuidString.lowercased())
        let payload = directory.appendingPathComponent("telemetry.json")
        switch kind {
        case "namespaceSymlink", "practiceSymlink", "fileSymlink":
            let target = kind == "namespaceSymlink" ? namespace : kind == "practiceSymlink" ? directory : payload
            let held = base.appendingPathComponent("held-reader-target")
            try FileManager.default.moveItem(at: target, to: held)
            try FileManager.default.createSymbolicLink(at: target, withDestinationURL: held)
        case "hardlinkedPayload":
            try FileManager.default.linkItem(at: payload, to: base.appendingPathComponent("linked-reader-payload"))
        case "oversizedPayload":
            try Data(repeating: 0, count: OwnerPracticeTelemetry.maximumBytes + 1).write(to: payload)
        case "directoryOverflow":
            // Existing one plus 512 more exceeds 512 practices / 1,024 paired namespace entries.
            for _ in 0..<512 {
                let name = UUID().uuidString.lowercased()
                try FileManager.default.createDirectory(at: namespace.appendingPathComponent(name), withIntermediateDirectories: false)
                try Data().write(to: namespace.appendingPathComponent(".used-" + name))
            }
        default: break
        }
        var visited: [OwnerPracticeTelemetry] = []
        var refused = false
        do { try OwnerPracticeRecoveryReader.forEachCandidate(base: base) { visited.append($0) } }
        catch { refused = true }
        if kind == "valid" {
            #expect(!refused && visited.count == 1)
            let candidate = try #require(visited.first)
            #expect(try candidate.encoded() == original.encoded())
        } else {
            #expect(refused && visited.isEmpty, "Unsafe descriptors or bounds must be refused before decode/visitor publication")
        }
    }

    @Test(arguments: [false, true])
    func disablingHeartRateDuringStartupCommitsAndCancelsWithoutRevival(nativeAuthorizationPending: Bool) async throws {
        let publication = OwnerLifecycleBarrier()
        let f = try await OwnerLifecycleFixture(heartRate: true, beforeTelemetryPublication: { value in
            if nativeAuthorizationPending && value.finalization != nil { await publication.suspend() }
        })
        do {
            try #require(f.practice.canBeginPractice && f.practice.currentPracticeID == nil)
            let before = try #require(f.owner.authority)
            let mutation = try OwnerAuthorityMutation.heartRate(from: before, allowed: false,
                decisionID: UUID(), confirmedAtUnixSeconds: f.clock.wall)
            let expected = try mutation.resolve(from: before)
            f.practice.begin()
            if nativeAuthorizationPending { try await f.wait { f.workout.authorizations.count == 1 } }
            let reply = try await f.owner.receive(.mutate(requestID: UUID(), generations: f.owner.generations, mutation: mutation))
            if case .applied? = reply {} else { Issue.record("A durably applied HR disable must return its checked applied response") }
            #expect(f.owner.authority == expected && !expected.heartRateConsent)
            if nativeAuthorizationPending {
                try await f.wait { publication.entered }
                try #require(publication.entered && f.practice.state == .ending)
                let pending = try await f.practice.telemetrySnapshot()
                try #require(pending.finalization == nil)
            }
            publication.release()
            let stale = f.workout.authorizations
            for completion in stale { completion(nil) }
            try await f.settle()
            for session in f.workout.sessions { session.emit(.running) }
            try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
            #expect(f.workout.sessions.isEmpty && f.heart.requests.isEmpty && f.heart.queries.isEmpty)
            #expect(f.motion.accelerometerStarts == 0 && f.motion.deviceMotionStarts == 0)
            #expect(!f.practice.canStartSet && !f.model.canStart)
        } catch { publication.release(); await f.close(); throw error }
        publication.release(); await f.close()
    }

    @Test(arguments: [false, true])
    func directEndAfterDurationLimitKeepsActualSetBoundsAndWaitsForNativeClosure(crossesBoundaryDuringEnd: Bool) async throws {
        let f = try await OwnerLifecycleFixture()
        try await f.beginAndRun(); try await f.startSet()
        f.model.stop(); try await f.wait { f.model.canBeginNextSet }
        let before = try await f.practice.telemetrySnapshot()
        let actualEnd: OwnerTelemetryInstant
        if crossesBoundaryDuringEnd {
            let ingress = try OwnerTelemetryInstant(wallUnixSeconds: before.header.clock.wallAnchorUnixSeconds + 1799.999,
                monotonicSeconds: before.header.clock.monotonicAnchorSeconds + 1799.999)
            actualEnd = try OwnerTelemetryInstant(wallUnixSeconds: before.header.clock.wallAnchorUnixSeconds + 1800.001,
                monotonicSeconds: before.header.clock.monotonicAnchorSeconds + 1800.001)
            // Real raw Stop/drain completed above; only the injected End clock now crosses the policy boundary.
            f.clock.freeze(first: ingress, then: actualEnd)
        } else {
            f.clock.advance(1801)
            actualEnd = try f.clock.freeze(wallShift: 0)
        }
        f.practice.end() // No deadline check is allowed to manufacture the limit detection first.
        #expect(try f.clock.now == actualEnd)
        #expect(f.practice.state == .ending && !f.practice.canBeginPractice)
        try await f.settle()
        #expect(f.practice.state == .ending && !f.driver.isClosed)
        f.session.emit(.ended)
        try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
        let saved = try await f.practice.telemetrySnapshot()
        let finalization = try #require(saved.finalization)
        #expect(finalization.status == .interrupted)
        #expect(finalization.absenceReasons.contains(.interrupted) && finalization.absenceReasons.contains(.durationLimit))
        #expect(finalization.endedAt.monotonicSeconds == before.header.clock.monotonicAnchorSeconds + 1800)
        #expect(actualEnd.monotonicSeconds > finalization.endedAt.monotonicSeconds)
        #expect(saved.sets == before.sets, "The policy cutoff cannot rewrite actual raw set boundaries")
        await f.close()
    }

    @Test func enteredHeartRateRejectionKeepsItsActualEntryTimeAcrossOverdueEnd() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun(); try await f.settle()
        let before = try await f.practice.telemetrySnapshot()
        let sample = f.heart.sample(at: f.clock.wall, watchEpoch: f.preparation.authority.watchInstallationEpoch, userEntered: true)
        let query = try #require(f.heart.queries.first)
        let enteredBefore = try f.clock.now
        query.deliver([sample], 0, HKQueryAnchor(fromValue: 1), nil)
        let enteredAfter = try f.clock.now
        try #require(f.heartRate.pendingCallbacks == 1)
        f.clock.advance(1801)
        _ = try f.clock.freeze(wallShift: 0)
        f.practice.end() // Callback is entered, but its MainActor publication has not run.
        #expect(f.practice.state == .ending)
        f.session.emit(.ended)
        try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
        let saved = try await f.practice.telemetrySnapshot()
        let event = try #require(saved.events.first { $0.reason == .userEntered })
        #expect(event.count == 1 && saved.exclusionCounts[.userEntered] == 1 && saved.sampleRecords.isEmpty)
        #expect(event.at.wallUnixSeconds >= enteredBefore.wallUnixSeconds && event.at.wallUnixSeconds <= enteredAfter.wallUnixSeconds)
        #expect(event.at.monotonicSeconds >= enteredBefore.monotonicSeconds && event.at.monotonicSeconds <= enteredAfter.monotonicSeconds)
        #expect(event.at.monotonicSeconds < before.header.clock.monotonicAnchorSeconds + 1800,
                "An entered callback must retain its genuine entry time; End cannot clamp or backdate its event")
        let finalization = try #require(saved.finalization)
        #expect(finalization.status == .interrupted && finalization.absenceReasons.contains(.durationLimit))
        await f.close()
    }

    @Test func withdrawnPracticeStillRetiresDurablyWithoutRestoringCollection() async throws {
        let f = try await OwnerLifecycleFixture()
        try await f.beginAndRun(); try await f.startSet()
        let practiceID = f.preparation.practiceID
        f.model.stop(); try await f.wait { f.model.canBeginNextSet }
        let previous = try #require(f.owner.authority)
        let withdrawal = try OwnerAuthorityMutation.withdraw(from: previous, decisionID: UUID(),
            confirmedAtUnixSeconds: f.clock.wall)
        let reply = try await f.owner.receive(.mutate(requestID: UUID(), generations: f.owner.generations, mutation: withdrawal))
        if case .applied? = reply {} else { Issue.record("Withdrawal must be durably applied before retirement is tested") }
        let withdrawn = try #require(f.owner.authority)
        try #require(!withdrawn.isCollectionAllowed)
        f.session.emit(.ended)
        do { try await f.wait { f.driver.isClosed && (f.practice.state == .ended || f.practice.state == .interrupted) } }
        catch { await f.close(); throw error }
        // Target retirement after actual closure; collection permission is not permission to retain an old practice.
        do { try await f.owner.retireLocalPractice(practiceID) }
        catch { await f.close(); throw error }
        let retired = try #require(f.owner.authority)
        #expect(!retired.isCollectionAllowed && retired.revision == withdrawn.revision + 1)
        #expect(retired.consentGeneration == withdrawn.consentGeneration && retired.withdrawalBarrier == withdrawn.withdrawalBarrier)
        #expect(f.owner.acceptedPreparation == nil && f.owner.nextPreparation == nil)
        #expect(!f.practice.canBeginPractice && !f.model.canStart)
        let base = try #require(f.services.environment.base)
        await f.close()
        let channel = try PracticeSetupChannel(base: base, localInstallationEpoch: retired.watchInstallationEpoch,
            device: .watch, intent: .openExisting)
        #expect(try channel.hasReplayGuard(scope: .practice, id: practiceID))
        #expect(try channel.readSnapshot().authority == retired)
        var cursor = try OwnerAuthorityReplayCursor(ownerID: retired.ownerID, phoneEpoch: retired.phoneInstallationEpoch,
            watchEpoch: retired.watchInstallationEpoch)
        var transitions: [OwnerAuthorityMutation] = []
        while let transition = try channel.nextTransition(after: cursor) {
            transitions.append(transition.mutation)
            cursor = try OwnerAuthorityReplayCursor(ownerID: retired.ownerID, phoneEpoch: retired.phoneInstallationEpoch,
                watchEpoch: retired.watchInstallationEpoch, after: OwnerAuthorityAcknowledgement(transition: transition))
        }
        #expect(transitions.map(\.kind) == [.enroll, .withdraw, .retirePractice])
        #expect(transitions.last?.retiredPracticeID == practiceID)
    }

    @Test func beginPracticeStartsOneWorkoutAndBaselineWithoutMotionOrAForcedWait() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        f.practice.begin()
        try await f.wait { f.workout.authorizations.count == 1 }
        #expect(f.motion.accelerometerStarts == 0 && f.motion.deviceMotionStarts == 0)
        try await f.makeWorkoutRunning()
        #expect(f.practice.state == .baseline)
        #expect(f.heart.requests.count == 1)
        #expect(f.heart.requests[0].share.isEmpty)
        #expect(f.heart.requests[0].read == [HKObjectType.quantityType(forIdentifier: .heartRate)!])
        f.heart.requests[0].completion(nil)
        try await f.wait { f.heart.queries.count == 1 }
        try await f.startSet()
        #expect(f.practice.state == .activeSet && f.model.state == .recording)
        #expect(f.clock.offset == 0, "The real recorder reached recording without a forced baseline wait")
        #expect(f.workout.sessions.count == 1)
        await f.finish()
    }

    @Test func twoSetsKeepOneNativeSessionAndDifferentImmutableContexts() async throws {
        let f = try await OwnerLifecycleFixture()
        try await f.beginAndRun()
        try await f.startSet()
        let first = try #require(f.model.capturedMetadata)
        let firstContext = try await f.context(first.recordingID)
        let nativeID = try #require(f.workout.sessions.first).id
        f.model.stop()
        try await f.wait { f.model.canBeginNextSet }
        #expect(f.practice.state == .recovery)
        #expect(f.session.endCount == 0 && !f.driver.isClosed)
        #expect(!f.motion.isAccelerometerActive && !f.motion.isDeviceMotionActive)
        let starts = f.motion.deviceMotionStarts
        f.session.emit(.running)
        try await f.settle()
        #expect(f.motion.deviceMotionStarts == starts, "A native running event is not a local Start")
        f.model.newSet()
        #expect(!f.model.canStart)
        try await f.startSet()
        let second = try #require(f.model.capturedMetadata)
        let secondContext = try await f.context(second.recordingID)
        #expect(first.recordingID != second.recordingID && first.clock.domainID != second.clock.domainID)
        #expect(try firstContext.encoded() != secondContext.encoded())
        #expect(f.workout.sessions.count == 1 && f.session.id == nativeID)
        let telemetry = try await f.practice.telemetrySnapshot()
        #expect(telemetry.sets.count == 2)
        #expect(telemetry.sets[0].context.recordingID == first.recordingID)
        #expect(telemetry.sets[1].context.recordingID == second.recordingID)
        let allSetsMapped = telemetry.sets.allSatisfy { $0.mapping != nil }
        #expect(allSetsMapped)
        await f.finish()
    }

    @Test(arguments: [false, true])
    func sourceObservationAndRealWriterAcknowledgementAreBothRequired(sourceFirst: Bool) async throws {
        let barrier = OwnerLifecycleBarrier()
        let f = try await OwnerLifecycleFixture(beforeWriterDrain: { await barrier.suspend() })
        defer { barrier.release() }
        try await f.beginAndRun(); try await f.startSet()
        f.motion.clearFlagsOnStop = sourceFirst
        f.model.stop()
        try await f.wait { barrier.entered }
        #expect(!f.model.canBeginNextSet && f.practice.state == .setClosing)
        if sourceFirst {
            #expect(!f.motion.isAccelerometerActive && !f.motion.isDeviceMotionActive)
            barrier.release()
        } else {
            barrier.release()
            try await f.settle()
            #expect(!f.model.canBeginNextSet)
            f.motion.isAccelerometerActive = false
            f.motion.isDeviceMotionActive = false
            f.practice.checkDeadlines()
        }
        try await f.wait { f.model.canBeginNextSet }
        #expect(f.model.snapshot?.state.isTerminal == true)
        #expect(f.session.endCount == 0)
        await f.finish()
    }

    @Test func admissionRechecksLiveSourceAfterContextPublicationAwait() async throws {
        let publication = OwnerLifecycleBarrier()
        var holdNext = false
        let f = try await OwnerLifecycleFixture(afterPublication: { _ in
            if holdNext { await publication.suspend() }
        })
        defer { publication.release() }
        try await f.beginAndRun(); try await f.startSet()
        f.model.stop(); try await f.wait { f.model.canBeginNextSet }
        f.model.newSet(); holdNext = true
        f.preparePhysical(); f.model.start()
        try await f.wait { publication.entered }
        let starts = f.motion.deviceMotionStarts
        f.motion.isDeviceMotionActive = true
        publication.release()
        try await f.settle()
        #expect(f.motion.deviceMotionStarts == starts)
        #expect(f.model.state != .recording)
        #expect(!f.model.canBeginNextSet)
        f.motion.isDeviceMotionActive = false
        await f.finish()
    }

    @Test func endingDuringHeldWriterAcknowledgementCannotAdmitAnotherSet() async throws {
        let barrier = OwnerLifecycleBarrier()
        let f = try await OwnerLifecycleFixture(beforeWriterDrain: { await barrier.suspend() })
        defer { barrier.release() }
        try await f.beginAndRun(); try await f.startSet()
        f.model.stop(); try await f.wait { barrier.entered }
        f.practice.end(); f.session.emit(.ended)
        #expect(!f.practice.canBeginPractice && !f.model.canBeginNextSet)
        barrier.release()
        try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
        #expect(!f.model.canBeginNextSet)
        #expect(f.motion.deviceMotionStarts == 1)
        await f.close()
    }

    @Test func replacementNeedsNativeEndedAndTimeoutKeepsResourcesBlocked() async throws {
        let f = try await OwnerLifecycleFixture()
        try await f.beginAndRun(); try await f.startSet()
        f.practice.end()
        try await f.wait { f.model.snapshot?.state.isTerminal == true }
        #expect(!f.practice.canBeginPractice && !f.driver.isClosed)
        f.driver.checkShutdownDeadlineForTesting()
        f.clock.advance(6); f.practice.checkDeadlines()
        #expect(!f.practice.canBeginPractice)
        f.practice.begin()
        #expect(f.workout.sessions.count == 1)
        f.session.emit(.ended)
        try await f.wait { f.driver.isClosed }
        #expect(f.motion.deviceMotionStarts == 1)
        await f.close()
    }

    @Test(arguments: [false, true])
    func contiguousHeartRateChangesCarryOnlyAlreadyAdmittedMotion(paused: Bool) async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun(); try await f.startSet()
        let metadata = try #require(f.model.capturedMetadata)
        let original = try await f.context(metadata.recordingID)
        if paused { f.model.pause(); f.session.emit(.paused); try await f.wait { f.model.state == .paused } }
        let before = try #require(f.owner.authority)
        let revoke = try OwnerAuthorityMutation.heartRate(from: before, allowed: false,
            decisionID: UUID(), confirmedAtUnixSeconds: f.clock.wall)
        try await f.mutate(revoke)
        #expect(f.heart.stopped.count == 1)
        #expect(f.owner.acceptedPreparation == nil && f.owner.nextPreparation == nil)
        let revoked = try #require(f.owner.authority)
        try await f.mutate(revoke) // Exact duplicate must not add another authority segment.
        let regrant = try OwnerAuthorityMutation.heartRate(from: revoked, allowed: true,
            decisionID: UUID(), confirmedAtUnixSeconds: f.clock.wall)
        try await f.mutate(regrant)
        try await f.settle()
        let carriedContext = try await f.context(metadata.recordingID)
        #expect(try original.encoded() == carriedContext.encoded())
        #expect(f.model.capturedMetadata == metadata)
        #expect(paused ? f.model.state == .paused : f.model.state == .recording)
        let telemetry = try await f.practice.telemetrySnapshot()
        #expect(telemetry.consentSegments.count == 3)
        #expect(telemetry.consentSegments[0].authority == before)
        #expect(telemetry.consentSegments[1].authority == revoked)
        #expect(telemetry.consentSegments[2].authority == f.owner.authority)
        if paused {
            let starts = f.motion.deviceMotionStarts
            f.model.resume(); f.session.emit(.running)
            try await f.wait { f.motion.deviceMotionStarts == starts + 1 }
            f.motion.emitPair(at: ProcessInfo.processInfo.systemUptime)
            try await f.wait { f.model.state == .recording }
        }
        let status = try await f.owner.receive(.statusRequest(requestID: UUID(), phoneEpoch: before.phoneInstallationEpoch))
        #expect(status != nil)
        if let status { _ = try OwnerPreparationCodec.encode(status) }
        await f.finish()
    }

    @Test func pendingCaptureGetsNoHeartRateOnlyCarryException() async throws {
        let publication = OwnerLifecycleBarrier()
        let f = try await OwnerLifecycleFixture(heartRate: true, afterPublication: { _ in await publication.suspend() })
        defer { publication.release() }
        try await f.beginAndRun()
        f.preparePhysical(); f.model.start()
        try await f.wait { publication.entered }
        try await f.changeHeartRate(false)
        publication.release(); try await f.settle()
        #expect(f.motion.deviceMotionStarts == 0)
        #expect(f.model.state != .recording)
        await f.finish()
    }

    @Test func finiteQueryUsesCurrentPracticeBoundsLocalDeviceAndOneInFlightPage() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun()
        let query = try #require(f.heart.queries.first)
        #expect(query.type == HKObjectType.quantityType(forIdentifier: .heartRate))
        #expect(query.limit == 256 && query.query.updateHandler == nil && query.anchor == nil)
        let header = try await f.practice.telemetrySnapshot().header
        let expected = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: Date(timeIntervalSince1970: header.clock.wallAnchorUnixSeconds),
                end: Date(timeIntervalSince1970: header.clock.wallAnchorUnixSeconds + 1800), options: .strictStartDate),
            HKQuery.predicateForObjects(from: [f.heart.localDevice])])
        #expect(query.predicate.isEqual(expected))
        for _ in 0..<20 { f.heartRate.wake() }
        #expect(f.heart.queries.count == 1)
        query.deliver([], 0, HKQueryAnchor(fromValue: 1), nil)
        try await f.settle()
        let telemetry = try await f.practice.telemetrySnapshot()
        #expect(telemetry.sampleRecords.isEmpty)
        #expect(f.practice.heartRateMessage == "No accessible heart-rate data")
        #expect(f.heart.queries.count <= 2)
        await f.finish()
    }

    @Test func fullPageAnchorAdvancesOnlyAfterActualTelemetryPublication() async throws {
        let publication = OwnerLifecycleBarrier()
        let f = try await OwnerLifecycleFixture(heartRate: true, beforeTelemetryPublication: { telemetry in
            if !telemetry.sampleRecords.isEmpty { await publication.suspend() }
        })
        defer { publication.release() }
        try await f.beginAndRun()
        let first = try #require(f.heart.queries.first)
        let samples = (0..<256).map { _ in f.heart.sample(at: f.clock.wall, watchEpoch: f.preparation.authority.watchInstallationEpoch) }
        let anchor = HKQueryAnchor(fromValue: 256)
        first.deliver(samples, 0, anchor, nil)
        try await f.wait { publication.entered }
        #expect(f.heart.queries.count == 1)
        let before = try await f.practice.telemetrySnapshot()
        #expect(before.sampleRecords.isEmpty)
        publication.release()
        try await f.wait { f.heart.queries.count == 2 }
        let persisted = try await f.practice.telemetrySnapshot()
        #expect(persisted.sampleRecords.count == 256)
        #expect(f.heart.queries[1].anchor?.isEqual(anchor) == true)
        #expect(f.heart.maximumInFlight == 1)
        await f.finish()
    }

    @Test func additionsPlusDeletionsAreBoundedBeforeNativeConversion() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun()
        let samples = (0..<256).map { _ in f.heart.sample(at: f.clock.wall, watchEpoch: f.preparation.authority.watchInstallationEpoch) }
        try #require(f.heart.queries.first).deliver(samples, 1, HKQueryAnchor(fromValue: 257), nil)
        try await f.settle()
        #expect(f.heart.readCount == 0)
        #expect(f.heart.queries.count == 1)
        let telemetry = try await f.practice.telemetrySnapshot()
        #expect(telemetry.sampleRecords.isEmpty)
        let refusals = telemetry.events.filter { $0.reason == .pageLimit }
        #expect(refusals.count == 1 && refusals.first?.count == 1)
        #expect(telemetry.exclusionCounts[.pageLimit] == 1)
        try await f.wait { f.session.endCount == 1 }
        #expect(!f.model.canStart && !f.model.canBeginNextSet && !f.practice.canBeginPractice)
        f.session.emit(.ended)
        try await f.wait { f.practice.state == .interrupted }
        let finalized = try await f.practice.telemetrySnapshot()
        #expect(finalized.finalization?.status == .interrupted)
        #expect(finalized.finalization?.absenceReasons.contains(.pageLimit) == true)
        #expect(finalized.finalization?.absenceReasons.contains(.interrupted) == true)
        await f.close()
    }

    @Test func nativeDeletionIsDurableAndInvalidatesRecoveryWithoutInventingRetractions() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun(); try await f.startSet()
        let metadata = try #require(f.model.capturedMetadata)
        let context = try await f.context(metadata.recordingID)
        let sample = f.heart.sample(at: f.clock.wall, watchEpoch: f.preparation.authority.watchInstallationEpoch)
        try #require(f.heart.queries.first).deliver([sample], 0, HKQueryAnchor(fromValue: 1), nil)
        try await f.wait { f.heart.readCount == 1 }
        f.model.stop(); try await f.wait { f.model.canBeginNextSet }
        let beforeDeletion = try await f.practice.telemetrySnapshot()
        let originalRecord = try #require(beforeDeletion.sampleRecords.first)
        f.heartRate.wake(); try await f.wait { f.heart.queries.count == 2 }
        try #require(f.heart.queries.last).deliver([], 1, HKQueryAnchor(fromValue: 2), nil)
        try await f.settle()
        let telemetry = try await f.practice.telemetrySnapshot()
        #expect(telemetry.sampleRecords.count == 1)
        #expect(telemetry.events.contains { $0.reason == .sourceDeleted && $0.count == 1 })
        #expect(telemetry.sampleRecords[0] == originalRecord && originalRecord.sample.id == sample.uuid)
        #expect(telemetry.incompleteReasons.contains(.sourceDeleted))
        let recovery = try OwnerRecoverySummary.calculate(telemetry: telemetry, recordingID: metadata.recordingID)
        #expect(recovery.coverage == .invalid)
        #expect(recovery.baseline.reason == .sourceDeleted && recovery.endReference.reason == .sourceDeleted)
        #expect(recovery.at60.reason == .sourceDeleted && recovery.at120.reason == .sourceDeleted)
        let retainedContext = try await f.context(metadata.recordingID)
        #expect(try retainedContext.encoded() == context.encoded())
        let queryCount = f.heart.queries.count
        f.heartRate.wake(); try await f.settle()
        #expect(f.heart.queries.count == queryCount, "A source deletion leaves finite paging interrupted")
        let bytes = try telemetry.encoded()
        #expect(!String(decoding: bytes, as: UTF8.self).contains("private-device-name"))
        #expect(!String(decoding: bytes, as: UTF8.self).contains("private-local-id"))
        await f.finish()
    }
    @Test func endDrainsEnteredPageAndLateDeliveryCannotChangeFinalizedTelemetry() async throws {
        let publication = OwnerLifecycleBarrier()
        let f = try await OwnerLifecycleFixture(heartRate: true, beforeTelemetryPublication: { telemetry in
            if !telemetry.sampleRecords.isEmpty && telemetry.finalization == nil { await publication.suspend() }
        })
        defer { publication.release() }
        try await f.beginAndRun()
        let query = try #require(f.heart.queries.first)
        let sample = f.heart.sample(at: f.clock.wall, watchEpoch: f.preparation.authority.watchInstallationEpoch)
        query.deliver([sample], 0, HKQueryAnchor(fromValue: 1), nil)
        try await f.wait { publication.entered }
        f.practice.end(); f.session.emit(.ended)
        #expect(f.practice.state == .ending && !f.practice.canBeginPractice)
        #expect(f.heart.stopped.count == 1)
        publication.release()
        try await f.wait { f.practice.state == .ended }
        let finalized = try await f.practice.telemetrySnapshot()
        #expect(finalized.sampleRecords.count == 1 && finalized.finalization != nil)
        let bytes = try finalized.encoded()
        query.deliver([sample], 0, HKQueryAnchor(fromValue: 2), nil)
        try await f.settle()
        #expect(try await f.practice.telemetrySnapshot().encoded() == bytes)
        await f.close()
    }

    @Test func practiceClockAndRecoveryDeadlinesDoNotResetAcrossSetsOrPauses() async throws {
        let f = try await OwnerLifecycleFixture()
        try await f.beginAndRun(); try await f.startSet()
        f.model.stop(); try await f.wait { f.model.canBeginNextSet }
        f.clock.advance(130); f.practice.checkDeadlines()
        #expect(f.session.pauseCount == 1)
        #expect(!f.model.canStart)
        f.session.emit(.paused)
        #expect(f.practice.state == .paused)
        f.practice.resume(); f.session.emit(.running)
        f.clock.advance(1670); f.practice.checkDeadlines()
        #expect(f.session.endCount == 1)
        #expect(!f.model.canStart && !f.model.canBeginNextSet)
        f.session.emit(.ended)
        try await f.wait { f.practice.state == .interrupted }
        let telemetry = try await f.practice.telemetrySnapshot()
        #expect(telemetry.finalization?.status == .interrupted)
        #expect(telemetry.finalization?.absenceReasons.contains(.durationLimit) == true)
        #expect(telemetry.finalization?.absenceReasons.contains(.interrupted) == true)
        await f.close()
    }


    @Test func twentySetsAreAllowedAndTheTwentyFirstNeverStartsAcquisition() async throws {
        let f = try await OwnerLifecycleFixture()
        try await f.beginAndRun()
        for index in 0..<20 {
            if index > 0 { f.model.newSet() }
            try await f.startSet()
            f.model.stop()
            try await f.wait { f.model.snapshot?.state.isTerminal == true && f.practice.state != .setClosing }
            if index < 19 { try #require(f.model.canBeginNextSet) }
        }
        let telemetry = try await f.practice.telemetrySnapshot()
        #expect(telemetry.sets.count == 20 && f.motion.deviceMotionStarts == 20)
        f.model.newSet(); f.preparePhysical(); f.model.start()
        try await f.settle()
        #expect(f.motion.deviceMotionStarts == 20 && !f.model.canStart)
        #expect(try await f.practice.telemetrySnapshot().sets.count == 20)
        await f.finish()
    }

    @Test func enteredHeartRatePublicationTimeoutRetainsBlockedResources() async throws {
        let barrier = OwnerLifecycleBarrier()
        let f = try await OwnerLifecycleFixture(heartRate: true, beforeTelemetryPublication: { value in
            if !value.sampleRecords.isEmpty && value.finalization == nil { await barrier.suspend() }
        })
        defer { barrier.release() }
        try await f.beginAndRun()
        let sample = f.heart.sample(at: f.clock.wall, watchEpoch: f.preparation.authority.watchInstallationEpoch)
        try #require(f.heart.queries.first).deliver([sample], 0, HKQueryAnchor(fromValue: 1), nil)
        try await f.wait { barrier.entered }
        f.practice.end(); f.session.emit(.ended)
        f.clock.advance(6) // End has frozen the cutoff; no active raw capture is time-shifted.
        f.practice.checkDeadlines()
        #expect(!f.practice.canBeginPractice)
        f.practice.begin(); #expect(f.workout.sessions.count == 1)
        barrier.release()
        try await f.wait { f.practice.state == .interrupted }
        let final = try await f.practice.telemetrySnapshot()
        #expect(final.finalization?.status == .interrupted)
        await f.close()
    }

    @Test func sourceRejectionsPersistAggregateReasonsWithoutPrivatePayload() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun()
        let epoch = f.preparation.authority.watchInstallationEpoch
        let entered = f.heart.sample(at: f.clock.wall, watchEpoch: epoch, userEntered: true)
        let missing = f.heart.sample(at: f.clock.wall, watchEpoch: epoch, provenance: false)
        let foreign = f.heart.sample(at: f.clock.wall, watchEpoch: epoch, local: false)
        try #require(f.heart.queries.first).deliver([entered, missing, foreign], 0, HKQueryAnchor(fromValue: 3), nil)
        try await f.wait { f.heart.readCount == 3 && f.heartRate.pendingCallbacks == 0 }
        let telemetry = try await f.practice.telemetrySnapshot()
        #expect(telemetry.sampleRecords.isEmpty)
        for reason in [OwnerTelemetryReason.userEntered, .missingProvenance, .mismatchedProvenance] {
            #expect(telemetry.events.contains { $0.reason == reason && $0.count == 1 })
        }
        let text = String(decoding: try telemetry.encoded(), as: UTF8.self)
        #expect(!text.contains(entered.uuid.uuidString) && !text.contains(missing.uuid.uuidString))
        #expect(!text.contains("private-device-name") && !text.contains("private-local-id"))
        await f.finish()
    }

    @Test(arguments: [false, true])
    func skippedOrNonHeartRateAuthorityNeverCarriesAdmittedMotion(skipped: Bool) async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun(); try await f.startSet()
        let metadata = try #require(f.model.capturedMetadata)
        let context = try await f.context(metadata.recordingID)
        let before = try #require(f.owner.authority)
        if skipped {
            let revoke = try OwnerAuthorityMutation.heartRate(from: before, allowed: false,
                decisionID: UUID(), confirmedAtUnixSeconds: f.clock.wall)
            let unseen = try revoke.resolve(from: before)
            let gap = try OwnerAuthorityMutation.heartRate(from: unseen, allowed: true,
                decisionID: UUID(), confirmedAtUnixSeconds: f.clock.wall)
            var rejected = false
            do { try await f.mutate(gap) } catch { rejected = true }
            #expect(rejected)
        } else {
            try await f.mutate(.advance(from: before, mutationID: UUID()))
        }
        try await f.wait { f.model.snapshot?.state.isTerminal == true }
        #expect(!f.motion.isAccelerometerActive && !f.motion.isDeviceMotionActive)
        #expect(!f.model.canStart && !f.model.canBeginNextSet)
        let retained = try await f.context(metadata.recordingID)
        #expect(try retained.encoded() == context.encoded())
        await f.finish()
    }

    @Test func failedDurableAuthorityPublicationCannotCarryOrResumeMotion() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun(); try await f.startSet()
        let metadata = try #require(f.model.capturedMetadata)
        let context = try await f.context(metadata.recordingID)
        let telemetry = try await f.practice.telemetrySnapshot()
        let base = try #require(f.services.environment.base)
        let path = base.appendingPathComponent(OwnerTelemetryStore.directoryName)
            .appendingPathComponent(telemetry.header.practiceID.uuidString.lowercased()).appendingPathComponent("telemetry.json")
        let original = try Data(contentsOf: path)
        try original.write(to: path.appendingPathExtension("before-O7-fault"))
        try Data("isolated telemetry publication fault".utf8).write(to: path)
        do { try await f.changeHeartRate(false) } catch { /* Fail-closed receipt is allowed. */ }
        try await f.wait { f.model.snapshot?.state.isTerminal == true }
        #expect(!f.model.canStart && !f.model.canBeginNextSet)
        #expect(!f.motion.isAccelerometerActive && !f.motion.isDeviceMotionActive)
        let retained = try await f.context(metadata.recordingID)
        #expect(try retained.encoded() == context.encoded())
        await f.finish()
    }

    @Test func optionalHeartRateAuthorizationFailureDoesNotRequestOrInventSamples() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        f.practice.begin(); try await f.makeWorkoutRunning()
        try await f.wait { !f.heart.requests.isEmpty }
        try #require(f.heart.requests.last).completion("Synthetic Health authorization request failed")
        try await f.startSet()
        #expect(f.heart.queries.isEmpty && f.model.state == .recording)
        #expect(try await f.practice.telemetrySnapshot().sampleRecords.isEmpty)
        await f.finish()
    }

    @Test func queryFailureStopsPagingAndPreservesExplicitMissingEvidence() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun()
        try #require(f.heart.queries.first).deliver(nil, 0, nil, "Synthetic native query failure")
        try await f.settle()
        f.heartRate.wake(); try await f.settle()
        #expect(f.heart.queries.count == 1)
        let telemetry = try await f.practice.telemetrySnapshot()
        #expect(telemetry.sampleRecords.isEmpty)
        #expect(telemetry.events.contains { $0.reason == .sourceError })
        await f.finish()
    }

    @Test func oldPracticeCallbacksCannotBeRelabeledIntoAReplacementPractice() async throws {
        let f = try await OwnerLifecycleFixture(heartRate: true)
        try await f.beginAndRun()
        let oldQuery = try #require(f.heart.queries.first), oldSession = f.session
        let oldID = try await f.practice.telemetrySnapshot().header.practiceID
        f.practice.end(); oldSession.emit(.ended)
        try await f.wait { f.practice.state == .ended }
        let oldBytes = try await f.practice.telemetrySnapshot().encoded()
        let replacement = try await f.acceptReplacementPractice()
        f.practice.begin(); try await f.makeWorkoutRunning()
        oldSession.emit(.running); oldSession.emit(.paused); oldSession.emit(.ended)
        oldQuery.deliver([], 1, HKQueryAnchor(fromValue: 7), nil)
        try await f.settle()
        let current = try await f.practice.telemetrySnapshot()
        #expect(current.header.practiceID == replacement.practiceID && current.header.practiceID != oldID)
        #expect(current.sampleRecords.isEmpty && !current.incompleteReasons.contains(.sourceDeleted))
        #expect(f.session.id != oldSession.id && f.session.endCount == 0)
        let base = try #require(f.services.environment.base)
        let saved = try Data(contentsOf: base.appendingPathComponent(OwnerTelemetryStore.directoryName)
            .appendingPathComponent(oldID.uuidString.lowercased()).appendingPathComponent("telemetry.json"))
        #expect(saved == oldBytes)
        await f.finish()
    }

    @Test(arguments: OwnerLifecycleInjection.allCases, [false, true])
    func plannedInjectionsFailClosedWithoutACoherentFixture(injection: OwnerLifecycleInjection, missingFixtureID: Bool) async throws {
        try requireOwnerLifecycleHost()
        let isolated = try WatchRuntimeEnvironment.resolve(arguments: ["--owner-watch-fixture=\(UUID().uuidString)"], environment: [:])
        // Keep every attempted construction in temporary storage with native hardware disabled.
        // The missing or mismatched ID must still reject every fixture-only injection.
        let invalid = WatchRuntimeEnvironment(fixtureID: missingFixtureID ? nil : UUID(),
            base: isolated.base, preferenceSuite: isolated.preferenceSuite, allowsHardware: false, failure: nil)
        let backend = OwnerLifecycleWorkoutBackend()
        let driver = WatchWorkoutDriver(backend: backend, environment: isolated)
        let hardware = OwnerLifecycleHeartHardware()
        let heartRate = try OwnerHeartRateSource(hardware: hardware, environment: isolated)
        let clock = OwnerLifecycleClock()
        var clockCalls = 0, publicationCalls = 0, writerDrainCalls = 0
        let services: WatchRecordingServices
        var model: WatchRecorderModel?
        var controlModel: WatchRecorderModel?
        switch injection {
        case .workout:
            services = WatchRecordingServices(environment: invalid, workout: driver)
        case .heartRate:
            services = WatchRecordingServices(environment: invalid, heartRate: heartRate)
        case .practiceClock:
            services = WatchRecordingServices(environment: invalid, practiceClock: {
                clockCalls += 1; return try clock.now
            })
        case .telemetryPublication:
            services = WatchRecordingServices(environment: invalid, beforeTelemetryPublication: { _ in
                publicationCalls += 1
            })
        case .writerDrain:
            services = WatchRecordingServices(environment: invalid)
            controlModel = WatchRecorderModel(services: services)
            model = WatchRecorderModel(services: services, beforeWriterDrain: { writerDrainCalls += 1 })
        }
        if let model {
            model.beginPreparation(); model.confirmPlacement(); model.confirmOrientation(); model.confirmFit()
            model.start(); model.stop()
        } else {
            services.practice?.begin()
        }
        for _ in 0..<500 {
            if let model {
                if model.initializationIssue == .untrustedInjectedDependencies { break }
            } else if services.storageError?.isEmpty == false { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        if let model {
            #expect(model.initializationIssue == .untrustedInjectedDependencies)
            let control = try #require(controlModel)
            #expect(control.initializationIssue != .untrustedInjectedDependencies)
            #expect(!model.canStart && !model.canBeginNextSet && model.state != .recording)
            #expect(model.snapshot == nil && model.capturedMetadata == nil)
        } else {
            #expect(services.storageError?.isEmpty == false, "The actual services must expose their rejected injection")
            #expect(services.practice?.canBeginPractice != true)
        }
        #expect(!services.environment.allowsHardware && services.connectivity == nil)
        #expect(clockCalls == 0 && publicationCalls == 0 && writerDrainCalls == 0)
        #expect(backend.authorizations.isEmpty && backend.sessions.isEmpty && driver.isClosed)
        #expect(hardware.requests.isEmpty && hardware.queries.isEmpty)
        await services.practice?.closeForTesting()
        await services.coordinator?.closeForTesting()
    }

    @Test func injectedDependenciesAreRejectedOutsideACoherentIsolatedFixture() throws {
        try requireOwnerLifecycleHost()
        let environment = try WatchRuntimeEnvironment.resolve(arguments: [], environment: [:])
        let hardware = OwnerLifecycleHeartHardware()
        #expect(throws: OwnerCaptureFailure.self) { _ = try OwnerHeartRateSource(hardware: hardware, environment: environment) }
        #expect(hardware.requests.isEmpty && hardware.queries.isEmpty)
    }
}

enum OwnerLifecycleInjection: CaseIterable, Sendable {
    case workout, heartRate, practiceClock, telemetryPublication, writerDrain
}

@MainActor
final class OwnerLifecycleClock {
    private(set) var offset = 0.0
    var wall: Double { Date().timeIntervalSince1970 + offset }
    var monotonic: Double { ProcessInfo.processInfo.systemUptime + offset }
    private var frozen: OwnerTelemetryInstant?
    private var queued: [OwnerTelemetryInstant] = []
    var now: OwnerTelemetryInstant {
        get throws {
            if !queued.isEmpty { return queued.removeFirst() }
            return try frozen ?? .init(wallUnixSeconds: wall, monotonicSeconds: monotonic)
        }
    }
    // Called only after the actual raw writer has stopped and drained.
    func freeze(first: OwnerTelemetryInstant, then last: OwnerTelemetryInstant) {
        queued = [first]; frozen = last
    }
    // Only called after real raw stop/drain, or before a baseline-only End.
    func freeze(wallShift: Double) throws -> OwnerTelemetryInstant {
        let value = try OwnerTelemetryInstant(wallUnixSeconds: wall + wallShift, monotonicSeconds: monotonic)
        frozen = value
        return value
    }
    // Offset changes are used only after actual raw stop/drain, never during capture.
    func advance(_ seconds: Double) { offset += seconds }
}

@MainActor
final class OwnerLifecycleBarrier {
    private(set) var entered = false
    private var released = false
    private var continuations: [CheckedContinuation<Void, Never>] = []
    func suspend() async {
        entered = true
        if released { return }
        await withCheckedContinuation { continuations.append($0) }
    }
    func release() { released = true; let pending = continuations; continuations = []; pending.forEach { $0.resume() } }
}

@MainActor
final class OwnerLifecycleWorkoutBackend: WatchWorkoutBackend {
    var authorizations: [@MainActor (String?) -> Void] = []
    var sessions: [OwnerLifecycleWorkoutSession] = []
    func authorize(_ completion: @escaping @MainActor (String?) -> Void) { authorizations.append(completion) }
    func makeSession() throws -> any WatchWorkoutSessionHandle {
        let value = OwnerLifecycleWorkoutSession(); sessions.append(value); return value
    }
}

@MainActor
final class OwnerLifecycleWorkoutSession: WatchWorkoutSessionHandle {
    let id = UUID()
    var onState: ((WatchWorkoutDriver.Kind) -> Void)?
    var startCount = 0, pauseCount = 0, resumeCount = 0, endCount = 0
    func start() { startCount += 1 }
    func pause() { pauseCount += 1 }
    func resume() { resumeCount += 1 }
    func end() { endCount += 1 }
    func emit(_ kind: WatchWorkoutDriver.Kind) { onState?(kind) }
}

@MainActor
final class OwnerLifecycleMotionHardware: WatchMotionHardware {
    struct Start {
        let acceleration: @Sendable ([CMAccelerometerData]?, (any Error)?) -> Void
        let motion: @Sendable ([CMDeviceMotion]?, (any Error)?) -> Void
    }
    var isAccelerometerSupported = true, isDeviceMotionSupported = true
    var authorizationStatus: CMAuthorizationStatus = .authorized
    var accelerometerDataFrequency = 800, deviceMotionDataFrequency = 200
    var isAccelerometerActive = false, isDeviceMotionActive = false
    var clearFlagsOnStop = true
    var accelerometerStarts = 0, deviceMotionStarts = 0, stopCount = 0, startAttempts = 0
    var startFailure: String?
    var authorizations: [@MainActor (String?) -> Void] = []
    var starts: [Start] = []
    var accelerometerHandlers: [@Sendable ([CMAccelerometerData]?, (any Error)?) -> Void] = []
    var motionHandlers: [@Sendable ([CMDeviceMotion]?, (any Error)?) -> Void] = []
    var running: Bool { isAccelerometerActive && isDeviceMotionActive }
    func startAccelerometerUpdates(handler: @escaping @Sendable ([CMAccelerometerData]?, (any Error)?) -> Void) {
        accelerometerStarts += 1; isAccelerometerActive = true
        if authorizationStatus == .notDetermined {
            authorizations.append { [weak self] error in
                self?.authorizationStatus = error == nil ? .authorized : .denied
                handler(nil, error.map { NSError(domain: "O7.Motion", code: 1, userInfo: [NSLocalizedDescriptionKey: $0]) })
            }
            return
        }
        startAttempts += 1
        if let startFailure {
            isAccelerometerActive = false
            handler(nil, NSError(domain: "O7.Motion", code: 2, userInfo: [NSLocalizedDescriptionKey: startFailure]))
            return
        }
        accelerometerHandlers.append(handler)
    }
    func startDeviceMotionUpdates(handler: @escaping @Sendable ([CMDeviceMotion]?, (any Error)?) -> Void) {
        deviceMotionStarts += 1
        guard startFailure == nil, let acceleration = accelerometerHandlers.last else { return }
        isDeviceMotionActive = true; motionHandlers.append(handler)
        starts.append(.init(acceleration: acceleration, motion: handler))
    }
    func stopAccelerometerUpdates() { stopCount += 1; if clearFlagsOnStop { isAccelerometerActive = false } }
    func stopDeviceMotionUpdates() { stopCount += 1; if clearFlagsOnStop { isDeviceMotionActive = false } }
    func emitPair(at timestamp: Double) {
        guard let start = starts.last else { Issue.record("No admitted native handlers to deliver to"); return }
        deliver(start, at: timestamp)
    }
    func emitPair(using supplied: Start) { deliver(supplied, at: ProcessInfo.processInfo.systemUptime) }
    private func deliver(_ start: Start, at timestamp: Double) {
        let acceleration = OwnerLifecycleAcceleration(); acceleration.fixtureTimestamp = timestamp
        let motion = OwnerLifecycleDeviceMotion(); motion.fixtureTimestamp = timestamp
        start.acceleration([acceleration], nil); start.motion([motion], nil)
    }
}

nonisolated private final class OwnerLifecycleAcceleration: CMAccelerometerData, @unchecked Sendable {
    var fixtureTimestamp = 0.0
    override var timestamp: TimeInterval { fixtureTimestamp }
    override var acceleration: CMAcceleration { .init(x: 0.1, y: 0.2, z: 0.3) }
}
nonisolated private final class OwnerLifecycleAttitude: CMAttitude, @unchecked Sendable {
    override var quaternion: CMQuaternion { .init(x: 0, y: 0, z: 0, w: 1) }
}
nonisolated private final class OwnerLifecycleDeviceMotion: CMDeviceMotion, @unchecked Sendable {
    var fixtureTimestamp = 0.0
    override var timestamp: TimeInterval { fixtureTimestamp }
    override var attitude: CMAttitude { OwnerLifecycleAttitude() }
    override var rotationRate: CMRotationRate { .init(x: 0.2, y: 0.3, z: 0.4) }
    override var gravity: CMAcceleration { .init(x: 0, y: 0, z: -1) }
    override var userAcceleration: CMAcceleration { .init(x: 0.1, y: 0.2, z: 0.3) }
}

@MainActor
final class OwnerLifecycleHeartHardware: OwnerHeartRateHardware {
    struct Authorization {
        let share: Set<HKSampleType>, read: Set<HKObjectType>
        let completion: @MainActor (String?) -> Void
    }
    struct Query {
        let query: HKAnchoredObjectQuery
        let type: HKQuantityType, predicate: NSPredicate, anchor: HKQueryAnchor?, limit: Int
        let deliver: @MainActor ([HKSample]?, Int, HKQueryAnchor?, String?) -> Void
    }
    let localDevice = HKDevice(name: "private-device-name", manufacturer: "Apple", model: "Watch",
        hardwareVersion: "Watch7,5", firmwareVersion: "1", softwareVersion: "27.0",
        localIdentifier: "private-local-id", udiDeviceIdentifier: nil)
    var requests: [Authorization] = []
    var queries: [Query] = []
    var stopped: [HKAnchoredObjectQuery] = []
    var readings: [UUID: OwnerHeartRateNativeReading] = [:]
    var readCount = 0
    var activeQueries: Set<ObjectIdentifier> = []
    var maximumInFlight = 0
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>,
                              completion: @escaping @MainActor (String?) -> Void) {
        requests.append(.init(share: toShare, read: read, completion: completion))
    }
    func makeQuery(type: HKQuantityType, predicate: NSPredicate, anchor: HKQueryAnchor?, limit: Int,
                   handler: @escaping @Sendable ([HKSample]?, Int, HKQueryAnchor?, String?) -> Void) -> HKAnchoredObjectQuery {
        let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: anchor, limit: limit) { _, _, _, _, _ in }
        queries.append(.init(query: query, type: type, predicate: predicate, anchor: anchor, limit: limit, deliver: { [weak self] samples, deleted, next, error in
            self?.activeQueries.remove(ObjectIdentifier(query))
            handler(samples, deleted, next, error)
        }))
        return query
    }
    func execute(_ query: HKAnchoredObjectQuery) {
        activeQueries.insert(ObjectIdentifier(query)); maximumInFlight = max(maximumInFlight, activeQueries.count)
    }
    func stop(_ query: HKAnchoredObjectQuery) {
        stopped.append(query); activeQueries.remove(ObjectIdentifier(query))
    }
    func read(_ sample: HKQuantitySample, watchInstallationEpoch: UUID) -> OwnerHeartRateNativeReading {
        readCount += 1
        return readings[sample.uuid]!
    }
    func sample(at wall: Double, watchEpoch: UUID, bpm: Double = 100, userEntered: Bool = false,
                local: Bool = true, provenance: Bool = true) -> HKQuantitySample {
        let value = HKQuantitySample(type: HKObjectType.quantityType(forIdentifier: .heartRate)!,
            quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: bpm),
            start: Date(timeIntervalSince1970: wall), end: Date(timeIntervalSince1970: wall), device: localDevice,
            metadata: userEntered ? [HKMetadataKeyWasUserEntered: true] : nil)
        let machine = try! OwnerHeartRateProvenance(sourceBundleIdentifier: "com.apple.health", sourceVersion: "1",
            operatingSystem: "27.0", productType: "Watch7,5", manufacturer: "Apple", model: "Watch",
            hardwareVersion: "Watch7,5", softwareVersion: "27.0", watchInstallationEpoch: watchEpoch)
        readings[value.uuid] = OwnerHeartRateNativeReading(id: value.uuid, start: value.startDate, end: value.endDate,
            bpm: bpm, provenance: provenance ? machine : nil, isLocalDevice: local, isUserEntered: userEntered)
        return value
    }
}

@MainActor
final class OwnerLifecycleFixture {
    let services: WatchRecordingServices
    let owner: OwnerCaptureCoordinator
    let practice: OwnerPracticeCoordinator
    private(set) var preparation: OwnerPreparation
    let workout: OwnerLifecycleWorkoutBackend
    let driver: WatchWorkoutDriver
    let heart: OwnerLifecycleHeartHardware
    let heartRate: OwnerHeartRateSource
    let motion: OwnerLifecycleMotionHardware
    let model: WatchRecorderModel
    let clock: OwnerLifecycleClock
    var session: OwnerLifecycleWorkoutSession { workout.sessions.last! }

    init(heartRate includesHeartRate: Bool = false, drill: RecordingDrill = .forehandGroundstroke,
         injectMotion: Bool = true, injectWorkout: Bool = true,
         afterPublication: (@MainActor (OwnerContextPublication) async -> Void)? = nil,
         beforeWriterDrain: (@MainActor () async -> Void)? = nil,
         beforeTelemetryPublication: (@MainActor (OwnerPracticeTelemetry) async throws -> Void)? = nil) async throws {
        try requireOwnerLifecycleHost()
        let environment = try WatchRuntimeEnvironment.resolve(arguments: ["--owner-watch-fixture=\(UUID().uuidString)"], environment: [:])
        let clock = OwnerLifecycleClock(), workout = OwnerLifecycleWorkoutBackend()
        let driver = WatchWorkoutDriver(backend: workout, allowsHardware: false)
        let heart = OwnerLifecycleHeartHardware()
        let heartRate = try OwnerHeartRateSource(hardware: heart, environment: environment)
        let services = WatchRecordingServices(environment: environment, afterPublication: afterPublication,
            workout: injectWorkout ? driver : nil, heartRate: heartRate, practiceClock: { try clock.now },
            beforeTelemetryPublication: beforeTelemetryPublication)
        let owner = try #require(services.coordinator)
        try await owner.load()
        let authority = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: UUID(),
            watchInstallationEpoch: try #require(owner.watchEpoch), attestsWatchAccountOwner: true,
            acceptsMotionStudy: true, includesHeartRate: includesHeartRate, decisionID: UUID(),
            confirmedAtUnixSeconds: clock.wall, policyDigest: OwnerPracticePolicy.digest)
        _ = try await owner.receive(.mutate(requestID: UUID(), generations: owner.generations, mutation: .enrollment(authority)))
        let draft = try PracticeSetupDraft(originInstallationEpoch: authority.phoneInstallationEpoch,
            preparationID: UUID(), revision: 1, preferences: .init(currentRacketArm: .right, usualHand: .right,
                                                                  intendedDrill: drill))
        let preparation = try OwnerPreparation(authority: authority, practiceID: UUID(), draft: draft)
        let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: owner.generations, preparation: preparation.identity)
        _ = try await owner.receive(.prepare(correlation: correlation, preparation: preparation))
        let motion = OwnerLifecycleMotionHardware()
        let source = try WatchMotionSource(hardware: motion, environment: environment)
        let model = WatchRecorderModel(preparationSettingsProvider: {
            .init(wrist: .right, crownDescription: "Crown right", unavailableReason: nil, frequencyDescription: "Injected native motion")
        }, services: services, motionSource: injectMotion ? source : nil, beforeWriterDrain: beforeWriterDrain, storageValidation: { nil })
        self.services = services; self.owner = owner; self.preparation = preparation
        self.practice = try #require(services.practice)
        self.workout = workout; self.driver = driver; self.heart = heart; self.heartRate = heartRate
        self.motion = motion; self.model = model; self.clock = clock
    }
    func preparePhysical() {
        model.beginPreparation(); model.confirmPlacement(); model.confirmOrientation(); model.confirmFit()
    }
    private var completedWorkoutAuthorizations = 0
    private var startedWorkoutSessions = 0
    func makeWorkoutRunning() async throws {
        try await wait { workout.authorizations.count > completedWorkoutAuthorizations }
        let authorization = workout.authorizations[completedWorkoutAuthorizations]
        completedWorkoutAuthorizations += 1
        authorization(nil)
        try await wait { workout.sessions.count > startedWorkoutSessions }
        let session = workout.sessions[startedWorkoutSessions]
        startedWorkoutSessions += 1
        session.emit(.running)
        try await wait { practice.state == .baseline }
    }
    func beginAndRun() async throws {
        practice.begin(); try await makeWorkoutRunning()
        if preparation.authority.heartRateConsent {
            try await wait { !heart.requests.isEmpty }
            try #require(heart.requests.last).completion(nil)
            try await wait { heart.queries.count == 1 }
        }
    }
    func startSet() async throws {
        preparePhysical(); try #require(model.canStart)
        let previous = motion.deviceMotionStarts
        model.start()
        try await wait { motion.deviceMotionStarts > previous }
        let metadata = try #require(model.capturedMetadata)
        _ = metadata
        motion.emitPair(at: ProcessInfo.processInfo.systemUptime)
        try await wait { model.state == .recording }
    }
    func context(_ recordingID: UUID) async throws -> OwnerRecordingContext {
        guard case let .valid(context) = try await owner.inspectContext(recordingID: recordingID) else {
            Issue.record("Expected a durably valid immutable recording context")
            throw OwnerCaptureFailure.unavailable
        }
        return context
    }
    func acceptReplacementPractice() async throws -> OwnerPreparation {
        let authority = try #require(owner.authority)
        let draft = try PracticeSetupDraft(originInstallationEpoch: authority.phoneInstallationEpoch,
            preparationID: UUID(), revision: preparation.draft.identity.revision + 1, preferences: .init(currentRacketArm: .right, usualHand: .right,
                                                                  intendedDrill: .backhandGroundstroke))
        let value = try OwnerPreparation(authority: authority, practiceID: UUID(), draft: draft)
        let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: owner.generations, preparation: value.identity)
        _ = try await owner.receive(.prepare(correlation: correlation, preparation: value))
        preparation = value
        return value
    }
    func mutate(_ mutation: OwnerAuthorityMutation) async throws {
        _ = try await owner.receive(.mutate(requestID: UUID(), generations: owner.generations, mutation: mutation))
    }
    func changeHeartRate(_ allowed: Bool) async throws {
        try await mutate(.heartRate(from: try #require(owner.authority), allowed: allowed,
                                   decisionID: UUID(), confirmedAtUnixSeconds: clock.wall))
    }
    func wait(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<500 { if condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
        try #require(condition(), "Actual lifecycle did not reach its required state within five seconds")
    }
    func settle() async throws { try await Task.sleep(for: .milliseconds(50)) }
    func finish() async {
        motion.isAccelerometerActive = false; motion.isDeviceMotionActive = false
        practice.end(); workout.sessions.last?.emit(.ended)
        try? await wait { practice.state == .ended || practice.state == .interrupted }
        await close()
    }
    func close() async { await practice.closeForTesting(); await owner.closeForTesting() }
}

@MainActor
private func requireOwnerLifecycleHost() throws {
    let host = WatchRuntimeEnvironment.current
    try #require(host.fixtureID != nil && !host.allowsHardware && host.failure == nil,
                 "Use the existing UUID-isolated Watch app-host launch pipeline")
}
