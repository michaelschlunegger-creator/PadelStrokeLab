import Darwin
import Foundation

public enum RecordingLocalCopyError: Error, LocalizedError, Sendable {
    case deletedOnPhone, deletedOnWatch
    public var errorDescription: String? {
        switch self {
        case .deletedOnPhone: "Deleted on this iPhone. Automatic transfer cannot restore this copy."
        case .deletedOnWatch: "Deleted on this Watch. The phone copy and independent exports are unchanged."
        }
    }
}

private struct RecordingDeletion: Codable {
    let schemaVersion: Int
    let recordingID: UUID
    let device: String
}

/// The lock and deletion marker outlive the UUID's raw, annotation and received-file directories.
/// Every owner opens its own descriptor, so flock also serializes separate objects in one process.
final class RecordingLocalTransaction {
    private let ledger: Int32
    private let lockFD: Int32
    let recordingID: UUID

    init(recordingID: UUID, notesRoot: URL, onContention: (() -> Void)? = nil) throws {
        self.recordingID = recordingID
        let root = try AnnotationFiles.root(notesRoot)
        defer { close(root) }
        let directory = try AnnotationFiles.directory(".transactions", parent: root, create: true)
        let fd = openat(directory, recordingID.uuidString + ".lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { close(directory); throw AnnotationFiles.error("open recording transaction") }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1 else {
            close(fd); close(directory); throw RecordingError.integrity("recording transaction file")
        }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EINTR else {
                let failure = AnnotationFiles.error("try recording transaction")
                close(fd); close(directory); throw failure
            }
            onContention?()
            while flock(fd, LOCK_EX) != 0 {
            if errno == EINTR { continue }
            let failure = AnnotationFiles.error("lock recording transaction")
            close(fd); close(directory); throw failure
            }
        }
        ledger = directory; lockFD = fd
    }

    deinit { flock(lockFD, LOCK_UN); close(lockFD); close(ledger) }

    func requireAvailable() throws {
        if let data = try AnnotationFiles.read(recordingID.uuidString + ".deleted.json", directory: ledger, limit: 4096) {
            let value: RecordingDeletion = try RecordingJSON.decode(data, limit: 4096)
            guard value.schemaVersion == 1, value.recordingID == recordingID, ["phone", "watch"].contains(value.device) else {
                throw RecordingError.integrity("deletion tombstone identity")
            }
            throw value.device == "watch" ? RecordingLocalCopyError.deletedOnWatch : RecordingLocalCopyError.deletedOnPhone
        }
    }

    func markDeleted(device: String) throws {
        let value = RecordingDeletion(schemaVersion: 1, recordingID: recordingID, device: device)
        try AnnotationFiles.publish(RecordingJSON.encode(value, limit: 4096),
            name: recordingID.uuidString + ".deleted.json", directory: ledger)
    }
}

public enum RecordingLocalCopies {
    /// Whole-practice cleanup already holds capture and transaction ownership.
    static func removeForPracticeDeletion(recordingID: UUID, paths: RecordingPaths,
                                         transaction: RecordingLocalTransaction, device: OwnerPracticeDevice) throws {
        guard transaction.recordingID == recordingID else { throw RecordingError.integrity("deletion transaction scope") }
        try transaction.markDeleted(device: device.rawValue)
        try removePrivateCopies(recordingID: recordingID, paths: paths)
        let outbox = try AnnotationFiles.root(paths.outboxRoot)
        defer { close(outbox) }
        for name in try AnnotationFiles.names(outbox, limit: 4096) {
            let prefix = ".pending-auto-\(recordingID.uuidString)-"
            let pending = name.hasPrefix(prefix) && UUID(uuidString: String(name.dropFirst(prefix.count))) != nil
            let exportPrefix = "export-\(recordingID.uuidString)-"
            let exported = name.hasPrefix(exportPrefix) && name.hasSuffix(".pslrecording") &&
                UUID(uuidString: String(name.dropFirst(exportPrefix.count).dropLast(13))) != nil
            if pending || exported || isAutomaticOutboxName(name, recordingID: recordingID) || name == recordingID.uuidString + ".transfer.json" {
                guard unlinkat(outbox, name, 0) == 0 else { throw AnnotationFiles.error("remove practice raw export") }
            }
        }
        try AnnotationFiles.sync(outbox)
    }
    /// A durable tombstone is published before deleting data. Retried or delayed transfers cannot
    /// recreate the phone copy. Watch originals and independent outbox exports are untouched.
    public static func deletePhoneCopy(recordingID: UUID, paths: RecordingPaths) throws {
        try deletePhoneCopy(recordingID: recordingID, paths: paths, onContention: nil)
    }

    static func deletePhoneCopy(recordingID: UUID, paths: RecordingPaths, onContention: (() -> Void)?) throws {
        let transaction = try RecordingLocalTransaction(recordingID: recordingID, notesRoot: paths.notesRoot, onContention: onContention)
        defer { withExtendedLifetime(transaction) {} }
        try transaction.markDeleted(device: "phone")
        try removePrivateCopies(recordingID: recordingID, paths: paths)
    }

    static func deleteWatchCopy(recordingID: UUID, paths: RecordingPaths, cancelTransfers: () -> Void) throws {
        let lease = try RecordingCaptureLease(recordingID: recordingID, rawRoot: paths.rawRoot)
        defer { withExtendedLifetime(lease) {} }
        let transaction = try RecordingLocalTransaction(recordingID: recordingID, notesRoot: paths.notesRoot)
        defer { withExtendedLifetime(transaction) {} }
        cancelTransfers()
        try transaction.markDeleted(device: "watch")
        let outbox = try AnnotationFiles.root(paths.outboxRoot)
        defer { close(outbox) }
        for name in try AnnotationFiles.names(outbox, limit: 4096) {
            let temporaryPrefix = ".pending-auto-\(recordingID.uuidString)-"
            let isTemporary = name.hasPrefix(temporaryPrefix) &&
                UUID(uuidString: String(name.dropFirst(temporaryPrefix.count)))?.uuidString == String(name.dropFirst(temporaryPrefix.count))
            if isAutomaticOutboxName(name, recordingID: recordingID) || isTemporary || name == recordingID.uuidString + ".transfer.json" {
                guard unlinkat(outbox, name, 0) == 0 else { throw AnnotationFiles.error("delete automatic Watch outbox copy") }
            }
        }
        try AnnotationFiles.sync(outbox)
        try removePrivateCopies(recordingID: recordingID, paths: paths)
    }

    static func isAutomaticOutboxName(_ name: String, recordingID: UUID) -> Bool {
        let prefix = recordingID.uuidString + "-"
        guard name.hasPrefix(prefix), name.hasSuffix(".pslrecording") else { return false }
        let suffix = String(name.dropFirst(prefix.count).dropLast(13))
        return UUID(uuidString: suffix)?.uuidString == suffix
    }

    private static func removePrivateCopies(recordingID: UUID, paths: RecordingPaths) throws {
        for root in [paths.rawRoot, paths.notesRoot, paths.inboxRoot] {
            let directory = try AnnotationFiles.root(root)
            defer { close(directory) }
            try removeFlatDirectory(recordingID.uuidString, parent: directory)
        }
        let raw = try AnnotationFiles.root(paths.rawRoot)
        defer { close(raw) }
        for name in try AnnotationFiles.names(raw, limit: 4096) where name.hasPrefix(".incoming-") {
            let prefix = ".incoming-\(recordingID.uuidString)-"
            let isCurrent = name.hasPrefix(prefix) && UUID(uuidString: String(name.dropFirst(prefix.count))) != nil
            let isLegacy = UUID(uuidString: String(name.dropFirst(10))) != nil
            guard isCurrent || isLegacy else { continue }
            let stage: Int32
            do { stage = try AnnotationFiles.directory(name, parent: raw, create: false) }
            catch RecordingError.io(_, let code) where code == ENOENT { continue }
            defer { close(stage) }
            // Both current identity-prefixed and earlier private stages contain a UUID child.
            let names = try AnnotationFiles.names(stage, limit: RecordingLimits.directoryEntries)
            if names.contains(recordingID.uuidString) {
                try removeFlatDirectory(recordingID.uuidString, parent: stage)
                if try AnnotationFiles.names(stage, limit: RecordingLimits.directoryEntries).isEmpty {
                    guard unlinkat(raw, name, AT_REMOVEDIR) == 0 else { throw AnnotationFiles.error("delete incoming stage") }
                }
            }
        }
        try AnnotationFiles.sync(raw)
    }

    /// Executes the actual application-acknowledgment decision while deletion is excluded.
    /// The durable receipt alone is insufficient: a presently valid raw copy and timeline must exist.
    static func withVerifiedReceipt<T>(_ receipt: RecordingArchiveReceipt, paths: RecordingPaths,
                                       _ action: () throws -> T) throws -> T {
        let transaction = try RecordingLocalTransaction(recordingID: receipt.recordingID, notesRoot: paths.notesRoot)
        defer { withExtendedLifetime(transaction) {} }
        try transaction.requireAvailable()
        let notes = try SessionAnnotationsStore(root: paths.notesRoot)
        guard try notes.loadReceipt(recordingID: receipt.recordingID) == receipt else {
            throw RecordingError.integrity("durable receipt missing or changed")
        }
        let report = try RecordingStore.inspect(root: paths.rawRoot, recordingID: receipt.recordingID)
        guard report.status == .finalized || report.status == .interrupted,
              let metadata = report.metadata,
              let timeline = try notes.loadTimeline(recordingID: receipt.recordingID) else {
            throw RecordingError.integrity("verified local recording missing")
        }
        try timeline.validate(metadata: metadata)
        _ = try notes.loadLabels(recordingID: receipt.recordingID)
        return try action()
    }

    /// WC owns its temporary file only until the callback returns. Copy it synchronously into a
    /// private inbox using bounded buffers, then enqueue the separate verification/install work.
    static func copyIncoming(_ source: URL, recordingID: UUID, paths: RecordingPaths) throws -> URL {
        let transaction = try RecordingLocalTransaction(recordingID: recordingID, notesRoot: paths.notesRoot)
        defer { withExtendedLifetime(transaction) {} }
        try transaction.requireAvailable()
        guard let canonical = realpath(source.deletingLastPathComponent().path, nil) else {
            throw AnnotationFiles.error("canonical received container")
        }
        defer { free(canonical) }
        let parent = try AnnotationFiles.root(URL(fileURLWithPath: String(cString: canonical)))
        defer { close(parent) }
        let (fd, size) = try AnnotationFiles.openFile(source.lastPathComponent, directory: parent)
        defer { close(fd) }
        guard size > 0, size <= RecordingArchive.maximumBytes else { throw RecordingError.limit("incoming archive") }
        let inbox = try AnnotationFiles.root(paths.inboxRoot)
        defer { close(inbox) }
        let incoming = try AnnotationFiles.directory(recordingID.uuidString, parent: inbox, create: true)
        defer { close(incoming) }
        let name = UUID().uuidString + ".pslrecording"
        let output = openat(incoming, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard output >= 0 else { throw AnnotationFiles.error("create incoming copy") }
        defer { close(output) }
        var remaining = size
        while remaining > 0 {
            let bytes = try AnnotationFiles.readExactly(fd, count: min(65_536, remaining))
            try AnnotationFiles.write(bytes, fd: output); remaining -= bytes.count
        }
        try AnnotationFiles.sync(output); try AnnotationFiles.sync(incoming)
        return paths.inboxRoot.appendingPathComponent(recordingID.uuidString, isDirectory: true).appendingPathComponent(name)
    }

    static func removeIncomingCopy(_ url: URL, recordingID: UUID, paths: RecordingPaths) throws {
        guard url.deletingLastPathComponent() == paths.inboxRoot.appendingPathComponent(recordingID.uuidString, isDirectory: true) else {
            throw RecordingError.invalid("incoming cleanup path")
        }
        let inbox = try AnnotationFiles.root(paths.inboxRoot)
        defer { close(inbox) }
        let recording = try AnnotationFiles.directory(recordingID.uuidString, parent: inbox, create: false)
        defer { close(recording) }
        try AnnotationFiles.safeName(url.lastPathComponent)
        guard unlinkat(recording, url.lastPathComponent, 0) == 0 else { throw AnnotationFiles.error("remove verified incoming copy") }
        try AnnotationFiles.sync(recording)
        if try AnnotationFiles.names(recording, limit: 4096).isEmpty {
            guard unlinkat(inbox, recordingID.uuidString, AT_REMOVEDIR) == 0 else { throw AnnotationFiles.error("remove empty inbox directory") }
            try AnnotationFiles.sync(inbox)
        }
    }

    private static func removeFlatDirectory(_ name: String, parent: Int32) throws {
        let directory: Int32
        do { directory = try AnnotationFiles.directory(name, parent: parent, create: false) }
        catch RecordingError.io(_, let code) where code == ENOENT { return }
        defer { close(directory) }
        for file in try AnnotationFiles.names(directory, limit: 4096) {
            try AnnotationFiles.safeName(file)
            var info = stat()
            guard fstatat(directory, file, &info, AT_SYMLINK_NOFOLLOW) == 0,
                  info.st_mode & S_IFMT == S_IFREG || info.st_mode & S_IFMT == S_IFLNK else {
                throw RecordingError.integrity("unexpected local deletion descendant")
            }
            guard unlinkat(directory, file, 0) == 0 else { throw AnnotationFiles.error("delete local file") }
        }
        try AnnotationFiles.sync(directory)
        guard unlinkat(parent, name, AT_REMOVEDIR) == 0 else { throw AnnotationFiles.error("delete local directory") }
        try AnnotationFiles.sync(parent)
    }
}
