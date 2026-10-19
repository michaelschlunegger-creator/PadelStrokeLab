import Darwin
import Foundation
import Testing
@testable import PadelCore

final class RecordingDirectoryFixture {
    let root: URL
    var session: URL { root.appendingPathComponent(recordingTestID.uuidString) }

    init() throws {
        let created = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: created, withIntermediateDirectories: false)
        guard let canonical = realpath(created.path, nil) else {
            throw RecordingError.io(operation: "canonical test directory", code: errno)
        }
        defer { free(canonical) }
        root = URL(fileURLWithPath: String(cString: canonical))
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func snapshot() throws -> [String: Data] {
        var result: [String: Data] = [:]
        for name in try FileManager.default.contentsOfDirectory(atPath: session.path) {
            result[name] = try Data(contentsOf: session.appendingPathComponent(name))
        }
        return result
    }

    func inspect(budget: RecordingInspectionBudget? = nil) throws -> RecordingRecoveryReport {
        try RecordingStore.inspect(root: root, recordingID: recordingTestID, budget: budget)
    }
}

struct RecordingStoreTests {
    @Test func realStorageBothStreamsFinalizationAndReinspection() throws {
        let fixture = try RecordingDirectoryFixture()
        let metadata = try recordingMetadata()
        let store = try RecordingStore.create(root: fixture.root, metadata: metadata)
        try store.append(recordingChunk())
        try store.append(recordingChunk(stream: .deviceMotion, times: [10.15, 10.3]))
        try store.append(recordingChunk(sequence: 1, times: [20, 21]))
        let completion = try store.finalize(stopRequestTimestamp: 30, reason: .userStopped)
        #expect(completion.retainedCoverage[0].sampleCount == 4)
        #expect(completion.retainedCoverage[0].lastTimestamp == 21)
        #expect(completion.stopRequestTimestamp == 30) // Unobserved stop tail remains separate.
        #expect(try store.finalize(stopRequestTimestamp: 30, reason: .userStopped) == completion)
        #expect(throws: RecordingError.finalized) { try store.finalize(stopRequestTimestamp: 31, reason: .userStopped) }
        #expect(throws: RecordingError.finalized) { try store.append(recordingChunk(sequence: 2, times: [22])) }
        let before = try fixture.snapshot()
        for _ in 0..<2 {
            let recovered = try fixture.inspect()
            #expect(recovered.status == .finalized)
            #expect(recovered.metadata == metadata)
            #expect(recovered.finalization == completion)
            #expect(recovered.chunks.count == 3)
            #expect(recovered.issues.isEmpty)
        }
        #expect(try fixture.snapshot() == before)
    }

    @Test func directoriesCannotBeReusedOrReopenedForCapture() throws {
        let fixture = try RecordingDirectoryFixture()
        _ = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        let before = try fixture.snapshot()
        #expect(throws: (any Error).self) { try RecordingStore.create(root: fixture.root, metadata: recordingMetadata()) }
        #expect(try fixture.snapshot() == before)
        #expect(try fixture.inspect().status == .interrupted)
    }

    @Test func independentSequencesAndClockIdentityEnforced() throws {
        let fixture = try RecordingDirectoryFixture()
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        try store.append(recordingChunk())
        #expect(throws: (any Error).self) { try store.append(recordingChunk()) }
        #expect(throws: (any Error).self) { try store.append(recordingChunk(sequence: 2, times: [11])) }
        #expect(throws: (any Error).self) { try store.append(recordingChunk(sequence: 1, times: [10.2])) }
        for (id, clock) in [(UUID(), recordingTestClockID), (recordingTestID, UUID())] {
            let chunk = try RecordingChunk(recordingID: id, clockDomainID: clock, stream: .accelerometer,
                                           sequence: 1, samples: [.init(timestamp: 11, values: [1, 2, 3])])
            #expect(throws: (any Error).self) { try store.append(chunk) }
        }
        try store.append(recordingChunk(stream: .deviceMotion, times: [9]))
        #expect(throws: (any Error).self) { try store.finalize(stopRequestTimestamp: 10, reason: .userStopped) }
        #expect(try fixture.inspect().chunks.count == 2)
    }

    @Test func actualShortWritesAreCompletedAndZeroWriteFails() throws {
        let fixture = try RecordingDirectoryFixture()
        var writes = 0
        let operations = RecordingFileOperations(write: { fd, pointer, count in
            writes += 1
            let n = Darwin.write(fd, pointer, min(count, 7))
            guard n >= 0 else { throw RecordingError.io(operation: "test write", code: errno) }
            return n
        })
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata(), operations: operations)
        try store.append(recordingChunk())
        try store.finalize(stopRequestTimestamp: 11, reason: .userStopped)
        #expect(writes > 20)
        #expect(try fixture.inspect().status == .finalized)
        let second = try RecordingDirectoryFixture()
        #expect(throws: (any Error).self) {
            try RecordingStore.create(root: second.root, metadata: recordingMetadata(), operations: .init(write: { _, _, _ in 0 }))
        }
        #expect(try second.inspect().status != .finalized)
    }

    @Test(arguments: [ENOSPC, EACCES, EIO])
    func writeFailuresPreservePreviousChunks(_ code: Int32) throws {
        let fixture = try RecordingDirectoryFixture()
        var fail = false
        let operations = RecordingFileOperations(write: { fd, pointer, count in
            if fail { throw RecordingError.io(operation: "injected write", code: code) }
            let result = Darwin.write(fd, pointer, count)
            guard result >= 0 else { throw RecordingError.io(operation: "write", code: errno) }
            return result
        })
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata(), operations: operations)
        try store.append(recordingChunk())
        let original = try Data(contentsOf: fixture.session.appendingPathComponent("chunk-1-0.bin"))
        fail = true
        #expect(throws: RecordingError.io(operation: "injected write", code: code)) {
            try store.append(recordingChunk(sequence: 1, times: [11]))
        }
        #expect(throws: RecordingError.closed) { try store.finalize(stopRequestTimestamp: 12, reason: .failed) }
        let report = try fixture.inspect()
        #expect(report.status == .interrupted)
        #expect(report.chunks.count == 1)
        #expect(report.issues.contains { $0.kind == .partial })
        #expect(try Data(contentsOf: fixture.session.appendingPathComponent("chunk-1-0.bin")) == original)
    }

    @Test(arguments: [RecordingIOEvent.beforeSynchronize, .afterSynchronize, .beforePublish,
                      .afterPublish, .beforeDirectorySync])
    func chunkBoundaryFailuresNeverReportSuccessfulAppend(_ stage: RecordingIOEvent) throws {
        let fixture = try RecordingDirectoryFixture()
        var fail = false
        let operations = RecordingFileOperations(event: { event, name in
            if fail, event == stage, name == "chunk-1-1.bin" { throw RecordingError.io(operation: "injected stage", code: EIO) }
        })
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata(), operations: operations)
        try store.append(recordingChunk())
        fail = true
        #expect(throws: (any Error).self) { try store.append(recordingChunk(sequence: 1, times: [11])) }
        let before = try fixture.snapshot()
        let report = try fixture.inspect()
        #expect(report.status == .interrupted)
        #expect(report.chunks.contains { $0.sequence == 0 })
        #expect(report.issues.contains { $0.kind == .partial || $0.kind == .orphan })
        #expect(try fixture.snapshot() == before)
        #expect(throws: RecordingError.closed) { try store.append(recordingChunk(sequence: 1, times: [11])) }
    }

    @Test(arguments: [RecordingIOEvent.beforeWrite, .beforeSynchronize, .beforePublish])
    func manifestFailureRecoversPublishedOrphan(_ stage: RecordingIOEvent) throws {
        let fixture = try RecordingDirectoryFixture()
        var fail = false
        let operations = RecordingFileOperations(event: { event, name in
            if fail, event == stage, name == "manifest.json" { throw RecordingError.io(operation: "manifest fault", code: ENOSPC) }
        })
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata(), operations: operations)
        fail = true
        #expect(throws: (any Error).self) { try store.append(recordingChunk()) }
        let report = try fixture.inspect()
        #expect(report.status == .interrupted)
        #expect(report.chunks.count == 1)
        #expect(report.issues.contains { $0.kind == .orphan })
        #expect(report.finalization == nil)
    }

    @Test(arguments: [RecordingIOEvent.beforeFinalize, .beforeRead, .beforeWrite, .beforeSynchronize, .beforePublish])
    func finalizationFaultCannotReturnSaved(_ stage: RecordingIOEvent) throws {
        let fixture = try RecordingDirectoryFixture()
        var fail = false
        let operations = RecordingFileOperations(event: { event, name in
            if fail, event == stage, name == "manifest.json" { throw RecordingError.io(operation: "finalize fault", code: EIO) }
        })
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata(), operations: operations)
        try store.append(recordingChunk())
        fail = true
        #expect(throws: (any Error).self) { try store.finalize(stopRequestTimestamp: 11, reason: .userStopped) }
        let report = try fixture.inspect()
        #expect(report.status != .finalized)
        #expect(report.chunks.count == 1)
        #expect(report.finalization == nil)
    }

    @Test func immutableDestinationCollisionNeverOverwrites() throws {
        let fixture = try RecordingDirectoryFixture()
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        let file = fixture.session.appendingPathComponent("chunk-1-0.bin")
        let original = Data("external evidence".utf8)
        try original.write(to: file)
        #expect(throws: (any Error).self) { try store.append(recordingChunk()) }
        #expect(try Data(contentsOf: file) == original)
        #expect(try fixture.inspect().status == .corrupt)
    }

    @Test func storedCorruptionMissingChunkAndManifestDisagreementRemainVisible() throws {
        for mode in ["modify", "truncate", "missing", "manifest", "metadata", "rename"] {
            let fixture = try RecordingDirectoryFixture()
            let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
            try store.append(recordingChunk())
            let file = fixture.session.appendingPathComponent("chunk-1-0.bin")
            switch mode {
            case "modify":
                var bytes = try Data(contentsOf: file)
                bytes[75] ^= 1
                try bytes.write(to: file)
            case "truncate": try Data(contentsOf: file).dropLast().write(to: file)
            case "missing": try FileManager.default.removeItem(at: file)
            case "manifest":
                let manifest = fixture.session.appendingPathComponent("manifest.json")
                let text = try String(contentsOf: manifest, encoding: .utf8)
                try text.replacingOccurrences(of: "\"sampleCount\":2", with: "\"sampleCount\":3").write(to: manifest, atomically: false, encoding: .utf8)
            case "metadata":
                let changed = try RecordingChunkCodec.encodeMetadata(recordingMetadata(appBuild: "different"))
                try changed.write(to: fixture.session.appendingPathComponent("metadata.json"))
            default: try FileManager.default.moveItem(at: file, to: fixture.session.appendingPathComponent("chunk-1-1.bin"))
            }
            let before = try fixture.snapshot()
            #expect(throws: (any Error).self) { try store.finalize(stopRequestTimestamp: 11, reason: .userStopped) }
            let report = try fixture.inspect()
            #expect(report.status == .corrupt)
            #expect(report.finalization == nil)
            #expect(!report.issues.isEmpty)
            #expect(try fixture.snapshot() == before)
        }
    }

    @Test func finalizationRechecksAlreadyFinalizedBytes() throws {
        let fixture = try RecordingDirectoryFixture()
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        try store.append(recordingChunk())
        try store.finalize(stopRequestTimestamp: 11, reason: .userStopped)
        try Data([1]).write(to: fixture.session.appendingPathComponent("chunk-1-0.bin"))
        #expect(throws: (any Error).self) { try store.finalize(stopRequestTimestamp: 11, reason: .userStopped) }
        #expect(try fixture.inspect().status == .corrupt)
    }

    @Test func finalManifestPublicationIsReadBackBeforeSuccess() throws {
        let fixture = try RecordingDirectoryFixture()
        var finalizing = false
        let operations = RecordingFileOperations(event: { event, name in
            if finalizing, event == .afterPublish, name == "manifest.json" {
                try Data("corrupted after publication".utf8).write(to: fixture.session.appendingPathComponent(name))
            }
        })
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata(), operations: operations)
        try store.append(recordingChunk())
        finalizing = true
        #expect(throws: RecordingError.integrity("manifest publication readback")) {
            try store.finalize(stopRequestTimestamp: 11, reason: .userStopped)
        }
        #expect(try fixture.inspect().status == .corrupt)
    }

    @Test func emptyFinalizationExplicitlyRetainsNoSamples() throws {
        let fixture = try RecordingDirectoryFixture()
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        let result = try store.finalize(stopRequestTimestamp: 10, reason: .failed)
        #expect(result.retainedCoverage.isEmpty)
        #expect(result.reason == .failed)
        #expect(try fixture.inspect().chunks.isEmpty)
    }

    @Test func recoveryIsBoundedByBytesAndDirectoryEntries() throws {
        let fixture = try RecordingDirectoryFixture()
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        try store.append(recordingChunk())
        let byteCount = try fixture.snapshot().values.reduce(0) { $0 + $1.count }
        #expect(try fixture.inspect(budget: RecordingInspectionBudget(maximumBytes: byteCount)).status == .interrupted)
        #expect(try fixture.inspect(budget: RecordingInspectionBudget(maximumBytes: byteCount - 1)).status == .limited)
        #expect(try fixture.inspect(budget: RecordingInspectionBudget(maximumEntries: 3)).status == .interrupted)
        #expect(try fixture.inspect(budget: RecordingInspectionBudget(maximumEntries: 2)).status == .limited)
        for index in 0..<269 { try Data().write(to: fixture.session.appendingPathComponent("unknown-\(index)")) }
        #expect(try fixture.inspect().status == .corrupt) // Exactly 272 entries.
        try Data().write(to: fixture.session.appendingPathComponent("one-more"))
        #expect(try fixture.inspect().status == .limited)
    }

    @Test func oversizedFilesRejectedBeforeDecode() throws {
        let fixture = try RecordingDirectoryFixture()
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        try store.append(recordingChunk())
        for (name, size) in [("chunk-1-0.bin", 1_048_577), ("manifest.json", 262_145), ("metadata.json", 16_385)] {
            let original = try Data(contentsOf: fixture.session.appendingPathComponent(name))
            try Data(count: size).write(to: fixture.session.appendingPathComponent(name))
            #expect(try fixture.inspect().issues.contains { $0.fileName == name && $0.kind == .corrupt })
            try original.write(to: fixture.session.appendingPathComponent(name))
        }
    }

    @Test func recordingChunkCountHasHardLimit() throws {
        let fixture = try RecordingDirectoryFixture()
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        for sequence in 0..<256 { try store.append(recordingChunk(sequence: sequence, times: [Double(sequence)])) }
        #expect(throws: RecordingError.limit("chunk count")) { try store.append(recordingChunk(stream: .deviceMotion, times: [300])) }
        #expect(try fixture.inspect().chunks.count == 256)
        #expect(try store.finalize(stopRequestTimestamp: 300, reason: .userStopped).retainedCoverage[0].sampleCount == 256)
    }

    @Test func symlinkRootAncestorsAndStoredFilesAreRejected() throws {
        let fixture = try RecordingDirectoryFixture()
        let outside = try RecordingDirectoryFixture()
        let link = fixture.root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside.root)
        #expect(throws: (any Error).self) { try RecordingStore.create(root: link, metadata: recordingMetadata()) }
        let child = outside.root.appendingPathComponent("child")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try RecordingStore.create(root: link.appendingPathComponent("child"), metadata: recordingMetadata()) }
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        try store.append(recordingChunk())
        let target = outside.root.appendingPathComponent("original")
        try Data("untouched".utf8).write(to: target)
        let raw = fixture.session.appendingPathComponent("chunk-1-0.bin")
        try FileManager.default.removeItem(at: raw)
        try FileManager.default.createSymbolicLink(at: raw, withDestinationURL: target)
        #expect(try fixture.inspect().status == .corrupt)
        #expect(throws: (any Error).self) { try store.finalize(stopRequestTimestamp: 11, reason: .userStopped) }
        #expect(try Data(contentsOf: target) == Data("untouched".utf8))
    }

    @Test func traversalAndSpecialFilesCannotEscapeOrBlockInspection() throws {
        let fixture = try RecordingDirectoryFixture()
        let traversal = URL(fileURLWithPath: fixture.root.path + "/../" + fixture.root.lastPathComponent)
        #expect(throws: (any Error).self) { try RecordingStore.create(root: traversal, metadata: recordingMetadata()) }
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        try store.append(recordingChunk())
        let raw = fixture.session.appendingPathComponent("chunk-1-0.bin")
        try FileManager.default.removeItem(at: raw)
        #expect(mkfifo(raw.path, 0o600) == 0)
        #expect(try fixture.inspect().status == .corrupt)
    }

    @Test func hardLinksAndUnknownFilesAreRetainedAndReported() throws {
        let fixture = try RecordingDirectoryFixture()
        let store = try RecordingStore.create(root: fixture.root, metadata: recordingMetadata())
        try store.append(recordingChunk())
        let raw = fixture.session.appendingPathComponent("chunk-1-0.bin")
        let alias = fixture.session.appendingPathComponent("alias")
        #expect(link(raw.path, alias.path) == 0)
        let before = try fixture.snapshot()
        let report = try fixture.inspect()
        #expect(report.status == .corrupt)
        #expect(report.issues.contains { $0.kind == .unexpected })
        #expect(try fixture.snapshot() == before)
    }

    #if os(macOS)
    @Test func ownedSubprocessPreservesExitStatusAndBothOutputStreams() throws {
        let result = try OwnedTestSubprocess.run(executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf 'normal-output\\n'; printf 'error-output\\n' >&2; exit 37"])
        #expect(!result.timedOut)
        #expect(result.terminationReason == .exit && result.terminationStatus == 37)
        #expect(result.output.contains("normal-output") && result.output.contains("error-output"))
    }

    @Test func ownedSubprocessDrainsMoreThanAPipeBufferWithBoundedDiagnostics() throws {
        let result = try OwnedTestSubprocess.run(executable: URL(fileURLWithPath: "/usr/bin/awk"),
            arguments: ["BEGIN { print \"output-begin\"; for (i=0; i<32768; i++) printf \"0123456789abcdef\"; print \"\\noutput-end\"; exit 23 }"])
        #expect(!result.timedOut)
        #expect(result.terminationReason == .exit && result.terminationStatus == 23)
        #expect(result.output.contains("output-begin") && result.output.contains("output-end"))
        #expect(result.output.contains("output bytes omitted"))
        #expect(result.output.utf8.count <= OwnedTestSubprocess.maximumLogBytes + 128)
    }

    @Test func ownedStalledSubprocessHasBoundedForcedCleanup() throws {
        let clock = ContinuousClock(), start = clock.now
        // exec preserves the ignored TERM disposition and leaves exactly one owned child PID.
        let result = try OwnedTestSubprocess.run(executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "trap '' TERM; printf 'stall-ready\\n'; exec /bin/sleep 30"],
            timeout: 1, terminationGrace: 1)
        #expect(result.timedOut)
        #expect(result.terminationReason == .uncaughtSignal && result.terminationStatus == SIGKILL)
        #expect(result.output.contains("stall-ready"))
        #expect(start.duration(to: clock.now) < .seconds(6))
        var status: Int32 = 0
        let waited = Darwin.waitpid(result.processID, &status, WNOHANG)
        let waitError = errno
        #expect(waited == -1 && waitError == ECHILD, "The helper must already have reaped its child")
    }

    @Test func abruptChildHelper() throws {
        guard let path = ProcessInfo.processInfo.environment["PSL_ABRUPT_ROOT"],
              let cut = ProcessInfo.processInfo.environment["PSL_ABRUPT_CUT"] else { return }
        var finalizing = false
        let operations = RecordingFileOperations(event: { event, name in
            if cut == "temporary", name == "chunk-1-0.bin", event == .afterWrite { _exit(71) }
            if cut == "published", name == "chunk-1-0.bin", event == .afterPublish { _exit(72) }
            if cut == "finalTemporary", finalizing, name == "manifest.json", event == .afterSynchronize { _exit(73) }
            if cut == "finalPublished", finalizing, name == "manifest.json", event == .afterPublish { _exit(74) }
        })
        let store = try RecordingStore.create(root: URL(fileURLWithPath: path), metadata: recordingMetadata(), operations: operations)
        try store.append(recordingChunk())
        finalizing = true
        try store.finalize(stopRequestTimestamp: 12, reason: .userStopped)
        Issue.record("Child did not reach the requested interruption boundary")
    }

    @Test(arguments: ["temporary", "published", "finalTemporary", "finalPublished"])
    func abruptProcessExitPreservesTruthfulRecovery(_ cut: String) throws {
        if ProcessInfo.processInfo.environment["PSL_ABRUPT_CHILD"] != nil {
            // Fail before any spawn if the runner ignores the requested child-only selection.
            FileHandle.standardError.write(Data("Crash-test child invoked its parent; refusing recursive spawn.\n".utf8))
            _exit(75)
        }
        let fixture = try RecordingDirectoryFixture()
        // Preserve SwiftPM's actual runner/bundle arguments; Xcode 27 uses swiftpm-testing-helper.
        // Replace only the selection so the child cannot recursively run the parent fault test.
        var arguments = Array(CommandLine.arguments.dropFirst())
        while let index = arguments.firstIndex(of: "--filter") {
            arguments.removeSubrange(index..<min(index + 2, arguments.count))
        }
        arguments += ["--filter", "RecordingStoreTests/abruptChildHelper"]
        var environment = ProcessInfo.processInfo.environment
        environment["PSL_ABRUPT_CHILD"] = "1"
        environment["PSL_ABRUPT_ROOT"] = fixture.root.path
        environment["PSL_ABRUPT_CUT"] = cut
        let child = try OwnedTestSubprocess.run(executable: URL(fileURLWithPath: CommandLine.arguments[0]),
                                                arguments: arguments, environment: environment)
        try #require(!child.timedOut, "Crash helper exceeded its deadline: \(child.output)")
        let expected: Int32 = ["temporary": 71, "published": 72, "finalTemporary": 73, "finalPublished": 74][cut]!
        #expect(child.terminationStatus == expected, "Unexpected child exit: \(child.output)")
        let before = try fixture.snapshot()
        let report = try fixture.inspect()
        #expect(report.status == (cut == "finalPublished" ? .finalized : .interrupted))
        #expect(report.chunks.count == (cut == "temporary" ? 0 : 1))
        if cut != "finalPublished" { #expect(report.finalization == nil) }
        else { #expect(report.finalization?.retainedCoverage[0].lastTimestamp == 10.25) }
        #expect(try fixture.snapshot() == before)
    }
    #endif
}
