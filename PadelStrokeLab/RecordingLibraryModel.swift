import CryptoKit
import Darwin
import Foundation
import Observation
import PadelCore

nonisolated struct RecordingSegment: Identifiable, Sendable {
    let id: Int
    let start: Double
    let end: Double
}

nonisolated struct RecordingStreamReview: Identifiable, Sendable {
    var id: UInt32 { stream.rawValue }
    let stream: RecordingStream
    let count: Int
    let first: Double?
    let last: Double?
    let segments: [RecordingSegmentStatistics]
}

nonisolated struct RecordingSegmentStatistics: Identifiable, Sendable {
    let id: Int
    let count: Int
    let rate: Double?
    let maximumInterval: Double?
}

nonisolated struct RecordingReview: Identifiable, Sendable {
    let id: UUID
    let report: RecordingRecoveryReport
    let timeline: CaptureTimeline?
    let labels: [RecordingAttemptLabel]
    let streams: [RecordingStreamReview]
    let segments: [RecordingSegment]
    let bytes: Int
    let receiptVerified: Bool
    let annotationWarning: String?
    let motionStatistics: MotionStatistics?
    let motionStatisticsUnavailableReason: String?

    static let ownerAnalysisUnavailable = "Owner analysis is unavailable while motion consent is withdrawn or unresolved. Retained data remains available for deletion."
    var withoutOwnerAnalysis: Self {
        Self(id: id, report: report, timeline: timeline, labels: labels,
            streams: streams.map { .init(stream: $0.stream, count: $0.count, first: $0.first, last: $0.last, segments: []) },
            segments: segments, bytes: bytes, receiptVerified: receiptVerified, annotationWarning: annotationWarning,
            motionStatistics: nil, motionStatisticsUnavailableReason: Self.ownerAnalysisUnavailable)
    }
    var latestLabels: [RecordingAttemptLabel] {
        Dictionary(grouping: labels, by: \.attemptID).values.compactMap {
            $0.max { $0.revision < $1.revision }
        }.sorted { $0.ordinal < $1.ordinal }
    }
    var status: String {
        if report.status != .finalized { return report.status.rawValue.capitalized }
        if report.finalization?.reason != .userStopped { return "Interrupted" }
        if timeline?.events.contains(where: { $0.kind == .limitReached }) == true { return "Limit reached" }
        return "Finalized"
    }
    var first: Double? { report.chunks.map(\.firstTimestamp).min() }
    var last: Double? { report.chunks.map(\.lastTimestamp).max() }
}

nonisolated struct OwnerPracticeReview: Sendable {
    let snapshot: OwnerPracticeBundleSnapshot
    let recordings: [RecordingReview]
    let recoveryByRecordingID: [UUID: OwnerRecoverySummary]
}

nonisolated struct RecordingLabelDraft: Sendable {
    var attemptID: UUID?
    var category: ContactCategory = .uncertain
    var confidence: RecordingLabelConfidence = .unspecified
    var evidence: RecordingLabelEvidence = .ownerRecall
    var note = ""
    var relativeStart = ""
    var relativeEnd = ""
}

nonisolated enum PhoneRecordingError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): message }
    }
}

/// One exclusive owner for bounded file work. No sensor samples are retained in view state.
actor RecordingLibraryRepository {
    let paths: RecordingPaths
    init(paths: RecordingPaths) { self.paths = paths }

    private var base: URL { paths.rawRoot.deletingLastPathComponent().deletingLastPathComponent() }
    private var deletingPractice: UUID?
    func beginPracticeDeletion(_ id: UUID) throws {
        guard deletingPractice == nil else { throw OwnerPracticeBundleError.unavailable }
        // This actor turn drains an active inspection. Later queued readers cannot reopen
        // the immutable revision's exclusive telemetry lease while cleanup owns it.
        deletingPractice = id
    }
    func endPracticeDeletion(_ id: UUID) { if deletingPractice == id { deletingPractice = nil } }
    func ownerPractice(_ id: UUID) throws -> OwnerPracticeBundleSnapshot? {
        guard deletingPractice == nil else { throw OwnerPracticeBundleError.unavailable }
        let matches = try OwnerPracticeTransferInventory.snapshots(base: base).filter { $0.receipt.recordingIDs.contains(id) }
        for match in matches {
            guard try OwnerPracticeDeletion.status(base: base, practiceID: match.receipt.practiceID) == nil else { throw OwnerPracticeBundleError.unavailable }
        }
        guard Set(matches.map { $0.receipt.practiceID }).count <= 1 else { throw OwnerPracticeBundleError.conflict }
        return matches.first
    }

    func list(owner: OwnerPracticeIdentity? = nil) throws -> [RecordingReview] {
        guard deletingPractice == nil else { throw OwnerPracticeBundleError.unavailable }
        var result: [RecordingReview] = []
        let practices = try OwnerPracticeTransferInventory.snapshots(base: base)
        let ownedIDs = Set(practices.flatMap { $0.receipt.recordingIDs })
        let names = try FileManager.default.contentsOfDirectory(atPath: paths.rawRoot.path).filter {
            UUID(uuidString: $0)?.uuidString == $0
        }
        // A prototype library is bounded independently of each recording's chunk limit.
        guard names.count <= 512 else { throw PhoneRecordingError.invalid("Library inspection limit reached. Preserve your recordings and contact support.") }
        for name in names.sorted() {
            try Task.checkCancellation()
            guard let id = UUID(uuidString: name), id.uuidString == name else { continue }
            if !ownedIDs.contains(id) { result.append(try review(id, includeStatistics: false)) }
        }
        var seen: Set<UUID> = []
        for practice in practices where Self.matches(practice, owner: owner) && seen.insert(practice.receipt.practiceID).inserted {
            for id in practice.receipt.recordingIDs {
                result.removeAll { $0.id == id }
                result.append(try review(id, includeStatistics: false, rawRoot: practice.rawRoot, notesRoot: practice.notesRoot))
            }
        }
        return result.sorted {
            ($0.report.metadata?.clock.wallAnchorUnixSeconds ?? 0) > ($1.report.metadata?.clock.wallAnchorUnixSeconds ?? 0)
        }
    }

    static func matches(_ snapshot: OwnerPracticeBundleSnapshot, owner: OwnerPracticeIdentity?) -> Bool {
        guard let owner else { return false }
        let scope = snapshot.scope
        return scope.ownerID == owner.ownerID && scope.phoneInstallationEpoch == owner.phoneInstallationEpoch
            && scope.watchInstallationEpoch == owner.watchInstallationEpoch
    }
    func selection(_ id: UUID, owner: OwnerPracticeIdentity?,
                   analysisAllowed: (@Sendable () -> Bool)? = nil) throws -> (RecordingReview, OwnerPracticeReview?) {
        guard let snapshot = try ownerPractice(id) else { return (try review(id), nil) }
        guard Self.matches(snapshot, owner: owner) else { throw OwnerPracticeBundleError.unavailable }
        func metadataOnly() throws -> (RecordingReview, OwnerPracticeReview?) {
            let records = try snapshot.receipt.recordingIDs.map {
                try review($0, includeStatistics: false, rawRoot: snapshot.rawRoot, notesRoot: snapshot.notesRoot).withoutOwnerAnalysis
            }
            guard let selected = records.first(where: { $0.id == id }) else { throw OwnerPracticeBundleError.integrity }
            return (selected, OwnerPracticeReview(snapshot: snapshot, recordings: records, recoveryByRecordingID: [:]))
        }
        guard owner?.isCollectionAllowed == true, let analysisAllowed, analysisAllowed() else { return try metadataOnly() }
        do {
            let records = try snapshot.receipt.recordingIDs.map {
                try review($0, includeStatistics: true, rawRoot: snapshot.rawRoot, notesRoot: snapshot.notesRoot,
                    analysisAllowed: analysisAllowed)
            }
            var recovery: [UUID: OwnerRecoverySummary] = [:]
            if let telemetry = snapshot.telemetry {
                for recording in records {
                    guard analysisAllowed() else { throw CancellationError() }
                    recovery[recording.id] = try .calculate(telemetry: telemetry, recordingID: recording.id)
                }
            }
            guard analysisAllowed() else { throw CancellationError() }
            guard let selected = records.first(where: { $0.id == id }) else { throw OwnerPracticeBundleError.integrity }
            return (selected, OwnerPracticeReview(snapshot: snapshot, recordings: records, recoveryByRecordingID: recovery))
        } catch is CancellationError {
            if !analysisAllowed() { return try metadataOnly() }
            throw CancellationError()
        }
    }

    func review(_ id: UUID, includeStatistics: Bool = true) throws -> RecordingReview {
        let practice = try ownerPractice(id)
        return try review(id, includeStatistics: includeStatistics,
            rawRoot: practice?.rawRoot ?? paths.rawRoot, notesRoot: practice?.notesRoot ?? paths.notesRoot)
    }
    private func review(_ id: UUID, includeStatistics: Bool, rawRoot: URL, notesRoot: URL,
                        analysisAllowed: (@Sendable () -> Bool)? = nil) throws -> RecordingReview {
        try Task.checkCancellation()
        let report = try RecordingStore.inspect(root: rawRoot, recordingID: id)
        let notes = try SessionAnnotationsStore(root: notesRoot)
        var warning: String?
        var timeline: CaptureTimeline?
        var labels: [RecordingAttemptLabel] = []
        var verified = false
        do {
            timeline = try notes.loadTimeline(recordingID: id)
            if let timeline, timeline.clockDomainID != report.metadata?.clock.domainID {
                throw PhoneRecordingError.invalid("Timeline clock differs from the raw recording.")
            }
            labels = try notes.loadLabels(recordingID: id)
            verified = try notes.loadReceipt(recordingID: id) != nil
        } catch {
            warning = "Annotations or receipt need attention: \(error.localizedDescription)"
            timeline = nil
        }
        let segments = Self.segments(timeline: timeline, report: report)
        var motion: MotionStatisticsAccumulator?
        var motionUnavailable: String?
        if includeStatistics {
            if let analysisAllowed, !analysisAllowed() { throw CancellationError() }
            if report.status == .corrupt || report.status == .limited {
                motionUnavailable = "Motion statistics are unavailable while retained data needs an integrity check."
            } else if let metadata = report.metadata, !segments.isEmpty {
                do {
                    motion = try MotionStatisticsAccumulator(metadata: metadata,
                        segments: segments.map { .init(id: $0.id, start: $0.start, end: $0.end) })
                } catch is CancellationError { throw CancellationError() } catch {
                    motionUnavailable = "Motion statistics are unavailable because active intervals could not be validated."
                }
            } else {
                motionUnavailable = "Motion statistics need valid capture details and known active intervals."
            }
        }
        let streams = try RecordingStream.allCases.map { stream in
            let chunks = report.chunks.filter { $0.stream == stream }
            return RecordingStreamReview(stream: stream, count: chunks.reduce(0) { $0 + $1.sampleCount },
                first: chunks.map(\.firstTimestamp).min(), last: chunks.map(\.lastTimestamp).max(),
                                        segments: includeStatistics ? try statistics(id: id, chunks: chunks, segments: segments, motion: &motion, rawRoot: rawRoot, analysisAllowed: analysisAllowed) : [])
        }
        let bytes = try storageBytes(id, rawRoot: rawRoot, notesRoot: notesRoot)
        return RecordingReview(id: id, report: report, timeline: timeline, labels: labels, streams: streams,
                               segments: segments, bytes: bytes, receiptVerified: verified, annotationWarning: warning,
                               motionStatistics: try motion?.result(), motionStatisticsUnavailableReason: motionUnavailable)
    }

    static func segments(timeline: CaptureTimeline?, report: RecordingRecoveryReport) -> [RecordingSegment] {
        guard let timeline else { return [] }
        var start: Double?
        var result: [RecordingSegment] = []
        for event in timeline.events {
            switch event.kind {
            case .start, .resumed: start = event.timestamp
            case .pauseRequested, .stopRequested, .interruption, .bufferOverflow, .writeFailure, .limitReached:
                if let lower = start, event.timestamp >= lower {
                    result.append(.init(id: result.count, start: lower, end: event.timestamp))
                }
                start = nil
            default: break
            }
        }
        if let lower = start, let last = report.chunks.map(\.lastTimestamp).max(), last >= lower {
            result.append(.init(id: result.count, start: lower, end: last))
        }
        return result
    }

    private func statistics(id: UUID, chunks: [RecordingChunkDescriptor], segments: [RecordingSegment],
                            motion: inout MotionStatisticsAccumulator?, rawRoot: URL,
                            analysisAllowed: (@Sendable () -> Bool)? = nil) throws -> [RecordingSegmentStatistics] {
        var counts = Array(repeating: 0, count: segments.count)
        var first = Array<Double?>(repeating: nil, count: segments.count)
        var previous = first
        var maximum = first
        for descriptor in chunks.sorted(by: { $0.sequence < $1.sequence }) {
            try Task.checkCancellation()
            if let analysisAllowed, !analysisAllowed() { throw CancellationError() }
            let bytes = try readChunk(id: id, descriptor: descriptor, rawRoot: rawRoot)
            let chunk = try RecordingChunkCodec.decode(bytes)
            try motion?.consume(chunk)
            for (indexInChunk, sample) in chunk.samples.enumerated() {
                if indexInChunk.isMultiple(of: 256) {
                    try Task.checkCancellation()
                    if let analysisAllowed, !analysisAllowed() { throw CancellationError() }
                }
                guard let index = segments.firstIndex(where: { sample.timestamp >= $0.start && sample.timestamp <= $0.end }) else { continue }
                if let last = previous[index] {
                    let gap = sample.timestamp - last
                    maximum[index] = max(maximum[index] ?? 0, gap)
                } else { first[index] = sample.timestamp }
                previous[index] = sample.timestamp
                counts[index] += 1
            }
        }
        return segments.indices.map { index in
            let span = (previous[index] ?? 0) - (first[index] ?? 0)
            return RecordingSegmentStatistics(id: index, count: counts[index],
                rate: counts[index] > 1 && span > 0 ? Double(counts[index] - 1) / span : nil,
                maximumInterval: maximum[index])
        }
    }

    private func readChunk(id: UUID, descriptor: RecordingChunkDescriptor, rawRoot: URL) throws -> Data {
        let directory = open(rawRoot.appendingPathComponent(id.uuidString).path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directory >= 0 else { throw RecordingError.io(operation: "open review directory", code: errno) }
        defer { close(directory) }
        let file = openat(directory, descriptor.fileName, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard file >= 0 else { throw RecordingError.io(operation: "open review chunk", code: errno) }
        defer { close(file) }
        var info = stat()
        guard fstat(file, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1,
              info.st_size == descriptor.byteCount, info.st_size <= RecordingLimits.chunkBytes else {
            throw RecordingError.integrity("review chunk size or type")
        }
        var data = Data(count: descriptor.byteCount)
        try data.withUnsafeMutableBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.read(file, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw RecordingError.integrity("review chunk truncated") }
                offset += count
            }
        }
        guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == descriptor.sha256 else {
            throw RecordingError.integrity("review chunk changed")
        }
        return data
    }

    private func storageBytes(_ id: UUID, rawRoot: URL, notesRoot: URL) throws -> Int {
        var total = 0
        for root in [rawRoot, notesRoot] {
            let directory = root.appendingPathComponent(id.uuidString)
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard files.count <= RecordingLimits.directoryEntries else { throw RecordingError.limit("review directory entries") }
            for file in files {
                let values = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                total += values.fileSize ?? 0
            }
        }
        return total
    }

    func saveLabel(recordingID: UUID, draft: RecordingLabelDraft) throws -> RecordingReview {
        guard try ownerPractice(recordingID) == nil else {
            throw PhoneRecordingError.invalid("This verified practice revision is immutable. Practice label editing is not available yet.")
        }
        let current = try review(recordingID, includeStatistics: false)
        let label = try makeLabel(current: current, draft: draft)
        let store = try SessionAnnotationsStore(root: paths.notesRoot)
        try store.saveLabels(current.labels + [label], recordingID: recordingID)
        return try review(recordingID)
    }
    private func makeLabel(current: RecordingReview, draft: RecordingLabelDraft) throws -> RecordingAttemptLabel {
        let recordingID = current.id
        guard current.annotationWarning == nil, let metadata = current.report.metadata else {
            throw PhoneRecordingError.invalid("Resolve the recording's metadata or annotation problem before editing labels.")
        }
        let previous = current.latestLabels.first { $0.attemptID == draft.attemptID }
        if draft.attemptID != nil && previous == nil { throw PhoneRecordingError.invalid("This attempt no longer exists.") }
        var start: Double?
        var end: Double?
        let startText = draft.relativeStart.trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = draft.relativeEnd.trimmingCharacters(in: .whitespacesAndNewlines)
        if !startText.isEmpty || !endText.isEmpty {
            guard let relativeStart = Double(startText), let relativeEnd = Double(endText),
                  relativeStart.isFinite, relativeEnd.isFinite, relativeStart >= 0, relativeEnd >= relativeStart,
                  let lower = current.first, let upper = current.last else {
                throw PhoneRecordingError.invalid("Enter both finite times in seconds, with end at or after start.")
            }
            let absoluteStart = metadata.clock.monotonicAnchorSeconds + relativeStart
            let absoluteEnd = metadata.clock.monotonicAnchorSeconds + relativeEnd
            guard absoluteStart >= lower, absoluteEnd <= upper,
                  current.segments.contains(where: { absoluteStart >= $0.start && absoluteEnd <= $0.end }) else {
                throw PhoneRecordingError.invalid("The interval must fit retained data within one active segment. A pause or unknown timeline makes matching uncertain; leave both times empty.")
            }
            start = absoluteStart; end = absoluteEnd
        }
        return try RecordingAttemptLabel(recordingID: recordingID, attemptID: previous?.attemptID ?? UUID(),
            ordinal: previous?.ordinal ?? ((current.latestLabels.map(\.ordinal).max() ?? 0) + 1),
            revision: (previous?.revision ?? 0) + 1, category: draft.category, confidence: draft.confidence,
            evidence: draft.evidence, note: draft.note.isEmpty ? nil : draft.note,
            clockDomainID: start == nil ? nil : metadata.clock.domainID, startTimestamp: start, endTimestamp: end)
    }

    struct PracticeExport: Sendable { let url: URL; let publication: OwnerPracticePreparedPublication }
    func preparePracticeLabel(_ id: UUID, draft: RecordingLabelDraft, expected: OwnerPracticeReceipt) throws -> PracticeExport {
        guard let practice = try ownerPractice(id), practice.receipt == expected,
              expected.revision < Int64.max else { throw OwnerPracticeBundleError.conflict }
        let current = try review(id, includeStatistics: false, rawRoot: practice.rawRoot, notesRoot: practice.notesRoot)
        let label = try makeLabel(current: current, draft: draft)
        // O9 attributes this existing layout by its checked bundle, even before a receipt is published.
        // A crash inside the writer leaves an incomplete known stage, so deletion fails closed.
        let name = ".owner-readback-" + UUID().uuidString
        let parent = open(paths.outboxRoot.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw RecordingError.io(operation: "open revision staging parent", code: errno) }
        defer { close(parent) }
        guard mkdirat(parent, name, 0o700) == 0 else { throw RecordingError.io(operation: "create revision stage", code: errno) }
        let destination = paths.outboxRoot.appendingPathComponent(name).appendingPathComponent("bundle")
        do {
            _ = try OwnerPracticeBundle.writeLabelRevision(from: practice, recordingID: id, appending: [label],
                revision: expected.revision + 1, destination: destination)
            guard fsync(parent) == 0 else { throw RecordingError.io(operation: "sync revision staging parent", code: errno) }
            return try PracticeExport(url: destination,
                publication: OwnerPracticeBundle.prepareImport(from: destination, destinationBase: base))
        } catch {
            // Unknown partial contents are retained as an incomplete stage, never hidden from deletion.
            try? discardPreparedFile(destination)
            throw error
        }
    }
    func discardPreparedFile(_ url: URL) throws {
        if url.deletingLastPathComponent() == paths.outboxRoot {
            try FileManager.default.removeItem(at: url)
            return
        }
        let stage = url.deletingLastPathComponent(), name = stage.lastPathComponent
        let prefix = ".owner-readback-"
        guard url.lastPathComponent == "bundle", stage.deletingLastPathComponent() == paths.outboxRoot,
              name.hasPrefix(prefix), let id = UUID(uuidString: String(name.dropFirst(prefix.count))),
              name == prefix + id.uuidString else { throw OwnerPracticeBundleError.integrity }
        let parent = open(paths.outboxRoot.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw RecordingError.io(operation: "open revision cleanup parent", code: errno) }
        defer { close(parent) }
        let directory = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directory >= 0 else { throw RecordingError.io(operation: "open revision cleanup stage", code: errno) }
        defer { close(directory) }
        var held = stat(), current = stat()
        guard fstat(directory, &held) == 0,
              fstatat(parent, name, &current, AT_SYMLINK_NOFOLLOW) == 0,
              held.st_dev == current.st_dev, held.st_ino == current.st_ino else { throw OwnerPracticeBundleError.integrity }
        let contents = try FileManager.default.contentsOfDirectory(atPath: stage.path)
        guard contents.isEmpty || contents == ["bundle"] else { throw OwnerPracticeBundleError.integrity }
        if !contents.isEmpty, unlinkat(directory, "bundle", 0) != 0 {
            throw RecordingError.io(operation: "remove revision scratch bundle", code: errno)
        }
        guard fsync(directory) == 0, fstatat(parent, name, &current, AT_SYMLINK_NOFOLLOW) == 0,
              held.st_dev == current.st_dev, held.st_ino == current.st_ino,
              unlinkat(parent, name, AT_REMOVEDIR) == 0, fsync(parent) == 0 else {
            throw RecordingError.io(operation: "remove revision scratch stage", code: errno)
        }
    }
    func preparePracticeExport(_ id: UUID, expected: OwnerPracticeReceipt? = nil) throws -> PracticeExport? {
        guard let practice = try ownerPractice(id) else { return nil }
        guard expected == nil || expected == practice.receipt else { throw OwnerPracticeBundleError.conflict }
        let destination = paths.outboxRoot.appendingPathComponent("export-" + UUID().uuidString + ".pslpractice")
        _ = try OwnerPracticeReceiptStore(base: base).exportBundle(practiceID: practice.receipt.practiceID,
            revision: practice.receipt.revision, destination: destination)
        return try PracticeExport(url: destination,
            publication: OwnerPracticeBundle.prepareImport(from: destination, destinationBase: base))
    }

    func export(_ id: UUID) throws -> URL {
        let current = try review(id, includeStatistics: false)
        guard current.annotationWarning == nil, let timeline = current.timeline else {
            throw PhoneRecordingError.invalid("A valid original timeline is required to export this recording.")
        }
        let destination = paths.outboxRoot.appendingPathComponent("export-\(id.uuidString)-\(UUID().uuidString).pslrecording")
        _ = try RecordingArchive.write(recordingID: id, rawRoot: paths.rawRoot, timeline: timeline,
                                       destination: destination, labels: current.labels)
        return destination
    }

    func deletePhoneCopy(_ id: UUID) throws {
        guard try ownerPractice(id) == nil else {
            throw PhoneRecordingError.invalid("This recording belongs to a complete practice. Whole-practice deletion is not available yet.")
        }
        try RecordingLocalCopies.deletePhoneCopy(recordingID: id, paths: paths)
    }
}

@MainActor @Observable
final class RecordingLibraryModel {
    #if DEBUG
    private(set) var isSyntheticUIReview = false
    // Tests may hold a real completed review before the unchanged publication guards.
    var detailReviewDidComplete: (@MainActor @Sendable (UUID) async -> Void)?
    #endif
    private(set) var recordings: [RecordingReview] = []
    private(set) var selected: RecordingReview?
    private(set) var selectedPractice: OwnerPracticeReview?
    private(set) var practiceExportPreview: OwnerPracticeBundleSnapshot?
    private(set) var loading = false
    private(set) var busy = false
    var error: String?
    private(set) var transferMessage = "Waiting for a verified Watch recording."
    private(set) var exportURL: URL?
    private(set) var pendingDeletion: UUID?
    private(set) var practiceDeletionMessage: String?
    private let repository: RecordingLibraryRepository?
    private(set) var connectivity: RecordingConnectivity?
    private(set) var practiceSetup: PracticeSetupModel?
    private var generation = UUID()
    private var libraryGeneration = UUID()
    var ownerAnalysisAvailable: Bool { practiceSetup?.allowsOwnerAnalysis == true }
    private func invalidateOwnerAnalysis() {
        exportURL = nil; practiceExportPreview = nil
        if let practice = selectedPractice {
            generation = UUID(); loading = false
            selected = selected?.withoutOwnerAnalysis
            selectedPractice = OwnerPracticeReview(snapshot: practice.snapshot,
                recordings: practice.recordings.map(\.withoutOwnerAnalysis), recoveryByRecordingID: [:])
        }
    }

    init(paths: RecordingPaths? = nil, activateConnectivity: Bool = true, injectedConnectivity: RecordingConnectivity? = nil) {
        do {
            var supplied = paths
            var shouldConnect = activateConnectivity
            #if DEBUG
            if supplied == nil, let fixture = try OwnerPracticeReviewFixture.make(arguments: ProcessInfo.processInfo.arguments) {
                supplied = fixture; shouldConnect = false
                isSyntheticUIReview = true; transferMessage = "SYNTHETIC UI REVIEW"
            } else if supplied == nil, ProcessInfo.processInfo.arguments.contains("--owner-setup-fixture=offline") {
                supplied = try RecordingPaths(base: FileManager.default.temporaryDirectory
                    .appendingPathComponent("OwnerSetupUI-" + UUID().uuidString, isDirectory: true))
                shouldConnect = false; isSyntheticUIReview = true; transferMessage = "SYNTHETIC UI REVIEW"
            } else if supplied == nil, let fixture = try RecordingMotionUIFixture.make(arguments: ProcessInfo.processInfo.arguments) {
                supplied = fixture; shouldConnect = false
                isSyntheticUIReview = true; transferMessage = "SYNTHETIC UI REVIEW"
            }
            #endif
            let resolved = try supplied ?? RecordingPaths()
            if let injectedConnectivity {
                let base = resolved.rawRoot.deletingLastPathComponent().deletingLastPathComponent()
                let temporary = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path + "/"
                guard paths != nil, !activateConnectivity, base.path.hasPrefix(temporary),
                      injectedConnectivity.isBound(to: resolved) else { throw OwnerPracticeBundleError.unavailable }
            }
            repository = RecordingLibraryRepository(paths: resolved)
            let connection = injectedConnectivity ?? (shouldConnect ? RecordingConnectivity(paths: resolved) : nil)
            let setup = PracticeSetupModel(base: resolved.rawRoot.deletingLastPathComponent().deletingLastPathComponent(),
                connectivity: connection)
            practiceSetup = setup
            setup.onOwnerAnalysisInvalidated = { [weak self] in self?.invalidateOwnerAnalysis() }
            connection?.onOwnerPracticePublication = { [weak setup] prepared in
                guard let setup else { throw OwnerPracticeBundleError.closed }
                return try await setup.publishVerifiedPractice(scope: prepared.scope, preparedPublication: prepared)
            }
            connection?.onPracticeDeletion = { [weak self, weak setup] command in
                guard let self, setup != nil else { throw OwnerPracticeBundleError.closed }
                let acknowledgment = try await self.performPracticeDeletion(command.practiceID, command: command)
                await self.practiceDeleted(acknowledgment)
                return acknowledgment
            }
            if connection != nil {
                guard let connection else { return }
                connectivity = connection
                connection.onChange = { [weak self] snapshot in
                    Task { @MainActor in
                        self?.transferMessage = "\(snapshot.state.rawValue.capitalized): \(snapshot.detail ?? "Watch recording")"
                        await self?.refresh()
                    }
                }
                if shouldConnect { connection.activate() }
            }
        } catch { repository = nil; self.error = "Recording storage unavailable: \(error.localizedDescription)" }
    }

    func refresh() async {
        guard let repository, !busy else { return }
        let request = UUID(); libraryGeneration = request; loading = true; error = nil
        defer { if libraryGeneration == request { loading = false } }
        do {
            await practiceSetup?.load()
            let owner = practiceSetup?.channel?.authority
            let values = try await repository.list(owner: owner)
            guard practiceSetup?.channel?.authority == owner, libraryGeneration == request, !Task.isCancelled else { return }
            recordings = values
        } catch is CancellationError { } catch {
            if libraryGeneration == request { self.error = error.localizedDescription }
        }
    }

    func open(_ id: UUID) async {
        guard let repository else { return }
        let request = UUID(); generation = request; loading = true; selected = nil; selectedPractice = nil; practiceExportPreview = nil; exportURL = nil; error = nil
        defer { if generation == request { loading = false } }
        do {
            await practiceSetup?.load()
            let owner = practiceSetup?.channel?.authority
            let admission = practiceSetup?.ownerAnalysisAdmission()
            let (value, practice) = try await repository.selection(id, owner: owner, analysisAllowed: admission)
            #if DEBUG
            await detailReviewDidComplete?(id)
            #endif
            guard practiceSetup?.channel?.authority == owner, generation == request, !Task.isCancelled else { return }
            if let practice, !ownerAnalysisAvailable {
                selected = value.withoutOwnerAnalysis
                selectedPractice = OwnerPracticeReview(snapshot: practice.snapshot,
                    recordings: practice.recordings.map(\.withoutOwnerAnalysis), recoveryByRecordingID: [:])
            } else {
                guard practice == nil || admission?() == true else { return }
                selected = value; selectedPractice = practice
            }
        } catch is CancellationError { } catch {
            if generation == request { self.error = error.localizedDescription }
        }
    }

    func closeDetail() { generation = UUID(); selected = nil; selectedPractice = nil; practiceExportPreview = nil; loading = false; exportURL = nil }

    func save(_ draft: RecordingLabelDraft, recordingID: UUID) async -> Bool {
        guard let repository, !busy, selected?.id == recordingID else { return false }
        let request = generation
        busy = true; error = nil
        defer { busy = false }
        do {
            if let practice = selectedPractice {
                guard ownerAnalysisAvailable, RecordingLibraryRepository.matches(practice.snapshot, owner: practiceSetup?.channel?.authority),
                      let practiceSetup else { throw OwnerPracticeBundleError.unavailable }
                let complete = try await repository.preparePracticeLabel(recordingID, draft: draft, expected: practice.snapshot.receipt)
                defer { complete.publication.cancel() }
                do {
                    _ = try await practiceSetup.publishVerifiedPractice(scope: complete.publication.scope, preparedPublication: complete.publication)
                    try await repository.discardPreparedFile(complete.url)
                } catch {
                    try? await repository.discardPreparedFile(complete.url)
                    throw error
                }
                if generation == request, selected?.id == recordingID { await open(recordingID) }
            } else {
                let value = try await repository.saveLabel(recordingID: recordingID, draft: draft)
                if generation == request, selected?.id == recordingID { selected = value; exportURL = nil }
            }
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func previewPracticeExport(_ id: UUID) async {
        guard let repository, !busy, selected?.id == id else { return }
        let request = generation
        exportURL = nil; practiceExportPreview = nil; error = nil
        do {
            guard ownerAnalysisAvailable, let snapshot = try await repository.ownerPractice(id),
                  ownerAnalysisAvailable, RecordingLibraryRepository.matches(snapshot, owner: practiceSetup?.channel?.authority) else {
                throw OwnerPracticeBundleError.unavailable
            }
            if generation == request, selected?.id == id, ownerAnalysisAvailable { practiceExportPreview = snapshot }
        } catch { if generation == request { self.error = error.localizedDescription } }
    }
    func cancelPracticeExportPreview() { practiceExportPreview = nil; exportURL = nil }

    func prepareExport(_ id: UUID) async {
        guard let repository, !busy, selected?.id == id else { return }
        busy = true; exportURL = nil; error = nil
        let request = generation
        defer { busy = false }
        do {
            let url: URL
            if let snapshot = try await repository.ownerPractice(id) {
                guard ownerAnalysisAvailable, RecordingLibraryRepository.matches(snapshot, owner: practiceSetup?.channel?.authority) else {
                    throw OwnerPracticeBundleError.unavailable
                }
            }
            if let complete = try await repository.preparePracticeExport(id, expected: practiceExportPreview?.receipt) {
                defer { complete.publication.cancel() }
                guard let practiceSetup else { throw OwnerPracticeBundleError.unavailable }
                _ = try await practiceSetup.publishVerifiedPractice(scope: complete.publication.scope,
                    preparedPublication: complete.publication)
                url = complete.url
            } else { url = try await repository.export(id) }
            if generation == request, selected?.id == id { exportURL = url; practiceExportPreview = nil }
        } catch { self.error = error.localizedDescription }
    }

    func requestDeletion(_ id: UUID) { guard !busy else { return }; pendingDeletion = id }
    @discardableResult func deletePractice(_ practiceID: UUID) -> Task<Void, Never> {
        practiceSetup?.fencePracticeDeletion(practiceID)
        generation = UUID(); libraryGeneration = UUID(); exportURL = nil; practiceExportPreview = nil
        selected = nil; selectedPractice = nil
        busy = true; practiceDeletionMessage = "Deleting this practice…"
        return Task { [weak self] in
            guard let self else { return }
            defer { busy = false }
            do {
                let acknowledgment = try await performPracticeDeletion(practiceID)
                practiceDeleted(acknowledgment)
            } catch {
                practiceDeletionMessage = "Deletion incomplete. Retry to finish removing this practice."
                self.error = error.localizedDescription
            }
        }
    }
    private func performPracticeDeletion(_ id: UUID, command: OwnerPracticeDeletionCommand? = nil) async throws -> OwnerPracticeDeletionAcknowledgment {
        guard let repository, let practiceSetup else { throw OwnerPracticeBundleError.unavailable }
        practiceSetup.fencePracticeDeletion(id)
        try await repository.beginPracticeDeletion(id)
        do {
            let acknowledgment = try await practiceSetup.deletePractice(id, command: command)
            await repository.endPracticeDeletion(id)
            return acknowledgment
        } catch {
            await repository.endPracticeDeletion(id)
            throw error
        }
    }
    private func practiceDeleted(_ acknowledgment: OwnerPracticeDeletionAcknowledgment) {
        let ids = Set(acknowledgment.command.recordingIDs)
        generation = UUID(); libraryGeneration = UUID(); exportURL = nil; practiceExportPreview = nil
        recordings.removeAll { ids.contains($0.id) }
        if let selected, ids.contains(selected.id) { closeDetail() }
        practiceDeletionMessage = "Deleted on this iPhone. Watch cleanup pending."
    }
    func cancelDeletion() { pendingDeletion = nil }
    func confirmDeletion(_ id: UUID) async -> Bool {
        guard let repository, pendingDeletion == id, !busy else { return false }
        pendingDeletion = nil; busy = true
        do {
            try await repository.deletePhoneCopy(id)
            recordings.removeAll { $0.id == id }
            if selected?.id == id { closeDetail() }
            busy = false
            return true
        } catch { self.error = error.localizedDescription; busy = false; return false }
    }
}

#if DEBUG
/// Explicit fixed UI-test modes only. Ordinary launches never touch a fixture or a temporary root.
enum RecordingMotionUIFixture {
    static let recordingID = UUID(uuidString: "A6201020-0007-4000-8000-000000000001")!
    static func make(arguments: [String]) throws -> RecordingPaths? {
        let modes = ["populated", "unavailable", "interrupted"]
        guard let mode = modes.first(where: { arguments.contains("--motion-statistics-fixture=\($0)") }) else { return nil }
        let paths = try RecordingPaths(base: FileManager.default.temporaryDirectory
            .appendingPathComponent("MotionStatisticsUI-\(UUID().uuidString)", isDirectory: true))
        let id = recordingID
        let metadata = try RecordingMetadata(recordingID: id,
            clock: RecordingClock(domainID: UUID(), monotonicAnchorSeconds: 100, wallAnchorUnixSeconds: 1_792_300_000),
            appBuild: "SYNTHETIC UI REVIEW", protocolVersion: "synthetic-ui-review",
            deviceModel: "SYNTHETIC UI REVIEW", operatingSystem: "Simulator fixture",
            handedness: .right, playingArm: .right, watchWrist: .right, watchOrientation: "synthetic",
            playingArmConfirmed: true, drill: "forehand", capabilityReport: "Synthetic values; no hardware evidence",
            streams: RecordingStream.allCases.map {
                try RecordingStreamConfiguration(stream: $0, supported: true, requestedRateHz: nil, knownSensorLimit: nil)
            })
        let store = try RecordingStore.create(root: paths.rawRoot, metadata: metadata)
        for stream in RecordingStream.allCases {
            let samples = (0..<80).map { index -> RecordingSample in
                let t = 100 + Double(index) / 10 + (index >= 40 ? 3 : 0)
                let a = index == 20 ? 2.0 : 0.5 + abs(sin(Double(index) / 6)) * 0.5
                let values = stream == .accelerometer ? [3.0, 4, 0]
                    : [0, 0, .pi, 0, 0, 1, 0, 0, a, 0, 0, 0, 1]
                return .init(timestamp: t, values: values)
            }
            try store.append(RecordingChunk(recordingID: id, clockDomainID: metadata.clock.domainID,
                stream: stream, sequence: 0, samples: samples))
        }
        if mode != "interrupted" { try store.finalize(stopRequestTimestamp: 111, reason: .userStopped) }
        if mode != "unavailable" {
            var timeline = CaptureTimeline(recordingID: id, clockDomainID: metadata.clock.domainID)
            timeline.events = try [.init(kind: .start, timestamp: 100),
                .init(kind: .pauseRequested, timestamp: 104), .init(kind: .paused, timestamp: 104),
                .init(kind: .resumeRequested, timestamp: 107), .init(kind: .resumed, timestamp: 107),
                .init(kind: .stopRequested, timestamp: 111),
                .init(kind: mode == "interrupted" ? .interruption : .stopped, timestamp: 111)]
            try SessionAnnotationsStore(root: paths.notesRoot).saveTimeline(timeline)
        }
        return paths
    }
}
#endif

#if DEBUG
/// Every launch uses real codecs in a fresh synthetic namespace before default storage resolves.
@MainActor private enum OwnerPracticeReviewFixture {
    static let recordingID = UUID(uuidString: "A6201022-0010-4000-8000-000000000001")!
    static func make(arguments: [String]) throws -> RecordingPaths? {
        guard let mode = ["included", "absent", "excluded", "legacy"].first(where: {
            arguments.contains("--owner-practice-review-fixture=" + $0)
        }) else { return nil }
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("OwnerPracticeReview-" + UUID().uuidString)
        let phone = root.appendingPathComponent("phone"), base = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: phone, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let destinationPaths = try RecordingPaths(base: phone)
        let bootstrap = try OwnerPhoneBootstrap(base: phone)
        let epoch = try bootstrap.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch }
        let authority = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: epoch,
            watchInstallationEpoch: UUID(), attestsWatchAccountOwner: true, acceptsMotionStudy: true,
            includesHeartRate: true, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000,
            policyDigest: OwnerPracticePolicy.digest)
        let remote = root.appendingPathComponent("remote")
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        let channel = try PracticeSetupChannel(base: remote, localInstallationEpoch: authority.watchInstallationEpoch,
            device: .watch, intent: .createNew)
        let enrollment = try OwnerAuthorityMutation.enrollment(authority)
        let transition = try channel.sequence(enrollment)
        try bootstrap.withStores { _, phoneChannel in
            try phoneChannel.request(enrollment); _ = try phoneChannel.mirror(transition)
        }
        let paths = try RecordingPaths(base: base), practiceID = UUID(), samples = mode != "absent"
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
            let metadata = try RecordingMetadata(recordingID: index == 0 ? recordingID : UUID(),
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
                throw OwnerPracticeBundleError.integrity
            }
        }
        let store = try OwnerTelemetryStore.create(base: base, telemetry: value)
        let telemetry = store.snapshot; store.close()

        let bundle = root.appendingPathComponent("synthetic.pslpractice")
        _ = try OwnerPracticeBundle.write(telemetry: telemetry, rawRoot: paths.rawRoot, notesRoot: paths.notesRoot,
            revision: 1, heartRate: mode == "excluded" ? .excludedByOwner : .asRecorded, destination: bundle)
        if mode == "legacy" {
            let raw = root.appendingPathComponent("legacy.pslrecording")
            guard let timeline = try notes.loadTimeline(recordingID: recordingID) else { throw OwnerPracticeBundleError.integrity }
            _ = try RecordingArchive.write(recordingID: recordingID, rawRoot: paths.rawRoot, timeline: timeline, destination: raw)
            _ = try RecordingArchive.importBundle(from: raw, rawRoot: destinationPaths.rawRoot, notesRoot: destinationPaths.notesRoot)
        } else {
            let pending = try OwnerPracticeBundle.prepareImport(from: bundle, destinationBase: phone)
            defer { pending.cancel() }
            try pending.renameForPublication(); _ = try pending.confirmPublication()
        }
        return destinationPaths
    }
}
#endif
