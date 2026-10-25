import Darwin
import Foundation

public enum VideoMotionStoreStage: Equatable, Sendable { case temporarySynced, revisionPublished, directorySynced }

/// Synchronous exclusive owner: call on one serial executor. The lease spans every read/write.
/// Revisions are immutable commit records; complete records survive interrupted publication.
/// This store proves retained metadata bytes, never camera playability or sensor acquisition.
public final class VideoMotionStore {
    public static let directoryName = "VideoMotion-v1"
    private static let markerName = ".VideoMotion-v1"
    private static let maximumSessions = 256
    public let directoryURL: URL
    var failureInjector: ((VideoMotionStoreStage) throws -> Void)?
    private let baseURL: URL
    private let baseFD: Int32, directoryFD: Int32, leaseFD: Int32
    private let witness: RootWitness
    private let markerBytes: Data
    private var closed = false, poisoned = false

    private struct Node: Codable, Equatable { let device: Int64, inode: UInt64 }
    private struct RootWitness: Codable {
        let schemaVersion: Int, base: Node, directory: Node, lease: Node
        let leaseDigest: String
    }
    private struct SessionWitness: Codable {
        let schemaVersion: Int, sessionID: UUID, bindingDigest: String, directory: Node
    }
    private struct Retirement: Codable {
        let schemaVersion: Int, ownerID: UUID, phoneEpoch: UUID, watchEpoch: UUID, practiceID: UUID, operationID: UUID
        func matches(_ binding: VideoMotionBinding) -> Bool {
            let identity = binding.preparation.identity
            return schemaVersion == 1 && ownerID == identity.ownerID && phoneEpoch == identity.phoneEpoch
                && watchEpoch == identity.watchEpoch && practiceID == binding.practiceID
        }
    }

    public init(base: URL) throws {
        let baseFD = try AnnotationFiles.root(base)
        var owned = [baseFD], transferred = false
        defer { if !transferred { for fd in owned.reversed() { Darwin.close(fd) } } }
        let initialMarker = try AnnotationFiles.read(Self.markerName, directory: baseFD, limit: 4_096)
        let namespace: Int32
        if initialMarker == nil {
            guard try !Self.exists(Self.directoryName, in: baseFD) else { throw VideoMotionError.integrity }
            // A failed bootstrap remains fenced, not silently reinitialized over retained data.
            try Self.exclusive(Data("pending\n".utf8), name: Self.markerName, directory: baseFD)
            guard mkdirat(baseFD, Self.directoryName, 0o700) == 0 else { throw AnnotationFiles.error("create video namespace") }
            try AnnotationFiles.sync(baseFD)
            namespace = try AnnotationFiles.directory(Self.directoryName, parent: baseFD, create: false)
            owned.append(namespace)
            try Self.exclusive(Data(("PSLVideoMotionLease1\n" + UUID().uuidString + "\n").utf8),
                               name: ".lease", directory: namespace)
        } else {
            namespace = try AnnotationFiles.directory(Self.directoryName, parent: baseFD, create: false)
            owned.append(namespace)
        }
        let (lease, _) = try AnnotationFiles.openFile(".lease", directory: namespace)
        owned.append(lease)
        guard flock(lease, LOCK_EX | LOCK_NB) == 0 else { throw VideoMotionError.busy }
        let leaseBytes = try Self.required(".lease", directory: namespace, limit: 256)
        let root: RootWitness, bytes: Data
        if let initialMarker {
            root = try OwnerCanonical.decode(initialMarker, domain: "PSLVideoMotionRoot1", limit: 4_096)
            bytes = initialMarker
        } else {
            root = RootWitness(schemaVersion: 1, base: try Self.node(baseFD, directory: true),
                directory: try Self.node(namespace, directory: true), lease: try Self.node(lease),
                leaseDigest: RecordingChunkCodec.digest(leaseBytes))
            bytes = try OwnerCanonical.encode(root, domain: "PSLVideoMotionRoot1", limit: 4_096)
            try AnnotationFiles.publish(bytes, name: Self.markerName, directory: baseFD)
        }
        guard root.schemaVersion == 1, root.base == (try Self.node(baseFD, directory: true)),
              root.directory == (try Self.node(namespace, directory: true)), root.lease == (try Self.node(lease)),
              root.leaseDigest == RecordingChunkCodec.digest(leaseBytes) else { throw VideoMotionError.integrity }
        let namedLease = try AnnotationFiles.openFile(".lease", directory: namespace).0
        defer { Darwin.close(namedLease) }
        guard try Self.node(namedLease) == root.lease else { throw VideoMotionError.integrity }
        var namespaceURL = base.appendingPathComponent(Self.directoryName, isDirectory: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try namespaceURL.setResourceValues(values)
        self.baseURL = base; self.baseFD = baseFD; directoryFD = namespace; leaseFD = lease
        directoryURL = namespaceURL; witness = root; markerBytes = bytes
        transferred = true
    }

    deinit { close() }
    public func close() {
        guard !closed else { return }
        closed = true; flock(leaseFD, LOCK_UN)
        Darwin.close(leaseFD); Darwin.close(directoryFD); Darwin.close(baseFD)
    }

    public func create(_ binding: VideoMotionBinding, authority: OwnerPracticeIdentity) throws -> VideoMotionSession {
        try checkLive(); try binding.requireCurrent(authority); try requireNotRetired(binding)
        let value = try VideoMotionSession(binding: binding), bytes = try value.encoded()
        let name = binding.sessionID.uuidString.lowercased(), used = ".used-" + name
        let recording = "recording-" + binding.recordingID.uuidString.lowercased()
        guard try !Self.exists(name, in: directoryFD), try !Self.exists(used, in: directoryFD),
              try !Self.exists(recording, in: directoryFD) else { throw VideoMotionError.conflict }
        let inventory = try AnnotationFiles.names(directoryFD, limit: 2_048)
        guard inventory.filter({ $0.hasPrefix(".used-") }).count < Self.maximumSessions else { throw VideoMotionError.capacity }
        do {
            // Both reservations survive failed creation. Neither UUID may be silently reused.
            try Self.exclusive(Data((try binding.digest).utf8), name: recording, directory: directoryFD)
            try Self.exclusive(Data("pending\n".utf8), name: used, directory: directoryFD)
            guard mkdirat(directoryFD, name, 0o700) == 0 else { throw AnnotationFiles.error("create video session") }
            try AnnotationFiles.sync(directoryFD)
            let session = try AnnotationFiles.directory(name, parent: directoryFD, create: false)
            defer { Darwin.close(session) }
            let staging = try AnnotationFiles.directory("staging", parent: session, create: true)
            Darwin.close(staging)
            try publishImmutable(bytes, revision: 1, directory: session)
            let marker = SessionWitness(schemaVersion: 1, sessionID: binding.sessionID,
                bindingDigest: try binding.digest, directory: try Self.node(session, directory: true))
            try AnnotationFiles.publish(OwnerCanonical.encode(marker, domain: "PSLVideoMotionSessionWitness1", limit: 4_096),
                                        name: used, directory: directoryFD)
            try checkLive()
            return value
        } catch { poisoned = true; throw error }
    }

    public func read(_ binding: VideoMotionBinding) throws -> VideoMotionSession {
        let session = try openSession(binding)
        defer { Darwin.close(session) }
        let value = try load(binding, directory: session)
        try checkLive(); try requireNotRetired(binding)
        return value
    }

    public func publish(_ value: VideoMotionSession, expectedDigest: String,
                        authority: OwnerPracticeIdentity) throws {
        try value.binding.requireCurrent(authority)
        let session = try openSession(value.binding)
        defer { Darwin.close(session) }
        let previous = try load(value.binding, directory: session)
        guard try previous.digest == expectedDigest else { throw VideoMotionError.conflict }
        try value.requireSuccessor(of: previous)
        let bytes = try value.encoded()
        try checkLive(); try requireNotRetired(value.binding)
        do {
            try publishImmutable(bytes, revision: value.revision, directory: session)
            try checkLive(); try requireNotRetired(value.binding)
        } catch { poisoned = true; throw error }
    }

    /// A durable fence only. Whole-practice cleanup and paired deletion acknowledgments are package G.
    /// Revoked collection consent does not prevent the same owner from retiring their retained practice.
    public func retirePractice(_ binding: VideoMotionBinding, authority: OwnerPracticeIdentity,
                               operationID: UUID) throws {
        try checkLive(); try binding.requireSameOwner(authority)
        let name = retirementName(binding)
        if let bytes = try AnnotationFiles.read(name, directory: directoryFD, limit: 4_096) {
            let existing: Retirement = try OwnerCanonical.decode(bytes, domain: "PSLVideoMotionRetirement1", limit: 4_096)
            guard existing.matches(binding) else { throw VideoMotionError.integrity }
            return
        }
        let identity = binding.preparation.identity
        let marker = Retirement(schemaVersion: 1, ownerID: identity.ownerID, phoneEpoch: identity.phoneEpoch,
            watchEpoch: identity.watchEpoch, practiceID: binding.practiceID, operationID: operationID)
        do {
            try AnnotationFiles.publish(OwnerCanonical.encode(marker, domain: "PSLVideoMotionRetirement1", limit: 4_096),
                                        name: name, directory: directoryFD, replace: false)
            try checkLive()
        } catch { poisoned = true; throw error }
    }

    /// For native media integration. The caller must retain this exclusive store and serialize file work.
    /// Returning a path is not a capture, playback, export, or deletion authorization.
    public func sessionDirectoryURL(_ binding: VideoMotionBinding) throws -> URL {
        let session = try openSession(binding); Darwin.close(session)
        return directoryURL.appendingPathComponent(binding.sessionID.uuidString.lowercased(), isDirectory: true)
    }

    private func openSession(_ binding: VideoMotionBinding) throws -> Int32 {
        try checkLive(); try binding.validate(); try requireNotRetired(binding)
        let name = binding.sessionID.uuidString.lowercased()
        let bytes = try Self.required(".used-" + name, directory: directoryFD, limit: 4_096)
        let marker: SessionWitness = try OwnerCanonical.decode(bytes, domain: "PSLVideoMotionSessionWitness1", limit: 4_096)
        guard marker.schemaVersion == 1, marker.sessionID == binding.sessionID,
              try marker.bindingDigest == binding.digest else { throw VideoMotionError.integrity }
        let reservation = try Self.required("recording-" + binding.recordingID.uuidString.lowercased(),
                                            directory: directoryFD, limit: 64)
        guard reservation == Data(marker.bindingDigest.utf8) else { throw VideoMotionError.integrity }
        let session = try AnnotationFiles.directory(name, parent: directoryFD, create: false)
        do {
            guard try Self.node(session, directory: true) == marker.directory else { throw VideoMotionError.integrity }
            return session
        } catch { Darwin.close(session); throw error }
    }

    private func load(_ binding: VideoMotionBinding, directory: Int32) throws -> VideoMotionSession {
        let names = try AnnotationFiles.names(directory, limit: VideoMotionSession.maximumRevisions + 65)
        var revisions: [String] = []
        for name in names {
            if name == "staging" {
                let staging = try AnnotationFiles.directory(name, parent: directory, create: false)
                Darwin.close(staging)
            } else if name.hasPrefix(".pending-"), UUID(uuidString: String(name.dropFirst(9))) != nil {
                let (fd, count) = try AnnotationFiles.openFile(name, directory: directory)
                Darwin.close(fd)
                guard count <= VideoMotionSession.maximumBytes else { throw VideoMotionError.capacity }
            } else if name.hasPrefix("revision-") { revisions.append(name) }
            else { throw VideoMotionError.integrity }
        }
        guard !revisions.isEmpty, revisions.count <= VideoMotionSession.maximumRevisions,
              names.contains("staging") else { throw VideoMotionError.integrity }
        var last: VideoMotionSession?
        for (offset, name) in revisions.enumerated() {
            guard name == Self.revisionName(offset + 1) else { throw VideoMotionError.integrity }
            let bytes = try Self.required(name, directory: directory, limit: VideoMotionSession.maximumBytes)
            let value = try VideoMotionSession.decode(bytes)
            guard value.binding == binding, value.revision == offset + 1 else { throw VideoMotionError.integrity }
            if let last { try value.requireSuccessor(of: last) }
            last = value
        }
        // A complete published revision whose directory sync was interrupted is durably adopted.
        // Unpublished temporary bytes are retained and are never promoted by this read.
        try AnnotationFiles.sync(directory)
        guard let last else { throw VideoMotionError.integrity }
        return last
    }

    private func publishImmutable(_ bytes: Data, revision: Int, directory: Int32) throws {
        let name = Self.revisionName(revision), temporary = ".pending-" + UUID().uuidString
        let fd = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw AnnotationFiles.error("stage video metadata") }
        defer { Darwin.close(fd) }
        try AnnotationFiles.write(bytes, fd: fd); try AnnotationFiles.sync(fd)
        try failureInjector?(.temporarySynced)
        // Atomic no-overwrite publication avoids a crash leaving temporary/final hard links
        // to the same inode, which the strict single-link reader must reject.
        guard renameatx_np(directory, temporary, directory, name, UInt32(RENAME_EXCL)) == 0 else {
            throw AnnotationFiles.error("publish video metadata")
        }
        try failureInjector?(.revisionPublished)
        try AnnotationFiles.sync(directory)
        try failureInjector?(.directorySynced)
    }

    private func retirementName(_ binding: VideoMotionBinding) -> String {
        "retired-" + binding.practiceID.uuidString.lowercased() + ".json"
    }
    private func requireNotRetired(_ binding: VideoMotionBinding) throws {
        if let bytes = try AnnotationFiles.read(retirementName(binding), directory: directoryFD, limit: 4_096) {
            let marker: Retirement = try OwnerCanonical.decode(bytes, domain: "PSLVideoMotionRetirement1", limit: 4_096)
            guard marker.matches(binding) else { throw VideoMotionError.integrity }
            throw VideoMotionError.retired
        }
    }

    private func checkLive() throws {
        guard !closed, !poisoned else { throw VideoMotionError.closed }
        do {
            let currentBase = try AnnotationFiles.root(baseURL)
            defer { Darwin.close(currentBase) }
            let currentDirectory = try AnnotationFiles.directory(Self.directoryName, parent: currentBase, create: false)
            defer { Darwin.close(currentDirectory) }
            let (currentLease, _) = try AnnotationFiles.openFile(".lease", directory: currentDirectory)
            defer { Darwin.close(currentLease) }
            guard try Self.node(currentBase, directory: true) == witness.base,
                  try Self.node(baseFD, directory: true) == witness.base,
                  try Self.node(currentDirectory, directory: true) == witness.directory,
                  try Self.node(directoryFD, directory: true) == witness.directory,
                  try Self.node(currentLease) == witness.lease, try Self.node(leaseFD) == witness.lease,
                  try Self.required(Self.markerName, directory: currentBase, limit: 4_096) == markerBytes,
                  try RecordingChunkCodec.digest(Self.required(".lease", directory: currentDirectory, limit: 256)) == witness.leaseDigest
            else { throw VideoMotionError.integrity }
        } catch { poisoned = true; throw error }
    }

    private static func revisionName(_ revision: Int) -> String { String(format: "revision-%06d.json", revision) }
    private static func node(_ fd: Int32, directory: Bool = false) throws -> Node {
        var value = stat()
        guard fstat(fd, &value) == 0,
              value.st_mode & S_IFMT == (directory ? S_IFDIR : S_IFREG),
              directory ? value.st_nlink > 0 : value.st_nlink == 1 else { throw VideoMotionError.integrity }
        return Node(device: Int64(value.st_dev), inode: UInt64(value.st_ino))
    }
    private static func exists(_ name: String, in directory: Int32) throws -> Bool {
        try AnnotationFiles.safeName(name)
        var value = stat()
        if fstatat(directory, name, &value, AT_SYMLINK_NOFOLLOW) == 0 { return true }
        guard errno == ENOENT else { throw AnnotationFiles.error("inspect video namespace") }
        return false
    }
    private static func required(_ name: String, directory: Int32, limit: Int) throws -> Data {
        guard let bytes = try AnnotationFiles.read(name, directory: directory, limit: limit) else { throw VideoMotionError.integrity }
        return bytes
    }
    private static func exclusive(_ bytes: Data, name: String, directory: Int32) throws {
        try AnnotationFiles.safeName(name)
        let fd = openat(directory, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw AnnotationFiles.error("reserve video identity") }
        defer { Darwin.close(fd) }
        try AnnotationFiles.write(bytes, fd: fd); try AnnotationFiles.sync(fd); try AnnotationFiles.sync(directory)
    }
}
