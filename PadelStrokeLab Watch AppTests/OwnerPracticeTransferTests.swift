import Foundation
import Testing
@testable import PadelCore
@testable import PadelStrokeLab_Watch_App

// O8b tests-first: only transport is replaced. The retained services, coordinator,
// raw/O6 stores, final publication gate and recorder retry action remain production paths.
@Suite(.serialized) @MainActor struct OwnerPracticeTransferTests {
    @Test(arguments: [false, true])
    func existingRetryActionQueuesEndedWholePracticeAndRetainsBothStrokes(heartRate: Bool) async throws {
        try await o8wFixture(samples: heartRate) { f in
            #expect(f.services.connectivity === f.connection)
            #expect(!f.services.environment.allowsHardware)
            let model = WatchRecorderModel(services: f.services)
            let context = f.source.contexts[0]
            let notes = try SessionAnnotationsStore(root: f.source.paths.notesRoot)
            let loadedTimeline = try notes.loadTimeline(recordingID: context.recordingID)
            let timeline = try #require(loadedTimeline)
            let entry = WatchRetainedRecording(id: context.recordingID, status: "Finalized", samples: 4,
                intendedDrill: context.metadata.drill, timeline: timeline, canTransfer: true)
            model.retryTransfer(entry)
            // Offline queue persists the complete evidence before any network delivery.
            try await o8wEventually { await f.status()?.state == .queued }
            #expect(f.link.files.isEmpty)
            f.link.available = true
            f.connection.resumePracticeTransfers()
            try await o8wEventually { !f.link.files.isEmpty }
            let sent = try #require(f.link.files.first)
            #expect(sent.metadata["kind"] == "PSLOwnerPractice1")
            #expect(sent.metadata["practiceID"] == f.receipt.practiceID.uuidString)
            #expect(try Data(contentsOf: sent.url) == Data(contentsOf: f.bundle))
            sent.complete(.success(()))
            try await o8wEventually { await f.status()?.state == .sent }
            f.connection.receiveUserInfo(["kind": "PSLOwnerPracticeReceipt1", "payload": try f.receipt.encoded()])
            try await o8wEventually { await f.status()?.state == .verified }
            for context in f.source.contexts {
                #expect(try RecordingStore.inspect(root: f.source.paths.rawRoot, recordingID: context.recordingID).metadata == context.metadata)
                #expect(try notes.loadTimeline(recordingID: context.recordingID) != nil)
                #expect(try await f.owner.inspectContext(recordingID: context.recordingID) == .retired)
            }
            #expect(FileManager.default.fileExists(atPath: f.bundle.path))
        }
    }

    @Test(arguments: [false, true])
    func pendingRestrictionAtReceiveLoadGapChecksActualHRContent(heartRateOnly: Bool) async throws {
        try await o8wFixture { f in
            // Restart only the real retained coordinator after closing its worker.
            // The next receive must register its pending restriction before load/persistence.
            await f.owner.closeForTesting()
            let owner = OwnerCaptureCoordinator(base: f.base)
            let gap = O8WAsyncBarrier()
            owner.beforeAuthorityPersistence = { await gap.hold() }
            let mutation = try heartRateOnly
                ? OwnerAuthorityMutation.heartRate(from: f.authority, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_100)
                : .withdraw(from: f.authority, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_100)
            let pending = Task { try await owner.receive(.mutate(requestID: UUID(), generations: owner.generations, mutation: mutation)) }
            defer { Task { await gap.release() } }
            try await o8wEventually { await gap.entered }
            await o8wReject { _ = try await f.publish(f.bundle, through: owner) }
            let (excluded, receipt) = try f.source.write(heartRate: .excludedByOwner, revision: 2)
            if heartRateOnly {
                #expect(try await f.publish(excluded, through: owner) == receipt)
            } else {
                await o8wReject { _ = try await f.publish(excluded, through: owner) }
            }
            await gap.release()
            _ = try await pending.value
            await o8wReject { _ = try await f.publish(f.bundle, through: owner) }
            await owner.closeForTesting()
        }
    }

    @Test(arguments: [false, true])
    func actualBoundedRenameOrdersRestrictionOnSharedFence(afterRename: Bool) async throws {
        try await o8wFixture { f in
            let boundary = O8WWorkerBarrier()
            if afterRename { f.owner.afterPracticeRename = { boundary.hold() } }
            else { f.owner.beforePracticeRename = { boundary.hold() } }
            defer { boundary.release() }
            let publication = Task { try await f.publish(f.bundle) }
            try await o8wEventually { boundary.entered }
            let mutation = try OwnerAuthorityMutation.withdraw(from: f.authority, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_100)
            let gap = O8WAsyncBarrier()
            f.owner.beforeAuthorityPersistence = { await gap.hold() }
            let restriction = Task { try await f.owner.receive(.mutate(requestID: UUID(), generations: f.owner.generations, mutation: mutation)) }
            defer { Task { await gap.release() } }
            try await o8wEventually { await gap.entered }
            boundary.release()
            let result = await publication.result
            let stored = try OwnerPracticeReceiptStore(base: f.base).receipt(practiceID: f.receipt.practiceID, revision: 1)
            if afterRename {
                #expect(stored == f.receipt)
            } else {
                if case .success = result { Issue.record("Restriction before fence acquisition allowed publication") }
                #expect(stored == nil)
            }
            await gap.release(); _ = try await restriction.value
            #expect(!boundary.timedOut)
        }
    }

    @Test func liveWorkerRejectsCorruptAuthorityDespiteItsCachedAllowedView() async throws {
        try await o8wFixture { f in
            let cached = f.owner.authority
            #expect(cached?.isCollectionAllowed == true)
            let journal = f.base.appendingPathComponent("OwnerChannel-v2/journal.json")
            let original = try Data(contentsOf: journal)
            try Data("corrupt-synthetic-channel".utf8).write(to: journal)
            #expect(f.owner.authority == cached)
            await o8wReject { _ = try await f.publish(f.bundle) }
            try original.write(to: journal)
            await o8wReject { _ = try await f.publish(f.bundle) }
            #expect(try OwnerPracticeReceiptStore(base: f.base).receipt(practiceID: f.receipt.practiceID, revision: 1) == nil)
        }
    }

    @Test func historicalPublicationCannotRestoreRetiredCaptureAdmission() async throws {
        try await o8wFixture { f in
            let publishedReceipt = try await f.publish(f.bundle)
            #expect(publishedReceipt == f.receipt)
            for context in f.source.contexts {
                let storedContext = try await f.owner.inspectContext(recordingID: context.recordingID)
                #expect(storedContext == .retired)
                await o8wReject { _ = try await f.owner.prepareCapture(metadata: context.metadata, confirmation: nil) }
            }
            #expect(f.owner.acceptedPreparation == nil && f.owner.nextPreparation == nil)
            #expect(f.owner.confirmPhysical(wrist: .right, crown: "Crown right", fit: true) == nil)
        }
    }
}

@MainActor private func o8wFixture(samples: Bool = true, _ body: (O8WatchFixture) async throws -> Void) async throws {
    let f = try O8WatchFixture(samples: samples)
    do {
        try await o8wEventually { f.services.ownerLoaded }
        try #require(f.services.storageError == nil)
        try await body(f)
        await f.close()
    } catch { await f.close(); throw error }
}
@MainActor private final class O8WatchFixture {
    let environment: WatchRuntimeEnvironment, base: URL, authority: OwnerPracticeIdentity
    let source: O8WatchHistoricalSource, bundle: URL, receipt: OwnerPracticeReceipt
    let link = O8WFileLink(), connection: RecordingConnectivity, services: WatchRecordingServices
    var owner: OwnerCaptureCoordinator { services.coordinator! }
    init(samples: Bool) throws {
        environment = try WatchRuntimeEnvironment.resolve(arguments: ["--owner-watch-fixture=\(UUID().uuidString)"], environment: [:])
        try environment.prepareFixtureDirectory()
        base = try #require(environment.base)
        // Bootstrap and populate before services takes sole ownership. No second live store.
        var bootstrap: OwnerWatchBootstrap? = try OwnerWatchBootstrap(base: base)
        let epoch = try bootstrap!.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch }
        let enrolled = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: UUID(),
            watchInstallationEpoch: epoch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
            includesHeartRate: true, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000, policyDigest: OwnerPracticePolicy.digest)
        let base = self.base
        var built: O8WatchHistoricalSource?
        try bootstrap!.withStores { _, channel in
            _ = try channel.sequence(.enrollment(enrolled))
            built = try O8WatchHistoricalSource(base: base, authority: enrolled, channel: channel, samples: samples)
        }
        authority = try bootstrap!.withStores { _, channel in try #require(channel.readSnapshot().authority) }
        bootstrap = nil
        source = try #require(built)
        (bundle, receipt) = try source.write()
        connection = RecordingConnectivity(paths: source.paths,
            backgroundStateProvider: { .init(activated: true, hasContentPending: false) }, backgroundTimeout: 2,
            practiceTransportAdapter: link.adapter)
        services = WatchRecordingServices(environment: environment, injectedConnectivity: connection)
        try #require(services.coordinator != nil)
    }
    func publish(_ bundle: URL, through coordinator: OwnerCaptureCoordinator? = nil) async throws -> OwnerPracticeReceipt {
        let prepared = try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: base)
        defer { prepared.cancel() }
        return try await (coordinator ?? owner).publishVerifiedPractice(scope: prepared.scope, preparedPublication: prepared)
    }
    func status() async -> OwnerPracticeTransferSnapshot? {
        await withCheckedContinuation { continuation in
            connection.practiceStatus(practiceID: receipt.practiceID, revision: receipt.revision,
                bundleSHA256: receipt.bundleSHA256) { continuation.resume(returning: $0) }
        }
    }
    func close() async {
        await services.practice?.closeForTesting(); await owner.closeForTesting()
        if let suite = environment.preferenceSuite { services.preferences.removePersistentDomain(forName: suite) }
        try? FileManager.default.removeItem(at: base)
    }
}
private actor O8WAsyncBarrier {
    private(set) var entered = false
    private var open = false
    private var waiter: CheckedContinuation<Void, Never>?
    func hold() async { entered = true; if !open { await withCheckedContinuation { waiter = $0 } } }
    func release() { open = true; waiter?.resume(); waiter = nil }
}
private nonisolated final class O8WWorkerBarrier: @unchecked Sendable {
    private let lock = NSLock(), gate = DispatchSemaphore(value: 0)
    private var arrived = false, expired = false
    var entered: Bool { lock.withLock { arrived } }
    var timedOut: Bool { lock.withLock { expired } }
    func hold() { lock.withLock { arrived = true }; if gate.wait(timeout: .now() + 5) != .success { lock.withLock { expired = true } } }
    func release() { gate.signal() }
}
private nonisolated final class O8WFileLink: @unchecked Sendable {
    struct File: Sendable {
        let url: URL, metadata: [String: String]
        let complete: @Sendable (Result<Void, OwnerTransportFailure>) -> Void
    }
    private let lock = NSLock()
    private var online = false, sent: [File] = []
    var available: Bool { get { lock.withLock { online } } set { lock.withLock { online = newValue } } }
    var files: [File] { lock.withLock { sent } }
    var adapter: OwnerPracticeTransportAdapter {
        .init(available: { [self] in available }, transferFile: { [self] url, metadata, completion in
            lock.withLock { sent.append(.init(url: url, metadata: metadata, complete: completion)) }
        }, transferReceipt: { _ in })
    }
}
@MainActor private func o8wEventually(_ condition: () async -> Bool) async throws {
    for _ in 0..<200 { if await condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
    Issue.record("Actual Watch transfer/publication boundary did not complete")
    throw O8AppFixtureFailure.timeout
}
@MainActor private func o8wReject(_ operation: () async throws -> Void) async {
    do { try await operation(); Issue.record("Current authority unexpectedly allowed publication/admission") } catch {}
}

// This builder uses validated raw/O6 APIs in a distinct synthetic source namespace.
// It is historical evidence, never an authority gate or a replacement live app store.
@MainActor private final class O8WatchHistoricalSource {
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
                throw O8AppFixtureFailure.invariant
            }
        }
        let store = try OwnerTelemetryStore.create(base: base, telemetry: value)
        telemetry = store.snapshot; store.close()
        self.contexts = contexts
    }
    func write(heartRate: OwnerPracticeHeartRateSelection = .asRecorded, revision: Int64 = 1) throws -> (URL, OwnerPracticeReceipt) {
        let destination = base.appendingPathComponent(UUID().uuidString + ".pslpractice")
        let receipt = try OwnerPracticeBundle.write(telemetry: telemetry, rawRoot: paths.rawRoot, notesRoot: paths.notesRoot,
            revision: revision, heartRate: heartRate, destination: destination)
        return (destination, receipt)
    }
}
private nonisolated enum O8AppFixtureFailure: Error { case invariant, timeout }

