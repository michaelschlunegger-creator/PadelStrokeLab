import CryptoKit
import Darwin
import Foundation

/// Exact frozen-envelope identity, not authentication of a sender or proof of local possession.
public struct OwnerPracticeReceipt: Equatable, Sendable {
    private struct Body: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let ownerID: UUID, phoneInstallationEpoch: UUID, watchInstallationEpoch: UUID, practiceID: UUID
        let revision: Int64, status: OwnerTelemetryStatus, heartRate: OwnerPracticeHeartRateDisposition
        let recordingIDs: [UUID], inventorySHA256: String, bundleSHA256: String, byteCount: Int
    }
    private let body: Body
    public var practiceID: UUID { body.practiceID }
    public var revision: Int64 { body.revision }
    public var status: OwnerTelemetryStatus { body.status }
    public var heartRate: OwnerPracticeHeartRateDisposition { body.heartRate }
    public var recordingIDs: [UUID] { body.recordingIDs }
    public var inventorySHA256: String { body.inventorySHA256 }
    public var bundleSHA256: String { body.bundleSHA256 }
    public var byteCount: Int { body.byteCount }
    public var scope: OwnerPracticePublicationScope {
        OwnerPracticePublicationScope(ownerID: body.ownerID, phoneInstallationEpoch: body.phoneInstallationEpoch,
            watchInstallationEpoch: body.watchInstallationEpoch, practiceID: body.practiceID, revision: body.revision,
            inventorySHA256: body.inventorySHA256, policyDigest: OwnerPracticePolicy.digest,
            includesHeartRate: body.heartRate == .included)
    }
    init(manifest: OwnerBundleManifest, inventory: String, digest: String, bytes: Int) throws {
        try manifest.validate()
        body = Body(schemaVersion: 1, ownerID: manifest.ownerID, phoneInstallationEpoch: manifest.phoneInstallationEpoch,
            watchInstallationEpoch: manifest.watchInstallationEpoch, practiceID: manifest.practiceID,
            revision: manifest.revision, status: manifest.status, heartRate: manifest.heartRate,
            recordingIDs: manifest.recordingIDs, inventorySHA256: inventory, bundleSHA256: digest, byteCount: bytes)
        try validate()
    }
    private init(body: Body) throws { self.body = body; try validate() }
    private func validate() throws {
        guard body.schemaVersion == 1, body.revision > 0, body.status != .open,
              body.phoneInstallationEpoch != body.watchInstallationEpoch,
              (1...20).contains(body.recordingIDs.count), Set(body.recordingIDs).count == body.recordingIDs.count,
              (45...OwnerPracticeBundle.maximumBytes).contains(body.byteCount),
              OwnerBundleIO.isDigest(body.inventorySHA256), OwnerBundleIO.isDigest(body.bundleSHA256) else {
            throw OwnerPracticeBundleError.integrity
        }
    }
    public func encoded() throws -> Data {
        try OwnerCanonical.encode(body, domain: "OwnerPracticeReceipt1", limit: 16_384)
    }
    public static func decode(_ bytes: Data) throws -> Self {
        try Self(body: OwnerCanonical.decode(bytes, domain: "OwnerPracticeReceipt1", limit: 16_384))
    }
}

struct OwnerBundleNode: Codable, Equatable {
    let device: Int64, inode: UInt64
    init(_ info: stat) { device = Int64(info.st_dev); inode = UInt64(info.st_ino) }
    init(fd: Int32, directory: Bool) throws {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == mode_t(directory ? S_IFDIR : S_IFREG),
              directory || info.st_nlink == 1 else { throw OwnerPracticeBundleError.integrity }
        self.init(info)
    }
    static func at(_ name: String, parent: Int32, directory: Bool) throws -> Self? {
        try AnnotationFiles.safeName(name)
        var info = stat()
        if fstatat(parent, name, &info, AT_SYMLINK_NOFOLLOW) != 0 {
            if errno == ENOENT { return nil }
            throw AnnotationFiles.error("inspect owner path")
        }
        guard info.st_mode & S_IFMT == mode_t(directory ? S_IFDIR : S_IFREG), directory || info.st_nlink == 1 else {
            throw OwnerPracticeBundleError.integrity
        }
        return Self(info)
    }
}

/// Pin every ancestor, so moving/replacing a parent cannot redirect an in-flight publication.
final class OwnerBundleAnchor {
    private var descriptors: [Int32] = []
    private var names: [String] = [], nodes: [OwnerBundleNode] = []
    var fd: Int32 { descriptors.last! }
    init(_ url: URL) throws {
        guard url.isFileURL, url.path.hasPrefix("/") else { throw OwnerPracticeBundleError.integrity }
        let components = url.path.split(separator: "/").map(String.init)
        guard components.count <= 128 else { throw OwnerPracticeBundleError.capacity }
        let root = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard root >= 0 else { throw AnnotationFiles.error("open owner anchor") }
        descriptors = [root]
        var complete = false
        defer { if !complete { descriptors.forEach { close($0) }; descriptors = [] } }
        for name in components {
            let child = try AnnotationFiles.directory(name, parent: fd, create: false)
            descriptors.append(child); names.append(name)
            nodes.append(try OwnerBundleNode(fd: child, directory: true))
        }
        try check(); complete = true
    }
    func check() throws {
        for index in names.indices {
            guard try OwnerBundleNode.at(names[index], parent: descriptors[index], directory: true) == nodes[index],
                  try OwnerBundleNode(fd: descriptors[index + 1], directory: true) == nodes[index] else {
                throw OwnerPracticeBundleError.integrity
            }
        }
    }
    deinit { descriptors.reversed().forEach { close($0) } }
}

enum OwnerBundleIO {
    static func hex(_ hash: SHA256.Digest) -> String { hash.map { String(format: "%02x", $0) }.joined() }
    static func digest(_ data: Data) -> String { hex(SHA256.hash(data: data)) }
    static func isDigest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    static func create(_ name: String, directory: Int32) throws -> Int32 {
        try AnnotationFiles.safeName(name)
        let fd = openat(directory, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw AnnotationFiles.error("create owner component") }
        return fd
    }
    static func put(_ data: Data, name: String, directory: Int32) throws {
        let fd = try create(name, directory: directory)
        defer { close(fd) }
        try AnnotationFiles.write(data, fd: fd); try AnnotationFiles.sync(fd)
    }
    static func required(_ name: String, directory: Int32, limit: Int) throws -> Data {
        guard let bytes = try AnnotationFiles.read(name, directory: directory, limit: limit) else {
            throw OwnerPracticeBundleError.integrity
        }
        return bytes
    }
    static func end(_ fd: Int32) throws {
        var byte: UInt8 = 0
        guard Darwin.read(fd, &byte, 1) == 0 else { throw OwnerPracticeBundleError.integrity }
    }
    static func consume(_ fd: Int32, count: Int, body: (Data) throws -> Void = { _ in }) throws -> String {
        var remaining = count, hash = SHA256()
        while remaining > 0 {
            let data = try AnnotationFiles.readExactly(fd, count: min(65_536, remaining))
            hash.update(data: data); try body(data); remaining -= data.count
        }
        try end(fd)
        return hex(hash.finalize())
    }
    static func match(_ name: String, directory: Int32, bytes: Int, digest: String) throws {
        let (fd, count) = try AnnotationFiles.openFile(name, directory: directory)
        defer { close(fd) }
        guard count == bytes, try consume(fd, count: count) == digest else { throw OwnerPracticeBundleError.integrity }
    }
    // Only private, owned staging trees use these bounded traversals. Symlinks are never followed.
    static func removeTree(_ fd: Int32, remaining: inout Int, depth: Int = 0) throws {
        guard depth <= 12 else { throw OwnerPracticeBundleError.capacity }
        for name in try AnnotationFiles.names(fd, limit: 4096) {
            guard remaining > 0 else { throw OwnerPracticeBundleError.capacity }
            remaining -= 1
            var info = stat()
            guard fstatat(fd, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { throw AnnotationFiles.error("inspect private stage") }
            if info.st_mode & S_IFMT == S_IFDIR {
                let child = try AnnotationFiles.directory(name, parent: fd, create: false)
                defer { close(child) }
                let node = try OwnerBundleNode(fd: child, directory: true)
                guard node == OwnerBundleNode(info) else { throw OwnerPracticeBundleError.integrity }
                try removeTree(child, remaining: &remaining, depth: depth + 1)
                guard try OwnerBundleNode.at(name, parent: fd, directory: true) == node,
                      unlinkat(fd, name, AT_REMOVEDIR) == 0 else { throw OwnerPracticeBundleError.integrity }
            } else {
                guard unlinkat(fd, name, 0) == 0 else { throw AnnotationFiles.error("remove private stage file") }
            }
        }
    }
    static func syncTree(_ fd: Int32, depth: Int = 0) throws {
        guard depth <= 12 else { throw OwnerPracticeBundleError.capacity }
        for name in try AnnotationFiles.names(fd, limit: 4096) {
            var info = stat()
            guard fstatat(fd, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { throw AnnotationFiles.error("inspect staged content") }
            if info.st_mode & S_IFMT == S_IFDIR {
                let child = try AnnotationFiles.directory(name, parent: fd, create: false)
                defer { close(child) }
                try syncTree(child, depth: depth + 1)
            } else {
                let (child, _) = try AnnotationFiles.openFile(name, directory: fd)
                defer { close(child) }
                try AnnotationFiles.sync(child)
            }
        }
        try AnnotationFiles.sync(fd)
    }
}

final class OwnerBundleTemporary {
    let name: String, fd: Int32, node: OwnerBundleNode
    private let parent: Int32
    private var removed = false
    init(parent: Int32, prefix: String) throws {
        self.parent = dup(parent)
        guard self.parent >= 0 else { throw AnnotationFiles.error("retain staging parent") }
        name = prefix + UUID().uuidString
        guard mkdirat(parent, name, 0o700) == 0 else { close(self.parent); throw AnnotationFiles.error("create private owner stage") }
        do {
            fd = try AnnotationFiles.directory(name, parent: parent, create: false)
        } catch { close(self.parent); throw error }
        do { node = try OwnerBundleNode(fd: fd, directory: true) }
        catch { close(fd); close(self.parent); throw error }
    }
    func remove() {
        guard !removed else { return }
        do {
            guard try OwnerBundleNode.at(name, parent: parent, directory: true) == node else { return }
            var budget = 16_384
            try OwnerBundleIO.removeTree(fd, remaining: &budget)
            guard try OwnerBundleNode.at(name, parent: parent, directory: true) == node,
                  unlinkat(parent, name, AT_REMOVEDIR) == 0 else { return }
            try AnnotationFiles.sync(parent); removed = true
        } catch { /* Unverified private debris remains isolated; future acquisition retries checked cleanup. */ }
    }
    deinit { close(fd); close(parent) }
}

/// These three immutable files bind the entire scope and inventory. Pin before verifying
/// content, then recheck afterward and at rename. ctime catches in-place rewrites even if
/// size/mtime are restored. Other components are hash-checked again before acknowledgement.
final class OwnerBundlePublicationPins {
    private struct Version: Equatable {
        let node: OwnerBundleNode, bytes: Int64, modified: Int64, modifiedNanos: Int64, changed: Int64, changedNanos: Int64
        init(_ info: stat) throws {
            guard info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1, info.st_size >= 0 else {
                throw OwnerPracticeBundleError.integrity
            }
            node = OwnerBundleNode(info); bytes = Int64(info.st_size)
            modified = Int64(info.st_mtimespec.tv_sec); modifiedNanos = Int64(info.st_mtimespec.tv_nsec)
            changed = Int64(info.st_ctimespec.tv_sec); changedNanos = Int64(info.st_ctimespec.tv_nsec)
        }
    }
    private var files: [(String, Int32, Version)] = []
    init(directory: Int32) throws {
        var complete = false
        defer { if !complete { files.forEach { close($0.1) }; files = [] } }
        for name in ["bundle.pslpractice", "manifest.json", "receipt.json"] {
            let (fd, _) = try AnnotationFiles.openFile(name, directory: directory)
            do {
                var info = stat()
                guard fstat(fd, &info) == 0 else { throw AnnotationFiles.error("pin publication file") }
                files.append((name, fd, try Version(info)))
            } catch { close(fd); throw error }
        }
        try check(directory: directory); complete = true
    }
    func check(directory: Int32) throws {
        for (name, fd, expected) in files {
            var path = stat(), held = stat()
            guard fstatat(directory, name, &path, AT_SYMLINK_NOFOLLOW) == 0, fstat(fd, &held) == 0,
                  try Version(path) == expected, try Version(held) == expected else { throw OwnerPracticeBundleError.integrity }
        }
    }
    deinit { files.forEach { close($0.1) } }
}

/// Shared with whole-practice deletion. Retain this lease throughout protected I/O;
/// never acquire it while holding an app authority fence. Its ownership is not consent.
public final class OwnerPracticePublicationLease: @unchecked Sendable {
    private let descriptor: Int32
    fileprivate init(descriptor: Int32) { self.descriptor = descriptor }
    deinit { flock(descriptor, LOCK_UN); close(descriptor) }
}

/// Private staging is excluded from lookup. Every visible revision is independently revalidated.
/// This store has no default container and never touches the live raw-only receipt namespace.
public final class OwnerPracticeReceiptStore {
    public static let directoryName = "OwnerPracticeBundles-v1"
    public let directoryURL: URL
    private let anchor: OwnerBundleAnchor
    let namespaceFD: Int32
    private let namespaceNode: OwnerBundleNode, lockNode: OwnerBundleNode
    private struct Identity: Codable {
        let schemaVersion: Int, directory: OwnerBundleNode, lock: OwnerBundleNode, lockSHA256: String
    }
    public init(base: URL) throws {
        let anchor = try OwnerBundleAnchor(base)
        let created = mkdirat(anchor.fd, Self.directoryName, 0o700) == 0
        guard created || errno == EEXIST else { throw AnnotationFiles.error("create owner receipt namespace") }
        let fd = try AnnotationFiles.directory(Self.directoryName, parent: anchor.fd, create: false)
        var success = false
        defer { if !success { close(fd) } }
        let node = try OwnerBundleNode(fd: fd, directory: true)
        if created {
            let bytes = Data(UUID().uuidString.utf8)
            try OwnerBundleIO.put(bytes, name: ".publication.lock", directory: fd)
            let lock = try AnnotationFiles.openFile(".publication.lock", directory: fd).0
            defer { close(lock) }
            let identity = Identity(schemaVersion: 1, directory: node,
                lock: try OwnerBundleNode(fd: lock, directory: false), lockSHA256: OwnerBundleIO.digest(bytes))
            try OwnerBundleIO.put(OwnerCanonical.encode(identity, domain: "PSLOwnerBundleNamespace1", limit: 4096),
                name: "identity.json", directory: fd)
            try AnnotationFiles.sync(fd); try AnnotationFiles.sync(anchor.fd)
        }
        let identity: Identity = try OwnerCanonical.decode(OwnerBundleIO.required("identity.json", directory: fd, limit: 4096),
            domain: "PSLOwnerBundleNamespace1", limit: 4096)
        let lock = try OwnerBundleIO.required(".publication.lock", directory: fd, limit: 128)
        guard identity.schemaVersion == 1, identity.directory == node,
              try OwnerBundleNode.at(".publication.lock", parent: fd, directory: false) == identity.lock,
              OwnerBundleIO.digest(lock) == identity.lockSHA256 else { throw OwnerPracticeBundleError.integrity }
        self.anchor = anchor; namespaceFD = fd; namespaceNode = node; lockNode = identity.lock
        directoryURL = base.appendingPathComponent(Self.directoryName)
        success = true
    }
    deinit { close(namespaceFD) }
    func check() throws {
        try anchor.check()
        guard try OwnerBundleNode.at(Self.directoryName, parent: anchor.fd, directory: true) == namespaceNode,
              try OwnerBundleNode(fd: namespaceFD, directory: true) == namespaceNode,
              try OwnerBundleNode.at(".publication.lock", parent: namespaceFD, directory: false) == lockNode else {
            throw OwnerPracticeBundleError.integrity
        }
    }
    public func acquirePublicationLease() throws -> OwnerPracticePublicationLease { try acquireLease() }
    func acquireLease() throws -> OwnerPracticePublicationLease {
        try check()
        let fd = openat(namespaceFD, ".publication.lock", O_RDWR | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw AnnotationFiles.error("open publication lease") }
        do {
            guard try OwnerBundleNode(fd: fd, directory: false) == lockNode else { throw OwnerPracticeBundleError.integrity }
            guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw OwnerPracticeBundleError.unavailable }
            try check()
            return OwnerPracticePublicationLease(descriptor: fd)
        } catch { close(fd); throw error }
    }
    static func name(_ practice: UUID, _ revision: Int64) -> String { practice.uuidString.lowercased() + "-r" + String(revision) }
    func removeAbandonedStages() throws {
        try check()
        let names = try AnnotationFiles.names(namespaceFD, limit: 258)
        guard names.filter({ !$0.hasPrefix(".stage-") }).count < 258 else { throw OwnerPracticeBundleError.capacity }
        for name in names where name.hasPrefix(".stage-") {
            guard let id = UUID(uuidString: String(name.dropFirst(7))), name == ".stage-" + id.uuidString else {
                throw OwnerPracticeBundleError.integrity
            }
            let fd = try AnnotationFiles.directory(name, parent: namespaceFD, create: false)
            defer { close(fd) }
            let node = try OwnerBundleNode(fd: fd, directory: true)
            var budget = 16_384
            try OwnerBundleIO.removeTree(fd, remaining: &budget)
            guard try OwnerBundleNode.at(name, parent: namespaceFD, directory: true) == node,
                  unlinkat(namespaceFD, name, AT_REMOVEDIR) == 0 else { throw OwnerPracticeBundleError.integrity }
        }
        try AnnotationFiles.sync(namespaceFD)
    }
    public func receipt(practiceID: UUID, revision: Int64) throws -> OwnerPracticeReceipt? {
        guard revision > 0 else { throw OwnerPracticeBundleError.integrity }
        try check()
        guard try OwnerBundleNode.at(Self.name(practiceID, revision), parent: namespaceFD, directory: true) != nil else { return nil }
        return try open(practiceID: practiceID, revision: revision).receipt
    }
    public func open(practiceID: UUID, revision: Int64) throws -> OwnerPracticeBundleSnapshot {
        guard revision > 0 else { throw OwnerPracticeBundleError.integrity }
        try check()
        let name = Self.name(practiceID, revision)
        let fd = try AnnotationFiles.directory(name, parent: namespaceFD, create: false)
        defer { close(fd) }
        let node = try OwnerBundleNode(fd: fd, directory: true)
        let result = try OwnerPracticeBundle.verify(directory: directoryURL.appendingPathComponent(name), fd: fd)
        try check()
        guard result.receipt.practiceID == practiceID, result.receipt.revision == revision,
              try OwnerBundleNode.at(name, parent: namespaceFD, directory: true) == node else { throw OwnerPracticeBundleError.integrity }
        return result
    }
    public func exportBundle(practiceID: UUID, revision: Int64, destination: URL) throws -> OwnerPracticeReceipt {
        let lease = try acquireLease()
        defer { withExtendedLifetime(lease) {} }
        let snapshot = try open(practiceID: practiceID, revision: revision)
        let directory = try AnnotationFiles.directory(Self.name(practiceID, revision), parent: namespaceFD, create: false)
        defer { close(directory) }
        let (input, size) = try AnnotationFiles.openFile("bundle.pslpractice", directory: directory)
        defer { close(input) }
        let anchor = try OwnerBundleAnchor(destination.deletingLastPathComponent())
        try AnnotationFiles.safeName(destination.lastPathComponent)
        let temporary = try OwnerBundleTemporary(parent: anchor.fd, prefix: ".owner-readback-")
        defer { temporary.remove() }
        let output = try OwnerBundleIO.create("bundle", directory: temporary.fd)
        defer { close(output) }
        guard size == snapshot.receipt.byteCount,
              try OwnerBundleIO.consume(input, count: size, body: { try AnnotationFiles.write($0, fd: output) }) == snapshot.receipt.bundleSHA256,
              try open(practiceID: practiceID, revision: revision).receipt == snapshot.receipt else { throw OwnerPracticeBundleError.integrity }
        try AnnotationFiles.sync(output); try anchor.check(); try check()
        guard renameatx_np(temporary.fd, "bundle", anchor.fd, destination.lastPathComponent, UInt32(RENAME_EXCL)) == 0 else {
            throw AnnotationFiles.error("publish owner readback")
        }
        try AnnotationFiles.sync(anchor.fd)
        return snapshot.receipt
    }
}

/// A sealed, verified publication capability. O8b must check current authority while
/// holding its shared fence and invoke ONLY renameForPublication inside that fence.
/// Confirmation, cancellation, hashing, fsync and receipt readback run outside it.
public final class OwnerPracticePreparedPublication: @unchecked Sendable {
    public let receipt: OwnerPracticeReceipt, scope: OwnerPracticePublicationScope
    private let store: OwnerPracticeReceiptStore, finalName: String
    private var lease: OwnerPracticePublicationLease?
    private let temporary: OwnerBundleTemporary?, pinnedFD: Int32, node: OwnerBundleNode, pins: OwnerBundlePublicationPins
    private let stateLock = NSLock()
    private enum State { case prepared, renamed, confirming, confirmed, closed }
    private var state: State = .prepared
    // Nil in production; configure before cancellation to hold its actual cleanup boundary.
    var beforeCancellationCleanup: (@Sendable () -> Void)?
    init(store: OwnerPracticeReceiptStore, lease: OwnerPracticePublicationLease, receipt: OwnerPracticeReceipt,
         name: String, temporary: OwnerBundleTemporary?, pins: OwnerBundlePublicationPins? = nil) throws {
        self.store = store; self.lease = lease; self.receipt = receipt; scope = receipt.scope
        finalName = name; self.temporary = temporary
        if let temporary {
            pinnedFD = dup(temporary.fd)
            guard pinnedFD >= 0 else { throw AnnotationFiles.error("pin verified stage") }
        } else { pinnedFD = try AnnotationFiles.directory(name, parent: store.namespaceFD, create: false) }
        do {
            node = try OwnerBundleNode(fd: pinnedFD, directory: true)
            if let pins { self.pins = pins }
            else {
                let verifiedPins = try OwnerBundlePublicationPins(directory: pinnedFD)
                _ = try OwnerPracticeBundle.verify(directory: store.directoryURL.appendingPathComponent(name),
                    fd: pinnedFD, expected: receipt)
                self.pins = verifiedPins
            }
            try self.pins.check(directory: pinnedFD)
        }
        catch { close(pinnedFD); throw error }
    }
    /// Public for the phone/Watch worker modules; no caller callback or authority bypass is supplied.
    /// Bounded path-witness checks and one exclusive descriptor-relative rename, without hashing/fsync.
    public func renameForPublication() throws {
        stateLock.lock(); defer { stateLock.unlock() }
        guard state == .prepared, lease != nil else { throw OwnerPracticeBundleError.closed }
        try store.check()
        try pins.check(directory: pinnedFD)
        let currentName = temporary?.name ?? finalName
        guard try OwnerBundleNode(fd: pinnedFD, directory: true) == node,
              try OwnerBundleNode.at(currentName, parent: store.namespaceFD, directory: true) == node else {
            throw OwnerPracticeBundleError.integrity
        }
        if let temporary {
            guard renameatx_np(store.namespaceFD, temporary.name, store.namespaceFD, finalName, UInt32(RENAME_EXCL)) == 0 else {
                if errno == EEXIST { throw OwnerPracticeBundleError.conflict }
                throw AnnotationFiles.error("publish complete owner practice")
            }
        }
        state = .renamed
    }
    /// A failure withholds acknowledgement; an already-renamed valid revision is retained.
    /// A new reader/retry revalidates the complete revision after lost confirmation or process death.
    public func confirmPublication() throws -> OwnerPracticeReceipt {
        stateLock.lock()
        guard state == .renamed, let heldLease = lease else {
            stateLock.unlock(); throw OwnerPracticeBundleError.closed
        }
        state = .confirming
        stateLock.unlock()
        // Cancellation may close the handle, but cannot release protection during readback.
        defer { withExtendedLifetime(heldLease) {} }
        do {
            try store.check(); try AnnotationFiles.sync(store.namespaceFD)
            try pins.check(directory: pinnedFD)
            guard try OwnerBundleNode.at(finalName, parent: store.namespaceFD, directory: true) == node,
                  try store.open(practiceID: receipt.practiceID, revision: receipt.revision).receipt == receipt else {
                throw OwnerPracticeBundleError.integrity
            }
        } catch {
            stateLock.lock()
            if state == .confirming { state = .renamed }
            stateLock.unlock()
            throw error
        }
        stateLock.lock(); defer { stateLock.unlock() }
        guard state == .confirming else { throw OwnerPracticeBundleError.closed }
        state = .confirmed; lease = nil
        return receipt
    }
    public func cancel() {
        stateLock.lock()
        let cleanup = state == .prepared ? temporary : nil
        let heldLease = lease
        state = .closed; lease = nil
        stateLock.unlock()
        // Exactly one caller owns staged cleanup, with its lease retained outside the state lock.
        defer { withExtendedLifetime(heldLease) {} }
        if let cleanup { beforeCancellationCleanup?(); cleanup.remove() }
    }
    deinit { cancel(); close(pinnedFD) }
}
