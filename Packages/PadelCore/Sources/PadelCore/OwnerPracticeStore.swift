import Darwin
import Foundation

public enum OwnerPracticeDevice: String, Codable, Sendable { case phone, watch }
public enum OwnerPracticeStoreIntent: Sendable { case createNew, openExisting }
public enum OwnerReplayScope: String, Codable, Sendable { case recording, practice }
public enum OwnerPracticeStorageError: Error, Equatable, Sendable {
    case busy, poisoned, invalid(String), integrity(String), capacity, retired, failedRecordingID
}

public struct OwnerPracticeStoreSnapshot: Equatable, Sendable {
    public let localInstallationEpoch: UUID
    public let device: OwnerPracticeDevice
    public let authority: OwnerPracticeIdentity?
}

public enum OwnerStoredContext: Equatable, Sendable {
    case missing, partial, corrupt, retired
    case valid(OwnerRecordingContext)
}

/// Durable metadata disposition only. Neither a duplicate nor a fresh receipt authorizes Start.
public struct OwnerContextPublication: Equatable, Sendable {
    public enum Disposition: Sendable { case newlyPublished, alreadyExisting }
    public let disposition: Disposition
    public let recordingID: UUID
    public let contextSHA256: String
    public let authorityDigest: String
    public let validatedRevision: Int64
    public let storeInstanceID: UUID
    public let publicationID: UUID

    fileprivate init(disposition: Disposition, binding: OwnerContextBinding, storeInstanceID: UUID) throws {
        self.disposition = disposition
        recordingID = binding.context.recordingID
        contextSHA256 = try RecordingChunkCodec.digest(binding.context.encoded())
        authorityDigest = binding.context.authorityDigest
        validatedRevision = binding.context.authorityRevision
        self.storeInstanceID = storeInstanceID
        publicationID = UUID()
    }
}

enum OwnerPracticeStoreStage: Sendable {
    case stateTemporarySynced, statePublished, stateDirectorySynced
    case reservationCommitted, reservationStubSynced
    case contextReserved, metadataPublished, contextTemporarySynced, contextPublished, contextDirectorySynced
    case guardReserved, guardDirectorySynced
}

/// Synchronous exclusive owner; intentionally not Sendable. Confine it to one actor/serial owner.
/// It never visits a raw recording directory, resumes capture, or infers historical wearer identity.
public final class OwnerPracticeStore {
    public static let directoryName = "OwnerPractice-v1"
    public static let maximumStateBytes = 16_384
    public static let maximumContexts = 512
    public static let maximumReplayGuards = 1_024
    public let directoryURL: URL
    public let storeInstanceID = UUID()
    public private(set) var snapshot: OwnerPracticeStoreSnapshot
    private let baseURL: URL
    private let baseFD: Int32
    private let directoryFD: Int32
    private let lockFD: Int32
    private let contextsFD: Int32
    private let guardsFD: Int32
    private var expectedStateBytes: Data
    private var storedState: OwnerStoreState
    private var poisoned = false
    // Nil in production. Failures occur at actual disk synchronization/publication boundaries.
    var writeFault: ((OwnerPracticeStoreStage) throws -> Void)?

    /// The installation coordinator must retain first-use state outside this namespace.
    /// A known installation must use openExisting, including when its namespace is missing.
    public init(base: URL, localInstallationEpoch: UUID, device: OwnerPracticeDevice,
                intent: OwnerPracticeStoreIntent) throws {
        guard base.isFileURL, !base.pathComponents.contains("Recordings"),
              !base.pathComponents.contains(Self.directoryName) else {
            throw OwnerPracticeStorageError.invalid("separate owner namespace required")
        }
        let baseDescriptor = try AnnotationFiles.root(base)
        var root: Int32 = -1, lock: Int32 = -1, contexts: Int32 = -1, guards: Int32 = -1
        do {
            let created = intent == .createNew
            if created, mkdirat(baseDescriptor, Self.directoryName, 0o700) != 0 {
                throw AnnotationFiles.error("create new owner namespace")
            }
            root = try AnnotationFiles.directory(Self.directoryName, parent: baseDescriptor, create: false)
            let flags = O_RDWR | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | (created ? O_CREAT | O_EXCL : 0)
            lock = openat(root, ".lock", flags, 0o600)
            guard lock >= 0 else { throw AnnotationFiles.error("open owner lock") }
            try Self.regular(lock, maximumBytes: 0)
            guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw OwnerPracticeStorageError.busy }
            contexts = try AnnotationFiles.directory("contexts", parent: root, create: created)
            guards = try AnnotationFiles.directory("guards", parent: root, create: created)
            try Self.checkEntries(root: root, contexts: contexts, guards: guards, allowsMissingState: created)
            var state: OwnerStoreState
            if created {
                state = OwnerStoreState(schemaVersion: 1, localInstallationEpoch: localInstallationEpoch,
                    device: device, authorityBytes: nil, contexts: Self.membership([]),
                    guards: Self.membership([]), reservation: nil)
                try Self.writeState(Self.encode(state), root: root, fault: nil)
                try AnnotationFiles.sync(baseDescriptor)
            } else {
                guard let existing = try AnnotationFiles.read("state.json", directory: root,
                                                             limit: Self.maximumStateBytes) else {
                    throw OwnerPracticeStorageError.integrity("missing initialized owner state")
                }
                state = try Self.decode(existing)
                guard state.localInstallationEpoch == localInstallationEpoch, state.device == device else {
                    throw OwnerPracticeStorageError.integrity("installation or device role changed")
                }
                try Self.validateMembership(state, contexts: contexts, guards: guards)
                state = try Self.reconcileTemporary(state, root: root, contexts: contexts, guards: guards)
                if let pending = state.reservation {
                    try Self.ensureStub(pending, contexts: contexts, guards: guards)
                    state = try Self.finalizing(state, contexts: contexts, guards: guards)
                    try Self.writeState(Self.encode(state), root: root, fault: nil)
                }
            }
            try Self.validateMembership(state, contexts: contexts, guards: guards)
            try Self.checkOwnership(base: base, baseFD: baseDescriptor, root: root, lock: lock,
                                    contexts: contexts, guards: guards)
            let bytes = try Self.encode(state), initialSnapshot = try Self.snapshot(state)
            guard try AnnotationFiles.read("state.json", directory: root, limit: Self.maximumStateBytes) == bytes else {
                throw OwnerPracticeStorageError.integrity("owner state changed during open")
            }
            try Self.syncFile("state.json", directory: root)
            try AnnotationFiles.sync(root)
            // All throwing work is complete; only deinit owns descriptors after this transfer.
            snapshot = initialSnapshot
            expectedStateBytes = bytes
            storedState = state
            baseURL = base
            directoryURL = base.appendingPathComponent(Self.directoryName, isDirectory: true)
            baseFD = baseDescriptor
            directoryFD = root
            lockFD = lock
            contextsFD = contexts
            guardsFD = guards
        } catch {
            for descriptor in [guards, contexts] where descriptor >= 0 { close(descriptor) }
            if lock >= 0 { flock(lock, LOCK_UN); close(lock) }
            if root >= 0 { close(root) }
            close(baseDescriptor)
            throw error
        }
    }

    deinit {
        close(guardsFD)
        close(contextsFD)
        flock(lockFD, LOCK_UN)
        close(lockFD)
        close(directoryFD)
        close(baseFD)
    }

    /// Explicit enrollment only into a genuinely new, empty authority slot.
    /// A factory value cannot replace persisted consent, replay guards or an established owner.
    public func enroll(_ authority: OwnerPracticeIdentity) throws {
        try checkLive()
        guard snapshot.authority == nil, authority.revision == 1, authority.consentGeneration == 1,
              authority.withdrawalBarrier == 0, authority.isCollectionAllowed,
              try AnnotationFiles.names(contextsFD, limit: Self.maximumContexts).isEmpty,
              try AnnotationFiles.names(guardsFD, limit: Self.maximumReplayGuards).isEmpty else {
            throw OwnerPracticeStorageError.invalid("explicit fresh enrollment required")
        }
        try persist(authority)
    }

    @discardableResult
    public func apply(_ decision: OwnerConsentDecision) throws -> OwnerPracticeIdentity {
        try checkLive()
        let current = try requireAuthority()
        let next = try current.applying(decision)
        if next != current { try persist(next) }
        return next
    }

    @discardableResult
    public func advanceAuthority(expectedRevision: Int64) throws -> OwnerPracticeIdentity {
        try checkLive()
        let next = try requireAuthority().advancingRevision(expectedRevision: expectedRevision)
        try persist(next)
        return next
    }

    public func publish(_ binding: OwnerContextBinding, expectedRevision: Int64) throws -> OwnerContextPublication {
        try checkLive()
        let current = try requireAuthority()
        guard current.revision == expectedRevision else { throw OwnerPracticeError.staleAuthority }
        try binding.validateCurrentAuthority(current)
        guard try !hasGuard(.recording, binding.context.recordingID),
              try !hasGuard(.practice, binding.context.practiceID) else { throw OwnerPracticeStorageError.retired }
        let contextBytes = try binding.context.encoded()
        switch try readContext(binding.context.recordingID) {
        case .valid(let existing):
            guard try existing.encoded() == contextBytes else {
                throw OwnerPracticeStorageError.integrity("conflicting immutable context")
            }
            try synchronizeContext(binding.context.recordingID)
            try checkLive()
            return try OwnerContextPublication(disposition: .alreadyExisting, binding: binding,
                                                storeInstanceID: storeInstanceID)
        case .missing: break
        case .partial, .corrupt, .retired: throw OwnerPracticeStorageError.failedRecordingID
        }
        guard try AnnotationFiles.names(contextsFD, limit: Self.maximumContexts).count < Self.maximumContexts else {
            throw OwnerPracticeStorageError.capacity
        }
        let name = binding.context.recordingID.uuidString
        var contextFD: Int32 = -1
        do {
            // Reservation membership is committed before any context payload can exist.
            try reserve(OwnerStoreReservation(kind: .context, id: binding.context.recordingID))
            contextFD = try AnnotationFiles.directory(name, parent: contextsFD, create: false)
            try writeFault?(.contextReserved)
            try Self.writeImmutable(binding.rawMetadataBytes, name: "metadata.json", temporary: "metadata.pending",
                                    directory: contextFD, temporarySynced: nil, published: nil)
            try writeFault?(.metadataPublished)
            try Self.writeImmutable(contextBytes, name: "context.json", temporary: "context.pending",
                directory: contextFD,
                temporarySynced: { try self.writeFault?(.contextTemporarySynced) },
                published: { try self.writeFault?(.contextPublished) })
            try AnnotationFiles.sync(contextFD)
            try writeFault?(.contextDirectorySynced)
            try checkLive()
            try Self.sameNamedDirectory(contextFD, parent: contextsFD, name: name)
            guard try readContext(binding.context.recordingID) == .valid(binding.context) else {
                throw OwnerPracticeStorageError.integrity("context changed before acknowledgement")
            }
            let receipt = try OwnerContextPublication(disposition: .newlyPublished, binding: binding,
                                                      storeInstanceID: storeInstanceID)
            close(contextFD); contextFD = -1
            return receipt
        } catch {
            if contextFD >= 0 { close(contextFD) }
            poisoned = true
            throw error
        }
    }

    public func inspectContext(recordingID: UUID) throws -> OwnerStoredContext {
        try checkLive()
        return try readContext(recordingID)
    }

    public func hasReplayGuard(scope: OwnerReplayScope, id: UUID) throws -> Bool {
        try checkLive()
        return try hasGuard(scope, id)
    }

    /// Minimal non-content tombstone only. This does not delete any raw/context/telemetry data.
    /// Guard publication precedes authority advancement; failure can leave a conservative guard.
    @discardableResult
    public func retire(scope: OwnerReplayScope, id: UUID, expectedRevision: Int64) throws -> OwnerPracticeIdentity {
        try checkLive()
        let current = try requireAuthority()
        guard current.revision == expectedRevision else { throw OwnerPracticeError.staleAuthority }
        if try hasGuard(scope, id) {
            try Self.syncFile(Self.guardName(scope, id), directory: guardsFD)
            try AnnotationFiles.sync(guardsFD)
            try checkLive()
            return current
        }
        let next = try current.advancingRevision(expectedRevision: expectedRevision)
        guard try AnnotationFiles.names(guardsFD, limit: Self.maximumReplayGuards).count < Self.maximumReplayGuards else {
            throw OwnerPracticeStorageError.capacity
        }
        do {
            try reserve(OwnerStoreReservation(kind: scope == .recording ? .recordingGuard : .practiceGuard, id: id))
            try writeFault?(.guardDirectorySynced)
            try persist(next)
            try checkLive()
            return next
        } catch { poisoned = true; throw error }
    }

    private func requireAuthority() throws -> OwnerPracticeIdentity {
        guard let authority = snapshot.authority else { throw OwnerPracticeError.consentRequired }
        return authority
    }

    private func persist(_ authority: OwnerPracticeIdentity) throws {
        var state = storedState
        state.authorityBytes = try authority.encoded()
        try persistState(state)
    }

    private func persistState(_ state: OwnerStoreState) throws {
        let next = try Self.snapshot(state)
        let bytes = try Self.encode(state)
        guard bytes != expectedStateBytes else { return }
        do {
            try Self.writeState(bytes, root: directoryFD, fault: writeFault)
            try checkOwnership()
            guard try AnnotationFiles.read("state.json", directory: directoryFD,
                                            limit: Self.maximumStateBytes) == bytes else {
                throw OwnerPracticeStorageError.integrity("state changed before commit acknowledgement")
            }
            snapshot = next
            expectedStateBytes = bytes
            storedState = state
        } catch { poisoned = true; throw error }
    }

    private func checkLive() throws {
        guard !poisoned else { throw OwnerPracticeStorageError.poisoned }
        do {
            try checkOwnership()
            try Self.checkEntries(root: directoryFD, contexts: contextsFD, guards: guardsFD,
                                  allowsMissingState: false)
            guard storedState.reservation == nil else { throw OwnerPracticeStorageError.integrity("pending owner reservation") }
            try Self.validateMembership(storedState, contexts: contextsFD, guards: guardsFD)
            guard try AnnotationFiles.read("state.json", directory: directoryFD,
                                            limit: Self.maximumStateBytes) == expectedStateBytes else {
                throw OwnerPracticeStorageError.integrity("authority changed or missing")
            }
        } catch { poisoned = true; throw error }
    }

    private func checkOwnership() throws {
        try Self.checkOwnership(base: baseURL, baseFD: baseFD, root: directoryFD, lock: lockFD,
                                contexts: contextsFD, guards: guardsFD)
    }

    private static func checkOwnership(base: URL, baseFD: Int32, root: Int32, lock: Int32,
                                       contexts: Int32, guards: Int32) throws {
        // Reopen the whole no-follow base path, so ancestor/base replacement cannot detach this owner silently.
        let namedBase = try AnnotationFiles.root(base)
        defer { close(namedBase) }
        try Self.sameDescriptors(baseFD, namedBase, kind: S_IFDIR)
        try Self.sameNamedDirectory(root, parent: baseFD, name: Self.directoryName)
        try Self.sameNamedDirectory(contexts, parent: root, name: "contexts")
        try Self.sameNamedDirectory(guards, parent: root, name: "guards")
        let namedLock = openat(root, ".lock", O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard namedLock >= 0 else { throw AnnotationFiles.error("recheck owner lock") }
        defer { close(namedLock) }
        try Self.regular(lock, maximumBytes: 0)
        try Self.regular(namedLock, maximumBytes: 0)
        try Self.sameDescriptors(lock, namedLock, kind: S_IFREG)
    }

    private func readContext(_ id: UUID) throws -> OwnerStoredContext {
        if try hasGuard(.recording, id) { return .retired }
        var info = stat()
        if fstatat(contextsFD, id.uuidString, &info, AT_SYMLINK_NOFOLLOW) != 0 {
            if errno == ENOENT { return .missing }
            throw AnnotationFiles.error("inspect context directory")
        }
        guard info.st_mode & S_IFMT == S_IFDIR else { return .corrupt }
        let descriptor = try AnnotationFiles.directory(id.uuidString, parent: contextsFD, create: false)
        defer { close(descriptor) }
        do {
            let names = try AnnotationFiles.names(descriptor, limit: 4)
            guard Set(names).isSubset(of: ["metadata.json", "metadata.pending", "context.json", "context.pending"]) else {
                return .corrupt
            }
            for name in names {
                let (file, size) = try AnnotationFiles.openFile(name, directory: descriptor)
                close(file)
                let limit = name.hasPrefix("metadata") ? RecordingLimits.metadataBytes : OwnerRecordingContext.maximumBytes
                guard size <= limit else { return .corrupt }
            }
            guard Set(names) == ["metadata.json", "context.json"] else { return .partial }
            guard let metadata = try AnnotationFiles.read("metadata.json", directory: descriptor, limit: RecordingLimits.metadataBytes),
                  let bytes = try AnnotationFiles.read("context.json", directory: descriptor, limit: OwnerRecordingContext.maximumBytes) else {
                return .partial
            }
            let context = try OwnerRecordingContext.decode(bytes, rawMetadataBytes: metadata)
            guard context.recordingID == id else { return .corrupt }
            try Self.sameNamedDirectory(descriptor, parent: contextsFD, name: id.uuidString)
            return try hasGuard(.practice, context.practiceID) ? .retired : .valid(context)
        } catch { return .corrupt }
    }

    private func hasGuard(_ scope: OwnerReplayScope, _ id: UUID) throws -> Bool {
        // checkLive validates the full bounded guard directory before this lookup.
        var info = stat()
        if fstatat(guardsFD, Self.guardName(scope, id), &info, AT_SYMLINK_NOFOLLOW) != 0 {
            if errno == ENOENT { return false }
            throw AnnotationFiles.error("inspect replay guard")
        }
        guard info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1, info.st_size == 0 else {
            throw OwnerPracticeStorageError.integrity("replay guard type")
        }
        return true
    }

    private static func guardName(_ scope: OwnerReplayScope, _ id: UUID) -> String { scope.rawValue + "-" + id.uuidString }

    private func synchronizeContext(_ id: UUID) throws {
        do {
            let descriptor = try AnnotationFiles.directory(id.uuidString, parent: contextsFD, create: false)
            defer { close(descriptor) }
            try Self.syncFile("metadata.json", directory: descriptor)
            try Self.syncFile("context.json", directory: descriptor)
            try AnnotationFiles.sync(descriptor)
            try Self.sameNamedDirectory(descriptor, parent: contextsFD, name: id.uuidString)
        } catch { poisoned = true; throw error }
    }

    private static func syncFile(_ name: String, directory: Int32) throws {
        let (descriptor, _) = try AnnotationFiles.openFile(name, directory: directory)
        defer { close(descriptor) }
        try AnnotationFiles.sync(descriptor)
    }

    private func reserve(_ reservation: OwnerStoreReservation) throws {
        var pending = storedState
        pending.reservation = reservation
        try persistState(pending)
        try writeFault?(.reservationCommitted)
        try Self.ensureStub(reservation, contexts: contextsFD, guards: guardsFD,
            guardCreated: { try self.writeFault?(.guardReserved) })
        try writeFault?(.reservationStubSynced)
        let finalized = try Self.finalizing(pending, contexts: contextsFD, guards: guardsFD)
        try persistState(finalized)
    }

    private static func membership(_ names: [String]) -> OwnerStoreMembership {
        OwnerStoreMembership(count: names.count,
            sha256: RecordingChunkCodec.digest(Data(("PSLOwnerMembership1\n" + names.sorted().joined(separator: "\n")).utf8)))
    }

    private static func validateMembership(_ state: OwnerStoreState, contexts: Int32, guards: Int32) throws {
        var contextNames = try AnnotationFiles.names(contexts, limit: maximumContexts)
        var guardNames = try AnnotationFiles.names(guards, limit: maximumReplayGuards)
        if let pending = state.reservation {
            if pending.kind == .context {
                contextNames.removeAll { $0 == pending.name }
            } else {
                guardNames.removeAll { $0 == pending.name }
            }
        }
        guard membership(contextNames) == state.contexts, membership(guardNames) == state.guards else {
            throw OwnerPracticeStorageError.integrity("reserved membership changed or missing")
        }
    }

    private static func ensureStub(_ pending: OwnerStoreReservation, contexts: Int32, guards: Int32,
                                    guardCreated: (() throws -> Void)? = nil) throws {
        if pending.kind == .context {
            if mkdirat(contexts, pending.name, 0o700) != 0, errno != EEXIST {
                throw AnnotationFiles.error("reserve context stub")
            }
            let descriptor = try AnnotationFiles.directory(pending.name, parent: contexts, create: false)
            defer { close(descriptor) }
            guard try AnnotationFiles.names(descriptor, limit: 1).isEmpty else {
                throw OwnerPracticeStorageError.integrity("payload in pending context reservation")
            }
            try AnnotationFiles.sync(descriptor)
            try AnnotationFiles.sync(contexts)
        } else {
            let descriptor = openat(guards, pending.name, O_WRONLY | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
            guard descriptor >= 0 else { throw AnnotationFiles.error("reserve guard stub") }
            defer { close(descriptor) }
            try regular(descriptor, maximumBytes: 0)
            try guardCreated?()
            try AnnotationFiles.sync(descriptor)
            try AnnotationFiles.sync(guards)
        }
    }

    private static func finalizing(_ state: OwnerStoreState, contexts: Int32, guards: Int32) throws -> OwnerStoreState {
        try validateMembership(state, contexts: contexts, guards: guards)
        guard let pending = state.reservation else { throw OwnerPracticeStorageError.integrity("missing reservation") }
        let contextNames = try AnnotationFiles.names(contexts, limit: maximumContexts)
        let guardNames = try AnnotationFiles.names(guards, limit: maximumReplayGuards)
        guard (pending.kind == .context ? contextNames : guardNames).contains(pending.name) else {
            throw OwnerPracticeStorageError.integrity("reservation stub disappeared")
        }
        var finalized = state
        finalized.contexts = membership(contextNames)
        finalized.guards = membership(guardNames)
        finalized.reservation = nil
        return finalized
    }

    private static func reconcileTemporary(_ state: OwnerStoreState, root: Int32,
                                            contexts: Int32, guards: Int32) throws -> OwnerStoreState {
        guard let bytes = try AnnotationFiles.read("state.pending", directory: root, limit: maximumStateBytes) else {
            return state
        }
        let candidate = try decode(bytes)
        guard candidate.localInstallationEpoch == state.localInstallationEpoch, candidate.device == state.device else {
            throw OwnerPracticeStorageError.integrity("unrelated owner state temporary")
        }
        var withoutReservation = candidate
        withoutReservation.reservation = nil
        if state.reservation == nil, candidate.reservation != nil, withoutReservation == state {
            // Recover only a single reservation with identical committed authority, never consent or payload.
            try validateMembership(candidate, contexts: contexts, guards: guards)
            guard renameat(root, "state.pending", root, "state.json") == 0 else {
                throw AnnotationFiles.error("preserve failed reservation")
            }
            try AnnotationFiles.sync(root)
            return candidate
        }
        // Other candidates were not acknowledged. Committed authority remains authoritative.
        try removeStateTemporary(root)
        return state
    }

    private static func checkEntries(root: Int32, contexts: Int32, guards: Int32,
                                      allowsMissingState: Bool) throws {
        let names = try AnnotationFiles.names(root, limit: 5)
        guard Set(names).isSubset(of: [".lock", "state.json", "state.pending", "contexts", "guards"]),
              Set([".lock", "contexts", "guards"]).isSubset(of: names),
              allowsMissingState || names.contains("state.json") else {
            throw OwnerPracticeStorageError.integrity("owner namespace entries")
        }
        for name in names where name != "contexts" && name != "guards" {
            let (descriptor, size) = try AnnotationFiles.openFile(name, directory: root)
            close(descriptor)
            guard size <= (name == ".lock" ? 0 : maximumStateBytes) else { throw OwnerPracticeStorageError.capacity }
        }
        for name in try AnnotationFiles.names(contexts, limit: maximumContexts) {
            guard let uuid = UUID(uuidString: name), uuid.uuidString == name else {
                throw OwnerPracticeStorageError.integrity("context name")
            }
            let descriptor = try AnnotationFiles.directory(name, parent: contexts, create: false)
            close(descriptor)
        }
        for name in try AnnotationFiles.names(guards, limit: maximumReplayGuards) {
            let prefix = name.hasPrefix("recording-") ? "recording-" : "practice-"
            let suffix = String(name.dropFirst(prefix.count))
            guard name.hasPrefix(prefix), let uuid = UUID(uuidString: suffix), uuid.uuidString == suffix else {
                throw OwnerPracticeStorageError.integrity("replay guard name")
            }
            let (descriptor, size) = try AnnotationFiles.openFile(name, directory: guards)
            close(descriptor)
            guard size == 0 else { throw OwnerPracticeStorageError.integrity("non-minimal replay guard") }
        }
    }

    private static func regular(_ descriptor: Int32, maximumBytes: Int) throws {
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_nlink == 1, info.st_size >= 0, info.st_size <= maximumBytes else {
            throw OwnerPracticeStorageError.integrity("regular unlinked owner file required")
        }
    }

    private static func sameDescriptors(_ held: Int32, _ named: Int32, kind: mode_t) throws {
        var first = stat(), second = stat()
        guard fstat(held, &first) == 0, fstat(named, &second) == 0,
              first.st_mode & S_IFMT == kind, second.st_mode & S_IFMT == kind,
              first.st_dev == second.st_dev, first.st_ino == second.st_ino else {
            throw OwnerPracticeStorageError.integrity("owner filesystem identity changed")
        }
    }

    private static func sameNamedDirectory(_ held: Int32, parent: Int32, name: String) throws {
        let named = try AnnotationFiles.directory(name, parent: parent, create: false)
        defer { close(named) }
        try sameDescriptors(held, named, kind: S_IFDIR)
    }

    private static func encode(_ state: OwnerStoreState) throws -> Data {
        _ = try snapshot(state)
        return try OwnerCanonical.encode(state, domain: "PSLOwnerStore1", limit: maximumStateBytes)
    }

    private static func decode(_ bytes: Data) throws -> OwnerStoreState {
        let state: OwnerStoreState = try OwnerCanonical.decode(bytes, domain: "PSLOwnerStore1", limit: maximumStateBytes)
        _ = try snapshot(state)
        return state
    }

    private static func snapshot(_ state: OwnerStoreState) throws -> OwnerPracticeStoreSnapshot {
        guard state.schemaVersion == 1 else { throw OwnerPracticeStorageError.invalid("owner state schema") }
        for (entry, maximum) in [(state.contexts, maximumContexts), (state.guards, maximumReplayGuards)] {
            guard (0...maximum).contains(entry.count), entry.sha256.count == 64,
                  entry.sha256.allSatisfy({ "0123456789abcdef".contains($0) }) else {
                throw OwnerPracticeStorageError.integrity("membership bounds")
            }
        }
        if let pending = state.reservation {
            let membership = pending.kind == .context ? state.contexts : state.guards
            guard membership.count < (pending.kind == .context ? maximumContexts : maximumReplayGuards) else {
                throw OwnerPracticeStorageError.capacity
            }
        }
        let authority = try state.authorityBytes.map(OwnerPracticeIdentity.decode)
        guard authority != nil || (state.contexts.count == 0 && state.guards.count == 0 && state.reservation == nil) else {
            throw OwnerPracticeStorageError.integrity("reservation without owner authority")
        }
        if let authority {
            let local = state.device == .phone ? authority.phoneInstallationEpoch : authority.watchInstallationEpoch
            guard local == state.localInstallationEpoch else { throw OwnerPracticeStorageError.invalid("local owner epoch") }
        }
        return OwnerPracticeStoreSnapshot(localInstallationEpoch: state.localInstallationEpoch,
                                          device: state.device, authority: authority)
    }

    private static func removeStateTemporary(_ directory: Int32) throws {
        if try AnnotationFiles.read("state.pending", directory: directory, limit: maximumStateBytes) != nil {
            guard unlinkat(directory, "state.pending", 0) == 0 else { throw AnnotationFiles.error("remove uncommitted owner state") }
            try AnnotationFiles.sync(directory)
        }
    }

    private static func writeState(_ bytes: Data, root: Int32,
                                    fault: ((OwnerPracticeStoreStage) throws -> Void)?) throws {
        try removeStateTemporary(root)
        let descriptor = openat(root, "state.pending", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw AnnotationFiles.error("create owner state temporary") }
        defer { close(descriptor) }
        try AnnotationFiles.write(bytes, fd: descriptor)
        try AnnotationFiles.sync(descriptor)
        try fault?(.stateTemporarySynced)
        guard renameat(root, "state.pending", root, "state.json") == 0 else { throw AnnotationFiles.error("publish owner state") }
        try fault?(.statePublished)
        try AnnotationFiles.sync(root)
        try fault?(.stateDirectorySynced)
    }

    private static func writeImmutable(_ bytes: Data, name: String, temporary: String, directory: Int32,
                                        temporarySynced: (() throws -> Void)?, published: (() throws -> Void)?) throws {
        let descriptor = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw AnnotationFiles.error("create owner context temporary") }
        defer { close(descriptor) }
        try AnnotationFiles.write(bytes, fd: descriptor)
        try AnnotationFiles.sync(descriptor)
        try temporarySynced?()
        guard linkat(directory, temporary, directory, name, 0) == 0 else { throw AnnotationFiles.error("publish immutable owner context") }
        guard unlinkat(directory, temporary, 0) == 0 else { throw AnnotationFiles.error("unlink context temporary") }
        try published?()
        try AnnotationFiles.sync(directory)
    }
}

private struct OwnerStoreState: Codable, Equatable {
    let schemaVersion: Int
    let localInstallationEpoch: UUID
    let device: OwnerPracticeDevice
    var authorityBytes: Data?
    var contexts: OwnerStoreMembership
    var guards: OwnerStoreMembership
    var reservation: OwnerStoreReservation?
}

private struct OwnerStoreMembership: Codable, Equatable {
    let count: Int
    let sha256: String
}

private struct OwnerStoreReservation: Codable, Equatable {
    enum Kind: String, Codable { case context, recordingGuard, practiceGuard }
    let kind: Kind
    let id: UUID
    var name: String {
        switch kind {
        case .context: id.uuidString
        case .recordingGuard: "recording-" + id.uuidString
        case .practiceGuard: "practice-" + id.uuidString
        }
    }
}
