import Darwin
import Foundation

/// Synchronous, single-caller storage. Not Sendable; callers must provide exclusive ownership.
/// Reopening is intentionally inspection-only: a new capture always needs a new recording ID.
public final class RecordingStore {
    public let metadata: RecordingMetadata
    private let directory: Int32
    private let metadataDigest: String
    private let io: RecordingFileOperations
    private var chunks: [RecordingChunkDescriptor] = []
    private var completion: RecordingFinalization?
    private var failed = false

    private init(directory: Int32, metadata: RecordingMetadata, digest: String, io: RecordingFileOperations) {
        self.directory = directory
        self.metadata = metadata
        self.metadataDigest = digest
        self.io = io
    }

    deinit { Darwin.close(directory) }

    public static func create(root: URL, metadata: RecordingMetadata) throws -> RecordingStore {
        try create(root: root, metadata: metadata, operations: RecordingFileOperations())
    }

    static func create(root: URL, metadata: RecordingMetadata, operations: RecordingFileOperations) throws -> RecordingStore {
        let bytes = try RecordingChunkCodec.encodeMetadata(metadata)
        let rootFD = try RecordingFiles.openRoot(root)
        defer { Darwin.close(rootFD) }
        let name = metadata.recordingID.uuidString
        guard mkdirat(rootFD, name, 0o700) == 0 else { throw RecordingFiles.error("create recording directory") }
        let directory = openat(rootFD, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directory >= 0 else { throw RecordingFiles.error("open new recording directory") }
        let store = RecordingStore(directory: directory, metadata: metadata,
                                   digest: RecordingChunkCodec.digest(bytes), io: operations)
        // Keep all partial evidence if creation fails. A failed UUID is never overwritten or reused.
        try RecordingFiles.sync(rootFD, name: name, operations: operations)
        try RecordingFiles.publish(bytes, name: "metadata.json", directory: directory, replace: false, operations: operations)
        try store.writeManifest(finalization: nil)
        return store
    }

    public func append(_ chunk: RecordingChunk) throws {
        guard !failed else { throw RecordingError.closed }
        guard completion == nil else { throw RecordingError.finalized }
        try chunk.validate()
        guard chunks.count < RecordingLimits.chunks else { throw RecordingError.limit("chunk count") }
        guard chunk.recordingID == metadata.recordingID, chunk.clockDomainID == metadata.clock.domainID,
              metadata.streams.contains(where: { $0.stream == chunk.stream && $0.supported }) else {
            throw RecordingError.invalid("chunk identity or stream")
        }
        let previous = chunks.last(where: { $0.stream == chunk.stream })
        guard chunk.sequence == (previous.map { $0.sequence + 1 } ?? 0),
              previous.map({ chunk.samples[0].timestamp > $0.lastTimestamp }) ?? true else {
            throw RecordingError.invalid("chunk order")
        }
        let bytes = try RecordingChunkCodec.encode(chunk)
        let descriptor = RecordingChunkCodec.descriptor(chunk, data: bytes)
        do {
            try RecordingFiles.publish(bytes, name: descriptor.fileName, directory: directory, replace: false, operations: io)
            chunks.append(descriptor)
            try writeManifest(finalization: nil)
        } catch {
            // Even publication can have succeeded before a later sync failed. Never continue by guessing.
            failed = true
            throw error
        }
    }

    /// Verifies all persisted bytes before publishing a final manifest. Retained coverage does not
    /// promise continuity, terminal-buffer flushing, or survival of every power/storage failure.
    @discardableResult
    public func finalize(stopRequestTimestamp: Double, reason: RecordingStopReason) throws -> RecordingFinalization {
        guard !failed else { throw RecordingError.closed }
        guard stopRequestTimestamp.isFinite, stopRequestTimestamp >= 0,
              chunks.allSatisfy({ $0.lastTimestamp <= stopRequestTimestamp }) else {
            throw RecordingError.invalid("stop timestamp")
        }
        let requested = RecordingFinalization(stopRequestTimestamp: stopRequestTimestamp,
                                              reason: reason, retainedCoverage: Self.coverage(chunks))
        if let completion, completion != requested { throw RecordingError.finalized }
        do {
            try io.event(.beforeFinalize, "manifest.json")
            let report = try Self.inspect(directory: directory, recordingID: metadata.recordingID,
                                          budget: RecordingInspectionBudget(), operations: io)
            guard report.issues.isEmpty, report.metadata == metadata,
                  report.chunks == Self.ordered(chunks),
                  report.finalization == completion,
                  report.status == (completion == nil ? .interrupted : .finalized) else {
                throw RecordingError.integrity("finalization readback")
            }
            if let completion { return completion }
            try writeManifest(finalization: requested)
            completion = requested
            return requested
        } catch {
            failed = true
            throw error
        }
    }

    public static func inspect(root: URL, recordingID: UUID,
                               budget: RecordingInspectionBudget? = nil) throws -> RecordingRecoveryReport {
        let rootFD = try RecordingFiles.openRoot(root)
        defer { Darwin.close(rootFD) }
        let directory = openat(rootFD, recordingID.uuidString, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directory >= 0 else { throw RecordingFiles.error("open recording for inspection") }
        defer { Darwin.close(directory) }
        return try inspect(directory: directory, recordingID: recordingID,
                           budget: budget ?? RecordingInspectionBudget(), operations: RecordingFileOperations())
    }

    private func writeManifest(finalization: RecordingFinalization?) throws {
        let manifest = RecordingManifest(schemaVersion: 1, recordingID: metadata.recordingID,
                                         metadataSHA256: metadataDigest, chunks: Self.ordered(chunks), finalization: finalization)
        let data = try RecordingJSON.encode(manifest, limit: RecordingLimits.manifestBytes)
        try RecordingFiles.publish(data, name: "manifest.json", directory: directory, replace: true, operations: io)
        var remaining = RecordingLimits.manifestBytes
        let stored = try RecordingFiles.read("manifest.json", directory: directory, cap: RecordingLimits.manifestBytes,
                                             remaining: &remaining, operations: io)
        guard stored == data else { throw RecordingError.integrity("manifest publication readback") }
    }

    private static func inspect(directory: Int32, recordingID: UUID, budget: RecordingInspectionBudget,
                                operations: RecordingFileOperations) throws -> RecordingRecoveryReport {
        var issues: [RecordingRecoveryIssue] = []
        let listing = try RecordingFiles.names(directory, maximum: budget.maximumEntries)
        if listing.limited { issues.append(.init(kind: .limit, fileName: "directory")) }
        let names = Set(listing.names)
        var remaining = budget.maximumBytes
        var metadata: RecordingMetadata?
        var manifest: RecordingManifest?
        var metadataHash: String?
        func issue(_ kind: RecordingRecoveryIssue.Kind, _ name: String) {
            issues.append(.init(kind: kind, fileName: name))
        }
        func read(_ name: String, cap: Int) throws -> Data {
            try RecordingFiles.read(name, directory: directory, cap: cap, remaining: &remaining, operations: operations)
        }
        func readIssue(_ error: Error, _ name: String) {
            if case RecordingError.limit("inspection bytes") = error { issue(.limit, name) }
            else { issue(.corrupt, name) }
        }
        if names.contains("metadata.json") {
            do {
                let data = try read("metadata.json", cap: RecordingLimits.metadataBytes)
                let decoded = try RecordingChunkCodec.decodeMetadata(data)
                guard decoded.recordingID == recordingID else { throw RecordingError.integrity("recording identity") }
                metadata = decoded
                metadataHash = RecordingChunkCodec.digest(data)
            } catch { readIssue(error, "metadata.json") }
        } else { issue(.missing, "metadata.json") }
        if names.contains("manifest.json") {
            do {
                let decoded: RecordingManifest = try RecordingJSON.decode(read("manifest.json", cap: RecordingLimits.manifestBytes),
                                                                          limit: RecordingLimits.manifestBytes)
                try decoded.validate(recordingID: recordingID, metadataHash: metadataHash)
                manifest = decoded
            } catch { readIssue(error, "manifest.json") }
        } else { issue(.missing, "manifest.json") }

        var valid: [RecordingChunkDescriptor] = []
        let indexed = Dictionary(uniqueKeysWithValues: (manifest?.chunks ?? []).map { ($0.fileName, $0) })
        var inspectedChunks = 0
        for name in listing.names.sorted() where name != "metadata.json" && name != "manifest.json" {
            if name.hasPrefix(".pending-") { issue(.partial, name); continue }
            guard name.hasPrefix("chunk-"), name.hasSuffix(".bin") else { issue(.unexpected, name); continue }
            guard inspectedChunks < RecordingLimits.chunks else { issue(.limit, name); continue }
            inspectedChunks += 1
            do {
                let data = try read(name, cap: RecordingLimits.chunkBytes)
                let chunk = try RecordingChunkCodec.decode(data)
                let descriptor = RecordingChunkCodec.descriptor(chunk, data: data)
                guard chunk.recordingID == recordingID, chunk.clockDomainID == metadata?.clock.domainID,
                      metadata?.streams.contains(where: { $0.stream == chunk.stream && $0.supported }) == true,
                      name == descriptor.fileName else { throw RecordingError.integrity("stored identity") }
                if let expected = indexed[name] {
                    guard expected == descriptor else { throw RecordingError.integrity("stored descriptor") }
                } else { issue(.orphan, name) }
                valid.append(descriptor)
            } catch { readIssue(error, name) }
        }
        for name in indexed.keys.sorted() where !names.contains(name) { issue(.missing, name) }
        valid = ordered(valid)
        do { try validateOrder(valid) } catch { issue(.inconsistent, "chunk sequence or timestamps") }
        if let finalization = manifest?.finalization {
            if finalization.retainedCoverage != coverage(valid)
                || valid != manifest?.chunks
                || !valid.allSatisfy({ $0.lastTimestamp <= finalization.stopRequestTimestamp }) {
                issue(.inconsistent, "finalization")
            }
        }
        let status: RecordingRecoveryStatus
        if issues.contains(where: { $0.kind == .limit }) { status = .limited }
        else if issues.contains(where: { [.corrupt, .missing, .inconsistent, .unexpected].contains($0.kind) }) { status = .corrupt }
        else if !issues.isEmpty || manifest?.finalization == nil { status = .interrupted }
        else { status = .finalized }
        return RecordingRecoveryReport(metadata: metadata, status: status, chunks: valid,
                                       finalization: status == .finalized ? manifest?.finalization : nil, issues: issues)
    }

    fileprivate static func ordered(_ chunks: [RecordingChunkDescriptor]) -> [RecordingChunkDescriptor] {
        chunks.sorted { $0.stream == $1.stream ? $0.sequence < $1.sequence : $0.stream.rawValue < $1.stream.rawValue }
    }

    fileprivate static func validateOrder(_ chunks: [RecordingChunkDescriptor]) throws {
        guard chunks.count <= RecordingLimits.chunks, chunks == ordered(chunks) else { throw RecordingError.invalid("manifest ordering") }
        var last: [RecordingStream: RecordingChunkDescriptor] = [:]
        for chunk in chunks {
            let previous = last[chunk.stream]
            guard chunk.sequence == (previous.map { $0.sequence + 1 } ?? 0),
                  previous.map({ chunk.firstTimestamp > $0.lastTimestamp }) ?? true,
                  chunk.sampleCount > 0, chunk.sampleCount <= chunk.stream.maximumSamples,
                  chunk.firstTimestamp.isFinite, chunk.lastTimestamp.isFinite, chunk.firstTimestamp >= 0,
                  (chunk.sampleCount == 1 ? chunk.firstTimestamp == chunk.lastTimestamp : chunk.firstTimestamp < chunk.lastTimestamp),
                  chunk.byteCount == 104 + chunk.sampleCount * (chunk.stream.componentCount + 1) * 8,
                  chunk.sha256.count == 64, chunk.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
                throw RecordingError.invalid("manifest chunk descriptor")
            }
            last[chunk.stream] = chunk
        }
    }

    fileprivate static func coverage(_ chunks: [RecordingChunkDescriptor]) -> [RecordingCoverage] {
        RecordingStream.allCases.compactMap { stream in
            let members = chunks.filter { $0.stream == stream }
            guard let first = members.first, let last = members.last else { return nil }
            return RecordingCoverage(stream: stream, sampleCount: members.reduce(0) { $0 + $1.sampleCount },
                                     firstTimestamp: first.firstTimestamp, lastTimestamp: last.lastTimestamp)
        }
    }
}

private struct RecordingManifest: Codable {
    let schemaVersion: Int
    let recordingID: UUID
    let metadataSHA256: String
    let chunks: [RecordingChunkDescriptor]
    let finalization: RecordingFinalization?

    func validate(recordingID: UUID, metadataHash: String?) throws {
        guard schemaVersion == 1, self.recordingID == recordingID, metadataSHA256 == metadataHash else {
            throw RecordingError.integrity("manifest metadata")
        }
        try RecordingStore.validateOrder(chunks)
        if let finalization {
            guard finalization.stopRequestTimestamp.isFinite, finalization.stopRequestTimestamp >= 0,
                  finalization.retainedCoverage == RecordingStore.coverage(chunks),
                  chunks.allSatisfy({ $0.lastTimestamp <= finalization.stopRequestTimestamp }) else {
                throw RecordingError.integrity("manifest finalization")
            }
        }
    }
}

/// Internal seam: production uses real POSIX operations. Hooks can fail/terminate at precise boundaries;
/// a test can shorten an actual write, but successful default writes are never mocked.
enum RecordingIOEvent: Sendable {
    case beforeWrite, afterWrite, beforeSynchronize, afterSynchronize
    case beforePublish, afterPublish, beforeDirectorySync, beforeRead, beforeFinalize
}

struct RecordingFileOperations {
    var event: (RecordingIOEvent, String) throws -> Void = { _, _ in }
    var write: (Int32, UnsafeRawPointer, Int) throws -> Int = { descriptor, pointer, count in
        let written = Darwin.write(descriptor, pointer, count)
        guard written >= 0 else { throw RecordingFiles.error("write") }
        return written
    }
}

private enum RecordingFiles {
    static func error(_ operation: String) -> RecordingError { .io(operation: operation, code: errno) }

    static func openRoot(_ url: URL) throws -> Int32 {
        guard url.isFileURL, url.path.hasPrefix("/"), !url.path.utf8.contains(0) else {
            throw RecordingError.invalid("root path")
        }
        let components = url.path.split(separator: "/")
        guard !components.contains("."), !components.contains("..") else { throw RecordingError.invalid("root traversal") }
        var descriptor = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw error("open filesystem root") }
        for component in components {
            let next = openat(descriptor, String(component), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            let savedError = errno
            Darwin.close(descriptor)
            guard next >= 0 else { throw RecordingError.io(operation: "open root component", code: savedError) }
            descriptor = next
        }
        return descriptor
    }

    static func sync(_ descriptor: Int32, name: String, operations: RecordingFileOperations) throws {
        try operations.event(.beforeDirectorySync, name)
        guard fsync(descriptor) == 0 else { throw error("synchronize directory") }
    }

    static func publish(_ data: Data, name: String, directory: Int32, replace: Bool,
                        operations: RecordingFileOperations) throws {
        let temporary = ".pending-\(UUID().uuidString)"
        let descriptor = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw error("create temporary file") }
        var open = true
        defer { if open { Darwin.close(descriptor) } }
        // Deliberately retain failed temporary writes for non-destructive inspection.
        try data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { throw RecordingError.invalid("empty file") }
            var offset = 0
            while offset < bytes.count {
                try operations.event(.beforeWrite, name)
                let count: Int
                do { count = try operations.write(descriptor, base.advanced(by: offset), bytes.count - offset) }
                catch RecordingError.io(_, let code) where code == EINTR { continue }
                guard count > 0, count <= bytes.count - offset else { throw RecordingError.integrity("invalid write progress") }
                offset += count
                try operations.event(.afterWrite, name)
            }
        }
        try operations.event(.beforeSynchronize, name)
        guard fsync(descriptor) == 0 else { throw error("synchronize temporary file") }
        try operations.event(.afterSynchronize, name)
        let closeResult = Darwin.close(descriptor)
        open = false
        guard closeResult == 0 else { throw error("close temporary file") }
        try operations.event(.beforePublish, name)
        if replace {
            guard renameat(directory, temporary, directory, name) == 0 else { throw error("publish manifest") }
        } else {
            // linkat is atomic and exclusive: an existing destination (including a symlink) fails.
            guard linkat(directory, temporary, directory, name, 0) == 0 else { throw error("publish immutable file") }
            guard unlinkat(directory, temporary, 0) == 0 else { throw error("unlink published temporary name") }
        }
        try operations.event(.afterPublish, name)
        try sync(directory, name: name, operations: operations)
    }

    static func read(_ name: String, directory: Int32, cap: Int, remaining: inout Int,
                     operations: RecordingFileOperations) throws -> Data {
        try operations.event(.beforeRead, name)
        let descriptor = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw error("open stored file") }
        defer { Darwin.close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw error("stat stored file") }
        guard info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1 else { throw RecordingError.integrity("file type or hard link") }
        guard info.st_size >= 0, info.st_size <= cap else { throw RecordingError.limit("stored file bytes") }
        let size = Int(info.st_size)
        guard size <= remaining else { throw RecordingError.limit("inspection bytes") }
        remaining -= size
        var data = Data(count: size)
        try data.withUnsafeMutableBytes { bytes in
            var offset = 0
            while offset < size {
                let count = Darwin.read(descriptor, bytes.baseAddress!.advanced(by: offset), size - offset)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw count == 0 ? RecordingError.integrity("truncated file") : error("read stored file") }
                offset += count
            }
        }
        var extra: UInt8 = 0
        let extraCount = Darwin.read(descriptor, &extra, 1)
        guard extraCount == 0 else { throw RecordingError.integrity("file changed during read") }
        return data
    }

    static func names(_ directory: Int32, maximum: Int) throws -> (names: [String], limited: Bool) {
        let duplicate = dup(directory)
        guard duplicate >= 0 else { throw error("duplicate directory") }
        guard let stream = fdopendir(duplicate) else {
            let failure = error("enumerate directory")
            Darwin.close(duplicate)
            throw failure
        }
        defer { closedir(stream) }
        rewinddir(stream)
        var result: [String] = []
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                guard errno == 0 else { throw error("read directory") }
                return (result, false)
            }
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(validatingCString: $0) }
            }
            guard let name else { throw RecordingError.integrity("directory entry encoding") }
            if name == "." || name == ".." { continue }
            guard result.count < maximum else { return (result, true) }
            result.append(name)
        }
    }
}
