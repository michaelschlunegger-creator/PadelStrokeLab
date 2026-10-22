import Foundation
import Testing
@testable import PadelCore
@testable import PadelStrokeLab_Watch_App

// Private full-O9 proposal. Explicit whole-practice API; never expands a single-copy action.
@Suite(.serialized) @MainActor struct OwnerPracticeDeletionTests {
    @Test func admissionCallbackDoesNotRetainTheSharedIngressLock() async throws {
        let base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("O9-Admission-Lock-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: base) }
        let ingress = OwnerPracticeDeletionIngress()
        let owner = OwnerCaptureCoordinator(base: base, deletionIngress: ingress)
        do {
            try await owner.load()
            let epoch = try #require(owner.watchEpoch)
            let authority = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: UUID(),
                watchInstallationEpoch: epoch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
                includesHeartRate: false, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000,
                policyDigest: OwnerPracticePolicy.digest)
            _ = try await owner.receive(.mutate(requestID: UUID(), generations: owner.generations,
                mutation: .enrollment(authority)))
            let draft = try PracticeSetupDraft(originInstallationEpoch: authority.phoneInstallationEpoch,
                preparationID: UUID(), revision: 1,
                preferences: .init(currentRacketArm: .right, usualHand: .right, intendedDrill: .forehandGroundstroke))
            let preparation = try OwnerPreparation(authority: authority, practiceID: UUID(), draft: draft)
            let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: owner.generations,
                preparation: preparation.identity)
            _ = try await owner.receive(.prepare(correlation: correlation, preparation: preparation))
            try #require(owner.acceptedPreparation == preparation)
            let confirmation = try #require(owner.confirmPhysical(wrist: .right, crown: "Crown right", fit: true))
            let metadata = try RecordingMetadata(recordingID: UUID(),
                clock: .init(domainID: UUID(), monotonicAnchorSeconds: 10, wallAnchorUnixSeconds: 1_800_000_000),
                appBuild: "O9-synthetic", protocolVersion: RecordingDrill.protocolVersion,
                deviceModel: "synthetic-watch", operatingSystem: "watchOS 27", handedness: .right,
                playingArm: .right, watchWrist: .right, watchOrientation: "Crown right", playingArmConfirmed: true,
                drill: RecordingDrill.forehandGroundstroke.rawValue, capabilityReport: "synthetic admission lock probe",
                streams: RecordingStream.allCases.map {
                    try .init(stream: $0, supported: true, requestedRateHz: nil, knownSensorLimit: nil)
                })
            let attempt = try await owner.prepareCapture(metadata: metadata, confirmation: confirmation)
            let probe = O9WIngressProbe()
            var completedInsideCallback = false
            try await owner.admit(attempt) {
                Thread {
                    probe.finish(ingress.allows(authority, practiceID: preparation.practiceID))
                }.start()
                // Always return after the deadline, even with the previous callback-under-lock bug.
                completedInsideCallback = probe.signal.wait(timeout: .now() + 1) == .success
            }
            let allowed = await probe.result()
            #expect(completedInsideCallback, "A concurrent ingress check must finish while the admission callback runs")
            #expect(allowed && owner.isAdmitted(attempt))
            owner.retireCapture(attempt); owner.engineDrained(attempt); owner.workoutClosed(attempt)
        } catch { await owner.closeForTesting(); throw error }
        await owner.closeForTesting()
    }
    @Test(arguments: [true, false])
    func sameTurnDeleteFencesOnlyTheTargetPracticeBeforeItsTaskRuns(targetsCurrent: Bool) async throws {
        let f = try await OwnerLifecycleFixture()
        do {
            try await f.beginAndRun()
            let first = try await f.practice.telemetrySnapshot()
            if !targetsCurrent {
                f.practice.end(); f.session.emit(.ended)
                try await f.wait { f.practice.state == .ended || f.practice.state == .interrupted }
                _ = try await f.acceptReplacementPractice()
                try await f.beginAndRun()
            }
            f.preparePhysical()
            try #require(f.owner.canBeginNextSet && f.model.canStart)
            let current = f.practice.currentPracticeID, session = f.session, endings = session.endCount
            let metadata = try f.model.makeMetadata()
            let deleting = f.services.deletePractice(first.header.practiceID)
            // There is deliberately no await between service ingress and these gates.
            #expect(f.owner.canBeginNextSet == !targetsCurrent)
            #expect(f.model.canStart == !targetsCurrent)
            let fresh = f.owner.confirmPhysical(wrist: .right, crown: "Crown right", fit: true)
            #expect((fresh == nil) == targetsCurrent, "A new confirmation must not bypass the deleted practice through a new fence generation")
            if targetsCurrent {
                var admitted = false
                do {
                    let attempt = try await f.owner.prepareCapture(metadata: metadata, confirmation: fresh)
                    try await f.owner.admit(attempt) { admitted = true }
                } catch { }
                #expect(!admitted, "No final admission may run after same-turn Delete")
                try await f.wait { session.endCount > endings }
                session.emit(.ended)
            }
            await deleting.value
            if !targetsCurrent {
                #expect(session.endCount == endings && !f.driver.isClosed)
                #expect(f.practice.currentPracticeID == current && f.practice.state == .baseline)
            }
        } catch { await f.finish(); throw error }
        await f.finish()
    }
    @Test func explicitDeleteRemovesWholeRetiredPracticeUnderWithdrawalAndPreservesUnrelated() async throws {
        try await o9wFixture { f in
            let before = try f.otherBytes()
            let authority = try #require(f.owner.authority)
            _ = try await f.owner.receive(.mutate(requestID: UUID(), generations: f.owner.generations,
                mutation: .withdraw(from: authority, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_200)))
            #expect(f.owner.authority?.isCollectionAllowed == false)
            await f.services.deletePractice(f.receipt.practiceID).value
            try f.assertGone()
            let after = try f.otherBytes()
            #expect(after == before)
            let observed = try OwnerPracticeDeletion.status(base: f.base, practiceID: f.receipt.practiceID)
            let status = try #require(observed)
            #expect(status.localComplete && !status.peerComplete)
            let completed = try OwnerPracticeDeletionProof.isCompleted(base: f.base, practiceID: f.receipt.practiceID)
            #expect(completed)
            let independentBytes = try Data(contentsOf: f.independent)
            #expect(independentBytes == f.originalBytes)
            var discovered: [UUID] = []
            try OwnerPracticeRecoveryReader.forEachCandidate(base: f.base) { discovered.append($0.header.practiceID) }
            #expect(discovered == [f.other.telemetry.header.practiceID])
            await o9wReject { _ = try await f.publish(f.independent) }
        }
    }

    @Test func actualActiveSetDeletionWaitsForWriterAndNativeClosureBeforeAnyCoveredRemoval() async throws {
        let writer = OwnerLifecycleBarrier()
        let f = try await OwnerLifecycleFixture(heartRate: true, beforeWriterDrain: { await writer.suspend() })
        do {
            try await f.beginAndRun(); try await f.startSet()
            let base = try #require(f.services.environment.base), paths = try #require(f.services.paths)
            let telemetry = try await f.practice.telemetrySnapshot()
            let context = try #require(f.model.capturedMetadata)
            let raw = paths.rawRoot.appendingPathComponent(context.recordingID.uuidString)
            let deleting = f.services.deletePractice(telemetry.header.practiceID)
            try await f.wait { writer.entered && f.session.endCount == 1 }
            #expect(FileManager.default.fileExists(atPath: raw.path))
            let pending = try OwnerPracticeDeletion.status(base: base, practiceID: telemetry.header.practiceID)
            #expect(pending?.localComplete != true)
            f.driver.checkShutdownDeadlineForTesting()
            #expect(FileManager.default.fileExists(atPath: raw.path) && !f.driver.isClosed)
            f.session.emit(.ended)
            #expect(FileManager.default.fileExists(atPath: raw.path), "Native closure alone cannot authorize cleanup while writer drain is held")
            writer.release(); await deleting.value
            let observed = try OwnerPracticeDeletion.status(base: base, practiceID: telemetry.header.practiceID)
            let status = try #require(observed)
            #expect(status.localComplete && !status.peerComplete)
            #expect(!FileManager.default.fileExists(atPath: raw.path))
            #expect(f.heartRate.pendingCallbacks == 0 && !f.motion.isAccelerometerActive && !f.motion.isDeviceMotionActive)
            #expect(f.driver.isClosed && f.model.snapshot?.state.isTerminal == true)
            let completed = try OwnerPracticeDeletionProof.isCompleted(base: base, practiceID: telemetry.header.practiceID)
            #expect(completed)
        } catch { writer.release(); await f.close(); throw error }
        writer.release(); await f.close()
    }

    @Test func wireAcknowledgmentFollowsActualCleanupAndRejectsConflictingOwnerEpochAndInventory() async throws {
        try await o9wFixture { f in
            let gap = O9WDeletionBarrier()
            f.owner.beforePracticeDeletion = { await gap.hold() }
            let command = try OwnerPracticeDeletionCommand(operationID: UUID(), authority: f.authority,
                practiceID: f.receipt.practiceID, recordingIDs: f.receipt.recordingIDs, revisions: f.receipts, requester: .phone)
            let bytes = try command.encoded()
            f.connection.receiveUserInfo(["kind": "PSLOwnerPracticeDelete1", "payload": bytes])
            defer { Task { await gap.release() } }
            try await o9wEventually { await gap.entered }
            #expect(f.link.acknowledgments.isEmpty)
            #expect(FileManager.default.fileExists(atPath: f.source.paths.rawRoot.appendingPathComponent(f.receipt.recordingIDs[0].uuidString).path))
            let before = try f.otherBytes()
            await gap.release()
            try await o9wEventually { !f.link.acknowledgments.isEmpty }
            let acknowledgmentBytes = try #require(f.link.acknowledgments.first)
            let acknowledgment = try OwnerPracticeDeletionAcknowledgment.decode(acknowledgmentBytes)
            #expect(acknowledgment.command == command && acknowledgment.device == .watch)
            try f.assertGone()
            let after = try f.otherBytes()
            #expect(after == before)
            f.connection.receiveUserInfo(["kind": "PSLOwnerPracticeDelete1", "payload": bytes])
            try await f.drainConnection()
            #expect(f.link.acknowledgments.allSatisfy { $0 == acknowledgmentBytes })
            let foreign = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: UUID(),
                watchInstallationEpoch: f.authority.watchInstallationEpoch, attestsWatchAccountOwner: true,
                acceptsMotionStudy: true, includesHeartRate: true, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_200,
                policyDigest: OwnerPracticePolicy.digest)
            let wrong = try OwnerPracticeDeletionCommand(operationID: command.operationID, authority: foreign,
                practiceID: f.other.telemetry.header.practiceID, recordingIDs: f.other.contexts.map(\.recordingID), revisions: [], requester: .phone)
            let count = f.link.acknowledgments.count
            f.connection.receiveUserInfo(["kind": "PSLOwnerPracticeDelete1", "payload": try wrong.encoded()])
            let conflicting = try OwnerPracticeDeletionCommand(operationID: command.operationID, authority: f.authority,
                practiceID: command.practiceID, recordingIDs: [command.recordingIDs[0]], revisions: [], requester: .phone)
            f.connection.receiveUserInfo(["kind": "PSLOwnerPracticeDelete1", "payload": try conflicting.encoded()])
            try await f.drainConnection()
            let unchanged = try f.link.acknowledgments.count == count && f.otherBytes() == before
            #expect(unchanged)
        }
    }
}

@MainActor private func o9wFixture(_ body: (O9WatchFixture) async throws -> Void) async throws {
    let f = try O9WatchFixture()
    do {
        try await o9wEventually { f.services.ownerLoaded }
        try #require(f.services.storageError == nil)
        try await f.seed(); try await body(f); await f.close()
    } catch { await f.close(); throw error }
}
@MainActor private final class O9WatchFixture {
    let environment: WatchRuntimeEnvironment, base: URL, authority: OwnerPracticeIdentity
    let source: O9WatchHistoricalSource, other: O9WatchHistoricalSource, bundle: URL, revision: URL
    let receipt: OwnerPracticeReceipt, receipts: [OwnerPracticeReceipt], independent: URL, originalBytes: Data
    let link = O9WDeletionLink(), connection: RecordingConnectivity, services: WatchRecordingServices
    var owner: OwnerCaptureCoordinator { services.coordinator! }
    init() throws {
        environment = try WatchRuntimeEnvironment.resolve(arguments: ["--owner-watch-fixture=\(UUID().uuidString)"], environment: [:])
        try environment.prepareFixtureDirectory(); base = try #require(environment.base)
        var bootstrap: OwnerWatchBootstrap? = try OwnerWatchBootstrap(base: base)
        let epoch = try bootstrap!.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch }
        let enrolled = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: UUID(),
            watchInstallationEpoch: epoch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
            includesHeartRate: true, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000, policyDigest: OwnerPracticePolicy.digest)
        let base = self.base
        var built: O9WatchHistoricalSource?, unrelated: O9WatchHistoricalSource?
        try bootstrap!.withStores { _, channel in
            _ = try channel.sequence(.enrollment(enrolled))
            built = try O9WatchHistoricalSource(base: base, authority: enrolled, channel: channel)
            let snapshot = try channel.readSnapshot()
            let current = try #require(snapshot.authority)
            unrelated = try O9WatchHistoricalSource(base: base, authority: current, channel: channel)
        }
        authority = try bootstrap!.withStores { _, channel in
            let snapshot = try channel.readSnapshot()
            return try #require(snapshot.authority)
        }
        bootstrap = nil
        source = try #require(built); other = try #require(unrelated)
        let first = try source.write(), second = try source.write(heartRate: .excludedByOwner, revision: 2)
        bundle = first.0; receipt = first.1; revision = second.0; receipts = [first.1, second.1]
        independent = base.deletingLastPathComponent().appendingPathComponent("independent-O9-" + UUID().uuidString + ".pslpractice")
        originalBytes = try Data(contentsOf: bundle); try originalBytes.write(to: independent)
        connection = RecordingConnectivity(paths: source.paths, backgroundStateProvider: { .init(activated: true, hasContentPending: false) }, backgroundTimeout: 2,
            practiceTransportAdapter: .init(available: { false }, transferFile: { _, _, _ in }, transferReceipt: { _ in }),
            practiceDeletionTransportAdapter: link.adapter)
        services = WatchRecordingServices(environment: environment, injectedConnectivity: connection)
        try #require(services.coordinator != nil)
    }
    func seed() async throws { _ = try await publish(bundle); _ = try await publish(revision) }
    func publish(_ bundle: URL) async throws -> OwnerPracticeReceipt {
        let prepared = try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: base)
        defer { prepared.cancel() }
        return try await owner.publishVerifiedPractice(scope: prepared.scope, preparedPublication: prepared)
    }
    func otherBytes() throws -> [Data] {
        try other.contexts.map { try RecordingChunkCodec.encodeMetadata(RecordingStore.inspect(root: other.paths.rawRoot, recordingID: $0.recordingID).metadata!) }
            + [Data(contentsOf: base.appendingPathComponent(OwnerTelemetryStore.directoryName)
                .appendingPathComponent(other.telemetry.header.practiceID.uuidString.lowercased()).appendingPathComponent("telemetry.json"))]
    }
    func assertGone() throws {
        for id in receipt.recordingIDs {
            for root in [source.paths.rawRoot, source.paths.notesRoot, source.paths.inboxRoot] {
                #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(id.uuidString).path))
            }
            let context = base.appendingPathComponent(OwnerPracticeStore.directoryName).appendingPathComponent("contexts").appendingPathComponent(id.uuidString)
            let entries = try FileManager.default.contentsOfDirectory(atPath: context.path)
            #expect(entries.isEmpty)
        }
        let inventory = try OwnerPracticeTransferInventory.snapshots(base: base)
        #expect(!inventory.contains { $0.receipt.practiceID == receipt.practiceID })
        #expect(!FileManager.default.fileExists(atPath: bundle.path) && !FileManager.default.fileExists(atPath: revision.path))
        let directory = base.appendingPathComponent(OwnerTelemetryStore.directoryName).appendingPathComponent(receipt.practiceID.uuidString.lowercased())
        let entries = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(entries.isEmpty)
    }
    func drainConnection() async throws {
        let drained = await withCheckedContinuation { continuation in
            _ = connection.drainForBackground { continuation.resume(returning: $0) }
        }
        #expect(drained, "Counted deletion/receipt handlers must finish before observation")
    }
    func close() async {
        await services.practice?.closeForTesting(); await owner.closeForTesting()
        if let suite = environment.preferenceSuite { services.preferences.removePersistentDomain(forName: suite) }
        try? FileManager.default.removeItem(at: base); try? FileManager.default.removeItem(at: independent)
    }
}
private nonisolated final class O9WDeletionLink: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Data] = []
    var acknowledgments: [Data] { lock.withLock { values } }
    var adapter: OwnerPracticeDeletionTransportAdapter {
        .init(available: { true }, transferCommand: { _ in }, transferAcknowledgment: { [self] bytes in lock.withLock { values.append(bytes) } })
    }
}
private actor O9WDeletionBarrier {
    private(set) var entered = false
    private var open = false, waiter: CheckedContinuation<Void, Never>?
    func hold() async { entered = true; if !open { await withCheckedContinuation { waiter = $0 } } }
    func release() { open = true; waiter?.resume(); waiter = nil }
}
@MainActor private func o9wEventually(_ condition: () async -> Bool) async throws {
    for _ in 0..<200 { if await condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
    Issue.record("Actual Watch deletion boundary did not complete")
    throw O9AppFixtureFailure.timeout
}
@MainActor private func o9wReject(_ operation: () async throws -> Void) async {
    do { try await operation(); Issue.record("Deleted practice was published") } catch {}
}

// This builder uses validated raw/O6 APIs in a distinct synthetic source namespace.
// It is historical evidence, never an authority gate or a replacement live app store.
@MainActor private final class O9WatchHistoricalSource {
    let base: URL, paths: RecordingPaths, telemetry: OwnerPracticeTelemetry
    let contexts: [OwnerRecordingContext]
    init(base: URL, authority: OwnerPracticeIdentity, channel: PracticeSetupChannel, practiceID: UUID = UUID(), samples: Bool = true) throws {
        self.base = base
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        paths = try RecordingPaths(base: base)
        let wall = 1_800_000_000.0, mono = 1_000.0, runtime = UUID(), consent = UUID(), query = UUID()
        let header = try OwnerTelemetryHeader(authority: authority, practiceID: practiceID,
            clock: RecordingClock(domainID: UUID(), monotonicAnchorSeconds: mono, wallAnchorUnixSeconds: wall),
            runtimeGeneration: runtime, clockUncertaintySeconds: 0)
        var value = try OwnerPracticeTelemetry(header: header, authority: authority,
            initialConsentSegmentID: consent, initialQueryGeneration: authority.heartRateConsent ? query : nil)
        let notes = try SessionAnnotationsStore(root: paths.notesRoot)
        var contexts: [OwnerRecordingContext] = []
        for index in 0..<2 {
            let raw = Double(100 + index * 100), seconds = Double(10 + index * 40)
            let drill: RecordingDrill = index == 0 ? .forehandGroundstroke : .backhandGroundstroke
            let metadata = try RecordingMetadata(recordingID: UUID(),
                clock: RecordingClock(domainID: UUID(), monotonicAnchorSeconds: raw, wallAnchorUnixSeconds: wall + seconds),
                appBuild: "7", protocolVersion: RecordingDrill.protocolVersion, deviceModel: "synthetic-watch",
                operatingSystem: "watchOS 27", handedness: .right, playingArm: .right, watchWrist: .right,
                watchOrientation: "Crown right", playingArmConfirmed: true, drill: drill.rawValue,
                capabilityReport: "synthetic supported", streams: try RecordingStream.allCases.map {
                    try RecordingStreamConfiguration(stream: $0, supported: true, requestedRateHz: nil, knownSensorLimit: nil)
                })
            let draft = try PracticeSetupDraft(originInstallationEpoch: authority.phoneInstallationEpoch,
                preparationID: UUID(), revision: Int64(index + 1),
                preferences: .init(currentRacketArm: .right, usualHand: .right, intendedDrill: drill))
            let binding = try OwnerRecordingContext.bind(rawMetadataBytes: RecordingChunkCodec.encodeMetadata(metadata),
                authority: authority, practiceID: practiceID, acceptedSetup: draft,
                generations: .init(runtimeGeneration: runtime, preparationGeneration: UUID()))
            _ = try channel.publish(binding, expectedRevision: authority.revision)
            let context = binding.context
            let calibration = try OwnerSetClockCalibration(rawClock: metadata.clock,
                practiceClockDomainID: header.clock.domainID, runtimeGeneration: runtime,
                rawBeforeSeconds: raw, rawAfterSeconds: raw, practiceMonotonicSeconds: mono + seconds,
                wallUnixSeconds: wall + seconds)
            try value.admitSet(context: context, mapping: SetClockMapping(context: context, header: header, calibration: calibration),
                consentSegmentID: consent, rawStartSeconds: raw,
                at: OwnerTelemetryInstant(wallUnixSeconds: wall + seconds, monotonicSeconds: mono + seconds))
            try value.stopSet(recordingID: metadata.recordingID, rawStopSeconds: raw + 2,
                at: OwnerTelemetryInstant(wallUnixSeconds: wall + seconds + 2, monotonicSeconds: mono + seconds + 2))
            let rawStore = try RecordingStore.create(root: paths.rawRoot, metadata: metadata)
            for stream in RecordingStream.allCases {
                try rawStore.append(RecordingChunk(recordingID: metadata.recordingID, clockDomainID: metadata.clock.domainID,
                    stream: stream, sequence: 0, samples: [
                        .init(timestamp: raw + 0.5, values: Array(repeating: 0.25, count: stream.componentCount)),
                        .init(timestamp: raw + 1, values: Array(repeating: 0.5, count: stream.componentCount))
                    ]))
            }
            try rawStore.finalize(stopRequestTimestamp: raw + 2, reason: .userStopped)
            try notes.saveTimeline(CaptureTimeline(recordingID: metadata.recordingID, clockDomainID: metadata.clock.domainID,
                events: [try .init(kind: .start, timestamp: raw, id: UUID()),
                         try .init(kind: .stopped, timestamp: raw + 2, id: UUID())]))
            try notes.saveLabels([], recordingID: metadata.recordingID)
            if samples && authority.heartRateConsent {
                let provenance = try OwnerHeartRateProvenance(sourceBundleIdentifier: "com.synthetic.o8",
                    sourceVersion: "1", operatingSystem: "watchOS 27", productType: "WatchSynthetic",
                    manufacturer: "Synthetic", model: "Watch", hardwareVersion: "1", softwareVersion: "1",
                    watchInstallationEpoch: authority.watchInstallationEpoch)
                _ = try value.appendPage([OwnerHeartRateSample(id: UUID(), bpm: Double(110 + index),
                    sourceStart: Date(timeIntervalSince1970: wall + seconds + 1),
                    sourceEnd: Date(timeIntervalSince1970: wall + seconds + 1),
                    arrival: Date(timeIntervalSince1970: wall + seconds + 3), provenance: provenance)],
                    consentSegmentID: consent, queryGeneration: query)
            }
            contexts.append(context)
        }
        try value.finalize(status: .ended,
            at: OwnerTelemetryInstant(wallUnixSeconds: wall + 85, monotonicSeconds: mono + 85),
            absenceReasons: samples && authority.heartRateConsent ? [] : [.noAccessibleHeartRateData])
        _ = try channel.sequence(.retirePractice(from: authority, practiceID: practiceID, mutationID: UUID()))
        for context in contexts {
            guard case .retired = try channel.inspectContext(recordingID: context.recordingID) else {
                throw O9AppFixtureFailure.invariant
            }
        }
        let store = try OwnerTelemetryStore.create(base: base, telemetry: value)
        telemetry = store.snapshot; store.close()
        self.contexts = contexts
    }
    func write(heartRate: OwnerPracticeHeartRateSelection = .asRecorded, revision: Int64 = 1) throws -> (URL, OwnerPracticeReceipt) {
        let destination = paths.outboxRoot.appendingPathComponent(UUID().uuidString + ".pslpractice")
        let receipt = try OwnerPracticeBundle.write(telemetry: telemetry, rawRoot: paths.rawRoot, notesRoot: paths.notesRoot,
            revision: revision, heartRate: heartRate, destination: destination)
        return (destination, receipt)
    }
}
private nonisolated enum O9AppFixtureFailure: Error { case invariant, timeout }


private nonisolated final class O9WIngressProbe: @unchecked Sendable {
    let signal = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var value: Bool?
    private var waiter: CheckedContinuation<Bool, Never>?
    func finish(_ result: Bool) {
        let continuation = lock.withLock {
            value = result
            let continuation = waiter; waiter = nil
            return continuation
        }
        signal.signal(); continuation?.resume(returning: result)
    }
    func result() async -> Bool {
        await withCheckedContinuation { continuation in
            let ready = lock.withLock { () -> Bool? in
                if let value { return value }
                waiter = continuation; return nil as Bool?
            }
            if let ready { continuation.resume(returning: ready) }
        }
    }
}
