import CryptoKit
import Darwin
import Foundation

public enum OwnerPracticeBundleError: Error, Equatable, Sendable {
    case capacity, integrity, conflict, unavailable, closed
}
public enum OwnerPracticeHeartRateSelection: Equatable, Sendable { case asRecorded, excludedByOwner }
public enum OwnerPracticeHeartRateDisposition: String, Codable, Sendable { case included, absent, excluded }
enum OwnerPracticeBundleStage: Equatable, Sendable { case rawImported, inventoryVerified, stagingSynced }

struct OwnerBundleComponent: Codable, Equatable, Sendable {
    let name: String, schema: String, identity: UUID, required: Bool, bytes: Int, sha256: String
}
struct OwnerBundleManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let ownerID: UUID, phoneInstallationEpoch: UUID, watchInstallationEpoch: UUID, practiceID: UUID
    let revision: Int64, status: OwnerTelemetryStatus, heartRate: OwnerPracticeHeartRateDisposition
    let recordingIDs: [UUID], components: [OwnerBundleComponent]

    func encoded() throws -> Data {
        try OwnerCanonical.encode(self, domain: "PSLOwnerPracticeManifest1", limit: 65_536)
    }
    func validate() throws {
        guard recordingIDs.count <= 20, components.count <= 64 else { throw OwnerPracticeBundleError.capacity }
        guard schemaVersion == 1, revision > 0, status != .open, phoneInstallationEpoch != watchInstallationEpoch,
              !recordingIDs.isEmpty, Set(recordingIDs).count == recordingIDs.count,
              components.map(\.name) == components.map(\.name).sorted(),
              Set(components.map(\.name)).count == components.count else { throw OwnerPracticeBundleError.integrity }
        var expected = ["evidence.json": ("PSLOwnerPracticeEvidence1", practiceID)]
        if heartRate != .excluded { expected["telemetry.json"] = ("PSLOwnerPracticeTelemetry1", practiceID) }
        for id in recordingIDs {
            expected[OwnerPracticeBundle.rawName(id)] = ("PSLBND01", id)
            expected[OwnerPracticeBundle.contextName(id)] = ("PSLOwnerContext1", id)
        }
        guard Set(expected.keys) == Set(components.map(\.name)) else { throw OwnerPracticeBundleError.integrity }
        var total = 0
        for part in components {
            guard let identity = expected[part.name], identity.0 == part.schema, identity.1 == part.identity,
                  part.required, part.bytes > 0, OwnerBundleIO.isDigest(part.sha256) else { throw OwnerPracticeBundleError.integrity }
            let limit: Int
            switch part.schema {
            case "PSLBND01": limit = min(RecordingArchive.maximumBytes, OwnerPracticeBundle.maximumBytes)
            case "PSLOwnerContext1": limit = OwnerRecordingContext.maximumBytes
            case "PSLOwnerPracticeTelemetry1": limit = OwnerPracticeTelemetry.maximumBytes
            default: limit = OwnerBundleEvidence.maximumBytes
            }
            guard part.bytes <= limit, part.bytes <= OwnerPracticeBundle.maximumBytes - total else {
                throw OwnerPracticeBundleError.capacity
            }
            total += part.bytes
        }
    }
}

/// Portable historical projection, explicitly distinguished from an original O6 telemetry file.
/// O6's own canonical decoder validates every remaining authority/context/clock/terminal join.
struct OwnerBundleEvidence: Codable, Sendable {
    static let maximumBytes = 3 * 1024 * 1024
    let schemaVersion: Int, sourceTelemetrySHA256: String
    let heartRate: OwnerPracticeHeartRateDisposition, projection: Data
    func encoded() throws -> Data {
        try OwnerCanonical.encode(self, domain: "PSLOwnerPracticeEvidence1", limit: Self.maximumBytes)
    }
    static func project(_ original: OwnerPracticeTelemetry) throws -> Data {
        guard var envelope = try JSONSerialization.jsonObject(with: original.encoded()) as? [String: Any],
              var body = envelope["body"] as? [String: Any], var terminal = body["finalization"] as? [String: Any],
              let consents = body["consentSegments"] as? [Any], let events = body["events"] as? [[String: Any]] else {
            throw OwnerPracticeBundleError.integrity
        }
        body["samples"] = [Any](); body["provenance"] = [Any](); body["observations"] = [Any]()
        // Retain only clock/interruption evidence, not HR observations, counts or derived summaries.
        let retained = events.filter { ["clockDiscontinuity", "interrupted", "durationLimit"].contains($0["reason"] as? String ?? "") }
        body["events"] = retained
        var counts: [String: Int] = [:]
        for event in retained {
            guard let reason = event["reason"] as? String, let count = event["count"] as? Int else { throw OwnerPracticeBundleError.integrity }
            counts[reason, default: 0] += count
        }
        body["exclusionCounts"] = counts
        terminal["sampleCount"] = 0; terminal["eventCount"] = consents.count + retained.count
        body["finalization"] = terminal
        let options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]
        let payload = try JSONSerialization.data(withJSONObject: body, options: options)
        envelope["body"] = body
        envelope["sha256"] = OwnerBundleIO.digest(Data("PSLOwnerPracticeTelemetry1\n".utf8) + payload)
        let bytes = try JSONSerialization.data(withJSONObject: envelope, options: options)
        _ = try OwnerPracticeTelemetry.decode(bytes)
        return bytes
    }
}

public struct OwnerPracticePublicationScope: Equatable, Sendable {
    public let ownerID: UUID, phoneInstallationEpoch: UUID, watchInstallationEpoch: UUID, practiceID: UUID
    public let revision: Int64, inventorySHA256: String, policyDigest: String, includesHeartRate: Bool
}
public struct OwnerPracticeBundleSnapshot: Sendable {
    public let receipt: OwnerPracticeReceipt, scope: OwnerPracticePublicationScope
    public let status: OwnerTelemetryStatus, heartRate: OwnerPracticeHeartRateDisposition
    public let absenceReasons: [OwnerTelemetryReason], sets: [OwnerTelemetrySet]
    public let telemetry: OwnerPracticeTelemetry?
    public let directoryURL: URL, rawRoot: URL, notesRoot: URL
}

/// Whole-practice envelopes are independent of legacy raw archives and confer no acquisition authority.
public enum OwnerPracticeBundle {
    public static let maximumBytes = 256 * 1024 * 1024
    static let magic = Data("PSLOWN01".utf8)
    static func rawName(_ id: UUID) -> String { id.uuidString.lowercased() + ".pslrecording" }
    static func contextName(_ id: UUID) -> String { id.uuidString.lowercased() + ".context.json" }

    public static func write(telemetry: OwnerPracticeTelemetry, rawRoot: URL, notesRoot: URL,
                             revision: Int64, heartRate: OwnerPracticeHeartRateSelection,
                             destination: URL) throws -> OwnerPracticeReceipt {
        let canonical = try telemetry.encoded(), checked = try OwnerPracticeTelemetry.decode(canonical)
        guard checked.finalization != nil, checked.status != .open, revision > 0,
              !checked.sets.isEmpty, checked.sets.count <= 20 else { throw OwnerPracticeBundleError.integrity }
        let disposition: OwnerPracticeHeartRateDisposition = heartRate == .excludedByOwner ? .excluded
            : (checked.sampleRecords.isEmpty ? .absent : .included)
        let anchor = try OwnerBundleAnchor(destination.deletingLastPathComponent())
        try AnnotationFiles.safeName(destination.lastPathComponent)
        let temporary = try OwnerBundleTemporary(parent: anchor.fd, prefix: ".owner-export-")
        defer { temporary.remove() }
        let temporaryURL = destination.deletingLastPathComponent().appendingPathComponent(temporary.name)
        let notes = try SessionAnnotationsStore(root: notesRoot)
        guard flock(notes.rootFD, LOCK_SH | LOCK_NB) == 0 else { throw OwnerPracticeBundleError.unavailable }
        defer { flock(notes.rootFD, LOCK_UN) }
        // Coordinate with the existing deletion ledger; every source set remains retained on failure.
        let transactions = try checked.sets.sorted { $0.context.recordingID.uuidString < $1.context.recordingID.uuidString }.map {
            try RecordingLocalTransaction(recordingID: $0.context.recordingID, notesRoot: notesRoot)
        }
        defer { withExtendedLifetime(transactions) {} }
        for transaction in transactions { try transaction.requireAvailable() }
        var components: [OwnerBundleComponent] = []
        func add(_ data: Data, name: String, schema: String, identity: UUID) throws {
            try OwnerBundleIO.put(data, name: name, directory: temporary.fd)
            components.append(OwnerBundleComponent(name: name, schema: schema, identity: identity,
                required: true, bytes: data.count, sha256: OwnerBundleIO.digest(data)))
        }
        let evidence = OwnerBundleEvidence(schemaVersion: 1, sourceTelemetrySHA256: OwnerBundleIO.digest(canonical),
            heartRate: disposition, projection: try OwnerBundleEvidence.project(checked))
        try add(evidence.encoded(), name: "evidence.json", schema: "PSLOwnerPracticeEvidence1", identity: checked.header.practiceID)
        if disposition != .excluded {
            try add(canonical, name: "telemetry.json", schema: "PSLOwnerPracticeTelemetry1", identity: checked.header.practiceID)
        }
        for set in checked.sets {
            let context = set.context, id = context.recordingID
            let report = try RecordingStore.inspect(root: rawRoot, recordingID: id)
            try validateSampleInterval(report.chunks, set: set)
            guard report.metadata == context.metadata,
                  try notes.read("labels.json", id: id, limit: SessionAnnotationsStore.labelsLimit) != nil,
                  let timeline = try notes.loadTimeline(recordingID: id) else { throw OwnerPracticeBundleError.integrity }
            let labels = try notes.loadLabels(recordingID: id)
            let raw = try RecordingArchive.write(recordingID: id, rawRoot: rawRoot, timeline: timeline,
                destination: temporaryURL.appendingPathComponent(rawName(id)), labels: labels)
            components.append(OwnerBundleComponent(name: rawName(id), schema: "PSLBND01", identity: id,
                required: true, bytes: raw.byteCount, sha256: raw.bundleSHA256))
            try add(context.encoded(), name: contextName(id), schema: "PSLOwnerContext1", identity: id)
        }
        let header = checked.header
        let manifest = OwnerBundleManifest(schemaVersion: 1, ownerID: header.ownerID,
            phoneInstallationEpoch: header.phoneInstallationEpoch, watchInstallationEpoch: header.watchInstallationEpoch,
            practiceID: header.practiceID, revision: revision, status: checked.status, heartRate: disposition,
            recordingIDs: checked.sets.map { $0.context.recordingID }, components: components.sorted { $0.name < $1.name })
        return try writeEnvelope(manifest, components: temporary.fd, temporary: temporary,
            anchor: anchor, destination: destination)
    }

    /// Append owner reference labels without reconstructing excluded Health evidence.
    /// The result is an envelope only; the existing publication gate still applies.
    public static func writeLabelRevision(from snapshot: OwnerPracticeBundleSnapshot, recordingID: UUID,
                                          appending labels: [RecordingAttemptLabel], revision: Int64,
                                          destination: URL) throws -> OwnerPracticeReceipt {
        guard revision > snapshot.receipt.revision, !labels.isEmpty, labels.count <= 4096,
              snapshot.receipt.recordingIDs.contains(recordingID),
              snapshot.directoryURL.lastPathComponent == OwnerPracticeReceiptStore.name(
                snapshot.receipt.practiceID, snapshot.receipt.revision),
              snapshot.directoryURL.deletingLastPathComponent().lastPathComponent == OwnerPracticeReceiptStore.directoryName,
              !destination.standardizedFileURL.path.hasPrefix(snapshot.directoryURL.standardizedFileURL.path + "/") else {
            throw OwnerPracticeBundleError.integrity
        }
        let store = try OwnerPracticeReceiptStore(base: snapshot.directoryURL.deletingLastPathComponent().deletingLastPathComponent())
        let lease = try store.acquireLease()
        defer { withExtendedLifetime(lease) {} }
        let source = try OwnerBundleAnchor(snapshot.directoryURL)
        let pins = try OwnerBundlePublicationPins(directory: source.fd)
        let checked = try verify(directory: snapshot.directoryURL, fd: source.fd, expected: snapshot.receipt)
        guard checked.scope == snapshot.scope, checked.status == snapshot.status, checked.heartRate == snapshot.heartRate,
              checked.absenceReasons == snapshot.absenceReasons, checked.sets == snapshot.sets,
              checked.rawRoot == snapshot.rawRoot, checked.notesRoot == snapshot.notesRoot,
              try checked.telemetry?.encoded() == snapshot.telemetry?.encoded() else {
            throw OwnerPracticeBundleError.integrity
        }
        try source.check(); try pins.check(directory: source.fd)
        let anchor = try OwnerBundleAnchor(destination.deletingLastPathComponent())
        try AnnotationFiles.safeName(destination.lastPathComponent)
        let temporary = try OwnerBundleTemporary(parent: anchor.fd, prefix: ".owner-export-")
        defer { temporary.remove() }
        let stageURL = destination.deletingLastPathComponent().appendingPathComponent(temporary.name)
        let parts = try AnnotationFiles.directory("components", parent: temporary.fd, create: true)
        defer { close(parts) }
        let (input, size) = try AnnotationFiles.openFile("bundle.pslpractice", directory: source.fd)
        defer { close(input) }
        let parsed = try parse(input, size: size, extract: parts)
        guard parsed.receipt == snapshot.receipt else { throw OwnerPracticeBundleError.integrity }
        // Work exclusively from the freshly checked archive copy, never from mutable source notes.
        let recordings = try AnnotationFiles.directory("Recordings", parent: temporary.fd, create: true)
        defer { close(recordings) }
        for name in ["raw", "notes"] { close(try AnnotationFiles.directory(name, parent: recordings, create: true)) }
        let rawRoot = stageURL.appendingPathComponent("Recordings/raw"), notesRoot = stageURL.appendingPathComponent("Recordings/notes")
        let originalURL = stageURL.appendingPathComponent("components").appendingPathComponent(rawName(recordingID))
        let originalIndex = try rawIndex(originalURL, expected: recordingID)
        _ = try RecordingArchive.importBundle(from: originalURL, rawRoot: rawRoot, notesRoot: notesRoot)
        let notes = try SessionAnnotationsStore(root: notesRoot)
        guard let timeline = try notes.loadTimeline(recordingID: recordingID) else { throw OwnerPracticeBundleError.integrity }
        let history = try notes.loadLabels(recordingID: recordingID) + labels
        try RecordingLabelHistory(schemaVersion: 1, recordingID: recordingID, labels: history).validate(timeline: timeline)
        let revisedURL = stageURL.appendingPathComponent(rawName(recordingID))
        let raw = try RecordingArchive.write(recordingID: recordingID, rawRoot: rawRoot, timeline: timeline,
            destination: revisedURL, labels: history)
        let revisedIndex = try rawIndex(revisedURL, expected: recordingID)
        // Even a codec normalization must not alter retained timeline, metadata or raw bytes.
        let retained = originalIndex.entries.filter { $0.name != "notes/labels.json" }
        let revised = revisedIndex.entries.filter { $0.name != "notes/labels.json" }
        guard originalIndex.status == revisedIndex.status, retained.count == revised.count,
              zip(retained, revised).allSatisfy({ $0.name == $1.name && $0.byteCount == $1.byteCount && $0.sha256 == $1.sha256 }) else {
            throw OwnerPracticeBundleError.integrity
        }
        guard renameat(temporary.fd, rawName(recordingID), parts, rawName(recordingID)) == 0 else {
            throw AnnotationFiles.error("stage owner label revision")
        }
        let original = parsed.manifest
        let components = original.components.map { part in
            part.name == rawName(recordingID)
                ? OwnerBundleComponent(name: part.name, schema: part.schema, identity: part.identity,
                    required: part.required, bytes: raw.byteCount, sha256: raw.bundleSHA256) : part
        }
        let manifest = OwnerBundleManifest(schemaVersion: original.schemaVersion, ownerID: original.ownerID,
            phoneInstallationEpoch: original.phoneInstallationEpoch, watchInstallationEpoch: original.watchInstallationEpoch,
            practiceID: original.practiceID, revision: revision, status: original.status, heartRate: original.heartRate,
            recordingIDs: original.recordingIDs, components: components)
        // Normalize completed scratch to the existing export-stage layout used by deletion.
        let partsNode = try OwnerBundleNode(fd: parts, directory: true)
        let recordingsNode = try OwnerBundleNode(fd: recordings, directory: true)
        for part in manifest.components {
            guard renameatx_np(parts, part.name, temporary.fd, part.name, UInt32(RENAME_EXCL)) == 0 else {
                throw AnnotationFiles.error("normalize owner export component")
            }
        }
        var cleanupBudget = 16_384
        try OwnerBundleIO.removeTree(recordings, remaining: &cleanupBudget)
        guard try OwnerBundleNode.at("Recordings", parent: temporary.fd, directory: true) == recordingsNode,
              try OwnerBundleNode.at("components", parent: temporary.fd, directory: true) == partsNode,
              unlinkat(temporary.fd, "Recordings", AT_REMOVEDIR) == 0,
              unlinkat(temporary.fd, "components", AT_REMOVEDIR) == 0 else {
            throw OwnerPracticeBundleError.integrity
        }
        try AnnotationFiles.sync(temporary.fd)
        // Recheck retained source and its path witnesses before making the envelope visible.
        _ = try verify(directory: snapshot.directoryURL, fd: source.fd, expected: snapshot.receipt)
        try store.check(); try source.check(); try pins.check(directory: source.fd)
        return try writeEnvelope(manifest, components: temporary.fd, temporary: temporary, anchor: anchor, destination: destination)
    }

    private static func writeEnvelope(_ manifest: OwnerBundleManifest, components: Int32,
                                      temporary: OwnerBundleTemporary, anchor: OwnerBundleAnchor,
                                      destination: URL) throws -> OwnerPracticeReceipt {
        try manifest.validate()
        let bytes = try manifest.encoded()
        let size = manifest.components.reduce(44 + bytes.count) { $0 + $1.bytes }
        guard size <= maximumBytes else { throw OwnerPracticeBundleError.capacity }
        let output = try OwnerBundleIO.create("bundle", directory: temporary.fd)
        defer { close(output) }
        var hash = SHA256()
        func emit(_ data: Data) throws { try AnnotationFiles.write(data, fd: output); hash.update(data: data) }
        try emit(magic)
        var length = UInt32(bytes.count).littleEndian
        try withUnsafeBytes(of: &length) { try emit(Data($0)) }
        try emit(bytes)
        for part in manifest.components {
            let (input, count) = try AnnotationFiles.openFile(part.name, directory: components)
            defer { close(input) }
            guard count == part.bytes,
                  try OwnerBundleIO.consume(input, count: count, body: emit) == part.sha256 else { throw OwnerPracticeBundleError.integrity }
        }
        try emit(Data(hash.finalize()))
        try AnnotationFiles.sync(output)
        let receipt = try OwnerPracticeReceipt(manifest: manifest, inventory: OwnerBundleIO.digest(bytes),
            digest: OwnerBundleIO.hex(hash.finalize()), bytes: size)
        try anchor.check()
        guard renameatx_np(temporary.fd, "bundle", anchor.fd, destination.lastPathComponent, UInt32(RENAME_EXCL)) == 0 else {
            throw AnnotationFiles.error("publish owner export")
        }
        try AnnotationFiles.sync(anchor.fd)
        return receipt
    }

    public static func prepareImport(from source: URL, destinationBase: URL) throws -> OwnerPracticePreparedPublication {
        try prepareImport(from: source, destinationBase: destinationBase, failureInjector: nil)
    }
    static func prepareImport(from source: URL, destinationBase: URL,
                              failureInjector: ((OwnerPracticeBundleStage) throws -> Void)?) throws -> OwnerPracticePreparedPublication {
        let store = try OwnerPracticeReceiptStore(base: destinationBase)
        let lease = try store.acquireLease()
        try store.removeAbandonedStages()
        let temporary = try OwnerBundleTemporary(parent: store.namespaceFD, prefix: ".stage-")
        var transferred = false
        defer { if !transferred { temporary.remove() } }
        let stageURL = store.directoryURL.appendingPathComponent(temporary.name)
        let componentFD = try AnnotationFiles.directory("components", parent: temporary.fd, create: true)
        defer { close(componentFD) }
        let sourceAnchor = try OwnerBundleAnchor(source.deletingLastPathComponent())
        let (sourceFD, size) = try AnnotationFiles.openFile(source.lastPathComponent, directory: sourceAnchor.fd)
        defer { close(sourceFD) }
        guard size <= maximumBytes else { throw OwnerPracticeBundleError.capacity }
        let output = try OwnerBundleIO.create("bundle.pslpractice", directory: temporary.fd)
        defer { close(output) }
        let parsed = try parse(sourceFD, size: size, extract: componentFD, mirror: output)
        try sourceAnchor.check(); try AnnotationFiles.sync(output)
        try OwnerBundleIO.put(parsed.bytes, name: "manifest.json", directory: temporary.fd)
        let historical = try evidence(parsed.manifest, directory: componentFD)
        // Create children descriptor-relatively; no realpath or symlink-following directory creation.
        let recordings = try AnnotationFiles.directory("Recordings", parent: temporary.fd, create: true)
        defer { close(recordings) }
        for name in ["raw", "notes", "inbox", "outbox"] {
            close(try AnnotationFiles.directory(name, parent: recordings, create: true))
        }
        let rawRoot = stageURL.appendingPathComponent("Recordings/raw"), notesRoot = stageURL.appendingPathComponent("Recordings/notes")
        for set in historical.projection.sets {
            let id = set.context.recordingID
            let rawURL = stageURL.appendingPathComponent("components").appendingPathComponent(rawName(id))
            _ = try rawIndex(rawURL, expected: id) // Whole-owner evidence requires explicit labels, even when empty.
            _ = try RecordingArchive.importBundle(from: rawURL, rawRoot: rawRoot, notesRoot: notesRoot)
            try failureInjector?(.rawImported)
        }
        if let telemetry = historical.telemetry {
            let local = try OwnerTelemetryStore.create(base: stageURL, telemetry: telemetry)
            local.close()
        }
        try OwnerBundleIO.put(parsed.receipt.encoded(), name: "receipt.json", directory: temporary.fd)
        let pins = try OwnerBundlePublicationPins(directory: temporary.fd)
        _ = try verify(directory: stageURL, fd: temporary.fd, expected: parsed.receipt)
        try pins.check(directory: temporary.fd)
        try failureInjector?(.inventoryVerified)
        try OwnerBundleIO.syncTree(temporary.fd)
        try AnnotationFiles.sync(store.namespaceFD)
        try failureInjector?(.stagingSynced)
        let finalName = OwnerPracticeReceiptStore.name(parsed.receipt.practiceID, parsed.receipt.revision)
        if let existing = try store.receipt(practiceID: parsed.receipt.practiceID, revision: parsed.receipt.revision) {
            guard existing == parsed.receipt else { throw OwnerPracticeBundleError.conflict }
            temporary.remove()
            let pending = try OwnerPracticePreparedPublication(store: store, lease: lease,
                receipt: existing, name: finalName, temporary: nil)
            transferred = true
            return pending
        }
        let pending = try OwnerPracticePreparedPublication(store: store, lease: lease,
            receipt: parsed.receipt, name: finalName, temporary: temporary, pins: pins)
        transferred = true
        return pending
    }

    struct Parsed {
        let manifest: OwnerBundleManifest, bytes: Data, receipt: OwnerPracticeReceipt
    }
    static func parse(_ input: Int32, size: Int, extract: Int32? = nil, mirror: Int32? = nil) throws -> Parsed {
        guard size <= maximumBytes else { throw OwnerPracticeBundleError.capacity }
        guard size >= 44, lseek(input, 0, SEEK_SET) == 0 else { throw OwnerPracticeBundleError.integrity }
        var hash = SHA256(), position = 0
        func take(_ count: Int) throws -> Data {
            guard count >= 0, count <= size - position else { throw OwnerPracticeBundleError.integrity }
            let bytes = try AnnotationFiles.readExactly(input, count: count)
            hash.update(data: bytes); position += count
            if let mirror { try AnnotationFiles.write(bytes, fd: mirror) }
            return bytes
        }
        guard try take(8) == magic else { throw OwnerPracticeBundleError.integrity }
        let length = try take(4).enumerated().reduce(0) { $0 | (Int($1.element) << (8 * $1.offset)) }
        guard length > 0, length <= 65_536 else { throw OwnerPracticeBundleError.integrity }
        let bytes = try take(length)
        let manifest: OwnerBundleManifest = try OwnerCanonical.decode(bytes, domain: "PSLOwnerPracticeManifest1", limit: 65_536)
        try manifest.validate()
        guard manifest.components.reduce(44 + length, { $0 + $1.bytes }) == size else { throw OwnerPracticeBundleError.integrity }
        for part in manifest.components {
            var remaining = part.bytes, partHash = SHA256()
            let output = try extract.map { try OwnerBundleIO.create(part.name, directory: $0) }
            defer { if let output { close(output) } }
            while remaining > 0 {
                let data = try take(min(65_536, remaining))
                partHash.update(data: data); remaining -= data.count
                if let output { try AnnotationFiles.write(data, fd: output) }
            }
            guard OwnerBundleIO.hex(partHash.finalize()) == part.sha256 else { throw OwnerPracticeBundleError.integrity }
            if let output { try AnnotationFiles.sync(output) }
        }
        let footer = Data(hash.finalize())
        guard try take(32) == footer else { throw OwnerPracticeBundleError.integrity }
        try OwnerBundleIO.end(input)
        let receipt = try OwnerPracticeReceipt(manifest: manifest, inventory: OwnerBundleIO.digest(bytes),
            digest: OwnerBundleIO.hex(hash.finalize()), bytes: size)
        return Parsed(manifest: manifest, bytes: bytes, receipt: receipt)
    }

    static func evidence(_ manifest: OwnerBundleManifest, directory: Int32)
        throws -> (projection: OwnerPracticeTelemetry, telemetry: OwnerPracticeTelemetry?) {
        let evidence: OwnerBundleEvidence = try OwnerCanonical.decode(
            OwnerBundleIO.required("evidence.json", directory: directory, limit: OwnerBundleEvidence.maximumBytes),
            domain: "PSLOwnerPracticeEvidence1", limit: OwnerBundleEvidence.maximumBytes)
        guard evidence.schemaVersion == 1, evidence.heartRate == manifest.heartRate,
              OwnerBundleIO.isDigest(evidence.sourceTelemetrySHA256) else { throw OwnerPracticeBundleError.integrity }
        let projection = try OwnerPracticeTelemetry.decode(evidence.projection), header = projection.header
        guard projection.finalization != nil, projection.status == manifest.status,
              header.ownerID == manifest.ownerID, header.phoneInstallationEpoch == manifest.phoneInstallationEpoch,
              header.watchInstallationEpoch == manifest.watchInstallationEpoch, header.practiceID == manifest.practiceID,
              projection.sets.map({ $0.context.recordingID }) == manifest.recordingIDs,
              projection.sampleRecords.isEmpty, projection.observations.isEmpty,
              try OwnerBundleEvidence.project(projection) == evidence.projection else { throw OwnerPracticeBundleError.integrity }
        var telemetry: OwnerPracticeTelemetry?
        if manifest.heartRate != .excluded {
            let bytes = try OwnerBundleIO.required("telemetry.json", directory: directory, limit: OwnerPracticeTelemetry.maximumBytes)
            let original = try OwnerPracticeTelemetry.decode(bytes)
            guard OwnerBundleIO.digest(bytes) == evidence.sourceTelemetrySHA256,
                  try OwnerBundleEvidence.project(original) == evidence.projection,
                  (original.sampleRecords.isEmpty ? OwnerPracticeHeartRateDisposition.absent : .included) == manifest.heartRate else {
                throw OwnerPracticeBundleError.integrity
            }
            telemetry = original
        }
        for set in projection.sets {
            let bytes = try OwnerBundleIO.required(contextName(set.context.recordingID), directory: directory,
                limit: OwnerRecordingContext.maximumBytes)
            guard try bytes == set.context.encoded() else { throw OwnerPracticeBundleError.integrity }
        }
        return (projection, telemetry)
    }

    struct RawEntry: Codable { let name: String, byteCount: Int, sha256: String }
    struct RawIndex: Codable { let schemaVersion: Int, recordingID: UUID, status: String, entries: [RawEntry] }
    static func rawIndex(_ url: URL, expected: UUID) throws -> RawIndex {
        let root = try OwnerBundleAnchor(url.deletingLastPathComponent())
        let (fd, count) = try AnnotationFiles.openFile(url.lastPathComponent, directory: root.fd)
        defer { close(fd) }
        guard count >= 44, count <= RecordingArchive.maximumBytes,
              try AnnotationFiles.readExactly(fd, count: 8) == Data("PSLBND01".utf8) else { throw OwnerPracticeBundleError.integrity }
        let length = try AnnotationFiles.readExactly(fd, count: 4).enumerated().reduce(0) { $0 | (Int($1.element) << (8 * $1.offset)) }
        guard length > 0, length <= 65_536 else { throw OwnerPracticeBundleError.integrity }
        let index: RawIndex = try RecordingJSON.decode(AnnotationFiles.readExactly(fd, count: length), limit: 65_536)
        guard index.schemaVersion == 1, index.recordingID == expected, ["finalized", "interrupted"].contains(index.status),
              index.entries.count <= RecordingLimits.directoryEntries + 2,
              index.entries.map(\.name) == index.entries.map(\.name).sorted(),
              Set(index.entries.map(\.name)).count == index.entries.count,
              ["raw/metadata.json", "raw/manifest.json", "notes/capture-events.json", "notes/labels.json"]
                .allSatisfy({ name in index.entries.contains { $0.name == name } }) else { throw OwnerPracticeBundleError.integrity }
        var total = 44 + length
        for entry in index.entries {
            guard entry.byteCount > 0, entry.byteCount <= count - total, OwnerBundleIO.isDigest(entry.sha256),
                  entry.name.hasPrefix("raw/") || ["notes/capture-events.json", "notes/labels.json"].contains(entry.name) else {
                throw OwnerPracticeBundleError.integrity
            }
            try AnnotationFiles.safeName(String(entry.name.dropFirst(entry.name.hasPrefix("raw/") ? 4 : 6)))
            total += entry.byteCount
        }
        guard total == count else { throw OwnerPracticeBundleError.integrity }
        return index
    }

    private static func validateSampleInterval(_ chunks: [RecordingChunkDescriptor], set: OwnerTelemetrySet) throws {
        // Inspection derives these bounds from retained samples; finalization may occur later.
        guard chunks.allSatisfy({ chunk in
            chunk.firstTimestamp >= set.rawStartSeconds
                && (set.rawStopSeconds.map { chunk.lastTimestamp <= $0 } ?? true)
        }) else { throw OwnerPracticeBundleError.integrity }
    }
    static func verify(directory: URL, fd: Int32, expected: OwnerPracticeReceipt? = nil) throws -> OwnerPracticeBundleSnapshot {
        let receipt = try OwnerPracticeReceipt.decode(OwnerBundleIO.required("receipt.json", directory: fd, limit: 16_384))
        guard expected.map({ $0 == receipt }) ?? true else { throw OwnerPracticeBundleError.integrity }
        let (archive, size) = try AnnotationFiles.openFile("bundle.pslpractice", directory: fd)
        defer { close(archive) }
        let parsed = try parse(archive, size: size)
        guard parsed.receipt == receipt,
              try OwnerBundleIO.required("manifest.json", directory: fd, limit: 65_536) == parsed.bytes else {
            throw OwnerPracticeBundleError.integrity
        }
        var expectedRoot = ["Recordings", "bundle.pslpractice", "components", "manifest.json", "receipt.json"]
        if receipt.heartRate != .excluded {
            expectedRoot += ["." + OwnerTelemetryStore.directoryName, OwnerTelemetryStore.directoryName]
        }
        guard try AnnotationFiles.names(fd, limit: 7) == expectedRoot.sorted() else { throw OwnerPracticeBundleError.integrity }
        let recordings = try AnnotationFiles.directory("Recordings", parent: fd, create: false)
        defer { close(recordings) }
        guard try AnnotationFiles.names(recordings, limit: 4) == ["inbox", "notes", "outbox", "raw"] else {
            throw OwnerPracticeBundleError.integrity
        }
        for name in ["inbox", "outbox"] {
            let child = try AnnotationFiles.directory(name, parent: recordings, create: false)
            defer { close(child) }
            guard try AnnotationFiles.names(child, limit: 0).isEmpty else { throw OwnerPracticeBundleError.integrity }
        }
        let parts = try AnnotationFiles.directory("components", parent: fd, create: false)
        defer { close(parts) }
        guard try AnnotationFiles.names(parts, limit: 64) == parsed.manifest.components.map(\.name) else { throw OwnerPracticeBundleError.integrity }
        for part in parsed.manifest.components {
            try OwnerBundleIO.match(part.name, directory: parts, bytes: part.bytes, digest: part.sha256)
        }
        let historical = try evidence(parsed.manifest, directory: parts)
        let rawRoot = directory.appendingPathComponent("Recordings/raw"), notesRoot = directory.appendingPathComponent("Recordings/notes")
        let raw = try AnnotationFiles.root(rawRoot), notes = try SessionAnnotationsStore(root: notesRoot)
        defer { close(raw) }
        guard flock(notes.rootFD, LOCK_SH | LOCK_NB) == 0 else { throw OwnerPracticeBundleError.unavailable }
        defer { flock(notes.rootFD, LOCK_UN) }
        let ids = receipt.recordingIDs.map(\.uuidString).sorted()
        guard try AnnotationFiles.names(raw, limit: 20) == ids,
              try AnnotationFiles.names(notes.rootFD, limit: 21) == ([".transactions"] + ids).sorted() else {
            throw OwnerPracticeBundleError.integrity
        }
        let ledger = try AnnotationFiles.directory(".transactions", parent: notes.rootFD, create: false)
        defer { close(ledger) }
        guard try AnnotationFiles.names(ledger, limit: 20) == ids.map({ $0 + ".lock" }) else { throw OwnerPracticeBundleError.integrity }
        for id in ids {
            guard try OwnerBundleIO.required(id + ".lock", directory: ledger, limit: 0).isEmpty else {
                throw OwnerPracticeBundleError.integrity
            }
        }
        for set in historical.projection.sets {
            let id = set.context.recordingID
            let index = try rawIndex(directory.appendingPathComponent("components").appendingPathComponent(rawName(id)), expected: id)
            let rawFD = try AnnotationFiles.directory(id.uuidString, parent: raw, create: false)
            let notesFD = try AnnotationFiles.directory(id.uuidString, parent: notes.rootFD, create: false)
            defer { close(rawFD); close(notesFD) }
            guard try AnnotationFiles.names(rawFD, limit: RecordingLimits.directoryEntries) == index.entries
                .filter({ $0.name.hasPrefix("raw/") }).map({ String($0.name.dropFirst(4)) }).sorted(),
                  try AnnotationFiles.names(notesFD, limit: 3) == ["capture-events.json", "labels.json", "receipt.json"] else {
                throw OwnerPracticeBundleError.integrity
            }
            for entry in index.entries {
                let isRaw = entry.name.hasPrefix("raw/")
                try OwnerBundleIO.match(String(entry.name.dropFirst(isRaw ? 4 : 6)), directory: isRaw ? rawFD : notesFD,
                    bytes: entry.byteCount, digest: entry.sha256)
            }
            let report = try RecordingStore.inspect(root: rawRoot, recordingID: id)
            try validateSampleInterval(report.chunks, set: set)
            guard report.metadata == set.context.metadata, report.status.rawValue == index.status,
                  let timeline = try notes.loadTimeline(recordingID: id), let rawReceipt = try notes.loadReceipt(recordingID: id),
                  let part = parsed.manifest.components.first(where: { $0.name == rawName(id) }),
                  rawReceipt.bundleSHA256 == part.sha256, rawReceipt.byteCount == part.bytes else { throw OwnerPracticeBundleError.integrity }
            let coverage = RecordingStream.allCases.compactMap { stream -> RecordingCoverage? in
                let chunks = report.chunks.filter { $0.stream == stream }.sorted { $0.sequence < $1.sequence }
                guard let first = chunks.first, let last = chunks.last else { return nil }
                return RecordingCoverage(stream: stream, sampleCount: chunks.reduce(0) { $0 + $1.sampleCount },
                    firstTimestamp: first.firstTimestamp, lastTimestamp: last.lastTimestamp)
            }
            guard rawReceipt.streams == coverage else { throw OwnerPracticeBundleError.integrity }
            try timeline.validate(metadata: report.metadata)
            _ = try notes.loadLabels(recordingID: id)
        }
        if let original = historical.telemetry {
            let local = try OwnerTelemetryStore.open(base: directory, practiceID: receipt.practiceID, expectedHeader: original.header)
            defer { local.close() }
            guard try local.snapshot.encoded() == original.encoded() else { throw OwnerPracticeBundleError.integrity }
        }
        let source = historical.telemetry ?? historical.projection
        return OwnerPracticeBundleSnapshot(receipt: receipt, scope: receipt.scope, status: receipt.status,
            heartRate: receipt.heartRate, absenceReasons: source.finalization!.absenceReasons, sets: source.sets,
            telemetry: historical.telemetry, directoryURL: directory, rawRoot: rawRoot, notesRoot: notesRoot)
    }
}
