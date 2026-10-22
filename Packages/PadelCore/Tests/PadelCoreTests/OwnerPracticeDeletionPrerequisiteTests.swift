import Darwin
import Foundation
import Testing
@testable import PadelCore

// O9p only: checked telemetry-deletion proof. This does not authorize deletion,
// implement paired cleanup, or accept an unchecked tombstone as recovery evidence.
@Suite(.serialized) struct OwnerPracticeDeletionPrerequisiteTests {
    @Test func completedProofRequiresActualEmptyReservedDirectoryAndPreservesNonreuse() throws {
        try o9pDirectory { base in
            let f = try O8Fixture(base)
            let preparation = try OwnerPracticeDeletionProof.prepare(base: base, header: f.telemetry.header, operationID: UUID())
            defer { preparation.cancel() }
            #expect(try !OwnerPracticeDeletionProof.isCompleted(base: base, practiceID: f.telemetry.header.practiceID))
            #expect(throws: (any Error).self) { try preparation.complete() }
            // Only synthetic fixture files are removed; O9 will own this cleanup later.
            try o9pRemoveTelemetryPayload(base, f.telemetry.header.practiceID)
            try preparation.complete()
            #expect(try OwnerPracticeDeletionProof.isCompleted(base: base, practiceID: f.telemetry.header.practiceID))
            let proof = try Data(contentsOf: o9pProofURL(base, f.telemetry.header.practiceID))
            #expect(proof.count <= 4096 && !o8HasHR(proof))
            let text = String(decoding: proof, as: UTF8.self)
            #expect(!text.contains("sampleRecords") && !text.contains("cleanContact") && !text.contains("mishit"))
            #expect(try FileManager.default.contentsOfDirectory(atPath: o9pTelemetryURL(base, f.telemetry.header.practiceID).path).isEmpty)
            #expect(throws: (any Error).self) { _ = try OwnerTelemetryStore.create(base: base, telemetry: f.telemetry) }
        }
    }

    @Test(arguments: ["pending", "corrupt", "foreignNamespace", "replacedDirectory", "changedWitness"])
    func incompleteOrUnboundProofNeverCertifiesDeletion(violation: String) throws {
        try o9pDirectory { root in
            let base = try o8Directory(root, "target"), f = try O8Fixture(base)
            let preparation = try OwnerPracticeDeletionProof.prepare(base: base, header: f.telemetry.header, operationID: UUID())
            defer { preparation.cancel() }
            try o9pRemoveTelemetryPayload(base, f.telemetry.header.practiceID)
            if violation == "pending" {
                #expect(try !OwnerPracticeDeletionProof.isCompleted(base: base, practiceID: f.telemetry.header.practiceID))
                return
            }
            try preparation.complete()
            let proof = o9pProofURL(base, f.telemetry.header.practiceID)
            if violation == "corrupt" { try Data("malformed-proof".utf8).write(to: proof) }
            if violation == "foreignNamespace" {
                let otherBase = try o8Directory(root, "other"), other = try O8Fixture(otherBase)
                let otherPreparation = try OwnerPracticeDeletionProof.prepare(base: otherBase, header: other.telemetry.header, operationID: UUID())
                defer { otherPreparation.cancel() }
                try o9pRemoveTelemetryPayload(otherBase, other.telemetry.header.practiceID)
                try otherPreparation.complete()
                try Data(contentsOf: o9pProofURL(otherBase, other.telemetry.header.practiceID)).write(to: proof)
            }
            if violation == "replacedDirectory" {
                let directory = o9pTelemetryURL(base, f.telemetry.header.practiceID)
                try FileManager.default.moveItem(at: directory, to: root.appendingPathComponent("displaced"))
                try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: root.appendingPathComponent("displaced"))
            }
            if violation == "changedWitness" {
                let witness = base.appendingPathComponent(OwnerTelemetryStore.directoryName)
                    .appendingPathComponent(".used-" + f.telemetry.header.practiceID.uuidString.lowercased())
                try Data("changed-original-witness".utf8).write(to: witness)
            }
            #expect(throws: (any Error).self) {
                _ = try OwnerPracticeDeletionProof.isCompleted(base: base, practiceID: f.telemetry.header.practiceID)
            }
        }
    }

    @Test func liveTelemetryLeasePreventsProofPreparationAndNoContentIsRemoved() throws {
        try o9pDirectory { base in
            let f = try O8Fixture(base)
            let store = try OwnerTelemetryStore.open(base: base, practiceID: f.telemetry.header.practiceID, expectedHeader: f.telemetry.header)
            defer { store.close() }
            let bytes = try Data(contentsOf: store.directoryURL.appendingPathComponent("telemetry.json"))
            #expect(throws: (any Error).self) {
                _ = try OwnerPracticeDeletionProof.prepare(base: base, header: f.telemetry.header, operationID: UUID())
            }
            #expect(try Data(contentsOf: store.directoryURL.appendingPathComponent("telemetry.json")) == bytes)
            store.close()
            let prepared = try OwnerPracticeDeletionProof.prepare(base: base, header: f.telemetry.header, operationID: UUID())
            prepared.cancel()
        }
    }
}
private func o9pDirectory(_ body: (URL) throws -> Void) throws {
    guard let resolved = realpath(FileManager.default.temporaryDirectory.path, nil) else { throw CocoaError(.fileReadUnknown) }
    defer { free(resolved) }
    let base = URL(fileURLWithPath: String(cString: resolved), isDirectory: true).appendingPathComponent("O9p-Core-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: base) }
    try body(base)
}
private func o9pTelemetryURL(_ base: URL, _ id: UUID) -> URL {
    base.appendingPathComponent(OwnerTelemetryStore.directoryName).appendingPathComponent(id.uuidString.lowercased())
}
private func o9pProofURL(_ base: URL, _ id: UUID) -> URL {
    base.appendingPathComponent(OwnerPracticeDeletionProof.directoryName).appendingPathComponent(id.uuidString.lowercased() + ".json")
}
private func o9pRemoveTelemetryPayload(_ base: URL, _ id: UUID) throws {
    let directory = o9pTelemetryURL(base, id)
    // Fixed actual O6 files, including its content-free lease. Reserved directory/witness remain.
    for name in ["header.json", "telemetry.json", "manifest.json", ".lock"] {
        try FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
}
