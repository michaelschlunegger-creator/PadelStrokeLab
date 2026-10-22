import Darwin
import Foundation
import Testing
@testable import PadelCore
@testable import PadelStrokeLab

// Private O10 proposal: real accepted owner stores, actual import/review/save/export.
// Existing O6 math is the oracle for the correct set; no new sensor/quality inference.
@Suite(.serialized) @MainActor struct OwnerPracticeReviewTests {
    @Test(arguments: ["preview", "export", "persistenceFailure"])
    func localWithdrawalImmediatelyRemovesAnalysisAndExportButKeepsDeletion(mode: String) async throws {
        try await o10Fixture { f, model in
            let source = try f.source(), (bundle, receipt) = try source.write()
            _ = try await f.receive(bundle, receipt)
            await model.refresh()
            let id = source.contexts[0].recordingID
            await model.open(id)
            let original = try #require(model.selectedPractice)
            let rawBefore = try o10Files(original.snapshot.rawRoot)
            #expect(model.selected?.motionStatistics != nil && !original.recoveryByRecordingID.isEmpty)
            if mode == "preview" {
                await model.previewPracticeExport(id); try #require(model.practiceExportPreview != nil)
            } else {
                await model.prepareExport(id); try #require(model.exportURL != nil)
            }
            let gap = O10ReviewBarrier()
            f.setup.beforeConsentPersistence = { await gap.hold() }
            let withdrawal = f.setup.withdrawMotionConsent()
            // No suspension: the user's local intent must fence displayed state immediately.
            #expect(model.selected?.motionStatistics == nil)
            #expect(model.selectedPractice?.recoveryByRecordingID.isEmpty == true)
            #expect(model.selectedPractice?.snapshot.receipt == receipt)
            #expect(model.practiceExportPreview == nil && model.exportURL == nil)
            try await o10Eventually { gap.entered }
            #expect(f.setup.channel?.authority?.isCollectionAllowed == true, "Exercise the pre-persistence gap")
            await model.open(id)
            #expect(model.selected?.id == id && model.selected?.motionStatistics == nil)
            #expect(model.selectedPractice?.recoveryByRecordingID.isEmpty == true)
            await model.previewPracticeExport(id); await model.prepareExport(id)
            #expect(model.practiceExportPreview == nil && model.exportURL == nil)
            #expect(try o10Files(original.snapshot.rawRoot) == rawBefore)
            if mode == "persistenceFailure" { await f.setup.closeForTesting() }
            gap.release(); await withdrawal.value
            if mode == "persistenceFailure" {
                #expect(f.setup.lastError != nil)
                await model.open(id)
                #expect(model.selected?.motionStatistics == nil && model.exportURL == nil)
            } else {
                await model.refresh()
                #expect(model.recordings.contains { $0.id == id })
                await model.deletePractice(receipt.practiceID).value
                let deletion = try OwnerPracticeDeletion.status(base: f.phone, practiceID: receipt.practiceID)
                #expect(deletion?.localComplete == true)
            }
        }
    }

    @Test func inFlightOwnerReviewCannotReappearAfterLocalWithdrawal() async throws {
        try await o10Fixture { f, model in
            let source = try f.source(), (bundle, receipt) = try source.write()
            _ = try await f.receive(bundle, receipt)
            let id = source.contexts[0].recordingID, reviewGap = O10ReviewBarrier(), persistenceGap = O10ReviewBarrier()
            model.detailReviewDidComplete = { _ in await reviewGap.hold() }
            let opening = Task { await model.open(id) }
            try await o10Eventually { reviewGap.entered }
            f.setup.beforeConsentPersistence = { await persistenceGap.hold() }
            let withdrawal = f.setup.withdrawMotionConsent()
            try await o10Eventually { persistenceGap.entered }
            reviewGap.release(); await opening.value
            #expect(model.selected?.motionStatistics == nil)
            #expect(model.selectedPractice?.recoveryByRecordingID.isEmpty != false)
            #expect(model.exportURL == nil && model.practiceExportPreview == nil)
            model.detailReviewDidComplete = nil
            await model.open(id)
            #expect(model.selected?.id == id && model.selectedPractice?.snapshot.receipt == receipt)
            #expect(model.selected?.motionStatistics == nil && model.selectedPractice?.recoveryByRecordingID.isEmpty == true)
            persistenceGap.release(); await withdrawal.value
        }
    }

    @Test func durableWithdrawalDeniesAnalysisAndExplicitReconsentPreservesOriginalIdentity() async throws {
        try await o10Fixture { f, model in
            let source = try f.source(), (bundle, receipt) = try source.write()
            _ = try await f.receive(bundle, receipt)
            let id = source.contexts[0].recordingID
            await model.open(id)
            let original = try #require(model.selectedPractice)
            let originalBytes = try o10Files(original.snapshot.directoryURL)
            try await f.deliver(f.remote.restrict(heartRateOnly: false))
            await model.open(id)
            #expect(model.selected?.id == id && model.selected?.motionStatistics == nil)
            #expect(model.selectedPractice?.recoveryByRecordingID.isEmpty == true)
            await model.previewPracticeExport(id); await model.prepareExport(id)
            #expect(model.exportURL == nil && model.practiceExportPreview == nil)
            #expect(try o10Files(original.snapshot.directoryURL) == originalBytes)
            try await f.deliver(f.remote.reconsent())
            await model.open(id)
            #expect(model.selected?.motionStatistics != nil)
            #expect(model.selectedPractice?.snapshot.receipt == receipt)
            #expect(model.selectedPractice?.snapshot.sets.map(\.context) == original.snapshot.sets.map(\.context))
        }
    }

    @Test func withdrawnRelaunchKeepsMetadataAndWholePracticeDeletionAvailable() async throws {
        try await o10Fixture { f, model in
            f.connection.onChange = nil
            let source = try f.source(), (bundle, receipt) = try source.write()
            _ = try await f.receive(bundle, receipt)
            let id = source.contexts[0].recordingID
            await model.open(id)
            let original = try #require(model.selectedPractice)
            let rawBefore = try o10Files(original.snapshot.rawRoot)
            try await f.deliver(f.remote.restrict(heartRateOnly: false))
            #expect(f.setup.channel?.authority?.isCollectionAllowed == false)
            await f.setup.closeForTesting()
            let reopened = RecordingLibraryModel(paths: try RecordingPaths(base: f.phone), activateConnectivity: false)
            await reopened.open(id)
            #expect(reopened.selected?.id == id && reopened.selected?.motionStatistics == nil)
            #expect(reopened.selectedPractice?.snapshot.receipt == receipt)
            #expect(reopened.selectedPractice?.recoveryByRecordingID.isEmpty == true)
            #expect(reopened.selected?.streams.allSatisfy { $0.segments.isEmpty } == true)
            #expect(!reopened.loading)
            await reopened.previewPracticeExport(id); await reopened.prepareExport(id)
            #expect(reopened.exportURL == nil && reopened.practiceExportPreview == nil)
            #expect(try o10Files(original.snapshot.rawRoot) == rawBefore)
            await reopened.refresh()
            #expect(reopened.recordings.contains { $0.id == id })
            await reopened.deletePractice(receipt.practiceID).value
            let deletion = try OwnerPracticeDeletion.status(base: f.phone, practiceID: receipt.practiceID)
            #expect(deletion?.localComplete == true)
            await reopened.practiceSetup?.closeForTesting()
        }
    }

    @Test func consentedRelaunchAndLegacyReviewDoNotDependOnDefaultOffConsentToggles() async throws {
        try await o10Fixture { f, _ in
            f.connection.onChange = nil
            let source = try f.source(), (bundle, receipt) = try source.write()
            _ = try await f.receive(bundle, receipt)
            let paths = try RecordingPaths(base: f.phone), legacy = try o10Legacy(paths)
            await f.setup.closeForTesting()
            let reopened = RecordingLibraryModel(paths: paths, activateConnectivity: false)
            await reopened.open(source.contexts[0].recordingID)
            #expect(reopened.practiceSetup?.motionConsent == false)
            #expect(reopened.selected?.motionStatistics != nil && reopened.selectedPractice?.snapshot.receipt == receipt)
            await reopened.practiceSetup?.withdrawMotionConsent().value
            await reopened.open(legacy)
            #expect(reopened.selected?.id == legacy && reopened.selectedPractice == nil)
            #expect(reopened.selected?.motionStatistics != nil)
            await reopened.practiceSetup?.closeForTesting()
        }
    }

    @Test(arguments: ["included", "absent", "excluded"])
    func exactPracticeAndSetReviewPreservesHeartRateDispositionAndSparseRecovery(mode: String) async throws {
        try await o10Fixture { f, model in
            let source = try f.source(samples: mode != "absent")
            let (bundle, receipt) = try source.write(heartRate: mode == "excluded" ? .excludedByOwner : .asRecorded)
            _ = try await f.receive(bundle, receipt)
            await model.refresh(); await model.open(source.contexts[0].recordingID)
            let review = try #require(model.selectedPractice)
            #expect(review.snapshot.receipt == receipt)
            #expect(review.snapshot.scope.ownerID == f.authority.ownerID)
            #expect(review.snapshot.scope.phoneInstallationEpoch == f.authority.phoneInstallationEpoch)
            #expect(review.snapshot.scope.watchInstallationEpoch == f.authority.watchInstallationEpoch)
            #expect(review.recordings.map(\.id) == source.contexts.map(\.recordingID))
            #expect(review.recordings.map { $0.report.metadata?.drill } == source.contexts.map { Optional($0.metadata.drill) })
            #expect(review.snapshot.heartRate == (mode == "included" ? .included : mode == "absent" ? .absent : .excluded))
            for recording in review.recordings {
                #expect(recording.motionStatistics != nil)
                if let telemetry = review.snapshot.telemetry {
                    let expected = try OwnerRecoverySummary.calculate(telemetry: telemetry, recordingID: recording.id)
                    #expect(review.recoveryByRecordingID[recording.id] == expected)
                    #expect(expected.at60.state == .missing && expected.at60.medianBPM == nil)
                    #expect(expected.at120.state == .missing && expected.at120.medianBPM == nil)
                } else {
                    #expect(review.recoveryByRecordingID[recording.id] == nil)
                    #expect(mode == "excluded")
                }
            }
            await model.open(source.contexts[1].recordingID)
            #expect(model.selected?.id == source.contexts[1].recordingID)
            #expect(model.selectedPractice?.snapshot.receipt == receipt)
        }
    }

    @Test(arguments: ["included", "absent", "excluded"])
    func manualLabelHistoryCreatesNewImmutableRevisionsWithoutChangingEvidence(mode: String) async throws {
        try await o10Fixture { f, model in
            let source = try f.source(samples: mode != "absent")
            let (bundle, receipt) = try source.write(heartRate: mode == "excluded" ? .excludedByOwner : .asRecorded)
            _ = try await f.receive(bundle, receipt)
            let store = try OwnerPracticeReceiptStore(base: f.phone)
            let original = try store.open(practiceID: receipt.practiceID, revision: 1)
            let originalTree = try o10Files(original.directoryURL)
            let originalRaw = try o10Files(original.rawRoot)
            let id = source.contexts[0].recordingID
            await model.open(id)
            var draft = RecordingLabelDraft(), attemptID: UUID?
            var expectedRevision: Int64 = 1
            let categories: [ContactCategory] = [.cleanContact, .mishit, .uncertain, .nonStroke]
            for category in categories {
                draft.attemptID = attemptID; draft.category = category; draft.note = "Synthetic owner reference only"
                let saved = await model.save(draft, recordingID: id)
                #expect(saved)
                let selected = try #require(model.selected)
                let label = try #require(selected.latestLabels.first)
                attemptID = label.attemptID; expectedRevision += 1
                #expect(label.category == category && label.author == .ownerSelf)
                #expect(label.revision == expectedRevision - 1 && selected.labels.count == Int(expectedRevision - 1))
                let current = try #require(model.selectedPractice)
                #expect(current.snapshot.receipt.practiceID == receipt.practiceID)
                #expect(current.snapshot.receipt.revision == expectedRevision)
                #expect(current.snapshot.receipt.bundleSHA256 != receipt.bundleSHA256)
                #expect(current.snapshot.heartRate == original.heartRate)
                #expect(current.snapshot.sets == original.sets && current.snapshot.absenceReasons == original.absenceReasons)
                let currentRawFiles = try o10Files(current.snapshot.rawRoot)
                #expect(currentRawFiles == originalRaw)
                if let originalTelemetry = original.telemetry {
                    let currentTelemetry = try #require(current.snapshot.telemetry)
                    let currentTelemetryBytes = try currentTelemetry.encoded()
                    let originalTelemetryBytes = try originalTelemetry.encoded()
                    #expect(currentTelemetryBytes == originalTelemetryBytes)
                } else { #expect(current.snapshot.telemetry == nil) }
                let retainedOriginalTree = try o10Files(original.directoryURL)
                #expect(retainedOriginalTree == originalTree)
                let retainedPreviousRevision = try store.open(practiceID: receipt.practiceID, revision: expectedRevision - 1).receipt.revision
                #expect(retainedPreviousRevision == expectedRevision - 1)
            }
            await model.prepareExport(id)
            let exported = try #require(model.exportURL), target = try f.directory("readback")
            let pending = try OwnerPracticeBundle.prepareImport(from: exported, destinationBase: target)
            defer { pending.cancel() }
            try pending.renameForPublication(); _ = try pending.confirmPublication()
            let readback = try OwnerPracticeReceiptStore(base: target).open(practiceID: receipt.practiceID, revision: expectedRevision)
            let labels = try SessionAnnotationsStore(root: readback.notesRoot).loadLabels(recordingID: id)
            #expect(labels.map(\.category) == [.cleanContact, .mishit, .uncertain, .nonStroke])
            let readbackRawFiles = try o10Files(readback.rawRoot)
            #expect(readbackRawFiles == originalRaw)
            let retainedOriginalTree = try o10Files(original.directoryURL)
            #expect(retainedOriginalTree == originalTree)
        }
    }

    @Test func staleReviewCannotReplaceNewPracticeSelectionOrItsRecovery() async throws {
        try await o10Fixture { f, model in
            let first = try f.source(), second = try O10HistoricalSource(base: f.directory("second"), authority: f.authority)
            let (firstBundle, firstReceipt) = try first.write(), (secondBundle, secondReceipt) = try second.write()
            _ = try await f.receive(firstBundle, firstReceipt); _ = try await f.receive(secondBundle, secondReceipt)
            let boundary = O10ReviewBarrier(), firstID = first.contexts[0].recordingID, secondID = second.contexts[1].recordingID
            model.detailReviewDidComplete = { if $0 == firstID { await boundary.hold() } }
            let stale = Task { await model.open(firstID) }
            defer { boundary.release() }
            try await o10Eventually { boundary.entered }
            await model.open(secondID)
            #expect(model.selected?.id == secondID && model.selectedPractice?.snapshot.receipt == secondReceipt)
            boundary.release(); await stale.value
            #expect(model.selected?.id == secondID && model.selectedPractice?.snapshot.receipt == secondReceipt)
            #expect(model.selectedPractice?.recordings.map(\.id) == second.contexts.map(\.recordingID))
            model.closeDetail()
            #expect(model.selectedPractice == nil && model.selected == nil && model.practiceExportPreview == nil)
        }
    }

    @Test func legacyStaysUnassignedAndForeignOwnerEvidenceNeverEntersCurrentOwnerReview() async throws {
        try await o10Fixture { f, model in
            await model.refresh(); #expect(model.recordings.isEmpty)
            let paths = try RecordingPaths(base: f.phone), id = try o10Legacy(paths)
            let other = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: f.authority.phoneInstallationEpoch,
                watchInstallationEpoch: f.authority.watchInstallationEpoch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
                includesHeartRate: true, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000, policyDigest: OwnerPracticePolicy.digest)
            let foreign = try O10HistoricalSource(base: f.directory("foreign"), authority: other)
            let (file, receipt) = try foreign.write()
            // Adversarial, correctly verified stored bytes still do not grant current-owner review.
            let prepared = try OwnerPracticeBundle.prepareImport(from: file, destinationBase: f.phone)
            defer { prepared.cancel() }
            try prepared.renameForPublication(); _ = try prepared.confirmPublication()
            await model.refresh()
            #expect(!model.recordings.contains { receipt.recordingIDs.contains($0.id) })
            await model.open(receipt.recordingIDs[0])
            #expect(model.selected == nil && model.selectedPractice == nil)
            await model.open(id)
            #expect(model.selected?.id == id && model.selectedPractice == nil)
            #expect(model.selected?.motionStatistics != nil)
        }
    }

    @Test func interruptedUnpublishedLabelRevisionIsIncludedInWholePracticeDeletion() async throws {
        try await o10Fixture { f, model in
            let source = try f.source(), (bundle, receipt) = try source.write()
            // This test owns a separate repository. Suppress only automatic UI refresh,
            // whose independent reader would contend for the retained telemetry lease.
            f.connection.onChange = nil
            _ = try await f.receive(bundle, receipt)
            let paths = try RecordingPaths(base: f.phone)
            let repository = RecordingLibraryRepository(paths: paths)
            let id = source.contexts[0].recordingID
            var draft = RecordingLabelDraft()
            draft.category = .mishit; draft.note = "Synthetic unpublished owner label"
            // Exercise the real writer/import boundary, without granting publication.
            let prepared = try await repository.preparePracticeLabel(id, draft: draft, expected: receipt)
            let unpublishedReceipt = prepared.publication.receipt
            #expect(unpublishedReceipt.practiceID == receipt.practiceID && unpublishedReceipt.revision == 2)
            #expect(unpublishedReceipt.bundleSHA256 != receipt.bundleSHA256)
            let retainedBytes = try Data(contentsOf: prepared.url)
            #expect(retainedBytes.count == unpublishedReceipt.byteCount)
            let store = try OwnerPracticeReceiptStore(base: f.phone)
            #expect(throws: (any Error).self) { try store.open(practiceID: receipt.practiceID, revision: 2) }
            // Release the prepared publication lease, retaining the writer's durable source.
            // This is the on-disk interruption boundary before publication, not a process-kill claim.
            prepared.publication.cancel()
            #expect(FileManager.default.fileExists(atPath: prepared.url.path))
            let originalReceipt = try store.open(practiceID: receipt.practiceID, revision: 1).receipt
            #expect(originalReceipt == receipt)
            await model.deletePractice(receipt.practiceID).value
            let status = try OwnerPracticeDeletion.status(base: f.phone, practiceID: receipt.practiceID)
            let deletion = try #require(status)
            #expect(deletion.localComplete && !deletion.peerComplete)
            #expect(!FileManager.default.fileExists(atPath: prepared.url.path),
                "Completed deletion must include durable unpublished label evidence")
            let retainedOutbox = try o10Files(paths.outboxRoot)
            #expect(!retainedOutbox.values.contains(retainedBytes),
                "The new revision must not survive under another outbox filename")
            #expect(throws: (any Error).self) { try store.open(practiceID: receipt.practiceID, revision: 1) }
        }
    }

    @Test func failedRevisionImportRemovesOnlyItsOwnDurableScratch() async throws {
        try await o10Fixture { f, model in
            let source = try f.source(), (bundle, receipt) = try source.write()
            // This test owns a separate repository. Suppress only automatic UI refresh,
            // whose independent reader would contend for the retained telemetry lease.
            f.connection.onChange = nil
            _ = try await f.receive(bundle, receipt)
            let paths = try RecordingPaths(base: f.phone)
            let repository = RecordingLibraryRepository(paths: paths)
            let store = try OwnerPracticeReceiptStore(base: f.phone)
            let snapshot = try store.open(practiceID: receipt.practiceID, revision: 1)
            let originalTree = try o10Files(snapshot.directoryURL), outboxBefore = try o10Files(paths.outboxRoot)
            let sentinel = store.directoryURL.appendingPathComponent(".stage-invalid")
            try FileManager.default.createDirectory(at: sentinel, withIntermediateDirectories: false)
            let marker = Data("Unrelated synthetic stage; must not be removed".utf8)
            try marker.write(to: sentinel.appendingPathComponent("sentinel"))
            let sentinelBefore = try o10Files(sentinel)
            // The actual writer accepts this valid source and label; only import's
            // abandoned-stage validation rejects the deliberately malformed sibling.
            let id = source.contexts[0].recordingID
            let probe = f.root.appendingPathComponent("validated-revision.pslpractice")
            let label = try RecordingAttemptLabel(recordingID: id, attemptID: UUID(), ordinal: 1, category: .uncertain)
            let validReceipt = try OwnerPracticeBundle.writeLabelRevision(from: snapshot, recordingID: id,
                appending: [label], revision: 2, destination: probe)
            #expect(validReceipt.revision == 2)
            #expect(throws: (any Error).self) {
                let rejected = try OwnerPracticeBundle.prepareImport(from: probe, destinationBase: f.phone)
                rejected.cancel()
            }
            var draft = RecordingLabelDraft(); draft.category = .uncertain
            await #expect(throws: (any Error).self) {
                let rejected = try await repository.preparePracticeLabel(id, draft: draft, expected: receipt)
                rejected.publication.cancel()
            }
            let outboxAfter = try o10Files(paths.outboxRoot)
            #expect(outboxAfter == outboxBefore, "Failed import must clean its own newly written revision evidence")
            let sourceAfter = try o10Files(snapshot.directoryURL), sentinelAfter = try o10Files(sentinel)
            #expect(sourceAfter == originalTree && sentinelAfter == sentinelBefore)
            try FileManager.default.removeItem(at: sentinel)
            await model.deletePractice(receipt.practiceID).value
            let status = try OwnerPracticeDeletion.status(base: f.phone, practiceID: receipt.practiceID)
            let deletion = try #require(status)
            #expect(deletion.localComplete && !deletion.peerComplete)
            let finalOutbox = try o10Files(paths.outboxRoot)
            #expect(finalOutbox.isEmpty)
        }
    }

    @Test func exportPreviewIsExactNonSharingScopeAndDeleteClearsStalePresentation() async throws {
        try await o10Fixture { f, model in
            let source = try f.source(), (bundle, receipt) = try source.write()
            _ = try await f.receive(bundle, receipt)
            let paths = try RecordingPaths(base: f.phone), before = try o10Files(paths.outboxRoot)
            let id = source.contexts[0].recordingID
            await model.open(id); await model.previewPracticeExport(id)
            let preview = try #require(model.practiceExportPreview)
            #expect(preview.receipt == receipt && preview.scope.ownerID == f.authority.ownerID)
            #expect(preview.receipt.recordingIDs == source.contexts.map(\.recordingID) && preview.heartRate == .included)
            let afterPreview = try o10Files(paths.outboxRoot)
            #expect(model.exportURL == nil && afterPreview == before)
            model.cancelPracticeExportPreview()
            #expect(model.practiceExportPreview == nil && model.exportURL == nil)
            await model.previewPracticeExport(id); await model.prepareExport(id)
            let export = try #require(model.exportURL)
            let exportedBytes = try Data(contentsOf: export)
            let originalBundleBytes = try Data(contentsOf: bundle)
            #expect(exportedBytes == originalBundleBytes)
            await model.deletePractice(receipt.practiceID).value
            #expect(model.selectedPractice == nil && model.practiceExportPreview == nil && model.exportURL == nil)
            let deletionStatus = try OwnerPracticeDeletion.status(base: f.phone, practiceID: receipt.practiceID)
            let deletion = try #require(deletionStatus)
            #expect(deletion.localComplete && !deletion.peerComplete)
        }
    }
}

@MainActor private func o10Fixture(_ body: (O10PhoneFixture, RecordingLibraryModel) async throws -> Void) async throws {
    let f = try O10PhoneFixture(library: true, beforeReplyCommit: nil)
    do {
        await f.setup.load(); f.setup.setConsent(ownerConfirmed: true, motion: true, heartRate: true)
        try await body(f, #require(f.library)); await f.close()
    } catch { await f.close(); throw error }
}
@MainActor private final class O10ReviewBarrier {
    private(set) var entered = false
    private var waiter: CheckedContinuation<Void, Never>?
    func hold() async { entered = true; await withCheckedContinuation { waiter = $0 } }
    func release() { waiter?.resume(); waiter = nil }
}
@MainActor private func o10Eventually(_ condition: () -> Bool) async throws {
    for _ in 0..<200 { if condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
    throw O10AppFixtureFailure.timeout
}
private nonisolated func o10Files(_ base: URL) throws -> [String: Data] {
    var result: [String: Data] = [:]
    let enumerator = try #require(FileManager.default.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey]))
    for case let url as URL in enumerator {
        if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            result[String(url.path.dropFirst(base.path.count + 1))] = try Data(contentsOf: url)
        }
    }
    return result
}
private nonisolated func o10Legacy(_ paths: RecordingPaths) throws -> UUID {
    let id = UUID(), clock = try RecordingClock(domainID: UUID(), monotonicAnchorSeconds: 100, wallAnchorUnixSeconds: 1_800_000_000)
    let metadata = try RecordingMetadata(recordingID: id, clock: clock, appBuild: "synthetic-legacy", protocolVersion: "1",
        deviceModel: "Synthetic", operatingSystem: "Test OS", handedness: .right, playingArm: .right, watchWrist: .right,
        watchOrientation: "legacy", playingArmConfirmed: true, drill: "forehand", capabilityReport: "Synthetic legacy",
        streams: [try .init(stream: .accelerometer, supported: true, requestedRateHz: nil, knownSensorLimit: nil)])
    let raw = try RecordingStore.create(root: paths.rawRoot, metadata: metadata)
    try raw.append(RecordingChunk(recordingID: id, clockDomainID: clock.domainID, stream: .accelerometer, sequence: 0,
        samples: [.init(timestamp: 100.1, values: [0.1, 0.2, 0.3]), .init(timestamp: 100.2, values: [0.2, 0.3, 0.4])]))
    try raw.finalize(stopRequestTimestamp: 101, reason: .userStopped)
    try SessionAnnotationsStore(root: paths.notesRoot).saveTimeline(CaptureTimeline(recordingID: id, clockDomainID: clock.domainID,
        events: [try .init(kind: .start, timestamp: 100), try .init(kind: .stopped, timestamp: 101)]))
    return id
}

@MainActor private final class O10PhoneFixture {
    let root: URL, phone: URL, authority: OwnerPracticeIdentity, practiceID = UUID()
    let remote: O10PhoneRemote, connection: RecordingConnectivity, setup: PracticeSetupModel
    let library: RecordingLibraryModel?
    init(library useLibrary: Bool, beforeReplyCommit: (@Sendable (OwnerPreparationMessage) async -> Void)?) throws {
        guard let resolved = realpath(FileManager.default.temporaryDirectory.path, nil) else { throw CocoaError(.fileReadUnknown) }
        defer { free(resolved) }
        root = URL(fileURLWithPath: String(cString: resolved)).appendingPathComponent("O10-Phone-" + UUID().uuidString)
        phone = root.appendingPathComponent("phone")
        try FileManager.default.createDirectory(at: phone, withIntermediateDirectories: true)
        let remoteBase = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: remoteBase, withIntermediateDirectories: false)
        let bootstrap = try OwnerPhoneBootstrap(base: phone)
        let phoneEpoch = try bootstrap.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch }
        authority = try .enrolled(ownerID: UUID(), phoneInstallationEpoch: phoneEpoch, watchInstallationEpoch: UUID(),
            attestsWatchAccountOwner: true, acceptsMotionStudy: true, includesHeartRate: true,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000, policyDigest: OwnerPracticePolicy.digest)
        remote = try O10PhoneRemote(base: remoteBase, authority: authority)
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
    func source(samples: Bool = true) throws -> O10HistoricalSource {
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
    func deliver(_ transition: OwnerAuthorityTransition) async throws {
        let bytes = try OwnerPreparationCodec.encode(.transition(transition))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.receiveOwnerData(bytes, delivery: .control) { result in
                continuation.resume(with: result.map { _ in () }.mapError { $0 as any Error })
            }
        }
    }
    func close() async { await setup.closeForTesting(); try? FileManager.default.removeItem(at: root) }
}
private nonisolated final class O10PhoneRemote: @unchecked Sendable {
    private let queue = DispatchQueue(label: "PadelStrokeLab.tests.o8-remote")
    private let channel: PracticeSetupChannel
    init(base: URL, authority: OwnerPracticeIdentity) throws {
        channel = try PracticeSetupChannel(base: base, localInstallationEpoch: authority.watchInstallationEpoch,
            device: .watch, intent: .createNew)
    }
    func enroll(_ mutation: OwnerAuthorityMutation) throws -> OwnerAuthorityTransition { try queue.sync { try channel.sequence(mutation) } }
    func restrict(heartRateOnly: Bool) throws -> OwnerAuthorityTransition { try queue.sync {
        let channelSnapshot = try channel.readSnapshot()
        let authority = try #require(channelSnapshot.authority)
        let command = try heartRateOnly
            ? OwnerAuthorityMutation.heartRate(from: authority, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_100)
            : .withdraw(from: authority, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_101)
        return try channel.sequence(command)
    } }
    func reconsent() throws -> OwnerAuthorityTransition { try queue.sync {
        let snapshot = try channel.readSnapshot(), owner = try #require(snapshot.authority)
        return try channel.sequence(.reconsent(from: owner, includesHeartRate: true, acknowledgesWithdrawal: true,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_202))
    } }
    func control(_ data: Data) throws { try queue.sync {
        if case let .acknowledge(value) = try OwnerPreparationCodec.decode(data) { try channel.acknowledge(value) }
    } }
}

// This builder uses validated raw/O6 APIs in a distinct synthetic source namespace.
// It is historical evidence, never an authority gate or a replacement live app store.
@MainActor private final class O10HistoricalSource {
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
                throw O10AppFixtureFailure.invariant
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
private nonisolated enum O10AppFixtureFailure: Error { case invariant, timeout }

