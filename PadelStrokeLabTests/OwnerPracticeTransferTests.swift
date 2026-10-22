import Foundation
import Testing
@testable import PadelCore
@testable import PadelStrokeLab

// Tests-first. New hooks below are nil in production and hold actual ingress/worker
// boundaries only. The final fence may call only the bounded O8a rename operation.
@Suite(.serialized) @MainActor struct OwnerPracticeTransferTests {
    @Test func actualLibraryReceivesAndExportsBothStrokesThroughExistingSelectionPath() async throws {
        try await o8pFixture(library: true) { f in
            let source = try f.source()
            let (bundle, receipt) = try source.write()
            let library = try #require(f.library)
            #expect(library.connectivity === f.connection)
            #expect(try await f.receive(bundle, receipt) == receipt)
            await library.refresh()
            let id = source.contexts[0].recordingID
            await library.open(id)
            await library.prepareExport(id)
            let exported = try #require(library.exportURL)
            #expect(exported.pathExtension == "pslpractice")
            #expect(try Data(contentsOf: exported) == Data(contentsOf: bundle))
            let readback = try f.directory("readback")
            let prepared = try OwnerPracticeBundle.prepareImport(from: exported, destinationBase: readback)
            try prepared.renameForPublication(); _ = try prepared.confirmPublication()
            let verified = try OwnerPracticeReceiptStore(base: readback).open(practiceID: receipt.practiceID, revision: 1)
            #expect(verified.sets.map(\.context.metadata.drill) == [
                RecordingDrill.forehandGroundstroke.rawValue, RecordingDrill.backhandGroundstroke.rawValue])
            #expect(verified.receipt == receipt && verified.heartRate == .included)
            #expect(try Data(contentsOf: bundle) == Data(contentsOf: exported), "Source remains after receipt and export.")
        }
    }

    @Test func synchronousConsentIngressBlocksHRDuringTaskGapButNotActualMotionOnlyContent() async throws {
        try await o8pFixture { f in
            let gap = O8PAsyncBarrier()
            f.setup.beforeConsentPersistence = { await gap.hold() }
            f.setup.setConsent(ownerConfirmed: true, motion: true, heartRate: false)
            defer { Task { await gap.releaseAll() } }
            try await o8pEventually { await gap.count == 1 }
            let source = try f.source()
            let (included, _) = try source.write()
            await o8pReject { _ = try await f.publish(included) }
            let (excluded, excludedReceipt) = try source.write(heartRate: .excludedByOwner, revision: 2)
            #expect(!excludedReceipt.scope.includesHeartRate)
            #expect(try await f.publish(excluded) == excludedReceipt)
            let absent = try f.source(samples: false)
            let (noSamples, absentReceipt) = try absent.write()
            #expect(absentReceipt.heartRate == .absent && !absentReceipt.scope.includesHeartRate)
            #expect(try await f.publish(noSamples) == absentReceipt)
            await gap.releaseAll()
            try await o8pEventually { f.setup.channel?.pending != nil || f.setup.lastError != nil }
        }
    }

    @Test func actualReplyCommitGapAndOlderCompletionCannotClearNewerFullRestriction() async throws {
        let gap = O8PAsyncBarrier()
        try await o8pFixture(beforeReplyCommit: { _ in await gap.hold() }) { f in
            defer { Task { await gap.releaseAll() } }
            let first = try f.remote.restrict(heartRateOnly: true)
            let firstResult = O8PMessageResult()
            f.connection.receiveOwnerData(try OwnerPreparationCodec.encode(.transition(first)), delivery: .control) { firstResult.set($0) }
            try await o8pEventually { await gap.count == 1 }
            let (hrBundle, _) = try f.source().write()
            await o8pReject { _ = try await f.publish(hrBundle) }
            let second = try f.remote.restrict(heartRateOnly: false)
            let secondResult = O8PMessageResult()
            f.connection.receiveOwnerData(try OwnerPreparationCodec.encode(.transition(second)), delivery: .control) { secondResult.set($0) }
            try await o8pEventually { await gap.count == 2 }
            await gap.release(0)
            try await o8pEventually { firstResult.value != nil }
            _ = try #require(firstResult.value).get()
            #expect(f.setup.channel?.authority?.heartRateConsent == false)
            let (motion, _) = try f.source().write(heartRate: .excludedByOwner, revision: 2)
            await o8pReject { _ = try await f.publish(motion) }
            await gap.releaseAll()
            try await o8pEventually { secondResult.value != nil }
            _ = try #require(secondResult.value).get()
            #expect(f.setup.channel?.authority?.isCollectionAllowed == false)
            await o8pReject { _ = try await f.publish(motion) }
        }
    }

    @Test(arguments: [false, true])
    func actualFinalRenameOrdersRestrictionBeforeAndAfterFence(afterRename: Bool) async throws {
        try await o8pFixture { f in
            let (bundle, receipt) = try f.source().write()
            let boundary = O8PWorkerBarrier()
            if afterRename { f.setup.afterPracticeRename = { boundary.hold() } }
            else { f.setup.beforePracticeRename = { boundary.hold() } }
            defer { boundary.release() }
            let pending = try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: f.phone)
            let publication = Task { try await f.setup.publishVerifiedPractice(scope: pending.scope, preparedPublication: pending) }
            try await o8pEventually { boundary.entered }
            let restriction = f.setup.withdrawMotionConsent()
            boundary.release()
            let result = await publication.result
            await restriction.value
            let retained = try OwnerPracticeReceiptStore(base: f.phone).receipt(practiceID: receipt.practiceID, revision: 1)
            if afterRename {
                #expect(retained == receipt, "A completed bounded rename precedes the later restriction.")
            } else {
                if case .success = result { Issue.record("Restriction before fence acquisition must deny actual publication") }
                #expect(retained == nil)
            }
            #expect(!boundary.timedOut)
        }
    }

    @Test func failedRestrictionPersistenceStaysClosedEvenAfterFixtureBytesAreRestored() async throws {
        try await o8pFixture { f in
            let gap = O8PAsyncBarrier()
            f.setup.beforeConsentPersistence = { await gap.hold() }
            let restriction = f.setup.withdrawMotionConsent()
            defer { Task { await gap.releaseAll() } }
            try await o8pEventually { await gap.count == 1 }
            let journal = f.phone.appendingPathComponent("OwnerChannel-v2/journal.json")
            let original = try Data(contentsOf: journal)
            try Data("broken-synthetic-journal".utf8).write(to: journal)
            await gap.releaseAll(); await restriction.value
            #expect(f.setup.lastError != nil)
            try original.write(to: journal)
            let (bundle, _) = try f.source().write(heartRate: .excludedByOwner)
            await o8pReject { _ = try await f.publish(bundle) }
            #expect(try OwnerPracticeReceiptStore(base: f.phone).receipt(practiceID: f.practiceID, revision: 1) == nil)
        }
    }

    @Test func pendingEndAndRetiredHistoricalContextsDoNotRequireCaptureAdmission() async throws {
        try await o8pFixture { f in
            await f.setup.endPractice().value
            #expect(f.setup.channel?.admissionBlocked == true)
            #expect(f.setup.channel?.authority?.isCollectionAllowed == true)
            let source = try f.source()
            let (bundle, receipt) = try source.write()
            #expect(try await f.publish(bundle) == receipt)
            #expect(f.setup.acceptedCurrent == nil && f.setup.acceptedNext == nil)
        }
    }

    @Test func publicationReadsLiveNamespaceAndRejectsAnotherOwnerScope() async throws {
        try await o8pFixture { f in
            let other = try OwnerPracticeIdentity.enrolled(ownerID: UUID(),
                phoneInstallationEpoch: f.authority.phoneInstallationEpoch, watchInstallationEpoch: f.authority.watchInstallationEpoch,
                attestsWatchAccountOwner: true, acceptsMotionStudy: true, includesHeartRate: true,
                decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000, policyDigest: OwnerPracticePolicy.digest)
            let source = try O8HistoricalSource(base: f.directory("foreign"), authority: other)
            let (foreign, _) = try source.write()
            await o8pReject { _ = try await f.publish(foreign) }
            let cached = f.setup.channel?.authority
            let journal = f.phone.appendingPathComponent("OwnerChannel-v2/journal.json")
            try Data("corrupt-after-model-load".utf8).write(to: journal)
            #expect(f.setup.channel?.authority == cached)
            let (bundle, _) = try f.source().write()
            await o8pReject { _ = try await f.publish(bundle) }
        }
    }
}

@MainActor private func o8pFixture(library: Bool = false,
    beforeReplyCommit: (@Sendable (OwnerPreparationMessage) async -> Void)? = nil,
    _ body: (O8PhoneFixture) async throws -> Void) async throws {
    let f = try O8PhoneFixture(library: library, beforeReplyCommit: beforeReplyCommit)
    do {
        await f.setup.load()
        f.setup.setConsent(ownerConfirmed: true, motion: true, heartRate: true)
        try await body(f)
        await f.close()
    } catch { await f.close(); throw error }
}
@MainActor private final class O8PhoneFixture {
    let root: URL, phone: URL, authority: OwnerPracticeIdentity, practiceID = UUID()
    let remote: O8PhoneRemote, connection: RecordingConnectivity, setup: PracticeSetupModel
    let library: RecordingLibraryModel?
    init(library useLibrary: Bool, beforeReplyCommit: (@Sendable (OwnerPreparationMessage) async -> Void)?) throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("O8B-Phone-" + UUID().uuidString)
        phone = root.appendingPathComponent("phone")
        try FileManager.default.createDirectory(at: phone, withIntermediateDirectories: true)
        let remoteBase = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: remoteBase, withIntermediateDirectories: false)
        let bootstrap = try OwnerPhoneBootstrap(base: phone)
        let phoneEpoch = try bootstrap.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch }
        authority = try .enrolled(ownerID: UUID(), phoneInstallationEpoch: phoneEpoch, watchInstallationEpoch: UUID(),
            attestsWatchAccountOwner: true, acceptsMotionStudy: true, includesHeartRate: true,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000, policyDigest: OwnerPracticePolicy.digest)
        remote = try O8PhoneRemote(base: remoteBase, authority: authority)
        let enrollment = try OwnerAuthorityMutation.enrollment(authority), transition = try remote.enroll(enrollment)
        let initialAuthority = authority, practice = practiceID
        try bootstrap.withStores { _, channel in
            try channel.request(enrollment); _ = try channel.mirror(transition)
            try channel.beginPhonePractice(practiceID: practice, preparationID: UUID(), owner: initialAuthority)
        }
        let remote = self.remote
        let paths = try RecordingPaths(base: phone)
        connection = RecordingConnectivity(paths: paths,
            backgroundStateProvider: { .init(activated: true, hasContentPending: false) }, backgroundTimeout: 2,
            ownerTransportAdapter: .init(request: { _, reply in reply(.failure(.unavailable)) },
                control: { try remote.control($0) }, draft: { _ in }),
            practiceTransportAdapter: .init(available: { false }, transferFile: { _, _, _ in },
                transferReceipt: { _ in }))
        if useLibrary {
            let value = RecordingLibraryModel(paths: paths, activateConnectivity: false, injectedConnectivity: connection)
            library = value; setup = try #require(value.practiceSetup)
        } else {
            library = nil; setup = PracticeSetupModel(base: phone, connectivity: connection, beforeReplyCommit: beforeReplyCommit)
        }
    }
    func directory(_ name: String) throws -> URL {
        let result = root.appendingPathComponent(name + "-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: result, withIntermediateDirectories: false)
        return result
    }
    func source(samples: Bool = true) throws -> O8HistoricalSource {
        try .init(base: directory("source"), authority: authority, practiceID: samples ? practiceID : UUID(), samples: samples)
    }
    func publish(_ bundle: URL) async throws -> OwnerPracticeReceipt {
        let pending = try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: phone)
        defer { pending.cancel() }
        return try await setup.publishVerifiedPractice(scope: pending.scope, preparedPublication: pending)
    }
    func receive(_ bundle: URL, _ receipt: OwnerPracticeReceipt) async throws -> OwnerPracticeReceipt {
        try await withCheckedThrowingContinuation { continuation in
            connection.receivePracticeFile(from: bundle, metadata: ["kind": "PSLOwnerPractice1",
                "practiceID": receipt.practiceID.uuidString, "revision": String(receipt.revision),
                "sha256": receipt.bundleSHA256]) { continuation.resume(with: $0) }
        }
    }
    func close() async { await setup.closeForTesting(); try? FileManager.default.removeItem(at: root) }
}
private nonisolated final class O8PhoneRemote: @unchecked Sendable {
    private let queue = DispatchQueue(label: "PadelStrokeLab.tests.o8-remote")
    private let channel: PracticeSetupChannel
    init(base: URL, authority: OwnerPracticeIdentity) throws {
        channel = try PracticeSetupChannel(base: base, localInstallationEpoch: authority.watchInstallationEpoch,
            device: .watch, intent: .createNew)
    }
    func enroll(_ mutation: OwnerAuthorityMutation) throws -> OwnerAuthorityTransition { try queue.sync { try channel.sequence(mutation) } }
    func restrict(heartRateOnly: Bool) throws -> OwnerAuthorityTransition { try queue.sync {
        let authority = try #require(channel.readSnapshot().authority)
        let command = try heartRateOnly
            ? OwnerAuthorityMutation.heartRate(from: authority, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_100)
            : .withdraw(from: authority, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_101)
        return try channel.sequence(command)
    } }
    func control(_ data: Data) throws { try queue.sync {
        if case let .acknowledge(value) = try OwnerPreparationCodec.decode(data) { try channel.acknowledge(value) }
    } }
}
private actor O8PAsyncBarrier {
    private(set) var count = 0
    private var open = false, released: Set<Int> = []
    private var waiters: [Int: CheckedContinuation<Void, Never>] = [:]
    func hold() async {
        let id = count; count += 1
        if !open && !released.contains(id) { await withCheckedContinuation { waiters[id] = $0 } }
    }
    func release(_ id: Int) { released.insert(id); waiters.removeValue(forKey: id)?.resume() }
    func releaseAll() { open = true; let held = waiters.values; waiters.removeAll(); held.forEach { $0.resume() } }
}
private nonisolated final class O8PWorkerBarrier: @unchecked Sendable {
    private let lock = NSLock(), gate = DispatchSemaphore(value: 0)
    private var didEnter = false, expired = false
    var entered: Bool { lock.withLock { didEnter } }
    var timedOut: Bool { lock.withLock { expired } }
    func hold() { lock.withLock { didEnter = true }; if gate.wait(timeout: .now() + 5) != .success { lock.withLock { expired = true } } }
    func release() { gate.signal() }
}
private nonisolated final class O8PMessageResult: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<OwnerPreparationMessage?, OwnerTransportFailure>?
    var value: Result<OwnerPreparationMessage?, OwnerTransportFailure>? { lock.withLock { result } }
    func set(_ value: Result<OwnerPreparationMessage?, OwnerTransportFailure>) { lock.withLock { result = value } }
}
@MainActor private func o8pEventually(_ predicate: () async -> Bool) async throws {
    for _ in 0..<200 { if await predicate() { return }; try await Task.sleep(for: .milliseconds(10)) }
    Issue.record("Actual phone boundary did not complete within the finite observation window")
    throw O8AppFixtureFailure.timeout
}
@MainActor private func o8pReject(_ operation: () async throws -> Void) async {
    do { try await operation(); Issue.record("Current authority unexpectedly allowed publication") } catch {}
}

// This builder uses validated raw/O6 APIs in a distinct synthetic source namespace.
// It is historical evidence, never an authority gate or a replacement live app store.
@MainActor private final class O8HistoricalSource {
    let base: URL, paths: RecordingPaths, telemetry: OwnerPracticeTelemetry
    let contexts: [OwnerRecordingContext]
    init(base: URL, authority: OwnerPracticeIdentity, practiceID: UUID = UUID(), samples: Bool = true) throws {
        self.base = base
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        paths = try RecordingPaths(base: base)
        let wall = 1_800_000_000.0, mono = 1_000.0, runtime = UUID(), consent = UUID(), query = UUID()
        let header = try OwnerTelemetryHeader(authority: authority, practiceID: practiceID,
            clock: RecordingClock(domainID: UUID(), monotonicAnchorSeconds: mono, wallAnchorUnixSeconds: wall),
            runtimeGeneration: runtime, clockUncertaintySeconds: 0)
        var value = try OwnerPracticeTelemetry(header: header, authority: authority,
            initialConsentSegmentID: consent, initialQueryGeneration: authority.heartRateConsent ? query : nil)
        let original = try OwnerPracticeStore(base: base, localInstallationEpoch: authority.watchInstallationEpoch,
            device: .watch, intent: .createNew)
        try original.enroll(authority)
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
            _ = try original.publish(binding, expectedRevision: authority.revision)
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
        _ = try original.retire(scope: .practice, id: practiceID, expectedRevision: authority.revision)
        for context in contexts {
            guard case .retired = try original.inspectContext(recordingID: context.recordingID) else {
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

