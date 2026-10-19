import Darwin
import Foundation

/// An active capture and an immutable export cannot own the same recording simultaneously.
/// Keep this object throughout capture, including pauses; releasing it or process exit unlocks.
public final class RecordingCaptureLease {
    private let descriptor: Int32

    public init(recordingID: UUID, rawRoot: URL) throws {
        let root = try AnnotationFiles.root(rawRoot)
        defer { close(root) }
        let fd = openat(root, ".capture-\(recordingID.uuidString).lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw AnnotationFiles.error("open capture lease") }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1 else {
            close(fd); throw RecordingError.integrity("capture lease file")
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd); throw RecordingError.invalid("Recording is still active; stop it before export or transfer.")
        }
        descriptor = fd
    }

    deinit { flock(descriptor, LOCK_UN); close(descriptor) }
}

/// Canonical, precreated app-container roots. Raw recordings and editable notes are separate.
public struct RecordingPaths: Sendable {
    public let rawRoot: URL
    public let notesRoot: URL
    public let outboxRoot: URL
    public let inboxRoot: URL

    public init(base: URL? = nil) throws {
        let supplied = try base ?? FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        // Resolve only the trusted system container boundary; every descendant uses no-follow.
        try FileManager.default.createDirectory(at: supplied, withIntermediateDirectories: true)
        guard let resolved = realpath(supplied.path, nil) else { throw AnnotationFiles.error("canonical container") }
        defer { free(resolved) }
        let canonical = URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
        let baseFD = try AnnotationFiles.root(canonical)
        defer { close(baseFD) }
        let recordings = try AnnotationFiles.directory("Recordings", parent: baseFD, create: true)
        defer { close(recordings) }
        for name in ["raw", "notes", "outbox", "inbox"] {
            let child = try AnnotationFiles.directory(name, parent: recordings, create: true)
            close(child)
        }
        let root = canonical.appendingPathComponent("Recordings", isDirectory: true)
        rawRoot = root.appendingPathComponent("raw", isDirectory: true)
        notesRoot = root.appendingPathComponent("notes", isDirectory: true)
        outboxRoot = root.appendingPathComponent("outbox", isDirectory: true)
        inboxRoot = root.appendingPathComponent("inbox", isDirectory: true)
        var excludedRoot = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try excludedRoot.setResourceValues(values)
    }
}

/// Shared descriptor-relative I/O. Synchronous; caller provides serialized ownership.
enum AnnotationFiles {
    static func error(_ operation: String) -> RecordingError { .io(operation: operation, code: errno) }

    static func root(_ url: URL) throws -> Int32 {
        guard url.isFileURL, url.path.hasPrefix("/"), !url.path.utf8.contains(0) else {
            throw RecordingError.invalid("annotation root")
        }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw error("open root") }
        do {
            for component in url.path.split(separator: "/") {
                guard component != ".", component != ".." else { throw RecordingError.invalid("root traversal") }
                let next = try directory(String(component), parent: fd, create: false)
                close(fd)
                fd = next
            }
            return fd
        } catch { close(fd); throw error }
    }

    static func directory(_ name: String, parent: Int32, create: Bool) throws -> Int32 {
        try safeName(name)
        if create {
            if mkdirat(parent, name, 0o700) != 0, errno != EEXIST { throw error("create directory") }
            try sync(parent)
        }
        let fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw error("open directory") }
        return fd
    }

    static func safeName(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..", name.utf8.count <= 128,
              !name.contains("/"), !name.utf8.contains(0) else { throw RecordingError.invalid("file name") }
    }

    static func sync(_ fd: Int32) throws {
        guard fsync(fd) == 0 else { throw error("synchronize") }
    }

    static func openFile(_ name: String, directory: Int32) throws -> (Int32, Int) {
        try safeName(name)
        let fd = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw error("open file") }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_nlink == 1, info.st_size >= 0, info.st_size <= Int.max else {
            close(fd); throw RecordingError.integrity("file type or hard link")
        }
        return (fd, Int(info.st_size))
    }

    static func read(_ name: String, directory: Int32, limit: Int) throws -> Data? {
        let fd: Int32, count: Int
        do { (fd, count) = try openFile(name, directory: directory) }
        catch RecordingError.io(_, let code) where code == ENOENT { return nil }
        defer { close(fd) }
        guard count <= limit else { throw RecordingError.limit("annotation bytes") }
        let data = try readExactly(fd, count: count)
        var extra: UInt8 = 0
        guard Darwin.read(fd, &extra, 1) == 0 else { throw RecordingError.integrity("file grew") }
        return data
    }

    static func readExactly(_ fd: Int32, count: Int) throws -> Data {
        var data = Data(count: count)
        try data.withUnsafeMutableBytes { buffer in
            var offset = 0
            while offset < count {
                let amount = Darwin.read(fd, buffer.baseAddress!.advanced(by: offset), count - offset)
                if amount < 0, errno == EINTR { continue }
                guard amount > 0 else { throw RecordingError.integrity("truncated file") }
                offset += amount
            }
        }
        return data
    }

    static func write(_ data: Data, fd: Int32) throws {
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let amount = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if amount < 0, errno == EINTR { continue }
                guard amount > 0 else { throw error("write") }
                offset += amount
            }
        }
    }

    static func publish(_ data: Data, name: String, directory: Int32, replace: Bool = true) throws {
        try safeName(name)
        let temporary = ".pending-\(UUID().uuidString)"
        let fd = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw error("create annotation") }
        defer { close(fd) }
        try write(data, fd: fd)
        try sync(fd)
        if replace {
            guard renameat(directory, temporary, directory, name) == 0 else { throw error("publish annotation") }
        } else {
            guard linkat(directory, temporary, directory, name, 0) == 0 else { throw error("publish immutable") }
            guard unlinkat(directory, temporary, 0) == 0 else { throw error("unlink temporary") }
        }
        try sync(directory)
    }

    static func names(_ fd: Int32, limit: Int) throws -> [String] {
        let duplicate = dup(fd)
        guard duplicate >= 0 else { throw error("duplicate directory") }
        guard let stream = fdopendir(duplicate) else { close(duplicate); throw error("enumerate") }
        defer { closedir(stream) }
        rewinddir(stream)
        var names: [String] = []
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                guard errno == 0 else { throw error("enumerate entry") }
                return names.sorted()
            }
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) {
                    String(validatingCString: $0)
                }
            }
            guard let name else { throw RecordingError.integrity("file name encoding") }
            if name == "." || name == ".." { continue }
            guard names.count < limit else { throw RecordingError.limit("directory entries") }
            names.append(name)
        }
    }
}
