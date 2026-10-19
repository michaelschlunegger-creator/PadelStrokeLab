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

    func list() throws -> [RecordingReview] {
        var result: [RecordingReview] = []
        let names = try FileManager.default.contentsOfDirectory(atPath: paths.rawRoot.path).filter {
            UUID(uuidString: $0)?.uuidString == $0
        }
        // A prototype library is bounded independently of each recording's chunk limit.
        guard names.count <= 512 else { throw PhoneRecordingError.invalid("Library inspection limit reached. Preserve your recordings and contact support.") }
        for name in names.sorted() {
            try Task.checkCancellation()
            guard let id = UUID(uuidString: name), id.uuidString == name else { continue }
            result.append(try review(id, includeStatistics: false))
        }
        return result.sorted {
            ($0.report.metadata?.clock.wallAnchorUnixSeconds ?? 0) > ($1.report.metadata?.clock.wallAnchorUnixSeconds ?? 0)
        }
    }

    func review(_ id: UUID, includeStatistics: Bool = true) throws -> RecordingReview {
        try Task.checkCancellation()
        let report = try RecordingStore.inspect(root: paths.rawRoot, recordingID: id)
        let notes = try SessionAnnotationsStore(root: paths.notesRoot)
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
        let streams = try RecordingStream.allCases.map { stream in
            let chunks = report.chunks.filter { $0.stream == stream }
            return RecordingStreamReview(stream: stream, count: chunks.reduce(0) { $0 + $1.sampleCount },
                first: chunks.map(\.firstTimestamp).min(), last: chunks.map(\.lastTimestamp).max(),
                segments: includeStatistics ? try statistics(id: id, chunks: chunks, segments: segments) : [])
        }
        let bytes = try storageBytes(id)
        return RecordingReview(id: id, report: report, timeline: timeline, labels: labels, streams: streams,
                               segments: segments, bytes: bytes, receiptVerified: verified, annotationWarning: warning)
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

    private func statistics(id: UUID, chunks: [RecordingChunkDescriptor], segments: [RecordingSegment]) throws -> [RecordingSegmentStatistics] {
        var counts = Array(repeating: 0, count: segments.count)
        var first = Array<Double?>(repeating: nil, count: segments.count)
        var previous = first
        var maximum = first
        for descriptor in chunks.sorted(by: { $0.sequence < $1.sequence }) {
            try Task.checkCancellation()
            let bytes = try readChunk(id: id, descriptor: descriptor)
            let chunk = try RecordingChunkCodec.decode(bytes)
            for sample in chunk.samples {
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

    private func readChunk(id: UUID, descriptor: RecordingChunkDescriptor) throws -> Data {
        let directory = open(paths.rawRoot.appendingPathComponent(id.uuidString).path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
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

    private func storageBytes(_ id: UUID) throws -> Int {
        var total = 0
        for root in [paths.rawRoot, paths.notesRoot] {
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
        let current = try review(recordingID, includeStatistics: false)
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
        let label = try RecordingAttemptLabel(recordingID: recordingID, attemptID: previous?.attemptID ?? UUID(),
            ordinal: previous?.ordinal ?? ((current.latestLabels.map(\.ordinal).max() ?? 0) + 1),
            revision: (previous?.revision ?? 0) + 1, category: draft.category, confidence: draft.confidence,
            evidence: draft.evidence, note: draft.note.isEmpty ? nil : draft.note,
            clockDomainID: start == nil ? nil : metadata.clock.domainID, startTimestamp: start, endTimestamp: end)
        let store = try SessionAnnotationsStore(root: paths.notesRoot)
        try store.saveLabels(current.labels + [label], recordingID: recordingID)
        return try review(recordingID)
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
        try RecordingLocalCopies.deletePhoneCopy(recordingID: id, paths: paths)
    }
}

@MainActor @Observable
final class RecordingLibraryModel {
    private(set) var recordings: [RecordingReview] = []
    private(set) var selected: RecordingReview?
    private(set) var loading = false
    private(set) var busy = false
    var error: String?
    private(set) var transferMessage = "Waiting for a verified Watch recording."
    private(set) var exportURL: URL?
    private(set) var pendingDeletion: UUID?
    private let repository: RecordingLibraryRepository?
    private var connectivity: RecordingConnectivity?
    private var generation = UUID()
    private var libraryGeneration = UUID()

    init(paths: RecordingPaths? = nil, activateConnectivity: Bool = true) {
        do {
            let resolved = try paths ?? RecordingPaths()
            repository = RecordingLibraryRepository(paths: resolved)
            if activateConnectivity {
                let connection = RecordingConnectivity(paths: resolved)
                connectivity = connection
                connection.onChange = { [weak self] snapshot in
                    Task { @MainActor in
                        self?.transferMessage = "\(snapshot.state.rawValue.capitalized): \(snapshot.detail ?? "Watch recording")"
                        await self?.refresh()
                    }
                }
                connection.activate()
            }
        } catch { repository = nil; self.error = "Recording storage unavailable: \(error.localizedDescription)" }
    }

    func refresh() async {
        guard let repository, !busy else { return }
        let request = UUID(); libraryGeneration = request; loading = true; error = nil
        defer { if libraryGeneration == request { loading = false } }
        do {
            let values = try await repository.list()
            guard libraryGeneration == request, !Task.isCancelled else { return }
            recordings = values
        } catch is CancellationError { } catch {
            if libraryGeneration == request { self.error = error.localizedDescription }
        }
    }

    func open(_ id: UUID) async {
        guard let repository else { return }
        let request = UUID(); generation = request; loading = true; selected = nil; exportURL = nil; error = nil
        defer { if generation == request { loading = false } }
        do {
            let value = try await repository.review(id)
            guard generation == request, !Task.isCancelled else { return }
            selected = value
        } catch is CancellationError { } catch {
            if generation == request { self.error = error.localizedDescription }
        }
    }

    func closeDetail() { generation = UUID(); selected = nil; loading = false; exportURL = nil }

    func save(_ draft: RecordingLabelDraft, recordingID: UUID) async -> Bool {
        guard let repository, !busy else { return false }
        busy = true; error = nil
        defer { busy = false }
        do {
            let value = try await repository.saveLabel(recordingID: recordingID, draft: draft)
            if selected?.id == recordingID { selected = value; exportURL = nil }
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func prepareExport(_ id: UUID) async {
        guard let repository, !busy else { return }
        busy = true; exportURL = nil; error = nil
        defer { busy = false }
        do {
            let url = try await repository.export(id)
            if selected?.id == id { exportURL = url }
        } catch { self.error = error.localizedDescription }
    }

    func requestDeletion(_ id: UUID) { guard !busy else { return }; pendingDeletion = id }
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
