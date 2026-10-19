import CryptoKit
import Darwin
import Foundation

public struct RecordingArchiveReceipt: Codable, Equatable, Sendable {
    public let recordingID: UUID
    public let bundleSHA256: String
    public let byteCount: Int
    public let streams: [RecordingCoverage]

    func validate() throws {
        guard ArchiveEntry.isDigest(bundleSHA256), byteCount > 0, byteCount <= RecordingArchive.maximumBytes,
              streams.count <= 2, Set(streams.map(\.stream)).count == streams.count else {
            throw RecordingError.invalid("archive receipt")
        }
        for stream in streams {
            guard stream.sampleCount > 0, stream.firstTimestamp.isFinite, stream.lastTimestamp.isFinite,
                  stream.firstTimestamp >= 0, stream.lastTimestamp >= stream.firstTimestamp else {
                throw RecordingError.invalid("receipt coverage")
            }
        }
    }
}

extension SessionAnnotationsStore {
    public func loadReceipt(recordingID: UUID) throws -> RecordingArchiveReceipt? {
        guard let data = try read("receipt.json", id: recordingID, limit: 4096) else { return nil }
        let receipt: RecordingArchiveReceipt = try RecordingJSON.decode(data, limit: 4096)
        try receipt.validate()
        guard receipt.recordingID == recordingID else { throw RecordingError.invalid("receipt identity") }
        return receipt
    }

    func saveReceipt(_ receipt: RecordingArchiveReceipt) throws {
        try receipt.validate()
        try save(RecordingJSON.encode(receipt, limit: 4096), name: "receipt.json", id: receipt.recordingID)
    }
}

private struct ArchiveEntry: Codable, Equatable {
    let name: String
    let byteCount: Int
    let sha256: String

    static func isDigest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    static func limit(_ name: String) throws -> Int {
        switch name {
        case "notes/capture-events.json": return SessionAnnotationsStore.timelineLimit
        case "notes/labels.json": return SessionAnnotationsStore.labelsLimit
        case "raw/metadata.json": return RecordingLimits.metadataBytes
        case "raw/manifest.json": return RecordingLimits.manifestBytes
        default:
            guard name.hasPrefix("raw/") else { throw RecordingError.invalid("archive entry name") }
            let raw = String(name.dropFirst(4))
            if raw.hasPrefix(".pending-"), let uuid = UUID(uuidString: String(raw.dropFirst(9))),
               raw == ".pending-\(uuid.uuidString)" { return RecordingLimits.chunkBytes }
            let parts = raw.split(separator: "-")
            guard parts.count == 3, parts[0] == "chunk", let stream = UInt32(parts[1]),
                  RecordingStream(rawValue: stream) != nil, parts[2].hasSuffix(".bin"),
                  let sequence = Int(parts[2].dropLast(4)), (0..<RecordingLimits.chunks).contains(sequence),
                  raw == "chunk-\(stream)-\(sequence).bin" else { throw RecordingError.invalid("archive raw name") }
            return RecordingLimits.chunkBytes
        }
    }
}

private struct ArchiveHeader: Codable {
    let schemaVersion: Int
    let recordingID: UUID
    let status: String
    let entries: [ArchiveEntry]

    func validate() throws {
        guard schemaVersion == 1, ["finalized", "interrupted"].contains(status),
              (3...(RecordingLimits.directoryEntries + 2)).contains(entries.count),
              entries.map(\.name) == entries.map(\.name).sorted(),
              Set(entries.map(\.name)).count == entries.count,
              entries.contains(where: { $0.name == "raw/metadata.json" }),
              entries.contains(where: { $0.name == "raw/manifest.json" }),
              entries.contains(where: { $0.name == "notes/capture-events.json" }) else {
            throw RecordingError.invalid("archive header")
        }
        var total = 0
        for entry in entries {
            let limit = try ArchiveEntry.limit(entry.name)
            guard entry.byteCount > 0, entry.byteCount <= limit, ArchiveEntry.isDigest(entry.sha256) else {
                throw RecordingError.invalid("archive entry size or digest")
            }
            total += entry.byteCount
        }
        guard total <= RecordingArchive.maximumBytes - 65_548 else { throw RecordingError.limit("archive bytes") }
    }
}

/// Bounded streaming format: magic, UInt32 little-endian canonical header length, JSON header,
/// ordered file bytes, SHA256 of every preceding byte. Receipt digest covers the entire bundle.
/// Checksums detect corruption; they do not authenticate an adversarial sender.
public enum RecordingArchive {
    static let maximumBytes = RecordingLimits.inspectionBytes + 1_310_720
    private static let magic = Data("PSLBND01".utf8)
    private static let block = 65_536

    public static func write(recordingID: UUID, rawRoot: URL, timeline: CaptureTimeline,
                             destination: URL, labels: [RecordingAttemptLabel] = []) throws -> RecordingArchiveReceipt {
        let lease = try RecordingCaptureLease(recordingID: recordingID, rawRoot: rawRoot)
        defer { withExtendedLifetime(lease) {} }
        let report = try RecordingStore.inspect(root: rawRoot, recordingID: recordingID)
        try acceptable(report)
        try timeline.validate(metadata: report.metadata)
        guard timeline.recordingID == recordingID else { throw RecordingError.invalid("archive timeline identity") }
        let history = RecordingLabelHistory(schemaVersion: 1, recordingID: recordingID, labels: labels)
        try history.validate(timeline: timeline)
        let noteBytes = [
            "notes/capture-events.json": try RecordingJSON.encode(timeline, limit: SessionAnnotationsStore.timelineLimit),
            "notes/labels.json": try RecordingJSON.encode(history, limit: SessionAnnotationsStore.labelsLimit)
        ]
        let root = try AnnotationFiles.root(rawRoot)
        defer { close(root) }
        let raw = try AnnotationFiles.directory(recordingID.uuidString, parent: root, create: false)
        defer { close(raw) }
        var entries: [ArchiveEntry] = []
        for name in try AnnotationFiles.names(raw, limit: RecordingLimits.directoryEntries) {
            let limit = try ArchiveEntry.limit("raw/" + name)
            let (fd, size) = try AnnotationFiles.openFile(name, directory: raw)
            defer { close(fd) }
            guard size > 0, size <= limit else { throw RecordingError.limit("raw archive file") }
            let digest = try consume(fd, size: size) { _ in }
            entries.append(ArchiveEntry(name: "raw/" + name, byteCount: size, sha256: digest))
        }
        for (name, bytes) in noteBytes {
            entries.append(ArchiveEntry(name: name, byteCount: bytes.count, sha256: RecordingChunkCodec.digest(bytes)))
        }
        entries.sort { $0.name < $1.name }
        let header = ArchiveHeader(schemaVersion: 1, recordingID: recordingID, status: report.status.rawValue, entries: entries)
        try header.validate()
        let headerBytes = try RecordingJSON.encode(header, limit: block)
        let destinationRoot = try AnnotationFiles.root(destination.deletingLastPathComponent())
        defer { close(destinationRoot) }
        try AnnotationFiles.safeName(destination.lastPathComponent)
        let temporaryKind = RecordingLocalCopies.isAutomaticOutboxName(destination.lastPathComponent, recordingID: recordingID) ? "auto" : "export"
        let temporary = ".pending-\(temporaryKind)-\(recordingID.uuidString)-\(UUID().uuidString)"
        let out = openat(destinationRoot, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard out >= 0 else { throw AnnotationFiles.error("create archive") }
        defer { close(out) }
        var hash = SHA256()
        var count = 0
        func emit(_ data: Data) throws {
            try AnnotationFiles.write(data, fd: out); hash.update(data: data); count += data.count
        }
        try emit(magic)
        var length = UInt32(headerBytes.count).littleEndian
        try withUnsafeBytes(of: &length) { try emit(Data($0)) }
        try emit(headerBytes)
        for entry in entries {
            if let bytes = noteBytes[entry.name] { try emit(bytes) }
            else {
                let (fd, size) = try AnnotationFiles.openFile(String(entry.name.dropFirst(4)), directory: raw)
                defer { close(fd) }
                guard size == entry.byteCount else { throw RecordingError.integrity("source file changed") }
                let digest = try consume(fd, size: size) { try emit($0) }
                guard digest == entry.sha256 else { throw RecordingError.integrity("source bytes changed") }
            }
        }
        let footer = Data(hash.finalize())
        try emit(footer)
        try AnnotationFiles.sync(out)
        // Reinspect after reading: active recordings are not eligible for immutable export.
        let after = try RecordingStore.inspect(root: rawRoot, recordingID: recordingID)
        guard after.status == report.status, after.chunks == report.chunks, after.issues == report.issues,
              after.finalization == report.finalization else { throw RecordingError.integrity("recording changed during export") }
        guard linkat(destinationRoot, temporary, destinationRoot, destination.lastPathComponent, 0) == 0 else {
            throw AnnotationFiles.error("publish archive")
        }
        guard unlinkat(destinationRoot, temporary, 0) == 0 else { throw AnnotationFiles.error("unlink archive temporary") }
        try AnnotationFiles.sync(destinationRoot)
        return RecordingArchiveReceipt(recordingID: recordingID, bundleSHA256: hex(hash.finalize()),
                                       byteCount: count, streams: coverage(report))
    }

    public static func importBundle(from source: URL, rawRoot: URL, notesRoot: URL) throws -> RecordingArchiveReceipt {
        try importBundle(from: source, rawRoot: rawRoot, notesRoot: notesRoot, beforeReceipt: {})
    }

    /// Fault seam only: production always executes durable writes and verification.
    static func importBundle(from source: URL, rawRoot: URL, notesRoot: URL,
                             expectedIdentity: UUID? = nil, expectedDigest: String? = nil,
                             beforeReceipt: () throws -> Void) throws -> RecordingArchiveReceipt {
        let sourceRoot = try AnnotationFiles.root(source.deletingLastPathComponent())
        defer { close(sourceRoot) }
        let (input, size) = try AnnotationFiles.openFile(source.lastPathComponent, directory: sourceRoot)
        defer { close(input) }
        guard size >= 44, size <= maximumBytes else { throw RecordingError.limit("archive file bytes") }
        var hash = SHA256()
        var readCount = 0
        func take(_ count: Int) throws -> Data {
            guard count >= 0, count <= size - readCount else { throw RecordingError.integrity("archive truncated") }
            let bytes = try AnnotationFiles.readExactly(input, count: count)
            hash.update(data: bytes); readCount += count; return bytes
        }
        guard try take(8) == magic else { throw RecordingError.invalid("archive magic") }
        let lengthBytes = try take(4)
        let length = lengthBytes.enumerated().reduce(0) { $0 | (Int($1.element) << ($1.offset * 8)) }
        guard length > 0, length <= block else { throw RecordingError.limit("archive header length") }
        let header: ArchiveHeader = try RecordingJSON.decode(take(length), limit: block)
        try header.validate()
        guard expectedIdentity.map({ $0 == header.recordingID }) ?? true else {
            throw RecordingError.integrity("transport recording identity")
        }
        let transaction = try RecordingLocalTransaction(recordingID: header.recordingID, notesRoot: notesRoot)
        defer { withExtendedLifetime(transaction) {} }
        try transaction.requireAvailable()
        guard header.entries.reduce(0, { $0 + $1.byteCount }) + 12 + length + 32 == size else {
            throw RecordingError.integrity("archive declared length")
        }
        let root = try AnnotationFiles.root(rawRoot)
        defer { close(root) }
        let stagingName = ".incoming-\(header.recordingID.uuidString)-\(UUID().uuidString)"
        let staging = try AnnotationFiles.directory(stagingName, parent: root, create: true)
        defer { close(staging) }
        let stageRaw = try AnnotationFiles.directory(header.recordingID.uuidString, parent: staging, create: true)
        defer { close(stageRaw) }
        var notes: [String: Data] = [:]
        for entry in header.entries {
            var entryHash = SHA256()
            let output: Int32
            if entry.name.hasPrefix("raw/") {
                output = openat(stageRaw, String(entry.name.dropFirst(4)), O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
                guard output >= 0 else { throw AnnotationFiles.error("stage raw entry") }
            } else { output = -1 }
            defer { if output >= 0 { close(output) } }
            var remaining = entry.byteCount
            var note = Data()
            while remaining > 0 {
                let bytes = try take(min(block, remaining))
                entryHash.update(data: bytes)
                if output >= 0 { try AnnotationFiles.write(bytes, fd: output) } else { note.append(bytes) }
                remaining -= bytes.count
            }
            guard hex(entryHash.finalize()) == entry.sha256 else { throw RecordingError.integrity("archive entry checksum") }
            if output >= 0 { try AnnotationFiles.sync(output) } else { notes[entry.name] = note }
        }
        let expectedFooter = Data(hash.finalize())
        guard try take(32) == expectedFooter else { throw RecordingError.integrity("archive checksum") }
        guard expectedDigest.map({ $0 == hex(hash.finalize()) }) ?? true else {
            throw RecordingError.integrity("transport archive digest")
        }
        var extra: UInt8 = 0
        guard Darwin.read(input, &extra, 1) == 0 else { throw RecordingError.integrity("archive grew") }
        try AnnotationFiles.sync(stageRaw)
        try AnnotationFiles.sync(staging)
        let stagedRoot = rawRoot.appendingPathComponent(stagingName, isDirectory: true)
        let report = try RecordingStore.inspect(root: stagedRoot, recordingID: header.recordingID)
        try acceptable(report)
        guard report.status.rawValue == header.status else { throw RecordingError.integrity("archive recovery status") }
        guard let timelineBytes = notes["notes/capture-events.json"] else { throw RecordingError.invalid("missing timeline") }
        let timeline: CaptureTimeline = try RecordingJSON.decode(timelineBytes, limit: SessionAnnotationsStore.timelineLimit)
        try timeline.validate(metadata: report.metadata)
        var labels: [RecordingAttemptLabel] = []
        if let bytes = notes["notes/labels.json"] {
            let history: RecordingLabelHistory = try RecordingJSON.decode(bytes, limit: SessionAnnotationsStore.labelsLimit)
            guard history.recordingID == header.recordingID else { throw RecordingError.invalid("archive label identity") }
            try history.validate(timeline: timeline); labels = history.labels
        }
        let receipt = RecordingArchiveReceipt(recordingID: header.recordingID, bundleSHA256: hex(hash.finalize()),
                                               byteCount: size, streams: coverage(report))
        let annotations = try SessionAnnotationsStore(root: notesRoot)
        if let existing = try annotations.loadReceipt(recordingID: header.recordingID), existing != receipt {
            throw RecordingError.integrity("conflicting recording receipt")
        }
        // An earlier crash may have installed raw data without its final receipt. Compare every
        // original byte before completing notes; never overwrite the existing raw directory.
        let existing: Int32
        do { existing = try AnnotationFiles.directory(header.recordingID.uuidString, parent: root, create: false) }
        catch RecordingError.io(_, let code) where code == ENOENT { existing = -1 }
        if existing >= 0 {
            defer { close(existing) }
            try matches(existing, entries: header.entries.filter { $0.name.hasPrefix("raw/") })
        } else {
            guard renameatx_np(staging, header.recordingID.uuidString, root, header.recordingID.uuidString, UInt32(RENAME_EXCL)) == 0 else {
                throw AnnotationFiles.error("install raw recording")
            }
            try AnnotationFiles.sync(root)
        }
        try annotations.saveTimeline(timeline)
        // A verified retry never rewrites owner edits. Only seed absent label files.
        try annotations.seedLabels(labels, recordingID: header.recordingID)
        try beforeReceipt()
        try annotations.saveReceipt(receipt)
        // Cleanup only the fully verified private staging copy; failures remain visible for diagnosis.
        if existing >= 0 {
            for entry in header.entries where entry.name.hasPrefix("raw/") {
                guard unlinkat(stageRaw, String(entry.name.dropFirst(4)), 0) == 0 else { throw AnnotationFiles.error("remove verified stage file") }
            }
            guard unlinkat(staging, header.recordingID.uuidString, AT_REMOVEDIR) == 0 else { throw AnnotationFiles.error("remove verified stage") }
        }
        guard unlinkat(root, stagingName, AT_REMOVEDIR) == 0 else { throw AnnotationFiles.error("remove staging root") }
        try AnnotationFiles.sync(root)
        return receipt
    }

    private static func acceptable(_ report: RecordingRecoveryReport) throws {
        guard report.metadata != nil, report.status == .finalized || report.status == .interrupted else {
            throw RecordingError.integrity("recording is corrupt or inspection-limited; originals retained")
        }
    }

    private static func coverage(_ report: RecordingRecoveryReport) -> [RecordingCoverage] {
        RecordingStream.allCases.compactMap { stream in
            let chunks = report.chunks.filter { $0.stream == stream }.sorted { $0.sequence < $1.sequence }
            guard let first = chunks.first, let last = chunks.last else { return nil }
            return RecordingCoverage(stream: stream, sampleCount: chunks.reduce(0) { $0 + $1.sampleCount },
                                     firstTimestamp: first.firstTimestamp, lastTimestamp: last.lastTimestamp)
        }
    }

    private static func matches(_ directory: Int32, entries: [ArchiveEntry]) throws {
        guard try AnnotationFiles.names(directory, limit: RecordingLimits.directoryEntries) == entries.map({ String($0.name.dropFirst(4)) }).sorted() else {
            throw RecordingError.integrity("conflicting raw inventory")
        }
        for entry in entries {
            let (fd, size) = try AnnotationFiles.openFile(String(entry.name.dropFirst(4)), directory: directory)
            defer { close(fd) }
            guard size == entry.byteCount, try consume(fd, size: size, body: { _ in }) == entry.sha256 else {
                throw RecordingError.integrity("conflicting raw bytes")
            }
        }
    }

    private static func consume(_ fd: Int32, size: Int, body: (Data) throws -> Void) throws -> String {
        var remaining = size
        var hash = SHA256()
        while remaining > 0 {
            let bytes = try AnnotationFiles.readExactly(fd, count: min(block, remaining))
            hash.update(data: bytes); try body(bytes); remaining -= bytes.count
        }
        var extra: UInt8 = 0
        guard Darwin.read(fd, &extra, 1) == 0 else { throw RecordingError.integrity("source file grew") }
        return hex(hash.finalize())
    }

    private static func hex(_ digest: SHA256.Digest) -> String { digest.map { String(format: "%02x", $0) }.joined() }
}
