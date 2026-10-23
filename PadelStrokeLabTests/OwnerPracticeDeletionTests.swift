import Darwin
import Foundation
import Testing
@testable import PadelCore
@testable import PadelStrokeLab

// Private full-O9 proposal. New whole-practice action is explicit; legacy deletion stays scoped.
@Suite(.serialized) @MainActor struct OwnerPracticeDeletionTests {
    @Test func receivedDeleteFencesPublicationBeforeItsAsyncHandlerRuns() async throws {
        try await o9pFixture { f in
            await f.library.open(f.source.contexts[0].recordingID)
            let (incoming, receipt) = try f.source.write(revision: 3)
            let prepared = try OwnerPracticeBundle.prepareImport(from: incoming, destinationBase: f.phone)
            let boundary = O9PWorkerBarrier(), ingress = O9PAsyncBarrier()
            let original = try #require(f.connection.onPracticeDeletion)
            f.connection.onPracticeDeletion = { command in
                await ingress.hold()
                return try await original(command)
            }
            f.setup.beforePracticeRename = { boundary.hold() }
            let publishing = Task { try await f.setup.publishVerifiedPractice(scope: prepared.scope, preparedPublication: prepared) }
            defer { boundary.release(); prepared.cancel(); Task { await ingress.release() } }
            try await o9pEventually { boundary.entered }
            let command = try OwnerPracticeDeletionCommand(operationID: UUID(), authority: f.authority,
                practiceID: f.practiceID, recordingIDs: f.receipts[0].recordingIDs, revisions: f.receipts, requester: .watch)
            f.connection.receiveUserInfo(["kind": "PSLOwnerPracticeDelete1", "payload": try command.encoded()])
            try await o9pEventually { await ingress.entered }
            // The delegate has accepted Delete, but no application handler has run.
            boundary.release()
            if case .success = await publishing.result { Issue.record("Wire Delete ingress allowed an already-held rename before its async handler") }
            prepared.cancel(); f.setup.beforePracticeRename = nil
            let published = try OwnerPracticeReceiptStore(base: f.phone).receipt(practiceID: f.practiceID, revision: receipt.revision)
            #expect(published == nil)
            await f.library.prepareExport(f.source.contexts[0].recordingID)
            #expect(f.library.exportURL == nil, "Export must be fenced during the actual receiveUserInfo-to-handler gap")
            await ingress.release(); try await f.drainConnection()
            #expect(!boundary.timedOut)
        }
    }
    @Test func explicitWholePracticeDeleteRemovesAllRevisionsAndManagedExportsAfterWithdrawal() async throws {
        try await o9pFixture { f in
            await f.library.open(f.source.contexts[0].recordingID)
            await f.library.prepareExport(f.source.contexts[0].recordingID)
            let exported = try #require(f.library.exportURL)
            let external = f.root.appendingPathComponent("independent-export.pslpractice")
            try FileManager.default.copyItem(at: exported, to: external)
            let externalBytes = try Data(contentsOf: external), unrelated = try f.unrelatedBytes()
            try await f.withdraw()
            #expect(f.setup.channel?.authority?.isCollectionAllowed == false)
            await f.library.deletePractice(f.practiceID).value
            try f.assertGone()
            #expect(!FileManager.default.fileExists(atPath: exported.path))
            let remainingExternal = try Data(contentsOf: external)
            #expect(remainingExternal == externalBytes)
            let remainingUnrelated = try f.unrelatedBytes()
            #expect(remainingUnrelated == unrelated)
            let observed = try f.status()
            let status = try #require(observed)
            #expect(status.localComplete && !status.peerComplete)
            #expect(f.library.exportURL == nil)
            await f.library.refresh()
            #expect(!f.library.recordings.contains { f.receipts[0].recordingIDs.contains($0.id) })
        }
    }

    @Test func sameTurnPendingDeleteFencesHeldPublicationAndLateImportsReceiptsAndExport() async throws {
        try await o9pFixture { f in
            let (oldRevision, receipt) = try f.source.write(revision: 3)
            let prepared = try OwnerPracticeBundle.prepareImport(from: oldRevision, destinationBase: f.phone)
            let boundary = O9PWorkerBarrier(), gap = O9PAsyncBarrier()
            f.setup.beforePracticeRename = { boundary.hold() }
            f.setup.beforePracticeDeletion = { await gap.hold() }
            let publishing = Task { try await f.setup.publishVerifiedPractice(scope: prepared.scope, preparedPublication: prepared) }
            defer { boundary.release(); prepared.cancel(); Task { await gap.release() } }
            try await o9pEventually { boundary.entered }
            let deleting = f.library.deletePractice(f.practiceID)
            // Ingress is synchronous: releasing the worker now cannot let the old fence publish.
            boundary.release()
            let outcome = await publishing.result
            if case .success = outcome { Issue.record("Pending deletion lost the synchronous publication fence") }
            try await o9pEventually { await gap.entered }
            prepared.cancel()
            f.setup.beforePracticeRename = nil
            await o9pReject { _ = try await f.receive(oldRevision, receipt) }
            await f.library.prepareExport(f.source.contexts[0].recordingID)
            #expect(f.library.exportURL == nil)
            await gap.release(); await deleting.value
            f.connection.receiveUserInfo(["kind": "PSLOwnerPracticeReceipt1", "payload": try receipt.encoded()])
            f.connection.receiveUserInfo(["kind": "PSLReceipt1", "recordingID": f.source.contexts[0].recordingID.uuidString,
                "sha256": receipt.bundleSHA256])
            await o9pReject { _ = try await f.receive(f.bundle, f.receipts[0]) }
            try f.assertGone()
            let observed = try f.status()
            #expect(observed?.peerComplete == false)
            #expect(!boundary.timedOut)
        }
    }

    @Test func actualRemovalFailureStaysIncompleteAndRestartResumesDurableOperation() async throws {
        try await o9pFixture { f in
            let trace = O9PDeletionTrace()
            f.setup.practiceDeletionFault = {
                trace.record($0)
                if $0 == .rawRemoved { throw O9PhoneFailure.injected }
            }
            await f.library.deletePractice(f.practiceID).value
            let observedFailure = try f.status()
            let diagnostic = "Stages: \(trace.summary); library: \(String(describing: f.library.error)); setup: \(String(describing: f.setup.lastError)); deletion: \(String(describing: f.library.practiceDeletionMessage))"
            let failed = try #require(observedFailure, "\(diagnostic)")
            #expect(!failed.localComplete && !failed.peerComplete)
            await f.restart()
            await f.library.deletePractice(f.practiceID).value
            let observedRecovery = try f.status()
            let recovered = try #require(observedRecovery)
            #expect(recovered.command == failed.command && recovered.localComplete && !recovered.peerComplete)
            try f.assertGone()
            await f.restart()
            #expect(f.setup.lastError == nil)
            await o9pReject { _ = try await f.receive(f.bundle, f.receipts[0]) }
        }
    }

    @Test func offlinePairedDeleteWaitsForActualPeerCleanupAndExactAcknowledgment() async throws {
        try await o9pFixture { f in
            let trace = O9PDeletionTrace()
            f.setup.practiceDeletionFault = { trace.record($0) }
            await f.library.deletePractice(f.practiceID).value
            let observedLocal = try f.status()
            let diagnostic = "Stages: \(trace.summary); library: \(String(describing: f.library.error)); setup: \(String(describing: f.setup.lastError)); deletion: \(String(describing: f.library.practiceDeletionMessage))"
            let local = try #require(observedLocal, "\(diagnostic)")
            #expect(local.localComplete && !local.peerComplete && f.link.commands.isEmpty)
            let beforeRemote = try OwnerPracticeTransferInventory.snapshots(base: f.remoteBase)
            #expect(beforeRemote.count == 2)
            f.link.available = true; f.connection.resumePracticeDeletions()
            try await o9pEventually { !f.link.commands.isEmpty }
            let bytes = try #require(f.link.commands.first)
            let command = try OwnerPracticeDeletionCommand.decode(bytes)
            #expect(command == local.command && command.practiceID == f.practiceID)
            #expect(Set(command.recordingIDs) == Set(f.receipts[0].recordingIDs))
            // A transport send and a raw/practice receipt do not complete paired erasure.
            let beforeAcknowledgment = try f.status()
            #expect(beforeAcknowledgment?.peerComplete == false)
            let wrongOperation = try OwnerPracticeDeletionCommand(operationID: UUID(), authority: f.authority,
                practiceID: command.practiceID, recordingIDs: command.recordingIDs, revisions: f.receipts, requester: .phone)
            let wrongAck = try OwnerPracticeDeletionAcknowledgment(command: wrongOperation, device: .watch)
            f.connection.receiveUserInfo(["kind": "PSLOwnerPracticeDeleteAck1", "payload": try wrongAck.encoded()])
            try await f.drainConnection()
            let afterWrongAcknowledgment = try f.status()
            #expect(afterWrongAcknowledgment?.peerComplete == false)
            // The synthetic peer runs real covered cleanup through its retained channel owner.
            let ack = try f.remote.delete(command)
            let afterRemote = try OwnerPracticeTransferInventory.snapshots(base: f.remoteBase)
            #expect(afterRemote.isEmpty)
            let repeated = try f.remote.delete(command)
            #expect(repeated == ack)
            f.connection.receiveUserInfo(["kind": "PSLOwnerPracticeDeleteAck1", "payload": try ack.encoded()])
            try await o9pEventually { (try? f.status()?.peerComplete) == true }
            f.connection.receiveUserInfo(["kind": "PSLOwnerPracticeDeleteAck1", "payload": try ack.encoded()])
            try await f.drainConnection()
            let finalCommand = try f.status()?.command
            let finalMatches = try finalCommand == command && f.status()?.peerComplete == true
            #expect(finalMatches)
            try f.assertGone()
        }
    }
}

@MainActor private func o9pFixture(_ body: (O9PhoneFixture) async throws -> Void) async throws {
    let f = try O9PhoneFixture()
    do { try await f.seed(); try await body(f); await f.close() }
    catch { await f.close(); throw error }
}
@MainActor private final class O9PhoneFixture {
    let root: URL, phone: URL, remoteBase: URL, paths: RecordingPaths, authority: OwnerPracticeIdentity, practiceID = UUID()
    let remote: O9PhoneRemote, link = O9PDeletionLink()
    let source: O9HistoricalSource, bundle: URL, receipts: [OwnerPracticeReceipt], revision: URL
    private(set) var connection: RecordingConnectivity
    private(set) var library: RecordingLibraryModel
    var setup: PracticeSetupModel { library.practiceSetup! }
    private var unrelated: O9HistoricalSource?
    init() throws {
        guard let resolved = realpath(FileManager.default.temporaryDirectory.path, nil) else { throw CocoaError(.fileReadUnknown) }
        defer { free(resolved) }
        root = URL(fileURLWithPath: String(cString: resolved)).appendingPathComponent("O9-Phone-" + UUID().uuidString)
        phone = root.appendingPathComponent("phone"); remoteBase = root.appendingPathComponent("peer")
        try FileManager.default.createDirectory(at: phone, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: remoteBase, withIntermediateDirectories: false)
        let bootstrap = try OwnerPhoneBootstrap(base: phone)
        let epoch = try bootstrap.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch }
        authority = try .enrolled(ownerID: UUID(), phoneInstallationEpoch: epoch, watchInstallationEpoch: UUID(),
            attestsWatchAccountOwner: true, acceptsMotionStudy: true, includesHeartRate: true,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000, policyDigest: OwnerPracticePolicy.digest)
        remote = try O9PhoneRemote(base: remoteBase, authority: authority)
        let mutation = try OwnerAuthorityMutation.enrollment(authority), transition = try remote.enroll(mutation)
        let enrolled = authority, practice = practiceID
        try bootstrap.withStores { _, channel in
            try channel.request(mutation); _ = try channel.mirror(transition)
            try channel.beginPhonePractice(practiceID: practice, preparationID: UUID(), owner: enrolled)
        }
        source = try O9HistoricalSource(base: root.appendingPathComponent("source"), authority: authority, practiceID: practiceID)
        let first = try source.write(), second = try source.write(heartRate: .excludedByOwner, revision: 2)
        bundle = first.0; revision = second.0; receipts = [first.1, second.1]
        paths = try RecordingPaths(base: phone)
        connection = Self.makeConnection(paths, link: link, remote: remote)
        library = RecordingLibraryModel(paths: paths, activateConnectivity: false, injectedConnectivity: connection)
    }
    private static func makeConnection(_ paths: RecordingPaths, link: O9PDeletionLink, remote: O9PhoneRemote) -> RecordingConnectivity {
        RecordingConnectivity(paths: paths, backgroundStateProvider: { .init(activated: true, hasContentPending: false) }, backgroundTimeout: 2,
            ownerTransportAdapter: .init(request: { _, reply in reply(.failure(.unavailable)) }, control: { try remote.control($0) }, draft: { _ in }),
            practiceTransportAdapter: .init(available: { false }, transferFile: { _, _, _ in }, transferReceipt: { _ in }),
            practiceDeletionTransportAdapter: link.adapter)
    }
    func seed() async throws {
        await setup.load(); setup.setConsent(ownerConfirmed: true, motion: true, heartRate: true)
        _ = try await receive(bundle, receipts[0]); _ = try await receive(revision, receipts[1])
        try remote.seed(bundle); try remote.seed(revision)
        let other = try O9HistoricalSource(base: root.appendingPathComponent("other"), authority: authority)
        let (file, receipt) = try other.write(); _ = try await receive(file, receipt)
        unrelated = other
        await library.refresh()
    }
    func receive(_ url: URL, _ receipt: OwnerPracticeReceipt) async throws -> OwnerPracticeReceipt {
        try await withCheckedThrowingContinuation { continuation in
            connection.receivePracticeFile(from: url, metadata: ["kind": "PSLOwnerPractice1", "practiceID": receipt.practiceID.uuidString,
                "revision": String(receipt.revision), "sha256": receipt.bundleSHA256]) { continuation.resume(with: $0) }
        }
    }
    func withdraw() async throws {
        let transition = try remote.withdraw()
        let bytes = try OwnerPreparationCodec.encode(.transition(transition))
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OwnerPreparationMessage?, any Error>) in
            connection.receiveOwnerData(bytes, delivery: .control) { continuation.resume(with: $0.mapError { $0 as any Error }) }
        }
    }
    func status() throws -> OwnerPracticeDeletionStatus? { try OwnerPracticeDeletion.status(base: phone, practiceID: practiceID) }
    func drainConnection() async throws {
        let drained = await withCheckedContinuation { continuation in
            _ = connection.drainForBackground { continuation.resume(returning: $0) }
        }
        #expect(drained, "Counted deletion/receipt handlers must finish before observation")
    }
    func restart() async {
        await setup.closeForTesting()
        connection = Self.makeConnection(paths, link: link, remote: remote)
        library = RecordingLibraryModel(paths: paths, activateConnectivity: false, injectedConnectivity: connection)
        await setup.load()
    }
    func unrelatedBytes() throws -> Data {
        let other = try #require(unrelated)
        return try OwnerPracticeReceiptStore(base: phone).open(practiceID: other.telemetry.header.practiceID, revision: 1).receipt.encoded()
    }
    func assertGone() throws {
        let snapshots = try OwnerPracticeTransferInventory.snapshots(base: phone)
        #expect(!snapshots.contains { $0.receipt.practiceID == practiceID })
        for id in receipts[0].recordingIDs {
            for root in [paths.rawRoot, paths.notesRoot, paths.inboxRoot] {
                #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(id.uuidString).path))
            }
        }
        for root in [paths.outboxRoot, paths.inboxRoot] {
            for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) where url.pathExtension == "pslpractice" {
                let bytes = try Data(contentsOf: url)
                let first = try Data(contentsOf: bundle), second = try Data(contentsOf: revision)
                #expect(bytes != first && bytes != second)
            }
        }
    }
    func close() async { await setup.closeForTesting(); remote.close(); try? FileManager.default.removeItem(at: root) }
}
private nonisolated final class O9PhoneRemote: @unchecked Sendable {
    private let queue = DispatchQueue(label: "PadelStrokeLab.tests.o9-peer")
    private let base: URL
    private var channel: PracticeSetupChannel?
    init(base: URL, authority: OwnerPracticeIdentity) throws {
        self.base = base
        channel = try PracticeSetupChannel(base: base, localInstallationEpoch: authority.watchInstallationEpoch, device: .watch, intent: .createNew)
    }
    func enroll(_ value: OwnerAuthorityMutation) throws -> OwnerAuthorityTransition { try queue.sync { try channel!.sequence(value) } }
    func control(_ bytes: Data) throws { try queue.sync {
        if case let .acknowledge(value) = try OwnerPreparationCodec.decode(bytes) { try channel!.acknowledge(value) }
    } }
    func seed(_ url: URL) throws { try queue.sync {
        let pending = try OwnerPracticeBundle.prepareImport(from: url, destinationBase: base)
        defer { pending.cancel() }
        try OwnerPracticePublicationPermission.require(pending.scope, current: channel!.readSnapshot())
        try pending.renameForPublication(); _ = try pending.confirmPublication()
    } }
    func withdraw() throws -> OwnerAuthorityTransition { try queue.sync {
        let snapshot = try channel!.readSnapshot()
        let owner = try #require(snapshot.authority)
        return try channel!.sequence(.withdraw(from: owner, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_100))
    } }
    func delete(_ command: OwnerPracticeDeletionCommand) throws -> OwnerPracticeDeletionAcknowledgment { try queue.sync {
        try OwnerPracticeDeletion.perform(command: command, base: base, device: .watch, channel: #require(channel))
    } }
    func close() { queue.sync { channel = nil } }
}
private nonisolated final class O9PDeletionLink: @unchecked Sendable {
    private let lock = NSLock()
    private var online = false, sent: [Data] = []
    var available: Bool { get { lock.withLock { online } } set { lock.withLock { online = newValue } } }
    var commands: [Data] { lock.withLock { sent } }
    var adapter: OwnerPracticeDeletionTransportAdapter {
        .init(available: { [self] in available }, transferCommand: { [self] bytes in lock.withLock { sent.append(bytes) } }, transferAcknowledgment: { _ in })
    }
}
private nonisolated final class O9PDeletionTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var stages: [String] = []
    func record(_ stage: OwnerPracticeDeletionStage) { lock.withLock { stages.append(String(describing: stage)) } }
    var summary: String { lock.withLock { stages.joined(separator: ", ") } }
}
private actor O9PAsyncBarrier {
    private(set) var entered = false
    private var open = false, waiter: CheckedContinuation<Void, Never>?
    func hold() async { entered = true; if !open { await withCheckedContinuation { waiter = $0 } } }
    func release() { open = true; waiter?.resume(); waiter = nil }
}
private nonisolated final class O9PWorkerBarrier: @unchecked Sendable {
    private let lock = NSLock(), gate = DispatchSemaphore(value: 0)
    private var arrived = false, expired = false
    var entered: Bool { lock.withLock { arrived } }
    var timedOut: Bool { lock.withLock { expired } }
    func hold() { lock.withLock { arrived = true }; if gate.wait(timeout: .now() + 5) != .success { lock.withLock { expired = true } } }
    func release() { gate.signal() }
}
@MainActor private func o9pEventually(_ condition: () async -> Bool) async throws {
    for _ in 0..<200 { if await condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
    Issue.record("Actual phone deletion boundary did not complete")
    throw O9PhoneFailure.timeout
}
@MainActor private func o9pReject(_ operation: () async throws -> Void) async {
    do { try await operation(); Issue.record("Deleted practice was admitted") } catch {}
}
private nonisolated enum O9PhoneFailure: Error { case injected, timeout }

// This builder uses validated raw/O6 APIs in a distinct synthetic source namespace.
// It is historical evidence, never an authority gate or a replacement live app store.
@MainActor private final class O9HistoricalSource {
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
                throw O9AppFixtureFailure.invariant
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
private nonisolated enum O9AppFixtureFailure: Error { case invariant, timeout }

