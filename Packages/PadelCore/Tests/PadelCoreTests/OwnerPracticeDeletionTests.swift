import Darwin
import Foundation
import Testing
@testable import PadelCore

// O9 tests-first. perform runs under the caller's existing exclusive channel owner.
// Fault hooks stop real boundaries; neither cleanup nor authority is mocked.
@Suite(.serialized) struct OwnerPracticeDeletionTests {
    @Test(arguments: [".owner-readback-", ".owner-export-"], [false, true])
    func crashLeftOwnedExportStagesCannotSurviveCompletedDeletion(prefix: String, malformed: Bool) throws {
        try o9WithDirectory { root in
            let f = try O9CoreFixture(root)
            let target = try o9CrashStage(prefix: prefix, bundle: f.sourceBundle, outbox: f.paths.outboxRoot)
            if malformed {
                let payload = target.appendingPathComponent(prefix == ".owner-readback-" ? "bundle" : "telemetry.json")
                try Data("interrupted-unattributable-private-payload".utf8).write(to: payload)
            }
            let otherBundle = try o9OtherPracticeBundle(source: f.source, destination: root.appendingPathComponent("other.pslpractice"))
            let unrelated = try o9CrashStage(prefix: prefix, bundle: otherBundle, outbox: f.paths.outboxRoot)
            let unrelatedBefore = try o9Files(unrelated)
            var acknowledged = false
            do { _ = try f.delete(); acknowledged = true } catch { }
            let observed = try OwnerPracticeDeletion.status(base: f.base, practiceID: f.command.practiceID)
            if malformed {
                #expect(!acknowledged && observed?.localComplete != true, "Unattributable private stage content must keep deletion incomplete")
            } else if acknowledged {
                #expect(!FileManager.default.fileExists(atPath: target.path), "Actual owned export staging bytes remained after complete acknowledgment")
                #expect(observed?.localComplete == true)
            } else {
                #expect(observed?.localComplete != true)
            }
            let unrelatedAfter = try o9Files(unrelated)
            #expect(unrelatedAfter == unrelatedBefore, "A verified different practice's staging bytes must remain untouched")
        }
    }
    @Test func omittedPublishedContextRejectsDeletionBeforeRemovingAnyPracticeContent() throws {
        try o9WithDirectory { root in
            let f = try O9CoreFixture(root, unadmittedContext: true)
            let before = try f.payloadSnapshot().filter {
                !$0.key.contains("/.transactions/") && !$0.key.contains("/.capture-")
            }
            #expect(throws: (any Error).self) { _ = try f.delete() }
            let observed = try OwnerPracticeDeletion.status(base: f.base, practiceID: f.command.practiceID)
            #expect(observed?.localComplete != true)
            let after = try f.payloadSnapshot().filter {
                !$0.key.contains("/.transactions/") && !$0.key.contains("/.capture-")
            }
            #expect(after == before, "A published same-practice context omitted from telemetry and command inventory must prevent cleanup and acknowledgment")
        }
    }
    @Test func deletesEveryRevisionAndOwnedCopyButPreservesUnrelatedAndIndependentFiles() throws {
        try o9WithDirectory { root in
            let f = try O9CoreFixture(root)
            let unrelated = try f.unrelatedSnapshot()
            let ack = try f.delete()
            #expect(ack.command == f.command && ack.device == .watch)
            try f.assertGone()
            let unchanged = try f.unrelatedSnapshot()
            #expect(unchanged == unrelated)
            let independentBytes = try Data(contentsOf: f.independent), sourceBytes = try Data(contentsOf: f.sourceBundle)
            #expect(independentBytes == sourceBytes)
            let observed = try OwnerPracticeDeletion.status(base: f.base, practiceID: f.command.practiceID)
            let status = try #require(observed)
            #expect(status.localComplete && !status.peerComplete)
            // A completed idempotent retry cannot reset the tombstone or acknowledge another scope.
            let repeated = try f.delete()
            #expect(repeated == ack)
            try f.reopenAndAssertNonreuse()
        }
    }

    @Test(arguments: [OwnerPracticeDeletionStage.intentPersisted, .rawRemoved, .contextsRemoved, .beforeCompletion])
    func interruptedCleanupPersistsMinimalIntentThenResumes(stage: OwnerPracticeDeletionStage) throws {
        try o9WithDirectory { root in
            let f = try O9CoreFixture(root)
            #expect(throws: O9Injected.stop) {
                _ = try f.delete(fault: { reached in
                    if reached == .intentPersisted {
                        let observed = try OwnerPracticeDeletion.status(base: f.base, practiceID: f.command.practiceID)
                        let status = try #require(observed)
                        #expect(!status.localComplete && status.command == f.command)
                        #expect(FileManager.default.fileExists(atPath: f.paths.rawRoot.appendingPathComponent(f.command.recordingIDs[0].uuidString).path))
                    }
                    if reached == stage { throw O9Injected.stop }
                })
            }
            let observed = try OwnerPracticeDeletion.status(base: f.base, practiceID: f.command.practiceID)
            let pending = try #require(observed)
            #expect(!pending.localComplete && !pending.peerComplete)
            let ledger = f.base.appendingPathComponent(OwnerPracticeDeletion.directoryName)
            for (_, bytes) in try o9Files(ledger) {
                #expect(bytes.count <= 32_768 && !o8HasHR(bytes))
                let text = String(decoding: bytes, as: UTF8.self)
                #expect(!text.contains("cleanContact") && !text.contains("mishit") && !text.contains("rawMetadataBytes"))
            }
            try f.reopen()
            _ = try f.delete()
            try f.assertGone()
            try f.reopenAndAssertNonreuse()
        }
    }

    @Test func failedIntentPersistenceRemovesNoContent() throws {
        try o9WithDirectory { root in
            let f = try O9CoreFixture(root), before = try f.payloadSnapshot()
            #expect(throws: O9Injected.stop) {
                _ = try f.delete(fault: { if $0 == .beforeIntent { throw O9Injected.stop } })
            }
            let after = try f.payloadSnapshot()
            #expect(after == before)
            let observed = try OwnerPracticeDeletion.status(base: f.base, practiceID: f.command.practiceID)
            #expect(observed?.localComplete != true)
            _ = try f.delete(); try f.assertGone()
        }
    }

    @Test(arguments: [false, true])
    func actualCaptureAndPublicationLeasesPreventPrematureRemoval(publication: Bool) throws {
        try o9WithDirectory { root in
            let f = try O9CoreFixture(root)
            var capture: RecordingCaptureLease? = publication ? nil : try RecordingCaptureLease(recordingID: f.command.recordingIDs[0], rawRoot: f.paths.rawRoot)
            var publishing: OwnerPracticePublicationLease? = publication ? try OwnerPracticeReceiptStore(base: f.base).acquirePublicationLease() : nil
            #expect(throws: (any Error).self) { _ = try f.delete() }
            #expect(FileManager.default.fileExists(atPath: f.paths.rawRoot.appendingPathComponent(f.command.recordingIDs[0].uuidString).path))
            let observed = try OwnerPracticeDeletion.status(base: f.base, practiceID: f.command.practiceID)
            #expect(observed?.localComplete != true)
            withExtendedLifetime(capture) {}; withExtendedLifetime(publishing) {}
            capture = nil; publishing = nil
            _ = try f.delete(); try f.assertGone()
        }
    }

    @Test func realRecordingTransactionIsAcquiredOnceAndCleanupWaitsForItsOwner() throws {
        try o9WithDirectory { root in
            let f = try O9CoreFixture(root)
            var transaction: RecordingLocalTransaction? = try RecordingLocalTransaction(recordingID: f.command.recordingIDs[0], notesRoot: f.paths.notesRoot)
            let contended = DispatchSemaphore(value: 0), finished = DispatchSemaphore(value: 0)
            let result = O9ThreadResult()
            let worker = Thread {
                defer { finished.signal() }
                do { _ = try f.delete(onLeaseContention: { contended.signal() }); result.finish(nil) }
                catch { result.finish(error) }
            }
            worker.start()
            #expect(contended.wait(timeout: .now() + 5) == .success)
            #expect(FileManager.default.fileExists(atPath: f.paths.rawRoot.appendingPathComponent(f.command.recordingIDs[0].uuidString).path))
            withExtendedLifetime(transaction) {}; transaction = nil
            #expect(finished.wait(timeout: .now() + 5) == .success, "Already-held recording locks must not be recursively acquired")
            #expect(result.completed && result.error == nil)
            try f.assertGone()
        }
    }

    @Test func exactCommandCodecRejectsConflictsAndForeignOwnerWithoutCleanup() throws {
        try o9WithDirectory { root in
            let f = try O9CoreFixture(root), before = try f.payloadSnapshot()
            let bytes = try f.command.encoded()
            #expect(bytes.count <= 32_768 && !o8HasHR(bytes))
            let decoded = try OwnerPracticeDeletionCommand.decode(bytes)
            #expect(decoded == f.command)
            #expect(throws: (any Error).self) { _ = try OwnerPracticeDeletionCommand.decode(Data(bytes.dropLast())) }
            let other = try o6Authority(heartRate: true)
            let foreign = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: other.phoneInstallationEpoch,
                watchInstallationEpoch: other.watchInstallationEpoch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
                includesHeartRate: true, decisionID: UUID(), confirmedAtUnixSeconds: o6Wall, policyDigest: OwnerPracticePolicy.digest)
            #expect(throws: (any Error).self) {
                let forged = try OwnerPracticeDeletionCommand(operationID: f.command.operationID, authority: foreign,
                    practiceID: f.command.practiceID, recordingIDs: f.command.recordingIDs, revisions: f.receipts, requester: .phone)
                _ = try f.delete(command: forged)
            }
            let after = try f.payloadSnapshot()
            #expect(after == before)
            _ = try f.delete()
            #expect(throws: (any Error).self) {
                let conflicting = try OwnerPracticeDeletionCommand(operationID: f.command.operationID,
                    authority: other, practiceID: f.command.practiceID, recordingIDs: [f.command.recordingIDs[0]], revisions: [], requester: .phone)
                _ = try f.delete(command: conflicting)
            }
            try f.assertGone()
        }
    }
}

private final class O9CoreFixture: @unchecked Sendable {
    let base: URL, paths: RecordingPaths, source: O8Fixture, sourceBundle: URL, independent: URL
    let receipts: [OwnerPracticeReceipt], command: OwnerPracticeDeletionCommand
    private var channel: PracticeSetupChannel?
    private let legacy: URL
    init(_ root: URL, unadmittedContext: Bool = false) throws {
        source = try O8Fixture(o8Directory(root, "source"))
        let (bundle, receipt) = try source.write()
        sourceBundle = bundle
        base = try o8Directory(root, "watch"); paths = try RecordingPaths(base: base)
        let authority = try o6Authority(heartRate: true)
        let channel = try PracticeSetupChannel(base: base, localInstallationEpoch: o6Watch, device: .watch, intent: .createNew)
        _ = try channel.sequence(.enrollment(authority))
        for (index, context) in source.contexts.enumerated() {
            let raw = paths.outboxRoot.appendingPathComponent(context.recordingID.uuidString + "-" + UUID().uuidString + ".pslrecording")
            _ = try RecordingArchive.write(recordingID: context.recordingID, rawRoot: source.paths.rawRoot,
                timeline: source.timelines[index], destination: raw)
            _ = try RecordingArchive.importBundle(from: raw, rawRoot: paths.rawRoot, notesRoot: paths.notesRoot)
            try SessionAnnotationsStore(root: paths.notesRoot).saveLabels(source.labels[index], recordingID: context.recordingID)
            let binding = try OwnerRecordingContext.bind(rawMetadataBytes: RecordingChunkCodec.encodeMetadata(context.metadata),
                authority: authority, practiceID: context.practiceID, acceptedSetup: context.acceptedSetup, generations: context.generations)
            _ = try channel.publish(binding, expectedRevision: authority.revision)
            let copied = try RecordingLocalCopies.copyIncoming(raw, recordingID: context.recordingID, paths: paths)
            _ = copied
            let partial = paths.outboxRoot.appendingPathComponent(".pending-auto-\(context.recordingID.uuidString)-\(UUID().uuidString)")
            try Data("synthetic partial raw payload".utf8).write(to: partial)
            let derived = paths.notesRoot.appendingPathComponent(context.recordingID.uuidString).appendingPathComponent("derived.json")
            try Data("synthetic private result".utf8).write(to: derived)
        }
        if unadmittedContext {
            let extra = try O8Fixture(o8Directory(root, "unadmitted-source"), count: 3)
            let context = try #require(extra.contexts.last)
            let binding = try OwnerRecordingContext.bind(rawMetadataBytes: RecordingChunkCodec.encodeMetadata(context.metadata),
                authority: authority, practiceID: receipt.practiceID, acceptedSetup: context.acceptedSetup, generations: context.generations)
            _ = try channel.publish(binding, expectedRevision: authority.revision)
            #expect(!source.telemetry.sets.contains { $0.context.recordingID == context.recordingID })
            #expect(!receipt.recordingIDs.contains(context.recordingID))
        }
        _ = try channel.sequence(.retirePractice(from: authority, practiceID: receipt.practiceID, mutationID: UUID()))
        let telemetry = try OwnerTelemetryStore.create(base: base, telemetry: source.telemetry); telemetry.close()
        _ = try o8Publish(bundle, to: base)
        let (second, revised) = try source.write("r2.pslpractice", revision: 2, heartRate: .excludedByOwner)
        _ = try o8Publish(second, to: base)
        receipts = [receipt, revised]
        for original in [bundle, second] {
            for destination in [paths.inboxRoot.appendingPathComponent(UUID().uuidString + ".pslpractice"),
                paths.outboxRoot.appendingPathComponent("export-" + UUID().uuidString + ".pslpractice"),
                paths.outboxRoot.appendingPathComponent(UUID().uuidString + ".practice-staging")] {
                try FileManager.default.copyItem(at: original, to: destination)
            }
        }
        independent = root.appendingPathComponent("independent-export.pslpractice")
        try FileManager.default.copyItem(at: bundle, to: independent)
        legacy = paths.rawRoot.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: false)
        try Data("unassigned legacy private bytes".utf8).write(to: legacy.appendingPathComponent("preserve.bin"))
        command = try OwnerPracticeDeletionCommand(operationID: UUID(), authority: authority,
            practiceID: receipt.practiceID, recordingIDs: receipt.recordingIDs, revisions: receipts, requester: .phone)
        self.channel = channel
    }
    func delete(command: OwnerPracticeDeletionCommand? = nil,
        fault: ((OwnerPracticeDeletionStage) throws -> Void)? = nil,
        onLeaseContention: (() -> Void)? = nil) throws -> OwnerPracticeDeletionAcknowledgment {
        try OwnerPracticeDeletion.perform(command: command ?? self.command, base: base, device: .watch,
            channel: #require(channel), fault: fault, onLeaseContention: onLeaseContention)
    }
    func reopen() throws {
        channel = nil
        channel = try PracticeSetupChannel(base: base, localInstallationEpoch: o6Watch, device: .watch, intent: .openExisting)
        _ = try channel!.readSnapshot()
    }
    func reopenAndAssertNonreuse() throws {
        try reopen()
        let snapshot = try channel!.readSnapshot()
        let current = try #require(snapshot.authority)
        for context in source.contexts {
            let directory = base.appendingPathComponent(OwnerPracticeStore.directoryName).appendingPathComponent("contexts").appendingPathComponent(context.recordingID.uuidString)
            let entries = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            #expect(entries.isEmpty)
            let binding = try OwnerRecordingContext.bind(rawMetadataBytes: RecordingChunkCodec.encodeMetadata(context.metadata),
                authority: current, practiceID: UUID(), acceptedSetup: context.acceptedSetup, generations: context.generations)
            #expect(throws: (any Error).self) { _ = try channel!.publish(binding, expectedRevision: current.revision) }
        }
    }
    func unrelatedSnapshot() throws -> [String: Data] { try o9Files(legacy) }
    func payloadSnapshot() throws -> [String: Data] {
        try o9Files(base).filter { !$0.key.hasPrefix(OwnerPracticeDeletion.directoryName + "/") }
    }
    func assertGone() throws {
        for id in command.recordingIDs {
            for root in [paths.rawRoot, paths.notesRoot, paths.inboxRoot] {
                #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(id.uuidString).path))
            }
            let context = base.appendingPathComponent(OwnerPracticeStore.directoryName).appendingPathComponent("contexts").appendingPathComponent(id.uuidString)
            let entries = try FileManager.default.contentsOfDirectory(atPath: context.path)
            #expect(entries.isEmpty)
        }
        let telemetry = base.appendingPathComponent(OwnerTelemetryStore.directoryName).appendingPathComponent(command.practiceID.uuidString.lowercased())
        #expect(!FileManager.default.fileExists(atPath: telemetry.appendingPathComponent("telemetry.json").path))
        let inventory = try OwnerPracticeTransferInventory.snapshots(base: base)
        #expect(inventory.isEmpty)
        let incoming = try FileManager.default.contentsOfDirectory(atPath: paths.inboxRoot.path)
        #expect(incoming.isEmpty)
        let outgoing = try FileManager.default.contentsOfDirectory(atPath: paths.outboxRoot.path)
        #expect(outgoing.isEmpty)
    }
}
private enum O9Injected: Error { case stop }
private func o9CrashStage(prefix: String, bundle: URL, outbox: URL) throws -> URL {
    let stage = outbox.appendingPathComponent(prefix + UUID().uuidString)
    try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
    let bytes = try Data(contentsOf: bundle)
    if prefix == ".owner-readback-" {
        try bytes.write(to: stage.appendingPathComponent("bundle"))
    } else {
        // Real export stages retain these components after bundle rename and before cleanup.
        for (name, content) in try o8Wire(bytes).components { try content.write(to: stage.appendingPathComponent(name)) }
    }
    return stage
}
private func o9OtherPracticeBundle(source: O8Fixture, destination: URL) throws -> URL {
    let authority = try o6Authority(heartRate: true), practiceID = UUID()
    let header = try OwnerTelemetryHeader(authority: authority, practiceID: practiceID, clock: source.telemetry.header.clock,
        runtimeGeneration: o6Runtime, clockUncertaintySeconds: 0)
    var value = try OwnerPracticeTelemetry(header: header, authority: authority,
        initialConsentSegmentID: o6Consent, initialQueryGeneration: o6Query)
    for (index, original) in source.contexts.enumerated() {
        let context = try OwnerRecordingContext.bind(rawMetadataBytes: RecordingChunkCodec.encodeMetadata(original.metadata),
            authority: authority, practiceID: practiceID, acceptedSetup: original.acceptedSetup, generations: original.generations).context
        let start = Double(10 + index * 40), raw = original.metadata.clock.monotonicAnchorSeconds
        try value.admitSet(context: context, mapping: o6Mapping(context, header: header), consentSegmentID: o6Consent,
            rawStartSeconds: raw, at: o6Instant(start))
        try value.stopSet(recordingID: context.recordingID, rawStopSeconds: raw + 2, at: o6Instant(start + 2))
    }
    try value.finalize(status: .ended, at: o6Instant(85), absenceReasons: [.noAccessibleHeartRateData])
    _ = try OwnerPracticeBundle.write(telemetry: value, rawRoot: source.paths.rawRoot, notesRoot: source.paths.notesRoot,
        revision: 1, heartRate: .asRecorded, destination: destination)
    return destination
}
private final class O9ThreadResult: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false, failure: String?
    var completed: Bool { lock.withLock { done } }
    var error: String? { lock.withLock { failure } }
    func finish(_ error: (any Error)?) { lock.withLock { done = true; failure = error.map(String.init(describing:)) } }
}
private func o9WithDirectory(_ body: (URL) throws -> Void) throws {
    guard let resolved = realpath(FileManager.default.temporaryDirectory.path, nil) else { throw CocoaError(.fileReadUnknown) }
    defer { free(resolved) }
    let root = URL(fileURLWithPath: String(cString: resolved), isDirectory: true).appendingPathComponent("O9-Core-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}
private func o9Files(_ root: URL) throws -> [String: Data] {
    var result: [String: Data] = [:]
    let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]))
    for case let url as URL in enumerator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
        result[String(url.path.dropFirst(root.path.count + 1))] = try Data(contentsOf: url)
    }
    return result
}
