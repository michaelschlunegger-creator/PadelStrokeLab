import Darwin
import Foundation

public enum OwnerTelemetryStoreStage: Equatable, Sendable {
    case componentTemporarySynced, componentPublished, manifestTemporarySynced, manifestPublished, directorySynced
}

/// Synchronous, exclusively owned store. Callers serialize access on one executor.
/// Durable identity witnesses reject detached locks before a competing opener can acquire them.
public final class OwnerTelemetryStore {
    public static let directoryName = "OwnerTelemetry-v1"
    public let directoryURL: URL
    public private(set) var snapshot: OwnerPracticeTelemetry
    var failureInjector: ((OwnerTelemetryStoreStage) throws -> Void)?
    private struct Node: Codable, Equatable {
        let device: Int64, inode: UInt64
    }
    private struct RootWitness: Codable {
        let schemaVersion: Int, directory: Node
    }
    private struct Witness: Codable {
        let schemaVersion: Int, practiceID: UUID, headerDigest: String, directory: Node, lock: Node, lockDigest: String
    }
    private struct Component: Codable {
        let name: String, bytes: Int, sha256: String
    }
    private struct Manifest: Codable {
        let schemaVersion: Int, practiceID: UUID, headerDigest: String
        let status: OwnerTelemetryStatus, components: [Component], recordingIDs: [UUID]
        let sampleCount: Int, eventCount: Int
    }
    private static let rootMarker = ".OwnerTelemetry-v1"
    private let baseURL: URL
    private let baseFD: Int32, namespaceFD: Int32, directoryFD: Int32, lockFD: Int32
    private let rootBytes: Data, witnessBytes: Data, lockBytes: Data
    private let baseNode: Node, namespaceNode: Node, directoryNode: Node, lockNode: Node, rootNode: Node, witnessNode: Node
    private let witnessName: String
    private var components: [String: (Node, Data)] = [:]
    private var componentFDs: [String: Int32] = [:]
    private var closed = false, poisoned = false

    public static func create(base: URL, telemetry: OwnerPracticeTelemetry) throws -> OwnerTelemetryStore {
        // Validate the complete semantic envelope before touching the namespace.
        _ = try OwnerPracticeTelemetry.decode(telemetry.encoded())
        return try acquire(base: base, practiceID: telemetry.header.practiceID, header: telemetry.header, initial: telemetry)
    }
    public static func open(base: URL, practiceID: UUID, expectedHeader: OwnerTelemetryHeader) throws -> OwnerTelemetryStore {
        try acquire(base: base, practiceID: practiceID, header: expectedHeader, initial: nil)
    }
    private init(base: URL, snapshot: OwnerPracticeTelemetry, descriptors: [Int32], nodes: [Node],
                 rootBytes: Data, witnessBytes: Data, lockBytes: Data, witnessName: String) {
        baseURL = base; self.snapshot = snapshot
        directoryURL = base.appendingPathComponent(Self.directoryName, isDirectory: true)
            .appendingPathComponent(snapshot.header.practiceID.uuidString.lowercased(), isDirectory: true)
        baseFD = descriptors[0]; namespaceFD = descriptors[1]; directoryFD = descriptors[2]; lockFD = descriptors[3]
        baseNode = nodes[0]; namespaceNode = nodes[1]; directoryNode = nodes[2]; lockNode = nodes[3]
        rootNode = nodes[4]; witnessNode = nodes[5]
        self.rootBytes = rootBytes; self.witnessBytes = witnessBytes; self.lockBytes = lockBytes; self.witnessName = witnessName
    }
    private static func acquire(base: URL, practiceID: UUID, header: OwnerTelemetryHeader,
                                initial: OwnerPracticeTelemetry?) throws -> OwnerTelemetryStore {
        guard header.practiceID == practiceID else { throw OwnerTelemetryError.invalid("store practice identity") }
        let baseFD = try AnnotationFiles.root(base)
        var owned = [baseFD], transferred = false
        defer { if !transferred { for fd in owned.reversed() { Darwin.close(fd) } } }
        let existingRoot = try file(Self.rootMarker, in: baseFD, limit: 4096)
        let namespaceFD: Int32
        if existingRoot == nil {
            guard initial != nil, try !exists(directoryName, in: baseFD) else { throw OwnerTelemetryError.integrity }
            try exclusive(Data("pending\n".utf8), name: rootMarker, in: baseFD)
            guard mkdirat(baseFD, directoryName, 0o700) == 0 else { throw AnnotationFiles.error("create telemetry namespace") }
            namespaceFD = try AnnotationFiles.directory(directoryName, parent: baseFD, create: false)
            owned.append(namespaceFD)
            let root = RootWitness(schemaVersion: 1, directory: try node(namespaceFD, directory: true))
            let bytes = try OwnerCanonical.encode(root, domain: "PSLOwnerTelemetryRoot1", limit: 4096)
            try AnnotationFiles.publish(bytes, name: rootMarker, directory: baseFD, replace: true)
        } else {
            namespaceFD = try AnnotationFiles.directory(directoryName, parent: baseFD, create: false)
            owned.append(namespaceFD)
            let root: RootWitness = try OwnerCanonical.decode(existingRoot!.1, domain: "PSLOwnerTelemetryRoot1", limit: 4096)
            guard root.schemaVersion == 1, try root.directory == node(namespaceFD, directory: true) else {
                throw OwnerTelemetryError.integrity
            }
        }
        let name = practiceID.uuidString.lowercased(), witnessName = ".used-" + name
        let headerBytes = try header.encoded()
        let directoryFD: Int32, lockFD: Int32
        if initial != nil {
            guard try !exists(name, in: namespaceFD), try !exists(witnessName, in: namespaceFD) else {
                throw OwnerTelemetryError.invalid("practice identity already used")
            }
            // Pending witness survives every failure, including failure before directory creation.
            try exclusive(Data("pending\n".utf8), name: witnessName, in: namespaceFD)
            guard mkdirat(namespaceFD, name, 0o700) == 0 else { throw AnnotationFiles.error("create telemetry practice") }
            try AnnotationFiles.sync(namespaceFD)
            directoryFD = try AnnotationFiles.directory(name, parent: namespaceFD, create: false)
            owned.append(directoryFD)
            try exclusive(Data(("PSLOwnerTelemetryLease1\n" + UUID().uuidString + "\n").utf8), name: ".lock", in: directoryFD)
            lockFD = openat(directoryFD, ".lock", O_RDWR | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard lockFD >= 0 else { throw AnnotationFiles.error("open telemetry lease") }
            owned.append(lockFD)
            guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw OwnerTelemetryError.unavailable }
            let lock = try required(".lock", in: directoryFD, limit: 256)
            let witness = Witness(schemaVersion: 1, practiceID: practiceID, headerDigest: OwnerTelemetryHeader.digest(headerBytes),
                directory: try node(directoryFD, directory: true), lock: try node(lockFD), lockDigest: OwnerTelemetryHeader.digest(lock.1))
            guard witness.lock == lock.0 else { throw OwnerTelemetryError.integrity }
            try AnnotationFiles.publish(OwnerCanonical.encode(witness, domain: "PSLOwnerTelemetryWitness1", limit: 4096),
                name: witnessName, directory: namespaceFD, replace: true)
        } else {
            let witnessFile = try required(witnessName, in: namespaceFD, limit: 4096)
            let witness: Witness = try OwnerCanonical.decode(witnessFile.1, domain: "PSLOwnerTelemetryWitness1", limit: 4096)
            directoryFD = try AnnotationFiles.directory(name, parent: namespaceFD, create: false)
            owned.append(directoryFD)
            let lock = try required(".lock", in: directoryFD, limit: 256)
            guard witness.schemaVersion == 1, witness.practiceID == practiceID,
                  witness.headerDigest == OwnerTelemetryHeader.digest(headerBytes),
                  try witness.directory == node(directoryFD, directory: true), witness.lock == lock.0,
                  witness.lockDigest == OwnerTelemetryHeader.digest(lock.1) else { throw OwnerTelemetryError.integrity }
            lockFD = openat(directoryFD, ".lock", O_RDWR | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard lockFD >= 0 else { throw AnnotationFiles.error("open telemetry lease") }
            owned.append(lockFD)
            guard try node(lockFD) == witness.lock, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
                throw OwnerTelemetryError.unavailable
            }
        }
        let root = try required(rootMarker, in: baseFD, limit: 4096)
        let witness = try required(witnessName, in: namespaceFD, limit: 4096)
        let lock = try required(".lock", in: directoryFD, limit: 256)
        var value: OwnerPracticeTelemetry
        var components: [String: (Node, Data)] = [:]
        if let initial { value = initial }
        else {
            let headerFile = try required("header.json", in: directoryFD, limit: 4096)
            let telemetryFile = try required("telemetry.json", in: directoryFD, limit: OwnerPracticeTelemetry.maximumBytes)
            guard headerFile.1 == headerBytes else { throw OwnerTelemetryError.integrity }
            value = try OwnerPracticeTelemetry.decode(telemetryFile.1)
            guard value.header == header else { throw OwnerTelemetryError.integrity }
            components = ["header.json": headerFile, "telemetry.json": telemetryFile]
            if let manifest = try file("manifest.json", in: directoryFD, limit: 16384) {
                guard value.finalization != nil, try manifest.1 == manifestBytes(value) else { throw OwnerTelemetryError.integrity }
                components["manifest.json"] = manifest
            } else if value.finalization != nil { throw OwnerTelemetryError.integrity }
        }
        let nodes = try [node(baseFD, directory: true), node(namespaceFD, directory: true), node(directoryFD, directory: true),
            node(lockFD), root.0, witness.0]
        let store = OwnerTelemetryStore(base: base, snapshot: value, descriptors: owned, nodes: nodes,
            rootBytes: root.1, witnessBytes: witness.1, lockBytes: lock.1, witnessName: witnessName)
        transferred = true; store.components = components
        do {
            for name in components.keys { try store.pin(name) }
            try store.check()
            if initial != nil { try store.publish(value) }
            else if value.finalization == nil, !value.incompleteReasons.contains(.reopenedPartial) {
                value.markReopenedPartial(); try store.publish(value); store.snapshot = value
            }
            return store
        } catch { store.close(); throw error }
    }
    public func update(_ operation: (inout OwnerPracticeTelemetry) throws -> Void) throws {
        try check()
        var candidate = snapshot
        let result = Result { try operation(&candidate) }
        // A capacity refusal retains only its explicit reason; still publish it before rethrowing.
        if try candidate.encoded() != snapshot.encoded() {
            try publish(candidate)
            snapshot = candidate
        }
        try result.get()
    }
    public func close() {
        guard !closed else { return }
        closed = true
        for fd in componentFDs.values { Darwin.close(fd) }
        componentFDs.removeAll()
        flock(lockFD, LOCK_UN)
        for fd in [lockFD, directoryFD, namespaceFD, baseFD] { Darwin.close(fd) }
    }
    deinit { close() }
    private func anchors() throws {
        guard !closed, !poisoned else { throw OwnerTelemetryError.closed }
        let reopened = try AnnotationFiles.root(baseURL)
        defer { Darwin.close(reopened) }
        guard try Self.node(reopened, directory: true) == baseNode,
              try Self.named(Self.directoryName, in: baseFD, directory: true) == namespaceNode,
              try Self.named(snapshot.header.practiceID.uuidString.lowercased(), in: namespaceFD, directory: true) == directoryNode,
              try Self.node(lockFD) == lockNode else { throw OwnerTelemetryError.integrity }
        for (name, fd, expectedNode, expectedBytes, limit) in [
            (Self.rootMarker, baseFD, rootNode, rootBytes, 4096),
            (witnessName, namespaceFD, witnessNode, witnessBytes, 4096),
            (".lock", directoryFD, lockNode, lockBytes, 256)
        ] {
            let value = try Self.required(name, in: fd, limit: limit)
            guard value.0 == expectedNode, value.1 == expectedBytes else { throw OwnerTelemetryError.integrity }
        }
    }
    private func check(publishing: Bool = false) throws {
        do {
            try anchors()
            let names = try AnnotationFiles.names(directoryFD, limit: 8)
            let expected = Set(components.keys).union(publishing ? [".lock", ".transaction"] : [".lock"])
            guard Set(names) == expected else { throw OwnerTelemetryError.integrity }
            for (name, expected) in components {
                let current = try Self.required(name, in: directoryFD, limit: OwnerPracticeTelemetry.maximumBytes)
                guard current.0 == expected.0, current.1 == expected.1 else { throw OwnerTelemetryError.integrity }
            }
        } catch { poisoned = true; throw error }
    }
    private func publish(_ value: OwnerPracticeTelemetry) throws {
        try check()
        do {
            try Self.exclusive(Data("pending\n".utf8), name: ".transaction", in: directoryFD)
            for (name, bytes) in [("header.json", try value.header.encoded()), ("telemetry.json", try value.encoded())] {
                if components[name]?.1 != bytes { try replace(bytes, name: name, manifest: false) }
            }
            if value.finalization != nil { try replace(Self.manifestBytes(value), name: "manifest.json", manifest: true) }
            try anchors(); try AnnotationFiles.sync(directoryFD)
            try failureInjector?(.directorySynced)
            try check(publishing: true)
            guard unlinkat(directoryFD, ".transaction", 0) == 0 else { throw AnnotationFiles.error("commit telemetry") }
            try AnnotationFiles.sync(directoryFD)
        } catch {
            // The durable transaction marker prevents even a published final manifest becoming success.
            poisoned = true
            throw error
        }
    }
    private func replace(_ bytes: Data, name: String, manifest: Bool) throws {
        try anchors()
        if let old = components[name] {
            let current = try Self.required(name, in: directoryFD, limit: OwnerPracticeTelemetry.maximumBytes)
            guard current.0 == old.0, current.1 == old.1 else { throw OwnerTelemetryError.integrity }
        } else {
            guard try !Self.exists(name, in: directoryFD) else { throw OwnerTelemetryError.integrity }
        }
        let temporary = ".stage-" + UUID().uuidString
        let fd = openat(directoryFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw AnnotationFiles.error("create telemetry stage") }
        defer { Darwin.close(fd) }
        try AnnotationFiles.write(bytes, fd: fd); try AnnotationFiles.sync(fd)
        try failureInjector?(manifest ? .manifestTemporarySynced : .componentTemporarySynced)
        try anchors()
        guard renameat(directoryFD, temporary, directoryFD, name) == 0 else { throw AnnotationFiles.error("publish telemetry component") }
        let published = try Self.required(name, in: directoryFD, limit: OwnerPracticeTelemetry.maximumBytes)
        guard try published.0 == Self.node(fd), published.1 == bytes else { throw OwnerTelemetryError.integrity }
        components[name] = published
        try pin(name)
        try AnnotationFiles.sync(directoryFD)
        try failureInjector?(manifest ? .manifestPublished : .componentPublished)
    }
    private func pin(_ name: String) throws {
        let (fd, _) = try AnnotationFiles.openFile(name, directory: directoryFD)
        do {
            guard try Self.node(fd) == components[name]?.0 else { throw OwnerTelemetryError.integrity }
        } catch { Darwin.close(fd); throw error }
        if let old = componentFDs.updateValue(fd, forKey: name) { Darwin.close(old) }
    }
    private static func manifestBytes(_ value: OwnerPracticeTelemetry) throws -> Data {
        guard let final = value.finalization else { throw OwnerTelemetryError.invalid("unfinalized manifest") }
        let header = try value.header.encoded(), telemetry = try value.encoded()
        let components = [("header.json", header), ("telemetry.json", telemetry)].map {
            Component(name: $0.0, bytes: $0.1.count, sha256: OwnerTelemetryHeader.digest($0.1))
        }
        return try OwnerCanonical.encode(Manifest(schemaVersion: 1, practiceID: value.header.practiceID,
            headerDigest: OwnerTelemetryHeader.digest(header), status: final.status, components: components,
            recordingIDs: final.recordingIDs, sampleCount: final.sampleCount, eventCount: final.eventCount),
            domain: "PSLOwnerTelemetryManifest1", limit: 16384)
    }
    private static func node(_ fd: Int32, directory: Bool = false) throws -> Node {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == geteuid(),
              info.st_mode & S_IFMT == (directory ? S_IFDIR : S_IFREG), directory || info.st_nlink == 1 else {
            throw OwnerTelemetryError.integrity
        }
        return Node(device: Int64(info.st_dev), inode: UInt64(info.st_ino))
    }
    private static func named(_ name: String, in parent: Int32, directory: Bool = false) throws -> Node {
        let fd = try directory ? AnnotationFiles.directory(name, parent: parent, create: false)
            : AnnotationFiles.openFile(name, directory: parent).0
        defer { Darwin.close(fd) }
        return try node(fd, directory: directory)
    }
    private static func exists(_ name: String, in parent: Int32) throws -> Bool {
        var info = stat()
        if fstatat(parent, name, &info, AT_SYMLINK_NOFOLLOW) == 0 { return true }
        guard errno == ENOENT else { throw AnnotationFiles.error("inspect telemetry path") }
        return false
    }
    private static func file(_ name: String, in parent: Int32, limit: Int) throws -> (Node, Data)? {
        guard try exists(name, in: parent) else { return nil }
        let (fd, count) = try AnnotationFiles.openFile(name, directory: parent)
        defer { Darwin.close(fd) }
        guard count <= limit else { throw OwnerTelemetryError.capacity }
        let identity = try node(fd), bytes = try AnnotationFiles.readExactly(fd, count: count)
        var extra: UInt8 = 0
        guard Darwin.read(fd, &extra, 1) == 0, try node(fd) == identity,
              try named(name, in: parent) == identity else { throw OwnerTelemetryError.integrity }
        return (identity, bytes)
    }
    private static func required(_ name: String, in parent: Int32, limit: Int) throws -> (Node, Data) {
        guard let result = try file(name, in: parent, limit: limit) else { throw OwnerTelemetryError.integrity }
        return result
    }
    private static func exclusive(_ bytes: Data, name: String, in parent: Int32) throws {
        let fd = openat(parent, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw AnnotationFiles.error("reserve telemetry identity") }
        defer { Darwin.close(fd) }
        try AnnotationFiles.write(bytes, fd: fd); try AnnotationFiles.sync(fd); try AnnotationFiles.sync(parent)
    }
}
