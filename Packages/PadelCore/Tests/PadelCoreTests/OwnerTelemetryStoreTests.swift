import Darwin
import Foundation
import Testing
@testable import PadelCore

// Store contract: a separately owned OwnerTelemetry-v1/<lowercase practice UUID>/ namespace.
// header.json and telemetry.json are bounded canonical components; manifest.json is published
// durably last. Manifest envelope body.components is the exact [{name, bytes, sha256}] inventory.
// Staging/lock/denial artifacts are not data components and must never be mistaken for success.
// The internal failureInjector seam fires at real checked publication/fsync boundaries.

func o6WithDirectory(_ body: (URL) throws -> Void) throws {
    // Resolve only the trusted system root; every owned/hostile child retains its original path.
    guard let resolved = realpath(FileManager.default.temporaryDirectory.path, nil) else {
        throw CocoaError(.fileReadUnknown)
    }
    defer { free(resolved) }
    let trustedRoot = URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
    let base = trustedRoot.appendingPathComponent("PSL-O6-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: base) }
    try body(base)
}

func o6Tree(_ base: URL) throws -> [String: Data] {
    var result: [String: Data] = [:]
    let iterator = try #require(FileManager.default.enumerator(at: base,
        includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]))
    for case let url as URL in iterator {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        if values.isRegularFile == true && values.isSymbolicLink != true {
            result[String(url.path.dropFirst(base.path.count + 1))] = try Data(contentsOf: url)
        }
    }
    return result
}

func o6ManifestEntries(_ directory: URL) throws -> [[String: Any]] {
    let envelope = try o6JSON(Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    let body = try #require(envelope["body"] as? [String: Any])
    return try #require(body["components"] as? [[String: Any]])
}

func o6RehashManifest(_ directory: URL) throws {
    let url = directory.appendingPathComponent("manifest.json")
    let bytes = try o6RewriteEnvelope(Data(contentsOf: url), domain: "PSLOwnerTelemetryManifest1") { body in
        var entries = try #require(body["components"] as? [[String: Any]])
        for index in entries.indices {
            let name = try #require(entries[index]["name"] as? String)
            let component = try Data(contentsOf: directory.appendingPathComponent(name))
            entries[index]["bytes"] = component.count
            entries[index]["sha256"] = o6SHA(component)
        }
        body["components"] = entries
    }
    try bytes.write(to: url)
}

func o6FinalizedTelemetry() throws -> OwnerPracticeTelemetry {
    var telemetry = try o6Telemetry()
    _ = try o6Admit(to: &telemetry)
    _ = try o6Append([o6Sample(50, end: 10), o6Sample(51, end: 11)], to: &telemetry)
    try telemetry.finalize(status: .ended, at: o6Instant(200),
        absenceReasons: [.insufficientSamples])
    return telemetry
}

@Suite struct OwnerTelemetryStoreTests {
    @Test func realPublicationManifestBindsExactCanonicalComponentsAndReopensFrozen() throws {
        try o6WithDirectory { base in
            let initial = try o6Telemetry()
            let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
            defer { store.close() }
            let directory = store.directoryURL
            #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("manifest.json").path))
            var stages = [OwnerTelemetryStoreStage]()
            store.failureInjector = { stage in
                stages.append(stage)
                if stage == .manifestTemporarySynced {
                    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("header.json").path))
                    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("telemetry.json").path))
                    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("manifest.json").path))
                }
            }
            try store.update {
                _ = try o6Admit(to: &$0)
                _ = try o6Append([o6Sample(50, end: 10), o6Sample(51, end: 11)], to: &$0)
                try $0.finalize(status: .ended, at: o6Instant(200), absenceReasons: [.insufficientSamples])
            }
            let componentIndex = try #require(stages.firstIndex(of: .componentPublished))
            let manifestIndex = try #require(stages.firstIndex(of: .manifestPublished))
            #expect(componentIndex < manifestIndex)
            #expect(stages.last == .directorySynced)
            let entries = try o6ManifestEntries(directory)
            #expect(Set(try entries.map { try #require($0["name"] as? String) }) == ["header.json", "telemetry.json"])
            for entry in entries {
                let name = try #require(entry["name"] as? String)
                let bytes = try Data(contentsOf: directory.appendingPathComponent(name))
                #expect(entry["bytes"] as? Int == bytes.count)
                #expect(entry["sha256"] as? String == o6SHA(bytes))
            }
            let before = try o6Tree(base)
            store.close()
            let reopened = try OwnerTelemetryStore.open(base: base, practiceID: o6Practice,
                expectedHeader: initial.header)
            defer { reopened.close() }
            #expect(reopened.snapshot.status == .ended)
            #expect(reopened.snapshot.finalization?.absenceReasons.contains(.insufficientSamples) == true)
            #expect(try reopened.snapshot.encoded() == store.snapshot.encoded())
            #expect(try o6Tree(base) == before)
        }
    }

    @Test func finalizedLatePagesAndDuplicateFinalizeLeaveAllPersistedBytesUnchanged() throws {
        try o6WithDirectory { base in
            let telemetry = try o6FinalizedTelemetry()
            let store = try OwnerTelemetryStore.create(base: base, telemetry: telemetry)
            defer { store.close() }
            let before = try o6Tree(base)
            try store.update {
                try $0.finalize(status: .ended, at: o6Instant(200), absenceReasons: [.insufficientSamples])
            }
            #expect(throws: (any Error).self) {
                try store.update { _ = try o6Append([o6Sample(52, end: 190)], to: &$0) }
            }
            #expect(throws: (any Error).self) {
                try store.update {
                    try $0.finalize(status: .interrupted, at: o6Instant(200), absenceReasons: [.interrupted])
                }
            }
            #expect(try o6Tree(base) == before)
        }
    }

    @Test func openPartialCheckpointIsInterruptedAndCannotBePromotedToCleanEnd() throws {
        try o6WithDirectory { base in
            let initial = try o6Telemetry()
            let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
            try store.update {
                _ = try o6Admit(start: 30, stop: nil, to: &$0)
                _ = try o6Append([o6Sample(50, end: 35)], to: &$0)
            }
            let oldContext = try store.snapshot.sets[0].context.encoded()
            store.close()
            let reopened = try OwnerTelemetryStore.open(base: base, practiceID: o6Practice,
                expectedHeader: initial.header)
            defer { reopened.close() }
            #expect(reopened.snapshot.status == .interrupted)
            #expect(reopened.snapshot.incompleteReasons.contains(.reopenedPartial))
            #expect(reopened.snapshot.sampleRecords.count == 1)
            #expect(try reopened.snapshot.sets[0].context.encoded() == oldContext)
            #expect(throws: (any Error).self) {
                try reopened.update {
                    try $0.finalize(status: .ended, at: o6Instant(100), absenceReasons: [])
                }
            }
            #expect(throws: (any Error).self) {
                try reopened.update { _ = try o6Append([o6Sample(51, end: 36)], to: &$0) }
            }
            #expect(throws: (any Error).self) { try OwnerTelemetryStore.create(base: base, telemetry: initial) }
        }
    }

    @Test func capacityRefusalIsDurableAndNeverAdmitsAHiddenPrefix() throws {
        try o6WithDirectory { base in
            let initial = try o6Telemetry()
            let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
            try store.update { _ = try o6Append([o6Sample(50, end: 10)], to: &$0) }
            let overflow = try (0..<257).map { try o6Sample(1_000 + $0, end: 20) }
            #expect(throws: (any Error).self) {
                try store.update { _ = try o6Append(overflow, to: &$0) }
            }
            #expect(store.snapshot.sampleRecords.count == 1)
            #expect(store.snapshot.incompleteReasons.contains(.pageLimit))
            store.close()
            let reopened = try OwnerTelemetryStore.open(base: base, practiceID: o6Practice,
                expectedHeader: initial.header)
            defer { reopened.close() }
            #expect(reopened.snapshot.sampleRecords.count == 1)
            #expect(reopened.snapshot.incompleteReasons.contains(.pageLimit))
            #expect(reopened.snapshot.status == .interrupted)
        }
    }

    @Test func exclusiveLockDeniesSecondOwnerAndWrongPracticeOrHeader() throws {
        try o6WithDirectory { base in
            let initial = try o6Telemetry()
            let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
            defer { store.close() }
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: initial.header)
            }
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.create(base: base, telemetry: initial)
            }
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.open(base: base, practiceID: o6ID(999), expectedHeader: initial.header)
            }
            store.close()
            let wrong = try OwnerTelemetryHeader(authority: o6Authority(), practiceID: o6Practice,
                clock: RecordingClock(domainID: o6ID(999), monotonicAnchorSeconds: o6Mono,
                    wallAnchorUnixSeconds: o6Wall), runtimeGeneration: o6Runtime, clockUncertaintySeconds: 0)
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: wrong)
            }
        }
    }

    @Test(arguments: ["detached", "replaced", "hardlinked", "symlinked"])
    func liveLockIdentityWitnessRejectsReplacementForHeldAndCompetingOwners(damage: String) throws {
        try o6WithDirectory { base in
            let initial = try o6Telemetry()
            let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
            defer { store.close() }
            // The .lock path is part of the checked practice namespace. Its persisted identity
            // witness must reject a fresh path even if the old owner still holds the original FD.
            let lock = store.directoryURL.appendingPathComponent(".lock")
            #expect(FileManager.default.fileExists(atPath: lock.path))
            let originalBytes = try Data(contentsOf: lock)
            let displaced = base.appendingPathComponent("displaced-live-lock")
            try FileManager.default.moveItem(at: lock, to: displaced)
            let outside = base.appendingPathComponent("outside-lock-target")
            let outsideBytes = Data("synthetic outside lock target must remain unchanged".utf8)
            try outsideBytes.write(to: outside)
            switch damage {
            case "replaced":
                // Identical bytes do not restore the original inode or its held exclusive lease.
                try originalBytes.write(to: lock)
            case "hardlinked":
                try FileManager.default.linkItem(at: outside, to: lock)
            case "symlinked":
                try FileManager.default.createSymbolicLink(at: lock, withDestinationURL: outside)
            default:
                break // Missing lock must not be silently recreated by either acquisition path.
            }
            let replacementBytes: Data? = try damage == "detached" ? nil : Data(contentsOf: lock)
            let replacementInode = try? FileManager.default.attributesOfItem(atPath: lock.path)[.systemFileNumber]
                as? NSNumber
            let outsideLinks = try FileManager.default.attributesOfItem(atPath: outside.path)[.referenceCount]
                as? NSNumber
            // Try the competing owner FIRST: rejection cannot depend on the held owner noticing
            // replacement and subsequently writing a denial/poison record.
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.open(base: base, practiceID: o6Practice,
                    expectedHeader: initial.header)
            }
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.create(base: base, telemetry: initial)
            }
            #expect(throws: (any Error).self) {
                try store.update { _ = try o6Append([o6Sample(50, end: 10)], to: &$0) }
            }
            #expect(store.snapshot.sampleRecords.isEmpty)
            #expect(try Data(contentsOf: displaced) == originalBytes)
            #expect(try Data(contentsOf: outside) == outsideBytes)
            #expect(try FileManager.default.attributesOfItem(atPath: outside.path)[.referenceCount]
                as? NSNumber == outsideLinks)
            if damage == "detached" {
                #expect(!FileManager.default.fileExists(atPath: lock.path))
            } else {
                #expect(try Data(contentsOf: lock) == replacementBytes)
                #expect(try FileManager.default.attributesOfItem(atPath: lock.path)[.systemFileNumber]
                    as? NSNumber == replacementInode)
                if damage == "symlinked" {
                    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: lock.path) == outside.path)
                }
            }
        }
    }

    @Test func missingNamespacesNeverSilentlyCreateOrReset() throws {
        try o6WithDirectory { base in
            let header = try o6Header()
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: header)
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: base.path).isEmpty)
            let store = try OwnerTelemetryStore.create(base: base, telemetry: o6Telemetry())
            let directory = store.directoryURL
            store.close()
            try FileManager.default.removeItem(at: directory)
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: header)
            }
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.create(base: base, telemetry: o6Telemetry())
            }
            #expect(!FileManager.default.fileExists(atPath: directory.path))
        }
    }

    @Test func arbitraryPreexistingNamespaceIsNotAdopted() throws {
        try o6WithDirectory { base in
            let namespace = base.appendingPathComponent(OwnerTelemetryStore.directoryName)
            try FileManager.default.createDirectory(at: namespace, withIntermediateDirectories: false)
            let sentinel = namespace.appendingPathComponent("unowned.txt")
            try Data("unowned synthetic fixture".utf8).write(to: sentinel)
            let before = try o6Tree(base)
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.create(base: base, telemetry: o6Telemetry())
            }
            #expect(try o6Tree(base) == before)
        }
    }

    @Test(arguments: ["base", "namespace", "practice"])
    func directorySymlinksAreRejectedWithoutFollowingOrWritingOutside(location: String) throws {
        try o6WithDirectory { outer in
            let real = outer.appendingPathComponent("real")
            let outside = outer.appendingPathComponent("outside")
            try FileManager.default.createDirectory(at: real, withIntermediateDirectories: false)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
            try Data("outside sentinel".utf8).write(to: outside.appendingPathComponent("sentinel"))
            let before = try o6Tree(outside)
            var base = real
            if location == "base" {
                base = outer.appendingPathComponent("link")
                try FileManager.default.createSymbolicLink(at: base, withDestinationURL: outside)
            } else if location == "namespace" {
                try FileManager.default.createSymbolicLink(
                    at: real.appendingPathComponent(OwnerTelemetryStore.directoryName), withDestinationURL: outside)
            } else {
                let initial = try OwnerTelemetryStore.create(base: real, telemetry: o6Telemetry())
                let directory = initial.directoryURL
                initial.close()
                try FileManager.default.removeItem(at: directory)
                try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: outside)
            }
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.create(base: base, telemetry: o6Telemetry())
            }
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: o6Header())
            }
            #expect(try o6Tree(outside) == before)
        }
    }

    @Test(arguments: ["header.json", "telemetry.json", "manifest.json"])
    func componentSymlinksAndHardlinksAreRejected(name: String) throws {
        for useSymlink in [true, false] {
            try o6WithDirectory { base in
                let initial = try o6FinalizedTelemetry()
                let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
                let component = store.directoryURL.appendingPathComponent(name)
                store.close()
                let outside = base.appendingPathComponent("outside-component")
                try FileManager.default.moveItem(at: component, to: outside)
                if useSymlink {
                    try FileManager.default.createSymbolicLink(at: component, withDestinationURL: outside)
                } else {
                    try FileManager.default.linkItem(at: outside, to: component)
                }
                let before = try Data(contentsOf: outside)
                #expect(throws: (any Error).self) {
                    try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: initial.header)
                }
                #expect(try Data(contentsOf: outside) == before)
            }
        }
    }

    @Test func liveNamespaceReplacementPoisonsOwnerWithoutWritingReplacement() throws {
        try o6WithDirectory { base in
            let store = try OwnerTelemetryStore.create(base: base, telemetry: o6Telemetry())
            defer { store.close() }
            let directory = store.directoryURL
            let moved = directory.deletingLastPathComponent().appendingPathComponent("displaced")
            try FileManager.default.moveItem(at: directory, to: moved)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            let before = try o6Tree(directory)
            #expect(throws: (any Error).self) {
                try store.update { _ = try o6Append([o6Sample(50, end: 10)], to: &$0) }
            }
            #expect(throws: (any Error).self) {
                try store.update { _ = try o6Append([o6Sample(51, end: 11)], to: &$0) }
            }
            #expect(try o6Tree(directory) == before)
        }
    }

    @Test func liveComponentReplacementIsDetectedEvenWithIdenticalBytes() throws {
        try o6WithDirectory { base in
            let store = try OwnerTelemetryStore.create(base: base, telemetry: o6Telemetry())
            defer { store.close() }
            let path = store.directoryURL.appendingPathComponent("telemetry.json")
            let bytes = try Data(contentsOf: path)
            try FileManager.default.removeItem(at: path)
            try bytes.write(to: path)
            #expect(throws: (any Error).self) {
                try store.update { _ = try o6Append([o6Sample(50, end: 10)], to: &$0) }
            }
            #expect(try Data(contentsOf: path) == bytes)
        }
    }

    @Test(arguments: ["header.json", "telemetry.json", "manifest.json"])
    func missingTruncatedOrOversizedComponentsNeverReopenAsComplete(name: String) throws {
        for damage in ["missing", "truncated", "oversized"] {
            try o6WithDirectory { base in
                let initial = try o6FinalizedTelemetry()
                let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
                let path = store.directoryURL.appendingPathComponent(name)
                let bytes = try Data(contentsOf: path)
                store.close()
                switch damage {
                case "missing": try FileManager.default.removeItem(at: path)
                case "truncated": try Data(bytes.dropLast()).write(to: path)
                default: try Data(repeating: 32, count: 2 * 1_024 * 1_024 + 1).write(to: path)
                }
                #expect(throws: (any Error).self) {
                    try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: initial.header)
                }
            }
        }
    }

    @Test(arguments: ["unknownSchema", "wrongPractice", "duplicateComponent", "missingComponent",
                      "unsafeName", "wrongDigest", "wrongSize", "unexpectedFile"])
    func manifestExactInventoryAndIdentityRejectRecomputedChecksums(damage: String) throws {
        try o6WithDirectory { base in
            let initial = try o6FinalizedTelemetry()
            let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
            let directory = store.directoryURL
            store.close()
            let url = directory.appendingPathComponent("manifest.json")
            if damage == "unexpectedFile" {
                try Data("unlisted".utf8).write(to: directory.appendingPathComponent("extra.json"))
            } else {
                let corrupted = try o6RewriteEnvelope(Data(contentsOf: url), domain: "PSLOwnerTelemetryManifest1") {
                    if damage == "unknownSchema" { $0["schemaVersion"] = 2; return }
                    if damage == "wrongPractice" { $0["practiceID"] = o6ID(999).uuidString; return }
                    var entries = try #require($0["components"] as? [[String: Any]])
                    switch damage {
                    case "duplicateComponent": entries.append(entries[0])
                    case "missingComponent": entries.removeLast()
                    case "unsafeName": entries[0]["name"] = "../outside.json"
                    case "wrongDigest": entries[0]["sha256"] = String(repeating: "0", count: 64)
                    case "wrongSize": entries[0]["bytes"] = 0
                    default: break
                    }
                    $0["components"] = entries
                }
                try corrupted.write(to: url)
            }
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: initial.header)
            }
        }
    }

    @Test func recomputedComponentAndManifestChecksumsCannotHideSemanticCorruption() throws {
        try o6WithDirectory { base in
            let initial = try o6FinalizedTelemetry()
            let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
            let directory = store.directoryURL
            store.close()
            let path = directory.appendingPathComponent("telemetry.json")
            // This mutates a required semantic field and then repairs both checksum layers.
            let corrupted = try o6RewriteEnvelope(Data(contentsOf: path), domain: "PSLOwnerPracticeTelemetry1") {
                $0["schemaVersion"] = 2
            }
            try corrupted.write(to: path)
            try o6RehashManifest(directory)
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: initial.header)
            }
        }
    }

    @Test(arguments: [OwnerTelemetryStoreStage.componentTemporarySynced, .componentPublished,
                      .manifestTemporarySynced, .manifestPublished, .directorySynced])
    func failedPublicationPoisonsOwnerRetainsFailedIDAndReopensOnlyInterrupted(stage: OwnerTelemetryStoreStage) throws {
        struct Injected: Error {}
        try o6WithDirectory { base in
            let initial = try o6Telemetry()
            let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
            var fired = false
            store.failureInjector = {
                if !fired && $0 == stage { fired = true; throw Injected() }
            }
            #expect(throws: Injected.self) {
                try store.update {
                    _ = try o6Admit(to: &$0)
                    try $0.finalize(status: .ended, at: o6Instant(200), absenceReasons: [.noAccessibleHeartRateData])
                }
            }
            #expect(fired)
            #expect(throws: (any Error).self) {
                try store.update { _ = try o6Append([o6Sample(50, end: 10)], to: &$0) }
            }
            store.close()
            #expect(throws: (any Error).self) {
                try OwnerTelemetryStore.create(base: base, telemetry: initial)
            }
            // A readable committed checkpoint must remain interrupted. An unreadable failed
            // publication may reject open explicitly; it must never return an ended snapshot.
            do {
                let reopened = try OwnerTelemetryStore.open(base: base, practiceID: o6Practice,
                    expectedHeader: initial.header)
                defer { reopened.close() }
                #expect(reopened.snapshot.status == .interrupted)
                #expect(reopened.snapshot.incompleteReasons.contains(.reopenedPartial))
            } catch {
                #expect(try FileManager.default.contentsOfDirectory(atPath: base.path)
                    .contains(OwnerTelemetryStore.directoryName))
            }
        }
    }

    @Test func countedNativeDeletionStaysInvalidAcrossFinalPublicationAndReopen() throws {
        try o6WithDirectory { base in
            let initial = try o6RecoveryFixture()
            let store = try OwnerTelemetryStore.create(base: base, telemetry: initial)
            defer { store.close() }
            try store.update {
                try $0.recordEvent(OwnerTelemetryEvent(id: o6ID(900), at: o6Instant(195), reason: .sourceDeleted, count: 2))
                try $0.finalize(status: .ended, at: o6Instant(200), absenceReasons: [.sourceDeleted])
            }
            let frozen = try store.snapshot.encoded()
            store.close()
            let reopened = try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: initial.header)
            defer { reopened.close() }
            #expect(try reopened.snapshot.encoded() == frozen)
            #expect(reopened.snapshot.exclusionCounts[.sourceDeleted] == 2)
            #expect(try o6Summary(reopened.snapshot).at60.reason == .sourceDeleted)
            #expect(try o6Summary(reopened.snapshot).coverage == .invalid)
        }
    }

    @Test(arguments: ["allowed", "ended", "noEvent", "noAbsence", "noResidual", "ordinaryFuture", "beyondBoth"])
    func interruptedBackwardClockEndPreservesEvidenceWithoutAdmittingFutureSamples(scenario: String) throws {
        try o6WithDirectory { base in
            var telemetry = try o6RecoveryFixture()
            let times = scenario == "noResidual" ? [199.25, 199.5]
                : ["ordinaryFuture", "beyondBoth"].contains(scenario) ? [201.0, 202.0] : [171.0, 180.0]
            _ = try o6Append([o6Sample(2_000, end: times[0]), o6Sample(2_001, end: times[1])], to: &telemetry)
            let shift = scenario == "noResidual" ? -1.0 : scenario == "ordinaryFuture" ? 0 : -60
            let terminal = try o6Instant(200, wallAdjustment: shift)
            let originalSamples = telemetry.sampleRecords.map(\.sample), originalContext = try telemetry.sets[0].context.encoded()
            if !["noEvent", "ordinaryFuture"].contains(scenario) {
                try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(900), at: terminal, reason: .clockDiscontinuity))
            }
            let reasons: [OwnerTelemetryReason] = scenario == "noAbsence" ? [.interrupted] : [.interrupted, .clockDiscontinuity]
            if scenario != "allowed" {
                #expect(throws: (any Error).self) {
                    try telemetry.finalize(status: scenario == "ended" ? .ended : .interrupted, at: terminal, absenceReasons: reasons)
                }
                let deniedSamples = telemetry.sampleRecords.map(\.sample)
                #expect(telemetry.finalization == nil && deniedSamples == originalSamples)
                return
            }
            try telemetry.finalize(status: .interrupted, at: terminal, absenceReasons: reasons)
            #expect(telemetry.finalization?.endedAt == terminal)
            let retainedSamples = telemetry.sampleRecords.map(\.sample)
            #expect(retainedSamples == originalSamples)
            let retainedContext = try telemetry.sets[0].context.encoded()
            #expect(retainedContext == originalContext)
            let clockInvalid = telemetry.sampleRecords.filter { $0.sample.sourceEnd.timeIntervalSince1970 > terminal.wallUnixSeconds }
            let allClockInvalid = clockInvalid.allSatisfy { !$0.isEligible }
            #expect(!clockInvalid.isEmpty && allClockInvalid)
            let store = try OwnerTelemetryStore.create(base: base, telemetry: telemetry)
            let frozen = try store.snapshot.encoded()
            store.close()
            let reopened = try OwnerTelemetryStore.open(base: base, practiceID: o6Practice, expectedHeader: telemetry.header)
            defer { reopened.close() }
            #expect(try reopened.snapshot.encoded() == frozen)
            let summary = try o6Summary(reopened.snapshot)
            #expect(summary.at120.state == .missing && summary.at120.medianBPM == nil && summary.at120.dropBPM == nil)
            #expect(summary.at120.reason == .clockDiscontinuity && summary.coverage == .invalid)
        }
    }

    @Test(arguments: ["replaceInode", "overwriteInPlace"])
    func publicationRejectsSubstitutedCanonicalStageAndPoisonsHeldStore(mode: String) throws {
        try o6WithDirectory { base in
            let store = try OwnerTelemetryStore.create(base: base, telemetry: o6Telemetry())
            defer { store.close() }
            let directory = store.directoryURL
            let oldBytes = try Data(contentsOf: directory.appendingPathComponent("telemetry.json"))
            var fired = false
            store.failureInjector = { boundary in
                guard boundary == .componentTemporarySynced else { return }
                let stages = try FileManager.default.contentsOfDirectory(at: directory,
                    includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix(".stage-") }
                #expect(stages.count == 1)
                let stage = try #require(stages.first)
                let before = try FileManager.default.attributesOfItem(atPath: stage.path)[.systemFileNumber] as? NSNumber
                if mode == "replaceInode" {
                    try FileManager.default.removeItem(at: stage); try oldBytes.write(to: stage)
                } else {
                    let handle = try FileHandle(forWritingTo: stage)
                    defer { try? handle.close() }
                    try handle.truncate(atOffset: 0); try handle.write(contentsOf: oldBytes); try handle.synchronize()
                }
                let after = try FileManager.default.attributesOfItem(atPath: stage.path)[.systemFileNumber] as? NSNumber
                #expect(before != nil && after != nil && (mode == "replaceInode" ? before != after : before == after))
                fired = true
            }
            #expect(throws: (any Error).self) {
                try store.update { try $0.recordEvent(OwnerTelemetryEvent(id: o6ID(900), at: o6Instant(10), reason: .noAccessibleHeartRateData)) }
            }
            #expect(fired)
            store.failureInjector = nil
            #expect(throws: (any Error).self) { try store.update { _ = try o6Admit(to: &$0) } }
        }
    }
}
