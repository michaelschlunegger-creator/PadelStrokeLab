import Darwin
import Foundation

/// Durable suggestions/bookkeeping only. Loading this value never restores practice authority.
public struct PracticeSetupPersistentState: Codable, Equatable, Sendable {
    public let localInstallationEpoch: UUID
    public fileprivate(set) var preferences: PracticeSetupPreferences?
    public fileprivate(set) var latestDraft: PracticeSetupDraft?
    public fileprivate(set) var highWater: PracticeSetupIdentity?

    fileprivate func validate() throws {
        try latestDraft?.identity.validate()
        try highWater?.validate()
        if let highWater {
            guard let latest = latestDraft?.identity,
                  latest.originInstallationEpoch == highWater.originInstallationEpoch,
                  latest.revision >= highWater.revision,
                  latest.revision != highWater.revision || latest == highWater else {
                throw PracticeSetupError.corrupt("bookkeeping consistency")
            }
        }
    }
}

public enum PracticeSetupRecordResult: Equatable, Sendable {
    /// Durable bookkeeping only, not permission to acknowledge before actor/generation revalidation.
    case recorded, duplicate
}

enum PracticeSetupStoreWriteStage: Equatable { case afterTemporarySync, afterRename }

/// Synchronous, exclusive owner. Keep on the channel's serial owner; intentionally not Sendable.
/// New runtime/preparation generations and fresh physical consent belong to the ephemeral channel.
public final class PracticeSetupStore {
    public static let directoryName = "PracticeSetup-v1"
    public static let maximumBytes = 16_384
    public let directoryURL: URL
    public private(set) var snapshot: PracticeSetupPersistentState
    private let baseDescriptor: Int32
    private let directory: Int32
    private let lockDescriptor: Int32
    private var expectedBytes: Data
    private var poisoned = false
    // Test-only failure injection at real durability boundaries. Production default remains nil.
    var writeFault: ((PracticeSetupStoreWriteStage) throws -> Void)?

    public init(base: URL) throws {
        guard base.isFileURL, !base.pathComponents.contains("Recordings") else {
            throw PracticeSetupError.invalid("setup base must be separate from recordings")
        }
        let baseFD = try AnnotationFiles.root(base)
        var root: Int32 = -1, lock: Int32 = -1
        do {
            let created: Bool
            if mkdirat(baseFD, Self.directoryName, 0o700) == 0 { created = true }
            else if errno == EEXIST { created = false }
            else { throw Self.io("create setup directory") }
            root = try AnnotationFiles.directory(Self.directoryName, parent: baseFD, create: false)
            lock = openat(root, ".lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
            guard lock >= 0 else { throw Self.io("open setup lock") }
            try Self.regular(lock)
            guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw PracticeSetupError.busy }
            try Self.checkEntries(root)
            let state: PracticeSetupPersistentState
            let bytes: Data
            if created {
                state = PracticeSetupPersistentState(localInstallationEpoch: UUID())
                bytes = try Self.encode(state)
                try Self.publish(bytes, directory: root, fault: nil)
                try AnnotationFiles.sync(baseFD)
            } else {
                // Existing empty namespace can be an interrupted initialization or a deletion: fail closed.
                guard let existing = try AnnotationFiles.read("state.json", directory: root, limit: Self.maximumBytes) else {
                    throw PracticeSetupError.corrupt("missing initialized setup state")
                }
                state = try Self.decode(existing)
                bytes = existing
                try Self.removePending(root)
            }
            baseDescriptor = baseFD
            directory = root
            lockDescriptor = lock
            directoryURL = base.appendingPathComponent(Self.directoryName, isDirectory: true)
            snapshot = state
            expectedBytes = bytes
        } catch {
            if lock >= 0 { flock(lock, LOCK_UN); close(lock) }
            if root >= 0 { close(root) }
            close(baseFD)
            throw error
        }
    }

    deinit {
        flock(lockDescriptor, LOCK_UN)
        close(lockDescriptor)
        close(directory)
        close(baseDescriptor)
    }

    /// Checks current owned storage without writing or restoring practice authority.
    public func checkedSnapshot() throws -> PracticeSetupPersistentState {
        try checkLive()
        return snapshot
    }

    public func savePreferences(_ value: PracticeSetupPreferences) throws {
        try checkLive()
        var next = snapshot
        next.preferences = value
        try persist(next)
    }

    /// Application context may update this suggestion, never the explicit high-water record.
    public func saveSuggestion(_ draft: PracticeSetupDraft) throws {
        try checkLive()
        for existing in [snapshot.highWater, snapshot.latestDraft?.identity].compactMap({ $0 }) {
            try Self.check(draft.identity, against: existing, allowsOriginReplacement: false)
        }
        guard snapshot.latestDraft != draft else { return }
        var next = snapshot
        next.latestDraft = draft
        try persist(next)
    }

    /// Call only after the live actor validates BOTH generations and cancellation. Return before an ack.
    /// `duplicate` proves bookkeeping, not acceptance: relaunch/End still require a new explicit request.
    @discardableResult
    public func recordExplicitPreparation(_ draft: PracticeSetupDraft,
                                          allowsOriginReplacement: Bool = false) throws -> PracticeSetupRecordResult {
        try checkLive()
        if let highWater = snapshot.highWater {
            try Self.check(draft.identity, against: highWater, allowsOriginReplacement: allowsOriginReplacement)
            if draft.identity == highWater { return .duplicate }
        }
        if let latest = snapshot.latestDraft?.identity {
            try Self.check(draft.identity, against: latest, allowsOriginReplacement: allowsOriginReplacement)
        }
        var next = snapshot
        next.highWater = draft.identity
        next.latestDraft = draft
        try persist(next)
        return .recorded
    }

    private static func check(_ incoming: PracticeSetupIdentity, against existing: PracticeSetupIdentity,
                              allowsOriginReplacement: Bool) throws {
        try incoming.validate()
        if incoming.originInstallationEpoch != existing.originInstallationEpoch {
            guard allowsOriginReplacement else { throw PracticeSetupError.originChangeRequiresExplicit }
            return
        }
        guard incoming.revision >= existing.revision else { throw PracticeSetupError.staleRevision }
        if incoming.revision == existing.revision, incoming != existing { throw PracticeSetupError.conflictingRevision }
    }

    private func checkLive() throws {
        guard !poisoned else { throw PracticeSetupError.poisoned }
        do {
            var opened = stat(), named = stat()
            guard fstat(directory, &opened) == 0,
                  fstatat(baseDescriptor, Self.directoryName, &named, AT_SYMLINK_NOFOLLOW) == 0,
                  named.st_mode & S_IFMT == S_IFDIR, opened.st_dev == named.st_dev, opened.st_ino == named.st_ino else {
                throw PracticeSetupError.corrupt("setup directory changed")
            }
            guard fstat(lockDescriptor, &opened) == 0,
                  fstatat(directory, ".lock", &named, AT_SYMLINK_NOFOLLOW) == 0,
                  named.st_mode & S_IFMT == S_IFREG, named.st_nlink == 1,
                  opened.st_dev == named.st_dev, opened.st_ino == named.st_ino else {
                throw PracticeSetupError.corrupt("setup ownership changed")
            }
            try Self.checkEntries(directory)
            guard let current = try AnnotationFiles.read("state.json", directory: directory, limit: Self.maximumBytes),
                  current == expectedBytes else { throw PracticeSetupError.corrupt("setup state changed or missing") }
        } catch { poisoned = true; throw error }
    }

    private func persist(_ next: PracticeSetupPersistentState) throws {
        let bytes = try Self.encode(next)
        guard bytes != expectedBytes else { return }
        do {
            try Self.publish(bytes, directory: directory, fault: writeFault)
            // Commit memory only after file AND parent-directory synchronization succeeded.
            snapshot = next
            expectedBytes = bytes
        } catch { poisoned = true; throw error }
    }

    private struct Envelope: Codable {
        let version: Int
        let state: PracticeSetupPersistentState
        let sha256: String
    }
    private static func encode(_ state: PracticeSetupPersistentState) throws -> Data {
        try state.validate()
        let digest = RecordingChunkCodec.digest(try PracticeSetupJSON.encode(state))
        let bytes = try PracticeSetupJSON.encode(Envelope(version: 1, state: state, sha256: digest))
        guard bytes.count <= maximumBytes else { throw PracticeSetupError.limit("setup state bytes") }
        return bytes
    }
    private static func decode(_ bytes: Data) throws -> PracticeSetupPersistentState {
        guard !bytes.isEmpty, bytes.count <= maximumBytes else { throw PracticeSetupError.limit("setup state bytes") }
        let envelope = try JSONDecoder().decode(Envelope.self, from: bytes)
        guard envelope.version == 1 else { throw PracticeSetupError.corrupt("setup state version") }
        try envelope.state.validate()
        guard try encode(envelope.state) == bytes else { throw PracticeSetupError.corrupt("setup state checksum or representation") }
        return envelope.state
    }

    private static func checkEntries(_ directory: Int32) throws {
        let names = try AnnotationFiles.names(directory, limit: 3)
        guard Set(names).isSubset(of: [".lock", "state.json", "state.pending"]) else {
            throw PracticeSetupError.corrupt("unexpected setup entries")
        }
    }
    private static func regular(_ fd: Int32) throws {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1 else {
            throw PracticeSetupError.corrupt("setup file type or hard link")
        }
    }
    private static func removePending(_ directory: Int32) throws {
        // A bounded regular temporary can remain after process death. Never follow or delete an alien link.
        guard try AnnotationFiles.read("state.pending", directory: directory, limit: maximumBytes) != nil else { return }
        guard unlinkat(directory, "state.pending", 0) == 0 else { throw io("remove setup temporary") }
        try AnnotationFiles.sync(directory)
    }
    private static func publish(_ bytes: Data, directory: Int32,
                                fault: ((PracticeSetupStoreWriteStage) throws -> Void)?) throws {
        try removePending(directory)
        let temporary = openat(directory, "state.pending", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard temporary >= 0 else { throw io("create setup temporary") }
        defer { close(temporary) }
        // Leave a failed temporary intact for bounded crash recovery on the next validated open.
        try AnnotationFiles.write(bytes, fd: temporary)
        try AnnotationFiles.sync(temporary)
        try fault?(.afterTemporarySync)
        guard renameat(directory, "state.pending", directory, "state.json") == 0 else { throw io("publish setup state") }
        try fault?(.afterRename)
        try AnnotationFiles.sync(directory)
    }
    private static func io(_ operation: String) -> PracticeSetupError { .io(operation: operation, code: errno) }
}
