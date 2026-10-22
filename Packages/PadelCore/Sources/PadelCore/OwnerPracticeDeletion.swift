import CryptoKit
import Darwin
import Foundation

public enum OwnerPracticeDeletionStage: Sendable {
    case beforeIntent, intentPersisted, rawRemoved, contextsRemoved, beforeCompletion
}

public struct OwnerPracticeDeletionCommand: Equatable, Sendable {
    private struct Body: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let operationID: UUID, ownerID: UUID, phoneInstallationEpoch: UUID, watchInstallationEpoch: UUID, practiceID: UUID
        let recordingIDs: [UUID], revisionBytes: [Data], requester: String
    }
    private let body: Body
    public var operationID: UUID { body.operationID }
    public var ownerID: UUID { body.ownerID }
    public var phoneInstallationEpoch: UUID { body.phoneInstallationEpoch }
    public var watchInstallationEpoch: UUID { body.watchInstallationEpoch }
    public var practiceID: UUID { body.practiceID }
    public var recordingIDs: [UUID] { body.recordingIDs }
    public var requester: OwnerPracticeDevice { body.requester == "phone" ? .phone : .watch }
    public var revisions: [OwnerPracticeReceipt] { get throws { try body.revisionBytes.map(OwnerPracticeReceipt.decode) } }
    public init(operationID: UUID, authority: OwnerPracticeIdentity, practiceID: UUID,
                recordingIDs: [UUID], revisions: [OwnerPracticeReceipt], requester: OwnerPracticeDevice) throws {
        body = Body(schemaVersion: 1, operationID: operationID, ownerID: authority.ownerID,
            phoneInstallationEpoch: authority.phoneInstallationEpoch, watchInstallationEpoch: authority.watchInstallationEpoch,
            practiceID: practiceID, recordingIDs: recordingIDs.sorted { $0.uuidString < $1.uuidString },
            revisionBytes: try revisions.sorted { $0.revision < $1.revision }.map { try $0.encoded() },
            requester: requester == .phone ? "phone" : "watch")
        try validate()
    }
    private init(_ body: Body) throws { self.body = body; try validate() }
    private func validate() throws {
        guard body.schemaVersion == 1, ["phone", "watch"].contains(body.requester),
              phoneInstallationEpoch != watchInstallationEpoch, recordingIDs.count <= 20,
              Set(recordingIDs).count == recordingIDs.count,
              recordingIDs == recordingIDs.sorted(by: { $0.uuidString < $1.uuidString }),
              body.revisionBytes.count <= 20 else { throw OwnerTelemetryError.integrity }
        let receipts = try revisions
        guard Set(receipts.map(\.revision)).count == receipts.count,
              receipts.map(\.revision) == receipts.map(\.revision).sorted() else { throw OwnerTelemetryError.integrity }
        for receipt in receipts {
            guard receipt.practiceID == practiceID, receipt.scope.ownerID == ownerID,
                  receipt.scope.phoneInstallationEpoch == phoneInstallationEpoch,
                  receipt.scope.watchInstallationEpoch == watchInstallationEpoch,
                  Set(receipt.recordingIDs).isSubset(of: Set(recordingIDs)) else { throw OwnerTelemetryError.integrity }
        }
        _ = try encoded()
        // Every admitted command must also fit the same bounded wire when acknowledged.
        _ = try OwnerPracticeDeletionAcknowledgment(command: self, device: .phone)
    }
    public func encoded() throws -> Data {
        try OwnerCanonical.encode(body, domain: "PSLOwnerPracticeDelete1", limit: 32_768)
    }
    public static func decode(_ bytes: Data) throws -> Self {
        try Self(OwnerCanonical.decode(bytes, domain: "PSLOwnerPracticeDelete1", limit: 32_768))
    }
    public func requireOwner(_ authority: OwnerPracticeIdentity) throws {
        guard authority.ownerID == ownerID, authority.phoneInstallationEpoch == phoneInstallationEpoch,
              authority.watchInstallationEpoch == watchInstallationEpoch else { throw OwnerTelemetryError.integrity }
    }
}

public struct OwnerPracticeDeletionAcknowledgment: Equatable, Sendable {
    public let command: OwnerPracticeDeletionCommand, device: OwnerPracticeDevice
    private struct Body: Codable { let schemaVersion: Int, commandBytes: Data, device: String }
    public init(command: OwnerPracticeDeletionCommand, device: OwnerPracticeDevice) throws {
        self.command = command; self.device = device
        _ = try encoded()
    }
    public func encoded() throws -> Data {
        try OwnerCanonical.encode(Body(schemaVersion: 1, commandBytes: command.encoded(),
            device: device == .phone ? "phone" : "watch"), domain: "PSLOwnerPracticeDeleteAck1", limit: 32_768)
    }
    public static func decode(_ bytes: Data) throws -> Self {
        let body: Body = try OwnerCanonical.decode(bytes, domain: "PSLOwnerPracticeDeleteAck1", limit: 32_768)
        guard body.schemaVersion == 1, ["phone", "watch"].contains(body.device) else { throw OwnerTelemetryError.integrity }
        return try Self(command: .decode(body.commandBytes), device: body.device == "phone" ? .phone : .watch)
    }
}

public struct OwnerPracticeDeletionStatus: Equatable, Sendable {
    public let command: OwnerPracticeDeletionCommand
    public let localComplete: Bool, peerComplete: Bool
}

/// Runs synchronously on the caller's existing channel owner. The durable intent
/// contains identities and owned relative paths only, never practice content.
public enum OwnerPracticeDeletion {
    public static let directoryName = "OwnerPracticeDeletionOperations-v1"
    public static func makeCommand(base: URL, authority: OwnerPracticeIdentity, practiceID: UUID,
                                   requester: OwnerPracticeDevice) throws -> OwnerPracticeDeletionCommand {
        if let retained = try status(base: base, practiceID: practiceID) {
            try retained.command.requireOwner(authority); return retained.command
        }
        let revisions = try OwnerPracticeTransferInventory.snapshots(base: base).filter { $0.receipt.practiceID == practiceID }.map(\.receipt)
        let known = Set(revisions.flatMap(\.recordingIDs))
        let candidate = try OwnerPracticeDeletionCommand(operationID: UUID(), authority: authority, practiceID: practiceID,
            recordingIDs: Array(known), revisions: revisions, requester: requester)
        let discovered = try inventory(command: candidate, base: base, receipts: OwnerPracticeReceiptStore(base: base), requireExact: false)
        return try .init(operationID: candidate.operationID, authority: authority, practiceID: practiceID,
            recordingIDs: Array(discovered.recordingIDs), revisions: revisions, requester: requester)
    }
    private struct Target: Codable { let path: [String], node: OwnerBundleNode; let directory: Bool, preserve: Bool }
    private struct Intent: Codable {
        let schemaVersion: Int, commandBytes: Data, device: OwnerPracticeDevice
        let targets: [Target], telemetry: Bool
        var localComplete: Bool, peerComplete: Bool
        var command: OwnerPracticeDeletionCommand { get throws { try .decode(commandBytes) } }
    }
    private final class Ledger {
        let anchor: OwnerBundleAnchor, fd: Int32, node: OwnerBundleNode
        private struct Identity: Codable { let schemaVersion: Int, base: OwnerBundleNode, directory: OwnerBundleNode }
        init(_ base: URL) throws {
            anchor = try OwnerBundleAnchor(base)
            let created = mkdirat(anchor.fd, directoryName, 0o700) == 0
            guard created || errno == EEXIST else { throw AnnotationFiles.error("create deletion ledger") }
            fd = try AnnotationFiles.directory(directoryName, parent: anchor.fd, create: false)
            do {
                node = try OwnerBundleNode(fd: fd, directory: true)
                if created {
                    let identity = Identity(schemaVersion: 1, base: try OwnerBundleNode(fd: anchor.fd, directory: true), directory: node)
                    try OwnerBundleIO.put(OwnerCanonical.encode(identity, domain: "PSLOwnerDeletionLedger1", limit: 4096), name: "identity.json", directory: fd)
                    try AnnotationFiles.sync(fd); try AnnotationFiles.sync(anchor.fd)
                }
                let identity: Identity = try OwnerCanonical.decode(OwnerBundleIO.required("identity.json", directory: fd, limit: 4096), domain: "PSLOwnerDeletionLedger1", limit: 4096)
                guard identity.schemaVersion == 1, identity.directory == node,
                      try identity.base == OwnerBundleNode(fd: anchor.fd, directory: true) else { throw OwnerTelemetryError.integrity }
            } catch { close(fd); throw error }
        }
        func check() throws {
            try anchor.check()
            guard try OwnerBundleNode.at(directoryName, parent: anchor.fd, directory: true) == node else { throw OwnerTelemetryError.integrity }
        }
        func load(_ id: UUID) throws -> Intent? {
            try check()
            guard let bytes = try AnnotationFiles.read(id.uuidString.lowercased() + ".json", directory: fd, limit: 32_768) else { return nil }
            let value: Intent = try OwnerCanonical.decode(bytes, domain: "PSLOwnerDeletionIntent1", limit: 32_768)
            guard value.schemaVersion == 1, try value.command.practiceID == id else { throw OwnerTelemetryError.integrity }
            return value
        }
        func save(_ value: Intent) throws {
            try check()
            try AnnotationFiles.publish(OwnerCanonical.encode(value, domain: "PSLOwnerDeletionIntent1", limit: 32_768),
                name: value.command.practiceID.uuidString.lowercased() + ".json", directory: fd, replace: true)
            try check()
        }
        deinit { close(fd) }
    }
    public static func status(base: URL, practiceID: UUID) throws -> OwnerPracticeDeletionStatus? {
        let root = try AnnotationFiles.root(base); defer { close(root) }
        guard try OwnerBundleNode.at(directoryName, parent: root, directory: true) != nil,
              let value = try Ledger(base).load(practiceID) else { return nil }
        return try .init(command: value.command, localComplete: value.localComplete, peerComplete: value.peerComplete)
    }
    public static func pending(base: URL) throws -> [OwnerPracticeDeletionStatus] {
        let root = try AnnotationFiles.root(base); defer { close(root) }
        guard try OwnerBundleNode.at(directoryName, parent: root, directory: true) != nil else { return [] }
        let ledger = try Ledger(base)
        return try AnnotationFiles.names(ledger.fd, limit: 513).filter { $0 != "identity.json" }.map { name in
            guard name.hasSuffix(".json"), let id = UUID(uuidString: String(name.dropLast(5))),
                  name == id.uuidString.lowercased() + ".json", let value = try ledger.load(id) else { throw OwnerTelemetryError.integrity }
            return try .init(command: value.command, localComplete: value.localComplete, peerComplete: value.peerComplete)
        }
    }
    public static func acknowledge(_ acknowledgment: OwnerPracticeDeletionAcknowledgment, base: URL, device: OwnerPracticeDevice) throws {
        let ledger = try Ledger(base)
        guard flock(ledger.fd, LOCK_EX | LOCK_NB) == 0 else { throw OwnerTelemetryError.unavailable }
        defer { flock(ledger.fd, LOCK_UN) }
        guard var intent = try ledger.load(acknowledgment.command.practiceID),
              try intent.command == acknowledgment.command, intent.device == device,
              acknowledgment.device != device, intent.localComplete else { throw OwnerTelemetryError.integrity }
        intent.peerComplete = true; try ledger.save(intent)
    }
    public static func perform(command: OwnerPracticeDeletionCommand, base: URL, device: OwnerPracticeDevice,
        channel: PracticeSetupChannel, fault: ((OwnerPracticeDeletionStage) throws -> Void)? = nil,
        onLeaseContention: (() -> Void)? = nil) throws -> OwnerPracticeDeletionAcknowledgment {
        guard let authority = try channel.readSnapshot().authority else { throw OwnerTelemetryError.unavailable }
        try command.requireOwner(authority)
        if let existing = try status(base: base, practiceID: command.practiceID) {
            guard existing.command == command else { throw OwnerTelemetryError.integrity }
            if existing.localComplete { return try .init(command: command, device: device) }
        }
        try fault?(.beforeIntent)
        let paths = try RecordingPaths(base: base)
        let captures = try command.recordingIDs.map { try RecordingCaptureLease(recordingID: $0, rawRoot: paths.rawRoot) }
        defer { withExtendedLifetime(captures) {} }
        let notes = try AnnotationFiles.root(paths.notesRoot); defer { close(notes) }
        guard flock(notes, LOCK_EX | LOCK_NB) == 0 else { throw OwnerTelemetryError.unavailable }
        defer { flock(notes, LOCK_UN) }
        let receipts = try OwnerPracticeReceiptStore(base: base), publication = try receipts.acquirePublicationLease()
        defer { withExtendedLifetime(publication) {} }
        let transactions = try command.recordingIDs.map {
            try RecordingLocalTransaction(recordingID: $0, notesRoot: paths.notesRoot, onContention: onLeaseContention)
        }
        defer { withExtendedLifetime(transactions) {} }
        let ledger = try Ledger(base)
        guard flock(ledger.fd, LOCK_EX | LOCK_NB) == 0 else { throw OwnerTelemetryError.unavailable }
        defer { flock(ledger.fd, LOCK_UN) }
        var intent: Intent
        var proof: OwnerPracticeDeletionProof?
        if let retained = try ledger.load(command.practiceID) {
            guard try retained.command == command, retained.device == device else { throw OwnerTelemetryError.integrity }
            intent = retained
            if intent.telemetry { proof = try OwnerPracticeDeletionProof.resume(base: base, practiceID: command.practiceID, operationID: command.operationID) }
        } else {
            let inventory = try inventory(command: command, base: base, receipts: receipts)
            if let telemetry = inventory.telemetry {
                proof = try OwnerPracticeDeletionProof.resume(base: base, practiceID: command.practiceID, operationID: command.operationID)
                if proof == nil { proof = try OwnerPracticeDeletionProof.prepare(base: base, header: telemetry.header, operationID: command.operationID) }
            }
            intent = try Intent(schemaVersion: 1, commandBytes: command.encoded(), device: device, targets: inventory.targets,
                telemetry: inventory.telemetry != nil, localComplete: false, peerComplete: false)
            try ledger.save(intent)
        }
        defer { proof?.cancel() }
        guard !intent.telemetry || proof != nil else { throw OwnerTelemetryError.integrity }
        try fault?(.intentPersisted)
        // The existing retained channel is the only authority-store owner.
        if device == .watch, try !channel.hasReplayGuard(scope: .practice, id: command.practiceID) {
            let current = try channel.readSnapshot().authority
            guard let current else { throw OwnerTelemetryError.unavailable }
            _ = try channel.sequence(.retirePractice(from: current, practiceID: command.practiceID, mutationID: command.operationID))
        }
        for transaction in transactions {
            try RecordingLocalCopies.removeForPracticeDeletion(recordingID: transaction.recordingID, paths: paths, transaction: transaction, device: device)
        }
        try fault?(.rawRemoved)
        for target in intent.targets where target.preserve { try remove(target, base: base) }
        try fault?(.contextsRemoved)
        for target in intent.targets where !target.preserve { try remove(target, base: base) }
        if let proof {
            let root = try AnnotationFiles.root(base); defer { close(root) }
            let namespace = try AnnotationFiles.directory(OwnerTelemetryStore.directoryName, parent: root, create: false); defer { close(namespace) }
            let directory = try AnnotationFiles.directory(command.practiceID.uuidString.lowercased(), parent: namespace, create: false); defer { close(directory) }
            let names = try AnnotationFiles.names(directory, limit: 4)
            guard Set(names).isSubset(of: ["header.json", "telemetry.json", "manifest.json", ".lock"]) else { throw OwnerTelemetryError.integrity }
            for name in ["header.json", "telemetry.json", "manifest.json", ".lock"] where names.contains(name) {
                guard unlinkat(directory, name, 0) == 0 else { throw AnnotationFiles.error("remove practice telemetry") }
            }
            try AnnotationFiles.sync(directory); try proof.complete()
        }
        try fault?(.beforeCompletion)
        _ = try channel.readSnapshot()
        intent.localComplete = true; try ledger.save(intent)
        return try .init(command: command, device: device)
    }
    private static func inventory(command: OwnerPracticeDeletionCommand, base: URL, receipts: OwnerPracticeReceiptStore, requireExact: Bool = true)
        throws -> (targets: [Target], telemetry: OwnerPracticeTelemetry?, recordingIDs: Set<UUID>) {
        let root = try AnnotationFiles.root(base); defer { close(root) }
        var targets: [Target] = [], knownIDs: Set<UUID> = [], telemetry: OwnerPracticeTelemetry?
        func add(_ path: [String], directory: Bool, preserve: Bool = false) throws {
            var parent = dup(root); guard parent >= 0 else { throw AnnotationFiles.error("open inventory") }
            defer { close(parent) }
            for part in path.dropLast() {
                guard try OwnerBundleNode.at(part, parent: parent, directory: true) != nil else { return }
                let next = try AnnotationFiles.directory(part, parent: parent, create: false); close(parent); parent = next
            }
            guard let name = path.last, let node = try OwnerBundleNode.at(name, parent: parent, directory: directory) else { return }
            targets.append(Target(path: path, node: node, directory: directory, preserve: preserve))
        }
        if try OwnerBundleNode.at(OwnerTelemetryStore.directoryName, parent: root, directory: true) != nil {
            let ns = try AnnotationFiles.directory(OwnerTelemetryStore.directoryName, parent: root, create: false); defer { close(ns) }
            if try OwnerBundleNode.at(command.practiceID.uuidString.lowercased(), parent: ns, directory: true) != nil {
                let dir = try AnnotationFiles.directory(command.practiceID.uuidString.lowercased(), parent: ns, create: false); defer { close(dir) }
                let value = try OwnerPracticeTelemetry.decode(OwnerBundleIO.required("telemetry.json", directory: dir, limit: OwnerPracticeTelemetry.maximumBytes))
                guard value.header.practiceID == command.practiceID, value.header.ownerID == command.ownerID,
                      value.header.phoneInstallationEpoch == command.phoneInstallationEpoch,
                      value.header.watchInstallationEpoch == command.watchInstallationEpoch, value.finalization != nil else { throw OwnerTelemetryError.integrity }
                knownIDs.formUnion(value.sets.map { $0.context.recordingID }); telemetry = value
            }
        }
        let expected = try command.revisions
        for snapshot in try OwnerPracticeTransferInventory.snapshots(base: base) where snapshot.receipt.practiceID == command.practiceID {
            guard expected.contains(snapshot.receipt) else { throw OwnerTelemetryError.integrity }
            knownIDs.formUnion(snapshot.receipt.recordingIDs)
            try add([OwnerPracticeReceiptStore.directoryName, OwnerPracticeReceiptStore.name(command.practiceID, snapshot.receipt.revision)], directory: true)
        }
        for name in try AnnotationFiles.names(receipts.namespaceFD, limit: 258) where name.hasPrefix(".stage-") {
            guard let id = UUID(uuidString: String(name.dropFirst(7))), name == ".stage-" + id.uuidString else { throw OwnerTelemetryError.integrity }
            let stage = try AnnotationFiles.directory(name, parent: receipts.namespaceFD, create: false); defer { close(stage) }
            // A stage without checked scope cannot be attributed or silently ignored.
            let manifest: OwnerBundleManifest = try OwnerCanonical.decode(
                OwnerBundleIO.required("manifest.json", directory: stage, limit: 65_536), domain: "PSLOwnerPracticeManifest1", limit: 65_536)
            try manifest.validate()
            if manifest.practiceID == command.practiceID {
                guard manifest.ownerID == command.ownerID, manifest.phoneInstallationEpoch == command.phoneInstallationEpoch,
                      manifest.watchInstallationEpoch == command.watchInstallationEpoch else { throw OwnerTelemetryError.integrity }
                knownIDs.formUnion(manifest.recordingIDs)
                try add([OwnerPracticeReceiptStore.directoryName, name], directory: true)
            }
        }
        let ownerRoot = try AnnotationFiles.directory(OwnerPracticeStore.directoryName, parent: root, create: false)
        defer { close(ownerRoot) }
        let contexts = try AnnotationFiles.directory("contexts", parent: ownerRoot, create: false)
        defer { close(contexts) }
        for name in try AnnotationFiles.names(contexts, limit: OwnerPracticeStore.maximumContexts) {
            guard let id = UUID(uuidString: name), id.uuidString == name else { throw OwnerTelemetryError.integrity }
            let dir = try AnnotationFiles.directory(name, parent: contexts, create: false); defer { close(dir) }
            guard let bytes = try AnnotationFiles.read("context.json", directory: dir, limit: OwnerRecordingContext.maximumBytes) else {
                // Empty reservations are content-free. A partial payload has unknown scope.
                guard try AnnotationFiles.names(dir, limit: 4).isEmpty else { throw OwnerTelemetryError.integrity }
                continue
            }
            let context = try OwnerRecordingContext.decode(bytes,
                rawMetadataBytes: OwnerBundleIO.required("metadata.json", directory: dir, limit: RecordingLimits.metadataBytes))
            guard context.recordingID == id else { throw OwnerTelemetryError.integrity }
            if context.practiceID == command.practiceID {
                guard context.ownerID == command.ownerID,
                      context.phoneInstallationEpoch == command.phoneInstallationEpoch,
                      context.watchInstallationEpoch == command.watchInstallationEpoch else { throw OwnerTelemetryError.integrity }
                knownIDs.insert(id)
                try add([OwnerPracticeStore.directoryName, "contexts", name], directory: true, preserve: true)
            } else if command.recordingIDs.contains(id) { throw OwnerTelemetryError.integrity }
        }
        guard !requireExact || knownIDs == Set(command.recordingIDs) else { throw OwnerTelemetryError.integrity }
        for area in ["inbox", "outbox"] {
            let paths = try RecordingPaths(base: base), url = area == "inbox" ? paths.inboxRoot : paths.outboxRoot
            let fd = try AnnotationFiles.root(url); defer { close(fd) }
            for name in try AnnotationFiles.names(fd, limit: 4096) {
                if area == "outbox", name.hasPrefix(".owner-readback-") || name.hasPrefix(".owner-export-") {
                    let manifest = try exportStage(name, parent: fd, url: url.appendingPathComponent(name))
                    if manifest.practiceID == command.practiceID {
                        guard manifest.ownerID == command.ownerID, manifest.phoneInstallationEpoch == command.phoneInstallationEpoch,
                              manifest.watchInstallationEpoch == command.watchInstallationEpoch,
                              Set(manifest.recordingIDs).isSubset(of: knownIDs) else { throw OwnerTelemetryError.integrity }
                        try add(["Recordings", area, name], directory: true)
                    }
                } else if name.hasSuffix(".pslpractice") || name.hasSuffix(".practice-staging") {
                    let (input, count) = try AnnotationFiles.openFile(name, directory: fd); defer { close(input) }
                    guard count <= OwnerPracticeBundle.maximumBytes else { throw OwnerTelemetryError.capacity }
                    let digest = try OwnerBundleIO.consume(input, count: count)
                    if expected.contains(where: { $0.byteCount == count && $0.bundleSHA256 == digest }) {
                        try add(["Recordings", area, name], directory: false)
                    }
                } else if name.hasSuffix(".practice-ack.json") || name.hasSuffix(".practice.json") {
                    struct AcknowledgmentRecord: Codable { let receiptBytes: Data, delivered: Bool }
                    struct TransferRecord: Codable {
                        let receiptBytes: Data, fileName: String
                        let state: RecordingTransferState, detail: String?
                    }
                    let bytes = try OwnerBundleIO.required(name, directory: fd, limit: 32_768)
                    let receipt: OwnerPracticeReceipt
                    if name.hasSuffix(".practice-ack.json") {
                        let record: AcknowledgmentRecord = try RecordingJSON.decode(bytes, limit: 32_768)
                        receipt = try OwnerPracticeReceipt.decode(record.receiptBytes)
                        let key = OwnerBundleIO.digest(Data("\(receipt.practiceID.uuidString):\(receipt.revision):\(receipt.bundleSHA256)".utf8))
                        guard name == key + ".practice-ack.json" else { throw OwnerTelemetryError.integrity }
                    } else {
                        let record: TransferRecord = try RecordingJSON.decode(bytes, limit: 32_768)
                        receipt = try OwnerPracticeReceipt.decode(record.receiptBytes)
                        let key = OwnerBundleIO.digest(Data("\(receipt.practiceID.uuidString):\(receipt.revision):\(receipt.bundleSHA256)".utf8))
                        guard name == key + ".practice.json", record.fileName == key + ".pslpractice",
                              record.state != .received, (record.detail?.utf8.count ?? 0) <= 512 else { throw OwnerTelemetryError.integrity }
                    }
                    if receipt.practiceID == command.practiceID {
                        guard expected.contains(receipt) else { throw OwnerTelemetryError.integrity }
                        try add(["Recordings", area, name], directory: false)
                    }
                }
            }
        }
        return (targets, telemetry, knownIDs)
    }
    /// Actual export scratch layouts have no standalone manifest. Attribute only complete,
    /// bounded checked content; interrupted or unknown payloads keep deletion incomplete.
    private static func exportStage(_ name: String, parent: Int32, url: URL) throws -> OwnerBundleManifest {
        let readback = name.hasPrefix(".owner-readback-"), prefix = readback ? ".owner-readback-" : ".owner-export-"
        guard let id = UUID(uuidString: String(name.dropFirst(prefix.count))), name == prefix + id.uuidString else {
            throw OwnerTelemetryError.integrity
        }
        let fd = try AnnotationFiles.directory(name, parent: parent, create: false); defer { close(fd) }
        let node = try OwnerBundleNode(fd: fd, directory: true), names = try AnnotationFiles.names(fd, limit: 65)
        var bundled: OwnerBundleManifest?
        if names.contains("bundle") {
            let (input, count) = try AnnotationFiles.openFile("bundle", directory: fd); defer { close(input) }
            bundled = try OwnerPracticeBundle.parse(input, size: count).manifest
        }
        if readback {
            guard names == ["bundle"], let bundled,
                  try OwnerBundleNode.at(name, parent: parent, directory: true) == node else { throw OwnerTelemetryError.integrity }
            return bundled
        }
        let evidence: OwnerBundleEvidence = try OwnerCanonical.decode(
            OwnerBundleIO.required("evidence.json", directory: fd, limit: OwnerBundleEvidence.maximumBytes),
            domain: "PSLOwnerPracticeEvidence1", limit: OwnerBundleEvidence.maximumBytes)
        let projection = try OwnerPracticeTelemetry.decode(evidence.projection), header = projection.header
        var expected = ["evidence.json": ("PSLOwnerPracticeEvidence1", header.practiceID)]
        if evidence.heartRate != .excluded { expected["telemetry.json"] = ("PSLOwnerPracticeTelemetry1", header.practiceID) }
        for set in projection.sets {
            expected[OwnerPracticeBundle.rawName(set.context.recordingID)] = ("PSLBND01", set.context.recordingID)
            expected[OwnerPracticeBundle.contextName(set.context.recordingID)] = ("PSLOwnerContext1", set.context.recordingID)
        }
        guard names.filter({ $0 != "bundle" }) == expected.keys.sorted() else { throw OwnerTelemetryError.integrity }
        var total = 0, components: [OwnerBundleComponent] = []
        for name in expected.keys.sorted() {
            let (input, count) = try AnnotationFiles.openFile(name, directory: fd); defer { close(input) }
            guard count > 0, count <= OwnerPracticeBundle.maximumBytes - total else { throw OwnerTelemetryError.capacity }
            total += count
            let identity = expected[name]!
            components.append(.init(name: name, schema: identity.0, identity: identity.1, required: true,
                bytes: count, sha256: try OwnerBundleIO.consume(input, count: count)))
        }
        let manifest = OwnerBundleManifest(schemaVersion: 1, ownerID: header.ownerID,
            phoneInstallationEpoch: header.phoneInstallationEpoch, watchInstallationEpoch: header.watchInstallationEpoch,
            practiceID: header.practiceID, revision: bundled?.revision ?? 1, status: projection.status,
            heartRate: evidence.heartRate, recordingIDs: projection.sets.map { $0.context.recordingID }, components: components)
        try manifest.validate()
        guard bundled == nil || bundled == manifest else { throw OwnerTelemetryError.integrity }
        _ = try OwnerPracticeBundle.evidence(manifest, directory: fd)
        for set in projection.sets { try checkStagedRaw(set.context, directory: fd, url: url) }
        guard try OwnerBundleNode.at(name, parent: parent, directory: true) == node else { throw OwnerTelemetryError.integrity }
        return manifest
    }
    private static func checkStagedRaw(_ context: OwnerRecordingContext, directory: Int32, url: URL) throws {
        let name = OwnerPracticeBundle.rawName(context.recordingID)
        let index = try OwnerPracticeBundle.rawIndex(url.appendingPathComponent(name), expected: context.recordingID)
        guard index.entries.first(where: { $0.name == "raw/metadata.json" })?.sha256 == context.rawMetadataDigest else {
            throw OwnerTelemetryError.integrity
        }
        let (input, count) = try AnnotationFiles.openFile(name, directory: directory); defer { close(input) }
        var hash = SHA256(), consumed = 0
        func take(_ amount: Int) throws -> Data {
            guard amount >= 0, amount <= count - consumed else { throw OwnerTelemetryError.integrity }
            let data = try AnnotationFiles.readExactly(input, count: amount); consumed += amount; hash.update(data: data); return data
        }
        guard try take(8) == Data("PSLBND01".utf8) else { throw OwnerTelemetryError.integrity }
        let size = try take(4).enumerated().reduce(0) { $0 | (Int($1.element) << (8 * $1.offset)) }
        guard size > 0, size <= 65_536 else { throw OwnerTelemetryError.capacity }
        let header: OwnerPracticeBundle.RawIndex = try RecordingJSON.decode(take(size), limit: 65_536)
        guard try RecordingJSON.encode(header, limit: 65_536) == RecordingJSON.encode(index, limit: 65_536) else {
            throw OwnerTelemetryError.integrity
        }
        for entry in index.entries {
            var remaining = entry.byteCount, part = SHA256()
            while remaining > 0 { let bytes = try take(min(remaining, 65_536)); part.update(data: bytes); remaining -= bytes.count }
            guard OwnerBundleIO.hex(part.finalize()) == entry.sha256 else { throw OwnerTelemetryError.integrity }
        }
        let footer = Data(hash.finalize())
        guard try take(32) == footer, consumed == count else { throw OwnerTelemetryError.integrity }
        try OwnerBundleIO.end(input)
    }
    private static func remove(_ target: Target, base: URL) throws {
        var parent = try AnnotationFiles.root(base); defer { close(parent) }
        for part in target.path.dropLast() {
            guard try OwnerBundleNode.at(part, parent: parent, directory: true) != nil else { throw OwnerTelemetryError.integrity }
            let next = try AnnotationFiles.directory(part, parent: parent, create: false); close(parent); parent = next
        }
        guard let name = target.path.last else { throw OwnerTelemetryError.integrity }
        guard let node = try OwnerBundleNode.at(name, parent: parent, directory: target.directory) else {
            guard !target.preserve else { throw OwnerTelemetryError.integrity }; return
        }
        guard node == target.node else { throw OwnerTelemetryError.integrity }
        if target.directory {
            let fd = try AnnotationFiles.directory(name, parent: parent, create: false); defer { close(fd) }
            var budget = 16_384; try OwnerBundleIO.removeTree(fd, remaining: &budget); try AnnotationFiles.sync(fd)
        }
        if !target.preserve, unlinkat(parent, name, target.directory ? AT_REMOVEDIR : 0) != 0 { throw AnnotationFiles.error("remove practice copy") }
        try AnnotationFiles.sync(parent)
    }
}

/// Content-free evidence of completed telemetry removal. Preparation retains the real
/// telemetry lease; callers must remove payloads before completing this proof.
public final class OwnerPracticeDeletionProof {
    public static let directoryName = "OwnerPracticeDeletion-v1"
    private static let marker = ".OwnerPracticeDeletion-v1"
    private static let domain = "PSLOwnerPracticeDeletion1"
    private struct Node: Codable, Equatable { let device: Int64, inode: UInt64 }
    private struct Root: Codable { let schemaVersion: Int; let directory: Node }
    private struct ProofRoot: Codable { let schemaVersion: Int; let base: Node, directory: Node }
    private struct Witness: Codable {
        let schemaVersion: Int, practiceID: UUID, headerDigest: String
        let directory: Node, lock: Node, lockDigest: String
    }
    private struct Record: Codable, Equatable {
        let schemaVersion: Int
        let operationID: UUID, practiceID: UUID, ownerID: UUID
        let phoneInstallationEpoch: UUID, watchInstallationEpoch: UUID
        let base: Node, telemetryNamespace: Node, directory: Node, witness: Node
        let rootDigest: String, witnessDigest: String, headerDigest: String
        var completed: Bool
    }
    private let base: URL
    private var store: OwnerTelemetryStore?
    private var context: Context?
    private var record: Record
    private var proofBytes: Data
    private var proofNode: Node
    private var resumedLease: Int32?
    private var active = true

    private init(base: URL, store: OwnerTelemetryStore?, context: Context,
                 record: Record, bytes: Data, node: Node) {
        self.base = base; self.store = store; self.context = context
        self.record = record; proofBytes = bytes; proofNode = node
    }

    public static func prepare(base: URL, header: OwnerTelemetryHeader,
                               operationID: UUID) throws -> OwnerPracticeDeletionProof {
        let store = try OwnerTelemetryStore.open(base: base, practiceID: header.practiceID, expectedHeader: header)
        var transferred = false
        defer { if !transferred { store.close() } }
        let c = try Context(base: base, practiceID: header.practiceID, createProofRoot: true)
        let headerDigest = OwnerTelemetryHeader.digest(try header.encoded())
        guard c.witness.headerDigest == headerDigest else { throw OwnerTelemetryError.integrity }
        let record = Record(schemaVersion: 1, operationID: operationID, practiceID: header.practiceID,
            ownerID: header.ownerID, phoneInstallationEpoch: header.phoneInstallationEpoch,
            watchInstallationEpoch: header.watchInstallationEpoch, base: c.baseNode,
            telemetryNamespace: c.namespaceNode, directory: c.directoryNode, witness: c.witnessFile.0,
            rootDigest: OwnerTelemetryHeader.digest(c.rootFile.1),
            witnessDigest: OwnerTelemetryHeader.digest(c.witnessFile.1), headerDigest: headerDigest, completed: false)
        let bytes = try OwnerCanonical.encode(record, domain: domain, limit: 4096)
        try c.validate(base: base)
        try exclusive(bytes, name: c.proofName, parent: c.proofFD)
        let saved = try file(c.proofName, parent: c.proofFD)
        guard saved.1 == bytes else { throw OwnerTelemetryError.integrity }
        let result = OwnerPracticeDeletionProof(base: base, store: store, context: c,
            record: record, bytes: bytes, node: saved.0)
        transferred = true
        return result
    }

    public func complete() throws {
        guard active, let c = context else { throw OwnerTelemetryError.closed }
        try c.validate(base: base)
        let current = try Self.file(c.proofName, parent: c.proofFD)
        guard current.0 == proofNode, current.1 == proofBytes,
              try Self.empty(c.directoryFD) else { throw OwnerTelemetryError.integrity }
        try AnnotationFiles.sync(c.directoryFD)
        var completed = record; completed.completed = true
        let bytes = try OwnerCanonical.encode(completed, domain: Self.domain, limit: 4096)
        try AnnotationFiles.publish(bytes, name: c.proofName, directory: c.proofFD, replace: true)
        let saved = try Self.file(c.proofName, parent: c.proofFD)
        guard saved.1 == bytes else { throw OwnerTelemetryError.integrity }
        proofNode = saved.0; proofBytes = bytes; record = completed
        try c.validate(base: base)
        guard try Self.empty(c.directoryFD) else { throw OwnerTelemetryError.integrity }
    }

    /// Cancellation releases ownership but leaves pending evidence fail-closed.
    public func cancel() {
        store?.close(); store = nil; context = nil; active = false
        if let resumedLease { flock(resumedLease, LOCK_UN); Darwin.close(resumedLease); self.resumedLease = nil }
    }
    deinit { cancel() }

    static func resume(base: URL, practiceID: UUID, operationID: UUID) throws -> OwnerPracticeDeletionProof? {
        let baseFD = try AnnotationFiles.root(base); defer { Darwin.close(baseFD) }
        guard try exists(marker, parent: baseFD) else { return nil }
        let c = try Context(base: base, practiceID: practiceID, createProofRoot: false)
        guard try exists(c.proofName, parent: c.proofFD) else { return nil }
        _ = try isCompleted(base: base, practiceID: practiceID)
        let saved = try file(c.proofName, parent: c.proofFD)
        let record: Record = try OwnerCanonical.decode(saved.1, domain: domain, limit: 4096)
        guard record.operationID == operationID else { throw OwnerTelemetryError.integrity }
        let value = OwnerPracticeDeletionProof(base: base, store: nil, context: c, record: record, bytes: saved.1, node: saved.0)
        if try exists(".lock", parent: c.directoryFD) {
            let lock = try file(".lock", parent: c.directoryFD)
            guard lock.0 == c.witness.lock, OwnerTelemetryHeader.digest(lock.1) == c.witness.lockDigest else {
                throw OwnerTelemetryError.integrity
            }
            let fd = openat(c.directoryFD, ".lock", O_RDWR | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard fd >= 0 else { throw AnnotationFiles.error("resume deletion lease") }
            value.resumedLease = fd
            guard try node(fd) == lock.0, flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw OwnerTelemetryError.unavailable }
        } else {
            guard try empty(c.directoryFD) else { throw OwnerTelemetryError.integrity }
        }
        return value
    }

    public static func isCompleted(base: URL, practiceID: UUID) throws -> Bool {
        let baseFD = try AnnotationFiles.root(base)
        defer { Darwin.close(baseFD) }
        guard try exists(marker, parent: baseFD) else {
            guard try !exists(directoryName, parent: baseFD) else { throw OwnerTelemetryError.integrity }
            return false
        }
        let c = try Context(base: base, practiceID: practiceID, createProofRoot: false)
        guard try exists(c.proofName, parent: c.proofFD) else { return false }
        let saved = try file(c.proofName, parent: c.proofFD)
        let record: Record = try OwnerCanonical.decode(saved.1, domain: domain, limit: 4096)
        guard record.schemaVersion == 1, record.practiceID == practiceID,
              record.base == c.baseNode, record.telemetryNamespace == c.namespaceNode,
              record.directory == c.directoryNode, record.witness == c.witnessFile.0,
              record.witnessDigest == OwnerTelemetryHeader.digest(c.witnessFile.1),
              record.rootDigest == OwnerTelemetryHeader.digest(c.rootFile.1),
              record.headerDigest == c.witness.headerDigest else { throw OwnerTelemetryError.integrity }
        try c.validate(base: base)
        if record.completed, try !empty(c.directoryFD) { throw OwnerTelemetryError.integrity }
        return record.completed
    }

    private final class Context {
        let baseFD: Int32, namespaceFD: Int32, directoryFD: Int32, proofFD: Int32
        let baseNode: Node, namespaceNode: Node, directoryNode: Node, proofNamespaceNode: Node
        let rootFile: (Node, Data), witnessFile: (Node, Data), proofRootFile: (Node, Data)
        let witness: Witness
        let name: String, proofName: String
        init(base: URL, practiceID: UUID, createProofRoot: Bool) throws {
            var owned: [Int32] = []; var transferred = false
            defer { if !transferred { owned.reversed().forEach { Darwin.close($0) } } }
            baseFD = try AnnotationFiles.root(base); owned.append(baseFD)
            baseNode = try node(baseFD, directory: true)
            namespaceFD = try AnnotationFiles.directory(OwnerTelemetryStore.directoryName, parent: baseFD, create: false)
            owned.append(namespaceFD); namespaceNode = try node(namespaceFD, directory: true)
            rootFile = try file(".OwnerTelemetry-v1", parent: baseFD)
            let root: Root = try OwnerCanonical.decode(rootFile.1, domain: "PSLOwnerTelemetryRoot1", limit: 4096)
            guard root.schemaVersion == 1, root.directory == namespaceNode else { throw OwnerTelemetryError.integrity }
            name = practiceID.uuidString.lowercased(); proofName = name + ".json"
            directoryFD = try AnnotationFiles.directory(name, parent: namespaceFD, create: false)
            owned.append(directoryFD); directoryNode = try node(directoryFD, directory: true)
            witnessFile = try file(".used-" + name, parent: namespaceFD)
            witness = try OwnerCanonical.decode(witnessFile.1, domain: "PSLOwnerTelemetryWitness1", limit: 4096)
            guard witness.schemaVersion == 1, witness.practiceID == practiceID,
                  witness.directory == directoryNode else { throw OwnerTelemetryError.integrity }
            if try !exists(marker, parent: baseFD) {
                guard createProofRoot, try !exists(directoryName, parent: baseFD) else { throw OwnerTelemetryError.integrity }
                try exclusive(Data("pending\n".utf8), name: marker, parent: baseFD)
                guard mkdirat(baseFD, directoryName, 0o700) == 0 else { throw AnnotationFiles.error("create deletion namespace") }
                let fd = try AnnotationFiles.directory(directoryName, parent: baseFD, create: false)
                defer { Darwin.close(fd) }
                let root = ProofRoot(schemaVersion: 1, base: baseNode, directory: try node(fd, directory: true))
                try AnnotationFiles.publish(OwnerCanonical.encode(root, domain: "PSLOwnerDeletionRoot1", limit: 4096),
                    name: marker, directory: baseFD, replace: true)
            }
            proofFD = try AnnotationFiles.directory(directoryName, parent: baseFD, create: false)
            owned.append(proofFD); proofNamespaceNode = try node(proofFD, directory: true)
            proofRootFile = try file(marker, parent: baseFD)
            let proofRoot: ProofRoot = try OwnerCanonical.decode(proofRootFile.1, domain: "PSLOwnerDeletionRoot1", limit: 4096)
            guard proofRoot.schemaVersion == 1, proofRoot.base == baseNode,
                  proofRoot.directory == proofNamespaceNode else { throw OwnerTelemetryError.integrity }
            transferred = true
        }
        func validate(base: URL) throws {
            let fresh = try AnnotationFiles.root(base); defer { Darwin.close(fresh) }
            guard try node(fresh, directory: true) == baseNode,
                  try named(OwnerTelemetryStore.directoryName, parent: baseFD) == namespaceNode,
                  try named(name, parent: namespaceFD) == directoryNode,
                  try named(directoryName, parent: baseFD) == proofNamespaceNode else { throw OwnerTelemetryError.integrity }
            for (name, parent, expected) in [(".OwnerTelemetry-v1", baseFD, rootFile),
                (".used-" + name, namespaceFD, witnessFile), (marker, baseFD, proofRootFile)] {
                let actual = try file(name, parent: parent)
                guard actual.0 == expected.0, actual.1 == expected.1 else { throw OwnerTelemetryError.integrity }
            }
        }
        deinit { [proofFD, directoryFD, namespaceFD, baseFD].forEach { Darwin.close($0) } }
    }

    private static func node(_ fd: Int32, directory: Bool = false) throws -> Node {
        var s = stat()
        guard fstat(fd, &s) == 0, s.st_uid == geteuid(),
              s.st_mode & S_IFMT == (directory ? S_IFDIR : S_IFREG), directory || s.st_nlink == 1 else {
            throw OwnerTelemetryError.integrity
        }
        return Node(device: Int64(s.st_dev), inode: UInt64(s.st_ino))
    }
    private static func named(_ name: String, parent: Int32) throws -> Node {
        let fd = try AnnotationFiles.directory(name, parent: parent, create: false)
        defer { Darwin.close(fd) }; return try node(fd, directory: true)
    }
    private static func exists(_ name: String, parent: Int32) throws -> Bool {
        var s = stat()
        if fstatat(parent, name, &s, AT_SYMLINK_NOFOLLOW) == 0 { return true }
        guard errno == ENOENT else { throw AnnotationFiles.error("inspect deletion path") }; return false
    }
    private static func file(_ name: String, parent: Int32) throws -> (Node, Data) {
        let (fd, count) = try AnnotationFiles.openFile(name, directory: parent)
        defer { Darwin.close(fd) }
        guard count <= 4096 else { throw OwnerTelemetryError.capacity }
        let identity = try node(fd), bytes = try AnnotationFiles.readExactly(fd, count: count)
        var extra: UInt8 = 0
        let (check, _) = try AnnotationFiles.openFile(name, directory: parent)
        defer { Darwin.close(check) }
        guard Darwin.read(fd, &extra, 1) == 0, try node(fd) == identity,
              try node(check) == identity else { throw OwnerTelemetryError.integrity }
        return (identity, bytes)
    }
    private static func exclusive(_ bytes: Data, name: String, parent: Int32) throws {
        let fd = openat(parent, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw AnnotationFiles.error("reserve deletion proof") }
        defer { Darwin.close(fd) }
        try AnnotationFiles.write(bytes, fd: fd); try AnnotationFiles.sync(fd); try AnnotationFiles.sync(parent)
    }
    private static func empty(_ fd: Int32) throws -> Bool {
        let copy = openat(fd, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard copy >= 0 else { throw AnnotationFiles.error("inspect reserved directory") }
        guard let stream = fdopendir(copy) else { Darwin.close(copy); throw AnnotationFiles.error("read reserved directory") }
        defer { closedir(stream) }
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                guard errno == 0 else { throw AnnotationFiles.error("enumerate reserved directory") }; return true
            }
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
            }
            if name != ".", name != ".." { return false }
        }
    }
}
