import Darwin
import Foundation
import PadelCore

/// Synchronous non-Sendable owner; construct and use on one non-main serial executor.
/// The witness can deny reinitialization. It cannot grant or reconstruct authority.
nonisolated final class OwnerPhoneBootstrap {
    enum Failure: Error { case invalidStorage, unavailable, poisoned }
    enum Stage: Equatable, Sendable { case pendingSynced, preferencesInitialized, channelInitialized }
    private static let witness = "OwnerPhoneBootstrap-v1"
    private static let namespaces = [PracticeSetupStore.directoryName, OwnerPracticeStore.directoryName, PracticeSetupChannel.directoryName]
    private static let pending = Data("PSLPhoneBootstrap1\npending\n".utf8)
    private struct Node: Equatable { let device: dev_t; let inode: ino_t }
    private let base: URL
    private let root: Int32
    private let witness: Int32
    private let ready: Data
    private let namespaces: [Node]
    private var stores: (PracticeSetupStore, PracticeSetupChannel)?
    private var poisoned = false

    // Nil in production. Faults occur after the actual durable/store initialization boundaries.
    init(base: URL, fault: ((Stage) throws -> Void)? = nil) throws {
        let root = try Self.openBase(base)
        var witness: Int32 = -1
        do {
            let existing = try Self.named(Self.witness, root)
            let namespaces = try Self.namespaces.map { try Self.named($0, root) }
            let creating = existing == nil
            guard creating ? namespaces.allSatisfy({ $0 == nil }) : namespaces.allSatisfy({
                $0.map { $0.st_mode & S_IFMT == S_IFDIR } == true
            }) else { throw Failure.invalidStorage }
            if let existing {
                guard existing.st_mode & S_IFMT == S_IFREG, existing.st_nlink == 1 else { throw Failure.invalidStorage }
            }
            let flags = O_RDWR | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | (creating ? O_CREAT | O_EXCL : 0)
            witness = openat(root, Self.witness, flags, 0o600)
            guard witness >= 0 else { throw Failure.unavailable }
            _ = try Self.read(witness)
            guard flock(witness, LOCK_EX | LOCK_NB) == 0 else { throw Failure.unavailable }
            let loaded: Data
            if creating {
                try Self.write(Self.pending, witness)
                guard fsync(root) == 0 else { throw Failure.unavailable }
                loaded = Self.pending
            } else {
                loaded = try Self.read(witness)
                _ = try Self.epoch(loaded)
                guard fsync(witness) == 0 else { throw Failure.unavailable }
            }
            try Self.checkPaths(base, root, witness, expected: loaded)
            if creating { try fault?(.pendingSynced) }
            let preferences = try PracticeSetupStore(base: base)
            let epoch = try preferences.checkedSnapshot().localInstallationEpoch
            if !creating, try Self.epoch(loaded) != epoch { throw Failure.invalidStorage }
            if creating { try fault?(.preferencesInitialized) }
            let channel = try PracticeSetupChannel(base: base, localInstallationEpoch: epoch,
                device: .phone, intent: creating ? .createNew : .openExisting)
            _ = try channel.readSnapshot()
            if creating { try fault?(.channelInitialized) }
            let nodes = try Self.namespaceNodes(root)
            let ready = Data("PSLPhoneBootstrap1\nready\n\(epoch.uuidString)\n".utf8)
            try Self.verify(base, root, witness, loaded, nodes, preferences, channel)
            if creating { try Self.write(ready, witness) }
            try Self.verify(base, root, witness, ready, nodes, preferences, channel)
            self.base = base; self.root = root; self.witness = witness
            self.ready = ready; self.namespaces = nodes; stores = (preferences, channel)
        } catch {
            if witness >= 0 { flock(witness, LOCK_UN); close(witness) }
            close(root)
            throw error
        }
    }

    deinit {
        stores = nil
        flock(witness, LOCK_UN)
        close(witness)
        close(root)
    }

    /// Callers must keep both store handles inside this synchronous, nonescaping operation.
    func withStores<T: Sendable>(_ body: (PracticeSetupStore, PracticeSetupChannel) throws -> T) throws -> T {
        try checkLive()
        guard let stores else { throw Failure.poisoned }
        let result = Result { try body(stores.0, stores.1) }
        // Even a throwing body can have durably raised a fence or damaged storage.
        try checkLive()
        return try result.get()
    }

    private func checkLive() throws {
        guard !poisoned, let stores else { throw Failure.poisoned }
        do { try Self.verify(base, root, witness, ready, namespaces, stores.0, stores.1) }
        catch { poisoned = true; throw error }
    }

    private static func verify(_ base: URL, _ root: Int32, _ witness: Int32, _ expected: Data,
                               _ namespaces: [Node], _ preferences: PracticeSetupStore, _ channel: PracticeSetupChannel) throws {
        try checkPaths(base, root, witness, expected: expected)
        guard try namespaceNodes(root) == namespaces else { throw Failure.invalidStorage }
        _ = try preferences.checkedSnapshot()
        _ = try channel.readSnapshot()
    }

    private static func checkPaths(_ base: URL, _ root: Int32, _ witness: Int32, expected: Data) throws {
        let reopened = try openBase(base)
        defer { close(reopened) }
        guard try node(reopened) == node(root), let named = try named(Self.witness, root),
              named.st_mode & S_IFMT == S_IFREG, named.st_nlink == 1,
              try node(witness) == Node(device: named.st_dev, inode: named.st_ino),
              try read(witness) == expected else { throw Failure.invalidStorage }
    }

    private static func namespaceNodes(_ root: Int32) throws -> [Node] {
        try namespaces.map { name in
            guard let info = try named(name, root), info.st_mode & S_IFMT == S_IFDIR else { throw Failure.invalidStorage }
            return Node(device: info.st_dev, inode: info.st_ino)
        }
    }

    private static func epoch(_ bytes: Data) throws -> UUID {
        guard let text = String(data: bytes, encoding: .utf8) else { throw Failure.invalidStorage }
        let fields = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard fields.count == 4, fields[0] == "PSLPhoneBootstrap1", fields[1] == "ready", fields[3].isEmpty,
              let epoch = UUID(uuidString: String(fields[2])), epoch.uuidString == fields[2] else { throw Failure.invalidStorage }
        return epoch
    }

    private static func openBase(_ base: URL) throws -> Int32 {
        guard base.isFileURL, base.path.hasPrefix("/"), !base.path.utf8.contains(0),
              !base.pathComponents.contains("Recordings") else { throw Failure.invalidStorage }
        var root = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard root >= 0 else { throw Failure.unavailable }
        do {
            for part in base.path.split(separator: "/") {
                guard part != ".", part != ".." else { throw Failure.invalidStorage }
                let next = openat(root, String(part), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard next >= 0 else { throw Failure.unavailable }
                close(root); root = next
            }
            return root
        } catch { close(root); throw error }
    }

    private static func named(_ name: String, _ root: Int32) throws -> stat? {
        var info = stat()
        if fstatat(root, name, &info, AT_SYMLINK_NOFOLLOW) == 0 { return info }
        guard errno == ENOENT else { throw Failure.unavailable }
        return nil
    }

    private static func node(_ descriptor: Int32) throws -> Node {
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw Failure.unavailable }
        return Node(device: info.st_dev, inode: info.st_ino)
    }

    private static func read(_ descriptor: Int32) throws -> Data {
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1,
              (0...128).contains(info.st_size) else { throw Failure.invalidStorage }
        var buffer = [UInt8](repeating: 0, count: 129)
        let count = buffer.withUnsafeMutableBytes { pread(descriptor, $0.baseAddress, $0.count, 0) }
        guard count >= 0, count == info.st_size else { throw Failure.invalidStorage }
        return Data(buffer.prefix(count))
    }

    private static func write(_ bytes: Data, _ descriptor: Int32) throws {
        guard bytes.count <= 128 else { throw Failure.invalidStorage }
        try bytes.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let written = pwrite(descriptor, buffer.baseAddress!.advanced(by: offset), buffer.count - offset, off_t(offset))
                guard written > 0 else { throw Failure.unavailable }
                offset += written
            }
        }
        guard ftruncate(descriptor, off_t(bytes.count)) == 0, fsync(descriptor) == 0 else { throw Failure.unavailable }
    }
}
