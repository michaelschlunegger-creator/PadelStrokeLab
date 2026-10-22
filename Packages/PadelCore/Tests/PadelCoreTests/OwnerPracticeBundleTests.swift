import CryptoKit
import Darwin
import Foundation
import Testing
@testable import PadelCore

// O8a tests-first surface. These are synthetic, isolated, real-store fixtures; no
// capture admission, default container, HealthKit or current-authority gate exists here.
// Proposed wire: PSLOWN01, UInt32 LE canonical manifest length, manifest envelope,
// ordered component bytes, SHA256(prefix). Manifest domain PSLOwnerPracticeManifest1;
// body has schemaVersion, owner/phone/watch/practice identity, revision, status,
// heartRate, recordingIDs and components [{name,schema,identity,required,bytes,sha256}].
// Components use PSLBND01 / PSLOwnerContext1 / PSLOwnerPracticeTelemetry1 and a
// bounded PSLOwnerPracticeEvidence1 projection. Unknown components are rejected.
// Exclusion omits telemetry containing HR, including nested native/derived HR data.
// Header/context/mapping/finalization evidence remains available in the projection.
// All raw/notes stay inside each immutable practice revision, never the live roots.

enum O8Injected: Error { case stop }

struct O8Fixture {
    let base: URL, paths: RecordingPaths, ownerStore: OwnerPracticeStore
    let telemetry: OwnerPracticeTelemetry
    let contexts: [OwnerRecordingContext], timelines: [CaptureTimeline]
    let labels: [[RecordingAttemptLabel]]

    init(_ base: URL, count: Int = 2, heartRate: Bool = true,
         samples: Bool = true, interrupted: Bool = false, finalized: Bool = true,
         withLabels: Bool = true) throws {
        self.base = base
        paths = try RecordingPaths(base: base)
        let authority = try o6Authority(heartRate: heartRate)
        ownerStore = try OwnerPracticeStore(base: base, localInstallationEpoch: o6Watch,
            device: .watch, intent: .createNew)
        try ownerStore.enroll(authority)
        var value = try o6Telemetry(heartRate: heartRate)
        let notes = try SessionAnnotationsStore(root: paths.notesRoot)
        var contexts: [OwnerRecordingContext] = [], timelines: [CaptureTimeline] = []
        var labels: [[RecordingAttemptLabel]] = []
        for index in 0..<count {
            let number = 10 + index, start = Double(10 + index * 40), raw = Double(100 + index * 100)
            let stroke: RecordingDrill = index.isMultiple(of: 2) ? .forehandGroundstroke : .backhandGroundstroke
            let metadata = try RecordingMetadata(recordingID: o6ID(number),
                clock: RecordingClock(domainID: o6ID(100_000 + number), monotonicAnchorSeconds: raw,
                    wallAnchorUnixSeconds: o6Wall + start), appBuild: "7",
                protocolVersion: RecordingDrill.protocolVersion, deviceModel: "synthetic-watch",
                operatingSystem: "watchOS 27", handedness: .right, playingArm: .right, watchWrist: .right,
                watchOrientation: "Crown left", playingArmConfirmed: true, drill: stroke.rawValue,
                capabilityReport: "synthetic supported", streams: try RecordingStream.allCases.map {
                    try RecordingStreamConfiguration(stream: $0, supported: true,
                        requestedRateHz: nil, knownSensorLimit: nil)
                })
            let draft = try PracticeSetupDraft(originInstallationEpoch: o6Phone,
                preparationID: o6ID(200_000 + number), revision: 1,
                preferences: PracticeSetupPreferences(currentRacketArm: .right, usualHand: .right,
                    intendedDrill: stroke))
            let binding = try OwnerRecordingContext.bind(rawMetadataBytes: RecordingChunkCodec.encodeMetadata(metadata),
                authority: authority, practiceID: o6Practice, acceptedSetup: draft,
                generations: PracticeSetupGenerations(runtimeGeneration: o6Runtime,
                    preparationGeneration: o6ID(300_000 + number)))
            _ = try ownerStore.publish(binding, expectedRevision: authority.revision)
            let context = binding.context
            try value.admitSet(context: context, mapping: o6Mapping(context, header: value.header),
                consentSegmentID: o6Consent, rawStartSeconds: raw, at: o6Instant(start))
            let unfinished = interrupted && index == count - 1
            if !unfinished {
                try value.stopSet(recordingID: context.recordingID, rawStopSeconds: raw + 2,
                    at: o6Instant(start + 2))
            }
            let store = try RecordingStore.create(root: paths.rawRoot, metadata: metadata)
            for stream in RecordingStream.allCases {
                try store.append(RecordingChunk(recordingID: metadata.recordingID,
                    clockDomainID: metadata.clock.domainID, stream: stream, sequence: 0,
                    samples: [0.5, 1.0].map { offset in
                        RecordingSample(timestamp: raw + offset,
                            values: (0..<stream.componentCount).map { Double($0 + index) / 8 })
                    }))
            }
            if !unfinished { try store.finalize(stopRequestTimestamp: raw + 2, reason: .userStopped) }
            let timeline = CaptureTimeline(recordingID: metadata.recordingID, clockDomainID: metadata.clock.domainID,
                events: [try RecordingCaptureEvent(kind: .start, timestamp: raw, id: o6ID(400_000 + number)),
                         try RecordingCaptureEvent(kind: unfinished ? .interruption : .stopped,
                            timestamp: raw + 2, id: o6ID(500_000 + number))])
            let categories: [ContactCategory] = withLabels ? [.cleanContact, .mishit, .uncertain] : []
            let history = try categories.enumerated().map { ordinal, category in
                try RecordingAttemptLabel(id: o6ID(600_000 + number * 10 + ordinal),
                    recordingID: metadata.recordingID, attemptID: o6ID(700_000 + number * 10 + ordinal),
                    ordinal: ordinal + 1, category: category, createdAt: Date(timeIntervalSince1970: o6Wall + start + 3),
                    confidence: .medium, evidence: .orderedNotes, clockDomainID: metadata.clock.domainID,
                    startTimestamp: raw + 0.5, endTimestamp: raw + 1)
            }
            try notes.saveTimeline(timeline)
            try notes.saveLabels(history, recordingID: metadata.recordingID)
            if heartRate && samples {
                _ = try o6Append([o6Sample(900_000 + number, end: start + 1, bpm: Double(111 + index))], to: &value)
            }
            contexts.append(context); timelines.append(timeline); labels.append(history)
        }
        if finalized {
            try value.finalize(status: interrupted ? .interrupted : .ended, at: o6Instant(Double(count * 40 + 5)),
                absenceReasons: interrupted ? [.interrupted] : (heartRate && samples ? [] : [.noAccessibleHeartRateData]))
            _ = try ownerStore.retire(scope: .practice, id: o6Practice, expectedRevision: authority.revision)
        }
        let telemetryStore = try OwnerTelemetryStore.create(base: base, telemetry: value)
        telemetry = telemetryStore.snapshot
        telemetryStore.close()
        self.contexts = contexts; self.timelines = timelines; self.labels = labels
    }

    func write(_ name: String = "practice.pslpractice", revision: Int64 = 1,
               heartRate: OwnerPracticeHeartRateSelection = .asRecorded) throws -> (URL, OwnerPracticeReceipt) {
        let url = base.appendingPathComponent(name)
        let receipt = try OwnerPracticeBundle.write(telemetry: telemetry, rawRoot: paths.rawRoot,
            notesRoot: paths.notesRoot, revision: revision, heartRate: heartRate, destination: url)
        return (url, receipt)
    }
}

func o8Directory(_ base: URL, _ name: String) throws -> URL {
    let url = base.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    return url
}

func o8Publish(_ source: URL, to base: URL) throws -> OwnerPracticeReceipt {
    let prepared = try OwnerPracticeBundle.prepareImport(from: source, destinationBase: base)
    // O8b invokes only this bounded internal operation while its authority fence is held.
    // No external/reentrant callback, hashing, copying, awaiting or sync occurs in it.
    try prepared.renameForPublication()
    return try prepared.confirmPublication()
}

// Independent, small-fixture wire decoder/mutator. Never used for a large/raw payload.
func o8Wire(_ data: Data) throws -> (manifest: Data, components: [String: Data]) {
    #expect(data.prefix(8) == Data("PSLOWN01".utf8))
    let length = data[8..<12].enumerated().reduce(0) { $0 | (Int($1.element) << (8 * $1.offset)) }
    let manifest = data.subdata(in: 12..<(12 + length))
    let envelope = try o6JSON(manifest), body = try #require(envelope["body"] as? [String: Any])
    let entries = try #require(body["components"] as? [[String: Any]])
    var offset = 12 + length, parts: [String: Data] = [:]
    for entry in entries {
        let name = try #require(entry["name"] as? String), size = try #require(entry["bytes"] as? Int)
        let part = data.subdata(in: offset..<(offset + size))
        #expect(entry["sha256"] as? String == o6SHA(part))
        #expect(parts[name] == nil)
        parts[name] = part; offset += size
    }
    #expect(offset == data.count - 32)
    #expect(data.suffix(32) == Data(SHA256.hash(data: data.prefix(offset))))
    #expect(try o6SHA(Data("PSLOwnerPracticeManifest1\n".utf8) + o6CanonicalJSON(body)) == envelope["sha256"] as? String)
    return (manifest, parts)
}

func o8Rewrite(_ original: Data, mutate: (inout [String: Any], inout [String: Data]) throws -> Void) throws -> Data {
    let wire = try o8Wire(original)
    var envelope = try o6JSON(wire.manifest), body = try #require(envelope["body"] as? [String: Any])
    var parts = wire.components
    try mutate(&body, &parts)
    let entries = try #require(body["components"] as? [[String: Any]])
    envelope["body"] = body
    envelope["sha256"] = try o6SHA(Data("PSLOwnerPracticeManifest1\n".utf8) + o6CanonicalJSON(body))
    let header = try o6CanonicalJSON(envelope)
    var length = UInt32(header.count).littleEndian
    var result = Data("PSLOWN01".utf8)
    withUnsafeBytes(of: &length) { result.append(contentsOf: $0) }
    result.append(header)
    for entry in entries { result.append(parts[try #require(entry["name"] as? String)] ?? Data()) }
    result.append(contentsOf: SHA256.hash(data: result))
    return result
}

func o8ChangeComponent(_ body: inout [String: Any], _ parts: inout [String: Data], schema: String,
                       transform: (Data) throws -> Data) throws {
    var entries = try #require(body["components"] as? [[String: Any]])
    let index = try #require(entries.firstIndex { $0["schema"] as? String == schema })
    let name = try #require(entries[index]["name"] as? String)
    let bytes = try transform(#require(parts[name]))
    parts[name] = bytes; entries[index]["bytes"] = bytes.count; entries[index]["sha256"] = o6SHA(bytes)
    body["components"] = entries
}

func o8HasHR(_ data: Data, depth: Int = 0) -> Bool {
    guard depth < 12 else { return false }
    if String(decoding: data, as: UTF8.self).contains("com.synthetic.hr") { return true }
    guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return false }
    func visit(_ value: Any) -> Bool {
        if let dictionary = value as? [String: Any] {
            if dictionary.keys.contains(where: { ["bpm", "meanBPM", "medianBPM", "sourceBundleIdentifier"].contains($0) }) { return true }
            return dictionary.values.contains(where: visit)
        }
        if let array = value as? [Any] { return array.contains(where: visit) }
        if let string = value as? String, let nested = Data(base64Encoded: string) { return o8HasHR(nested, depth: depth + 1) }
        return false
    }
    return visit(object)
}

// Remove the nested label inventory while recomputing BOTH raw and owner envelopes.
// Legacy raw import allows this; a complete owner-practice import must reject it.
func o8RawWithoutLabels(_ original: Data) throws -> Data {
    let length = original[8..<12].enumerated().reduce(0) { $0 | (Int($1.element) << (8 * $1.offset)) }
    var header = try o6JSON(original.subdata(in: 12..<(12 + length)))
    let entries = try #require(header["entries"] as? [[String: Any]])
    var offset = 12 + length, payload = Data(), kept: [[String: Any]] = []
    var removed = false
    for entry in entries {
        let count = try #require(entry["byteCount"] as? Int)
        if entry["name"] as? String == "notes/labels.json" { removed = true }
        else { kept.append(entry); payload.append(original.subdata(in: offset..<(offset + count))) }
        offset += count
    }
    #expect(removed && offset == original.count - 32)
    header["entries"] = kept
    let bytes = try o6CanonicalJSON(header)
    var newLength = UInt32(bytes.count).littleEndian, result = Data(original.prefix(8))
    withUnsafeBytes(of: &newLength) { result.append(contentsOf: $0) }
    result.append(bytes); result.append(payload)
    result.append(contentsOf: SHA256.hash(data: result))
    return result
}

// Reconstruct only synthetic temporary raw bytes, keeping their exact frozen metadata.
// The existing raw codec/store accepts these histories; O8 must additionally join O6's
// known sample interval. A later raw finalization timestamp is deliberately independent.
func o8ReplaceRawSamples(_ source: O8Fixture, index: Int = 0,
                        offsets: [Double], finalizationOffset: Double?) throws -> URL {
    let context = source.contexts[index], metadata = context.metadata
    let directory = source.paths.rawRoot.appendingPathComponent(context.recordingID.uuidString)
    try FileManager.default.removeItem(at: directory)
    let raw = try RecordingStore.create(root: source.paths.rawRoot, metadata: metadata)
    for stream in RecordingStream.allCases {
        try raw.append(RecordingChunk(recordingID: context.recordingID, clockDomainID: metadata.clock.domainID,
            stream: stream, sequence: 0, samples: offsets.map { offset in
                RecordingSample(timestamp: metadata.clock.monotonicAnchorSeconds + offset,
                    values: Array(repeating: 1, count: stream.componentCount))
            }))
    }
    if let finalizationOffset {
        try raw.finalize(stopRequestTimestamp: metadata.clock.monotonicAnchorSeconds + finalizationOffset,
            reason: .userStopped)
    }
    let inspected = try RecordingStore.inspect(root: source.paths.rawRoot, recordingID: context.recordingID)
    #expect(inspected.metadata == metadata && inspected.issues.isEmpty)
    #expect(inspected.status == (finalizationOffset == nil ? .interrupted : .finalized))
    let url = source.base.appendingPathComponent("replacement-\(index).pslrecording")
    _ = try RecordingArchive.write(recordingID: context.recordingID, rawRoot: source.paths.rawRoot,
        timeline: source.timelines[index], destination: url, labels: source.labels[index])
    return url
}

@Suite struct OwnerPracticeBundleTests {
    @Test(arguments: [true, false])
    func realTwoStrokeRoundTripPreservesEveryJoinAndHistoricalRetirement(heartRate: Bool) throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"), heartRate: heartRate)
            let (bundle, receipt) = try source.write()
            let rawBefore = try o6Tree(source.paths.rawRoot), notesBefore = try o6Tree(source.paths.notesRoot)
            let target = try o8Directory(base, "destination")
            #expect(try o8Publish(bundle, to: target) == receipt)
            let store = try OwnerPracticeReceiptStore(base: target)
            let result = try store.open(practiceID: o6Practice, revision: 1)
            #expect(result.receipt == receipt && result.status == .ended)
            #expect(result.heartRate == (heartRate ? .included : .absent))
            #expect(result.scope.includesHeartRate == heartRate)
            #expect(result.scope.ownerID == o6Owner && result.scope.phoneInstallationEpoch == o6Phone)
            #expect(result.scope.watchInstallationEpoch == o6Watch && result.scope.policyDigest == OwnerPracticePolicy.digest)
            #expect(result.sets.map { $0.context.manualStroke } == [.forehandGroundstroke, .backhandGroundstroke])
            #expect(try result.telemetry?.encoded() == source.telemetry.encoded())
            let notes = try SessionAnnotationsStore(root: result.notesRoot)
            for index in source.contexts.indices {
                let context = source.contexts[index]
                #expect(try source.ownerStore.inspectContext(recordingID: context.recordingID) == .retired)
                #expect(try result.sets[index].context.encoded() == context.encoded())
                #expect(result.sets[index].mapping == source.telemetry.sets[index].mapping)
                let raw = try RecordingStore.inspect(root: result.rawRoot, recordingID: context.recordingID)
                #expect(raw.metadata == context.metadata && raw.status == .finalized)
                #expect(raw.chunks.map(\.sampleCount) == [2, 2])
                #expect(try notes.loadTimeline(recordingID: context.recordingID) == source.timelines[index])
                #expect(try notes.loadLabels(recordingID: context.recordingID) == source.labels[index])
                #expect(source.timelines[index].terminalTailVerified == false)
            }
            // Destination witnesses are newly constructed by O6, never copied source inodes/locks.
            let localTelemetry = try OwnerTelemetryStore.open(base: result.directoryURL, practiceID: o6Practice,
                expectedHeader: source.telemetry.header)
            #expect(try localTelemetry.snapshot.encoded() == source.telemetry.encoded())
            localTelemetry.close()
            #expect(try o6Tree(source.paths.rawRoot) == rawBefore)
            #expect(try o6Tree(source.paths.notesRoot) == notesBefore)
            #expect(try source.ownerStore.snapshot.authority?.revision == 2)
        }
    }

    @Test func explicitExclusionRemovesAllHRWhileNoSamplesIsHonestAbsence() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let original = try source.telemetry.encoded()
            let (included, _) = try source.write("included.pslpractice")
            let (excluded, _) = try source.write("excluded.pslpractice", revision: 2, heartRate: .excludedByOwner)
            #expect(try o8Wire(Data(contentsOf: included)).components.values.contains(where: { o8HasHR($0) }))
            let wire = try o8Wire(Data(contentsOf: excluded))
            #expect(!o8HasHR(wire.manifest))
            #expect(!wire.components.values.contains(where: { o8HasHR($0) }))
            let target = try o8Directory(base, "target")
            _ = try o8Publish(excluded, to: target)
            let snapshot = try OwnerPracticeReceiptStore(base: target).open(practiceID: o6Practice, revision: 2)
            #expect(snapshot.heartRate == .excluded && !snapshot.scope.includesHeartRate)
            #expect(snapshot.telemetry == nil && snapshot.sets.count == 2)
            #expect(snapshot.sets.map(\.mapping) == source.telemetry.sets.map(\.mapping))
            #expect(try source.telemetry.encoded() == original)
            let empty = try O8Fixture(o8Directory(base, "empty"), heartRate: true, samples: false)
            let (absent, _) = try empty.write()
            let secondTarget = try o8Directory(base, "second-target")
            _ = try o8Publish(absent, to: secondTarget)
            let observed = try OwnerPracticeReceiptStore(base: secondTarget).open(practiceID: o6Practice, revision: 1)
            #expect(observed.heartRate == .absent && !observed.scope.includesHeartRate)
            #expect(observed.absenceReasons.contains(.noAccessibleHeartRateData))
        }
    }

    @Test func interruptedFinalizedEvidenceStaysInterruptedAndOpenPracticeCannotPublish() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "interrupted"), interrupted: true)
            let (bundle, receipt) = try source.write()
            let target = try o8Directory(base, "target")
            _ = try o8Publish(bundle, to: target)
            let value = try OwnerPracticeReceiptStore(base: target).open(practiceID: o6Practice, revision: 1)
            #expect(receipt.status == .interrupted && value.status == .interrupted)
            #expect(value.absenceReasons.contains(.interrupted))
            #expect(value.telemetry?.sets.last?.stoppedAt == nil)
            #expect(try RecordingStore.inspect(root: value.rawRoot, recordingID: source.contexts[1].recordingID).status == .interrupted)
            let unfinished = try O8Fixture(o8Directory(base, "open"), finalized: false)
            #expect(throws: (any Error).self) { try unfinished.write() }
            #expect(!FileManager.default.fileExists(atPath: unfinished.base.appendingPathComponent("practice.pslpractice").path))
        }
    }

    @Test func fullTwentySetInventoryAndCanonicalHashesAreBoundedAndExact() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"), count: 20, heartRate: false)
            let (bundle, receipt) = try source.write()
            let data = try Data(contentsOf: bundle), wire = try o8Wire(data)
            #expect(receipt.recordingIDs == source.contexts.map(\.recordingID))
            #expect(receipt.recordingIDs.count == 20 && wire.components.count <= 64)
            #expect(receipt.byteCount == data.count && receipt.byteCount <= 256 * 1024 * 1024)
            #expect(receipt.bundleSHA256 == o6SHA(data) && receipt.inventorySHA256 == o6SHA(wire.manifest))
            let target = try o8Directory(base, "target")
            _ = try o8Publish(bundle, to: target)
            #expect(try OwnerPracticeReceiptStore(base: target).open(practiceID: o6Practice, revision: 1).sets.count == 20)
        }
    }

    @Test(arguments: ["timeline", "labels", "chunk", "metadata"])
    func missingSourceComponentNeverExportsAPrefix(component: String) throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let id = source.contexts[1].recordingID.uuidString
            let path: URL
            switch component {
            case "timeline": path = source.paths.notesRoot.appendingPathComponent(id + "/capture-events.json")
            case "labels": path = source.paths.notesRoot.appendingPathComponent(id + "/labels.json")
            case "chunk": path = source.paths.rawRoot.appendingPathComponent(id + "/chunk-1-0.bin")
            default: path = source.paths.rawRoot.appendingPathComponent(id + "/metadata.json")
            }
            try FileManager.default.removeItem(at: path)
            #expect(throws: (any Error).self) { try source.write() }
            #expect(!FileManager.default.fileExists(atPath: source.base.appendingPathComponent("practice.pslpractice").path))
        }
    }

    @Test(arguments: ["owner", "practice", "schema", "missing", "duplicate", "traversal", "required", "count", "hash"])
    func independentlyRehashedManifestAttacksNeverPublish(attack: String) throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, _) = try source.write()
            let bad = try o8Rewrite(Data(contentsOf: bundle)) { body, _ in
                var entries = try #require(body["components"] as? [[String: Any]])
                switch attack {
                case "owner": body["ownerID"] = o6ID(987).uuidString
                case "practice": body["practiceID"] = o6ID(988).uuidString
                case "schema": body["schemaVersion"] = 2
                case "missing": entries.removeAll { $0["schema"] as? String == "PSLOwnerContext1" }
                case "duplicate": entries.append(entries[0])
                case "traversal": entries[0]["name"] = "../outside"
                case "required": entries[0]["required"] = false
                case "count": entries[0]["bytes"] = (entries[0]["bytes"] as! Int) + 1
                default: entries[0]["sha256"] = String(repeating: "0", count: 64)
                }
                body["components"] = entries
            }
            let badURL = base.appendingPathComponent("bad.pslpractice")
            try bad.write(to: badURL)
            let target = try o8Directory(base, "target")
            #expect(throws: (any Error).self) { try OwnerPracticeBundle.prepareImport(from: badURL, destinationBase: target) }
            #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: o6Practice, revision: 1) == nil)
        }
    }

    @Test func validButWrongContextAndRawTimelineLabelJoinsAreRejectedAfterRehash() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, _) = try source.write(), original = try Data(contentsOf: bundle)
            // Substitute another independently valid owner context, preserving outer integrity.
            let wrong = try o8Rewrite(original) { body, parts in
                try o8ChangeComponent(&body, &parts, schema: "PSLOwnerContext1") { _ in try source.contexts[1].encoded() }
            }
            let badURL = base.appendingPathComponent("wrong.pslpractice")
            try wrong.write(to: badURL)
            #expect(throws: (any Error).self) {
                try OwnerPracticeBundle.prepareImport(from: badURL, destinationBase: o8Directory(base, "wrong-target"))
            }
            let notes = try SessionAnnotationsStore(root: source.paths.notesRoot)
            let id = source.contexts[0].recordingID
            let wrongTimeline = CaptureTimeline(recordingID: id, clockDomainID: source.contexts[1].metadata.clock.domainID,
                events: source.timelines[0].events)
            try RecordingJSON.encode(wrongTimeline, limit: SessionAnnotationsStore.timelineLimit)
                .write(to: source.paths.notesRoot.appendingPathComponent(id.uuidString + "/capture-events.json"))
            #expect(throws: (any Error).self) { try source.write("wrong-timeline.pslpractice") }
            try RecordingJSON.encode(source.timelines[0], limit: SessionAnnotationsStore.timelineLimit)
                .write(to: source.paths.notesRoot.appendingPathComponent(id.uuidString + "/capture-events.json"))
            let wrongLabels = RecordingLabelHistory(schemaVersion: 1, recordingID: id, labels: source.labels[1])
            try RecordingJSON.encode(wrongLabels, limit: SessionAnnotationsStore.labelsLimit)
                .write(to: source.paths.notesRoot.appendingPathComponent(id.uuidString + "/labels.json"))
            #expect(throws: (any Error).self) { try notes.loadLabels(recordingID: id) }
            #expect(throws: (any Error).self) { try source.write("wrong-labels.pslpractice") }
        }
    }

    @Test func explicitEmptyLabelInventoryIsValidButLegacyMissingInventoryCannotCertifyOwnerEvidence() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"), withLabels: false)
            let (bundle, receipt) = try source.write()
            #expect(try o8Publish(bundle, to: o8Directory(base, "valid")) == receipt)
            var omittedRaw: Data?
            let bad = try o8Rewrite(Data(contentsOf: bundle)) { body, parts in
                try o8ChangeComponent(&body, &parts, schema: "PSLBND01") { raw in
                    let changed = try o8RawWithoutLabels(raw)
                    omittedRaw = changed
                    return changed
                }
            }
            let rawURL = base.appendingPathComponent("legacy-compatible.pslrecording")
            try #require(omittedRaw).write(to: rawURL)
            let legacyPaths = try RecordingPaths(base: o8Directory(base, "legacy"))
            _ = try RecordingArchive.importBundle(from: rawURL, rawRoot: legacyPaths.rawRoot, notesRoot: legacyPaths.notesRoot)
            let badURL = base.appendingPathComponent("omitted-labels.pslpractice")
            try bad.write(to: badURL)
            let target = try o8Directory(base, "owner-target")
            #expect(throws: (any Error).self) { try OwnerPracticeBundle.prepareImport(from: badURL, destinationBase: target) }
            #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: o6Practice, revision: 1) == nil)
        }
    }

    @Test func declaredCapsAndSparseByteBoundaryRejectBeforeUnboundedWork() throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, _) = try source.write(), original = try Data(contentsOf: bundle)
            for count in [64, 65] {
                let bad = try o8Rewrite(original) { body, _ in
                    let entries = try #require(body["components"] as? [[String: Any]])
                    body["components"] = Array(repeating: entries[0], count: count)
                }
                let url = base.appendingPathComponent("components-\(count)")
                try bad.write(to: url)
                let target = try o8Directory(base, "components-target-\(count)")
                #expect(throws: count == 65 ? OwnerPracticeBundleError.capacity : .integrity) {
                    try OwnerPracticeBundle.prepareImport(from: url, destinationBase: target)
                }
            }
            let excessSets = try o8Rewrite(original) { body, _ in body["recordingIDs"] = (0..<21).map { o6ID(10 + $0).uuidString } }
            let setsURL = base.appendingPathComponent("sets")
            try excessSets.write(to: setsURL)
            #expect(throws: OwnerPracticeBundleError.capacity) {
                try OwnerPracticeBundle.prepareImport(from: setsURL, destinationBase: o8Directory(base, "sets-target"))
            }
            for bytes in [256 * 1024 * 1024, 256 * 1024 * 1024 + 1] {
                let url = base.appendingPathComponent("sparse-\(bytes)")
                let fd = open(url.path, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, 0o600)
                #expect(fd >= 0)
                guard fd >= 0 else { throw O8Injected.stop }
                #expect(ftruncate(fd, off_t(bytes)) == 0)
                close(fd)
                let target = try o8Directory(base, "byte-target-\(bytes)")
                // At the cap, bad magic is integrity; above it, size is refused first.
                #expect(throws: bytes == 256 * 1024 * 1024 ? OwnerPracticeBundleError.integrity : .capacity) {
                    try OwnerPracticeBundle.prepareImport(from: url, destinationBase: target)
                }
            }
        }
    }

    @Test(arguments: ["truncated", "trailing", "checksum", "symlink", "hardlink"])
    func malformedOrAliasedInputNeverProducesCompleteEvidence(kind: String) throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"))
            let (bundle, _) = try source.write()
            let bad = base.appendingPathComponent("bad")
            var bytes = try Data(contentsOf: bundle)
            switch kind {
            case "symlink": try FileManager.default.createSymbolicLink(at: bad, withDestinationURL: bundle)
            case "hardlink": try FileManager.default.linkItem(at: bundle, to: bad)
            default:
                if kind == "truncated" { bytes.removeLast() }
                else if kind == "trailing" { bytes.append(0) }
                else { bytes[bytes.count - 33] ^= 1 }
                try bytes.write(to: bad)
            }
            let target = try o8Directory(base, "target")
            #expect(throws: (any Error).self) { try OwnerPracticeBundle.prepareImport(from: bad, destinationBase: target) }
            #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: o6Practice, revision: 1) == nil)
        }
    }

    @Test(arguments: [-0.5, 3.0])
    func knownO6SampleIntervalRejectsValidRawInBothWriterAndRehashedImport(offset: Double) throws {
        try o6WithDirectory { base in
            let source = try O8Fixture(o8Directory(base, "source"), heartRate: false)
            let (original, _) = try source.write()
            let replacement = try o8ReplaceRawSamples(source, offsets: [offset, offset + 0.125], finalizationOffset: 4)
            let before = try o6Tree(source.paths.rawRoot)
            // Both streams are outside the known O6 [100, 102] interval, while the
            // raw archive remains structurally valid and bound to identical metadata.
            #expect(throws: OwnerPracticeBundleError.integrity) { try source.write("contradictory.pslpractice") }
            #expect(!FileManager.default.fileExists(atPath: source.base.appendingPathComponent("contradictory.pslpractice").path))
            #expect(try o6Tree(source.paths.rawRoot) == before)
            let changed = try o8Rewrite(Data(contentsOf: original)) { body, parts in
                try o8ChangeComponent(&body, &parts, schema: "PSLBND01") { _ in try Data(contentsOf: replacement) }
            }
            let hostile = base.appendingPathComponent("rehashed.pslpractice")
            try changed.write(to: hostile)
            let target = try o8Directory(base, "target")
            #expect(throws: OwnerPracticeBundleError.integrity) { try o8Publish(hostile, to: target) }
            #expect(try OwnerPracticeReceiptStore(base: target).receipt(practiceID: o6Practice, revision: 1) == nil)
        }
    }

    @Test(arguments: ["interrupted-raw", "late-finalization", "unknown-stop"])
    func sampleIntervalGuardPreservesInclusiveBoundsAndExplicitPartialCoverage(kind: String) throws {
        try o6WithDirectory { base in
            let unknown = kind == "unknown-stop"
            let source = try O8Fixture(o8Directory(base, "source"), heartRate: false, interrupted: unknown)
            let index = unknown ? 1 : 0
            _ = try o8ReplaceRawSamples(source, index: index, offsets: [0, unknown ? 5 : 2],
                finalizationOffset: kind == "late-finalization" ? 4 : nil)
            let (bundle, receipt) = try source.write()
            let target = try o8Directory(base, "target")
            #expect(try o8Publish(bundle, to: target) == receipt)
            let result = try OwnerPracticeReceiptStore(base: target).open(practiceID: o6Practice, revision: 1)
            #expect(result.status == (unknown ? .interrupted : .ended))
            #expect((result.sets[index].rawStopSeconds == nil) == unknown)
            let raw = try RecordingStore.inspect(root: result.rawRoot, recordingID: source.contexts[index].recordingID)
            #expect(raw.status == (kind == "late-finalization" ? .finalized : .interrupted))
            #expect(raw.chunks.allSatisfy { $0.firstTimestamp == source.contexts[index].metadata.clock.monotonicAnchorSeconds })
            #expect(try SessionAnnotationsStore(root: result.notesRoot)
                .loadTimeline(recordingID: source.contexts[index].recordingID)?.terminalTailVerified == false)
        }
    }
}
