import CryptoKit
import Foundation
import Testing
@testable import PadelCore

func archiveFixture(finalize: Bool = true) throws -> (RecordingDirectoryFixture, RecordingPaths, CaptureTimeline, URL) {
    let fixture = try RecordingDirectoryFixture()
    let paths = try RecordingPaths(base: fixture.root)
    let store = try RecordingStore.create(root: paths.rawRoot, metadata: recordingMetadata())
    try store.append(recordingChunk())
    try store.append(recordingChunk(stream: .deviceMotion))
    if finalize { try store.finalize(stopRequestTimestamp: 11, reason: .userStopped) }
    let timeline = CaptureTimeline(recordingID: recordingTestID, clockDomainID: recordingTestClockID,
        events: [try RecordingCaptureEvent(kind: .start, timestamp: 10),
                 try RecordingCaptureEvent(kind: finalize ? .stopped : .interruption, timestamp: 11)])
    return (fixture, paths, timeline, paths.outboxRoot.appendingPathComponent("test.pslrecording"))
}

struct RecordingArchiveTests {
    @Test func realRoundTripDuplicateAndPhoneLabelPreservation() throws {
        let (source, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(source) {} }
        let receipt = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot,
                                                 timeline: timeline, destination: bundle)
        #expect(receipt.streams.map(\.sampleCount) == [2, 2])
        #expect(receipt.bundleSHA256 == RecordingChunkCodec.digest(try Data(contentsOf: bundle)))
        let target = try RecordingDirectoryFixture()
        let targetPaths = try RecordingPaths(base: target.root)
        let imported = try RecordingArchive.importBundle(from: bundle, rawRoot: targetPaths.rawRoot, notesRoot: targetPaths.notesRoot)
        #expect(imported == receipt)
        let report = try RecordingStore.inspect(root: targetPaths.rawRoot, recordingID: recordingTestID)
        #expect(report.status == .finalized)
        #expect(report.chunks.map(\.sampleCount) == [2, 2])
        let notes = try SessionAnnotationsStore(root: targetPaths.notesRoot)
        let label = try RecordingAttemptLabel(recordingID: recordingTestID, attemptID: UUID(), ordinal: 1, category: .mishit)
        try notes.saveLabels([label], recordingID: recordingTestID)
        #expect(try RecordingArchive.importBundle(from: bundle, rawRoot: targetPaths.rawRoot, notesRoot: targetPaths.notesRoot) == receipt)
        #expect(try notes.loadLabels(recordingID: recordingTestID) == [label])
        #expect(try notes.loadReceipt(recordingID: recordingTestID) == receipt)
        for name in try FileManager.default.contentsOfDirectory(atPath: paths.rawRoot.appendingPathComponent(recordingTestID.uuidString).path) {
            #expect(try Data(contentsOf: paths.rawRoot.appendingPathComponent(recordingTestID.uuidString).appendingPathComponent(name)) ==
                    Data(contentsOf: targetPaths.rawRoot.appendingPathComponent(recordingTestID.uuidString).appendingPathComponent(name)))
        }
    }

    @Test func interruptedRemainsInterruptedAndConflictingUUIDRejected() throws {
        let (source, paths, timeline, bundle) = try archiveFixture(finalize: false)
        defer { withExtendedLifetime(source) {} }
        _ = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: bundle)
        let target = try RecordingDirectoryFixture()
        let targetPaths = try RecordingPaths(base: target.root)
        _ = try RecordingArchive.importBundle(from: bundle, rawRoot: targetPaths.rawRoot, notesRoot: targetPaths.notesRoot)
        #expect(try RecordingStore.inspect(root: targetPaths.rawRoot, recordingID: recordingTestID).status == .interrupted)
        let second = paths.outboxRoot.appendingPathComponent("different.pslrecording")
        var changed = timeline
        changed.events.append(try RecordingCaptureEvent(kind: .interruption, timestamp: 12))
        _ = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: changed, destination: second)
        #expect(throws: (any Error).self) {
            try RecordingArchive.importBundle(from: second, rawRoot: targetPaths.rawRoot, notesRoot: targetPaths.notesRoot)
        }
    }

    @Test func truncationChecksumAndHeaderAttacksWithholdReceipt() throws {
        let (source, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(source) {} }
        _ = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: bundle)
        let original = try Data(contentsOf: bundle)
        var badChecksum = original
        badChecksum[badChecksum.count - 40] ^= 1
        var badLength = original
        badLength.replaceSubrange(8..<12, with: [255, 255, 255, 127])
        var variants = [Data(original.dropLast()), badChecksum, badLength]
        // Rewrite canonical header and correct outer digest to test structural validation itself.
        for attack in ["name", "duplicate", "length", "missing"] {
            variants.append(try mutateHeader(original) { header in
                var entries = header["entries"] as! [[String: Any]]
                if attack == "name" { entries[0]["name"] = "../../escape" }
                if attack == "duplicate" { entries[1] = entries[0] }
                if attack == "length" { entries[0]["byteCount"] = Int.max }
                if attack == "missing" { entries.removeAll { ($0["name"] as? String) == "raw/metadata.json" } }
                header["entries"] = entries
            })
        }
        for (index, variant) in variants.enumerated() {
            let target = try RecordingDirectoryFixture()
            let targetPaths = try RecordingPaths(base: target.root)
            let bad = paths.outboxRoot.appendingPathComponent("bad-\(index).pslrecording")
            try variant.write(to: bad)
            #expect(throws: (any Error).self) {
                try RecordingArchive.importBundle(from: bad, rawRoot: targetPaths.rawRoot, notesRoot: targetPaths.notesRoot)
            }
            #expect(try SessionAnnotationsStore(root: targetPaths.notesRoot).loadReceipt(recordingID: recordingTestID) == nil)
        }
    }

    @Test func missingRawChunksRefuseExportAndFaultBeforeReceiptRecovers() throws {
        let (source, paths, timeline, bundle) = try archiveFixture()
        defer { withExtendedLifetime(source) {} }
        let expected = try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline, destination: bundle)
        let target = try RecordingDirectoryFixture()
        let targetPaths = try RecordingPaths(base: target.root)
        #expect(throws: RecordingError.closed) {
            try RecordingArchive.importBundle(from: bundle, rawRoot: targetPaths.rawRoot, notesRoot: targetPaths.notesRoot,
                                              beforeReceipt: { throw RecordingError.closed })
        }
        #expect(try SessionAnnotationsStore(root: targetPaths.notesRoot).loadReceipt(recordingID: recordingTestID) == nil)
        #expect(try RecordingArchive.importBundle(from: bundle, rawRoot: targetPaths.rawRoot, notesRoot: targetPaths.notesRoot) == expected)
        try FileManager.default.removeItem(at: paths.rawRoot.appendingPathComponent(recordingTestID.uuidString).appendingPathComponent("chunk-1-0.bin"))
        #expect(throws: (any Error).self) {
            try RecordingArchive.write(recordingID: recordingTestID, rawRoot: paths.rawRoot, timeline: timeline,
                                       destination: paths.outboxRoot.appendingPathComponent("missing.pslrecording"))
        }
    }
}

private func mutateHeader(_ original: Data, mutation: (inout [String: Any]) -> Void) throws -> Data {
    let length = original[8..<12].enumerated().reduce(0) { $0 | (Int($1.element) << ($1.offset * 8)) }
    var header = try JSONSerialization.jsonObject(with: original.subdata(in: 12..<(12 + length))) as! [String: Any]
    mutation(&header)
    let bytes = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys, .withoutEscapingSlashes])
    var newLength = UInt32(bytes.count).littleEndian
    var result = original.prefix(8)
    withUnsafeBytes(of: &newLength) { result.append(contentsOf: $0) }
    result.append(bytes)
    result.append(original[(12 + length)..<(original.count - 32)])
    result.append(contentsOf: SHA256.hash(data: result))
    return result
}
