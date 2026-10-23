import Foundation
import HealthKit
import Testing
@testable import PadelCore
@testable import PadelStrokeLab_Watch_App

// O9p tests the actual accepted O7 resources. No deletion row, paired command,
// fake closure callback, default store or native Health data is used.
@Suite(.serialized) @MainActor struct OwnerPracticeDeletionPrerequisiteTests {
    @Test func releaseWaitsForNativeWriterAndFinalPublicationBeforeClosingTelemetry() async throws {
        let writer = OwnerLifecycleBarrier(), publication = OwnerLifecycleBarrier()
        let f = try await OwnerLifecycleFixture(heartRate: true,
            beforeWriterDrain: { await writer.suspend() },
            beforeTelemetryPublication: { if $0.finalization != nil { await publication.suspend() } })
        do {
            try await f.beginAndRun(); try await f.startSet()
            let original = try await f.practice.telemetrySnapshot(), base = try #require(f.services.environment.base)
            let result = O9PCompletion()
            let pending = Task { @MainActor in
                do { try await f.practice.prepareForDeletion(practiceID: original.header.practiceID); result.succeed() }
                catch { result.fail(error) }
            }
            try await f.wait { writer.entered && f.session.endCount == 1 }
            #expect(!result.finished && !f.driver.isClosed && !f.model.canStart)
            f.driver.checkShutdownDeadlineForTesting()
            #expect(!result.finished, "A deadline is not native closure or writer drain")
            f.session.emit(.ended)
            #expect(!result.finished)
            #expect(throws: (any Error).self) {
                _ = try OwnerTelemetryStore.open(base: base, practiceID: original.header.practiceID, expectedHeader: original.header)
            }
            writer.release()
            try await f.wait { publication.entered }
            #expect(!result.finished && f.model.snapshot?.state.isTerminal == true)
            #expect(f.heartRate.pendingCallbacks == 0 && !f.motion.isAccelerometerActive && !f.motion.isDeviceMotionActive)
            #expect(throws: (any Error).self) {
                _ = try OwnerTelemetryStore.open(base: base, practiceID: original.header.practiceID, expectedHeader: original.header)
            }
            publication.release(); await pending.value
            #expect(result.finished && result.error == nil)
            let reopened = try OwnerTelemetryStore.open(base: base, practiceID: original.header.practiceID, expectedHeader: original.header)
            #expect(reopened.snapshot.finalization != nil)
            reopened.close()
        } catch { writer.release(); publication.release(); await f.close(); throw error }
        writer.release(); publication.release(); await f.close()
    }

    @Test func enteredHeartRateCallbackMustDrainAndCancelledRequestCannotClaimRelease() async throws {
        let page = OwnerLifecycleBarrier()
        let f = try await OwnerLifecycleFixture(heartRate: true,
            beforeTelemetryPublication: { if !$0.sampleRecords.isEmpty && $0.finalization == nil { await page.suspend() } })
        do {
            try await f.beginAndRun()
            let original = try await f.practice.telemetrySnapshot(), base = try #require(f.services.environment.base)
            let query = try #require(f.heart.queries.first)
            let sample = f.heart.sample(at: f.clock.wall, watchEpoch: f.preparation.authority.watchInstallationEpoch)
            query.deliver([sample], 0, HKQueryAnchor(fromValue: 1), nil)
            try await f.wait { page.entered }
            try #require(f.heartRate.pendingCallbacks > 0)
            let result = O9PCompletion()
            let pending = Task { @MainActor in
                do { try await f.practice.prepareForDeletion(practiceID: original.header.practiceID); result.succeed() }
                catch { result.fail(error) }
            }
            try await f.wait { f.session.endCount == 1 }
            f.session.emit(.ended)
            #expect(!result.finished && f.heartRate.pendingCallbacks > 0)
            #expect(throws: (any Error).self) {
                _ = try OwnerTelemetryStore.open(base: base, practiceID: original.header.practiceID, expectedHeader: original.header)
            }
            pending.cancel()
            page.release(); await pending.value
            #expect(result.error != nil, "Cancelled deletion preparation must not report successful resource release")
            // A fresh explicit retry observes real closure and releases the actual telemetry owner.
            try await f.practice.prepareForDeletion(practiceID: original.header.practiceID)
            let reopened = try OwnerTelemetryStore.open(base: base, practiceID: original.header.practiceID, expectedHeader: original.header)
            let bytes = try reopened.snapshot.encoded(); reopened.close()
            query.deliver([sample], 0, HKQueryAnchor(fromValue: 2), nil)
            try await f.settle()
            let after = try OwnerTelemetryStore.open(base: base, practiceID: original.header.practiceID, expectedHeader: original.header)
            #expect(try after.snapshot.encoded() == bytes)
            after.close()
        } catch { page.release(); await f.close(); throw error }
        page.release(); await f.close()
    }

    @Test func historicalTargetNeverStopsOrReleasesAnUnrelatedCurrentPractice() async throws {
        let f = try await OwnerLifecycleFixture()
        do {
            try await f.beginAndRun()
            let historical = try await f.practice.telemetrySnapshot()
            f.practice.end(); f.session.emit(.ended)
            try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
            _ = try await f.acceptReplacementPractice()
            try await f.beginAndRun()
            let current = try await f.practice.telemetrySnapshot(), base = try #require(f.services.environment.base)
            try #require(current.header.practiceID != historical.header.practiceID)
            let session = f.session, endCount = session.endCount
            try await f.practice.prepareForDeletion(practiceID: historical.header.practiceID)
            #expect(session.endCount == endCount && !f.driver.isClosed && f.practice.state == .baseline)
            #expect(f.practice.currentPracticeID == current.header.practiceID)
            let stillCurrent = try await f.practice.telemetrySnapshot()
            #expect(stillCurrent.header == current.header && stillCurrent.finalization == nil)
            #expect(throws: (any Error).self) {
                _ = try OwnerTelemetryStore.open(base: base, practiceID: current.header.practiceID, expectedHeader: current.header)
            }
            let old = try OwnerTelemetryStore.open(base: base, practiceID: historical.header.practiceID, expectedHeader: historical.header)
            #expect(old.snapshot.finalization != nil); old.close()
        } catch { await f.finish(); throw error }
        await f.finish()
    }

    @Test(arguments: ["completed", "pending", "missing"])
    func recoverySkipsOnlyCheckedCompletedDeletionAndKeepsReservedIdentity(proofState: String) async throws {
        let f = try await OwnerLifecycleFixture()
        do {
            try await f.beginAndRun()
            let original = try await f.practice.telemetrySnapshot(), base = try #require(f.services.environment.base)
            f.practice.end(); f.session.emit(.ended)
            try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
            try await f.practice.prepareForDeletion(practiceID: original.header.practiceID)
            let completedStore = try OwnerTelemetryStore.open(base: base, practiceID: original.header.practiceID, expectedHeader: original.header)
            let finalized = completedStore.snapshot; completedStore.close()
            let proof = try OwnerPracticeDeletionProof.prepare(base: base, header: original.header, operationID: UUID())
            defer { proof.cancel() }
            let directory = base.appendingPathComponent(OwnerTelemetryStore.directoryName)
                .appendingPathComponent(original.header.practiceID.uuidString.lowercased())
            // Simulates later O9 payload cleanup, only after real O7 resources released.
            for name in ["header.json", "telemetry.json", "manifest.json", ".lock"] {
                try FileManager.default.removeItem(at: directory.appendingPathComponent(name))
            }
            if proofState == "completed" { try proof.complete() }
            if proofState == "missing" {
                proof.cancel()
                let file = base.appendingPathComponent(OwnerPracticeDeletionProof.directoryName)
                    .appendingPathComponent(original.header.practiceID.uuidString.lowercased() + ".json")
                try FileManager.default.removeItem(at: file)
            }
            var visited: [UUID] = []
            if proofState == "completed" {
                try OwnerPracticeRecoveryReader.forEachCandidate(base: base) { visited.append($0.header.practiceID) }
                #expect(visited.isEmpty)
                // Fresh retained services perform actual recovery, with the same owner bootstrap.
                await f.close()
                let restarted = WatchRecordingServices(environment: f.services.environment,
                    workout: WatchWorkoutDriver(backend: OwnerLifecycleWorkoutBackend(), allowsHardware: false))
                let owner = try #require(restarted.coordinator)
                try await owner.load()
                #expect(owner.lastError == nil)
                await restarted.practice?.closeForTesting(); await owner.closeForTesting()
                #expect(throws: (any Error).self) { _ = try OwnerTelemetryStore.create(base: base, telemetry: finalized) }
            } else {
                #expect(throws: (any Error).self) {
                    try OwnerPracticeRecoveryReader.forEachCandidate(base: base) { visited.append($0.header.practiceID) }
                }
                #expect(visited.isEmpty)
            }
        } catch { await f.close(); throw error }
        await f.close()
    }
}
@MainActor private final class O9PCompletion {
    private(set) var finished = false
    private(set) var error: String?
    func succeed() { finished = true }
    func fail(_ failure: any Error) { error = String(describing: failure); finished = true }
}
