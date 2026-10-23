import Darwin
import Foundation
import Testing
@testable import PadelCore

private enum SetupInjectedFailure: Error { case write }

struct PracticeSetupStoreTests {
    @Test func checkedReadsPreserveStateLockAndDirectory() throws {
        let fixture = try RecordingDirectoryFixture(), store = try PracticeSetupStore(base: fixture.root)
        let original = store.snapshot
        let before = try SetupCheckedReadFingerprint(directory: store.directoryURL)
        for _ in 0..<5 { #expect(try store.checkedSnapshot() == original) }
        #expect(try SetupCheckedReadFingerprint(directory: store.directoryURL) == before)
        #expect(original.preferences == nil && original.latestDraft == nil && original.highWater == nil)
    }

    @Test func checkedReadReturnsActualSavedPreferencesSuggestionAndBookkeeping() throws {
        let fixture = try RecordingDirectoryFixture(), store = try PracticeSetupStore(base: fixture.root)
        let epoch = store.snapshot.localInstallationEpoch, first = try setupDraft(), next = try setupDraft(revision: 2)
        try store.savePreferences(first.preferences)
        let preferences = try store.checkedSnapshot()
        #expect(preferences.preferences == first.preferences)
        #expect(preferences.latestDraft == nil && preferences.highWater == nil)
        try store.saveSuggestion(first)
        let suggestion = try store.checkedSnapshot()
        #expect(suggestion.latestDraft == first && suggestion.highWater == nil)
        #expect(try store.recordExplicitPreparation(first) == .recorded)
        try store.saveSuggestion(next)
        let bookkeeping = try store.checkedSnapshot()
        #expect(bookkeeping.preferences == first.preferences && bookkeeping.latestDraft == next)
        #expect(bookkeeping.highWater == first.identity && bookkeeping.localInstallationEpoch == epoch)
        let before = try SetupCheckedReadFingerprint(directory: store.directoryURL)
        for _ in 0..<5 { #expect(try store.checkedSnapshot() == bookkeeping) }
        #expect(try SetupCheckedReadFingerprint(directory: store.directoryURL) == before)
    }

    @Test(arguments: ["valid-state-replacement", "missing-state", "replaced-lock",
                      "detached-namespace", "replaced-namespace", "unexpected-entry"])
    func checkedReadRejectsTamperingAndRemainsPoisonedAfterRestoration(attack: String) throws {
        let fixture = try RecordingDirectoryFixture(), store = try PracticeSetupStore(base: fixture.root)
        try store.savePreferences(setupDraft().preferences)
        let original = try store.checkedSnapshot(), directory = store.directoryURL
        let state = directory.appendingPathComponent("state.json"), lock = directory.appendingPathComponent(".lock")
        let retained = fixture.root.appendingPathComponent("retained-original")
        let manager = FileManager.default
        let restore: () throws -> Void
        switch attack {
        case "valid-state-replacement":
            // Obtain independently valid, checksummed bytes through the real store, not a forged codec.
            let other = try RecordingDirectoryFixture(), donor = try PracticeSetupStore(base: other.root)
            let replacement = try Data(contentsOf: donor.directoryURL.appendingPathComponent("state.json"))
            let bytes = try Data(contentsOf: state)
            #expect(try donor.checkedSnapshot().localInstallationEpoch != original.localInstallationEpoch)
            #expect(replacement != bytes)
            try replacement.write(to: state)
            restore = { try bytes.write(to: state) }
        case "missing-state":
            try manager.moveItem(at: state, to: retained)
            restore = { try manager.moveItem(at: retained, to: state) }
        case "replaced-lock":
            try manager.moveItem(at: lock, to: retained)
            try Data().write(to: lock)
            restore = { try manager.removeItem(at: lock); try manager.moveItem(at: retained, to: lock) }
        case "detached-namespace", "replaced-namespace":
            try manager.moveItem(at: directory, to: retained)
            if attack == "replaced-namespace" {
                try manager.createDirectory(at: directory, withIntermediateDirectories: false)
            }
            restore = {
                if attack == "replaced-namespace" { try manager.removeItem(at: directory) }
                try manager.moveItem(at: retained, to: directory)
            }
        default:
            let unexpected = directory.appendingPathComponent("unexpected")
            try Data("untrusted entry".utf8).write(to: unexpected)
            restore = { try manager.removeItem(at: unexpected) }
        }
        #expect(throws: (any Error).self) { try store.checkedSnapshot() }
        #expect(store.snapshot == original)
        try restore()
        let restored = try SetupCheckedReadFingerprint(directory: directory)
        #expect(throws: PracticeSetupError.poisoned) { try store.checkedSnapshot() }
        #expect(throws: PracticeSetupError.poisoned) { try store.savePreferences(setupDraft().preferences) }
        #expect(try SetupCheckedReadFingerprint(directory: directory) == restored)
        #expect(store.snapshot == original)
    }

    @Test func freshPersistenceAndRelaunchContainNoAuthority() throws {
        let fixture = try RecordingDirectoryFixture()
        let draft = try setupDraft()
        var epoch: UUID!
        do {
            let store = try PracticeSetupStore(base: fixture.root)
            epoch = store.snapshot.localInstallationEpoch
            #expect(store.snapshot.preferences == nil && store.snapshot.latestDraft == nil && store.snapshot.highWater == nil)
            try store.savePreferences(draft.preferences)
            try store.saveSuggestion(draft)
            #expect(try store.recordExplicitPreparation(draft) == .recorded)
        }
        let reopened = try PracticeSetupStore(base: fixture.root)
        #expect(reopened.snapshot.localInstallationEpoch == epoch)
        #expect(reopened.snapshot.preferences == draft.preferences)
        #expect(reopened.snapshot.latestDraft == draft && reopened.snapshot.highWater == draft.identity)
        #expect(try reopened.recordExplicitPreparation(draft) == .duplicate)
        let bytes = try Data(contentsOf: reopened.directoryURL.appendingPathComponent("state.json"))
        let text = String(decoding: bytes, as: UTF8.self)
        for forbidden in ["acceptedCurrent", "acceptedNext", "physicalConfirmation", "runtimeGeneration", "preparationGeneration", "startConsent"] {
            #expect(!text.contains(forbidden))
        }
    }

    @Test func revisionIdentityConflictAndExplicitOriginReplacement() throws {
        let fixture = try RecordingDirectoryFixture(), store = try PracticeSetupStore(base: fixture.root)
        let first = try setupDraft(), newer = try setupDraft(revision: 2, preparation: UUID())
        try store.saveSuggestion(first)
        #expect(try store.recordExplicitPreparation(first) == .recorded)
        #expect(try store.recordExplicitPreparation(first) == .duplicate)
        #expect(throws: (any Error).self) { try store.recordExplicitPreparation(setupDraft(hand: .left)) }
        #expect(throws: (any Error).self) { try store.recordExplicitPreparation(setupDraft(preparation: UUID())) }
        #expect(try store.recordExplicitPreparation(newer) == .recorded)
        #expect(throws: (any Error).self) { try store.saveSuggestion(first) }
        #expect(throws: (any Error).self) { try store.recordExplicitPreparation(first) }
        let newOrigin = try setupDraft(origin: UUID())
        #expect(throws: (any Error).self) { try store.saveSuggestion(newOrigin) }
        #expect(throws: (any Error).self) { try store.recordExplicitPreparation(newOrigin) }
        #expect(store.snapshot.highWater == newer.identity)
        #expect(try store.recordExplicitPreparation(newOrigin, allowsOriginReplacement: true) == .recorded)
        #expect(store.snapshot.highWater == newOrigin.identity && store.snapshot.latestDraft == newOrigin)
        #expect(throws: (any Error).self) { try store.saveSuggestion(newer) }
        #expect(throws: (any Error).self) { try store.recordExplicitPreparation(newer) }
    }

    @Test func suggestionsNeverAdvanceBookkeepingAndDuplicatesNeverDowngradeSuggestion() throws {
        let fixture = try RecordingDirectoryFixture(), store = try PracticeSetupStore(base: fixture.root)
        let first = try setupDraft(), next = try setupDraft(revision: 3)
        try store.saveSuggestion(first)
        #expect(store.snapshot.highWater == nil)
        #expect(try store.recordExplicitPreparation(first) == .recorded)
        try store.saveSuggestion(next)
        #expect(store.snapshot.highWater == first.identity && store.snapshot.latestDraft == next)
        #expect(try store.recordExplicitPreparation(first) == .duplicate)
        #expect(store.snapshot.latestDraft == next)
        #expect(throws: (any Error).self) { try store.recordExplicitPreparation(setupDraft(revision: 2)) }
        #expect(try store.recordExplicitPreparation(next) == .recorded)
    }

    @Test(arguments: [PracticeSetupStoreWriteStage.afterTemporarySync, .afterRename])
    func failedAtomicWriteNeverReturnsSuccessAndPoisonsOwner(stage: PracticeSetupStoreWriteStage) throws {
        let fixture = try RecordingDirectoryFixture(), first = try setupDraft(), next = try setupDraft(revision: 2)
        do {
            let store = try PracticeSetupStore(base: fixture.root)
            _ = try store.recordExplicitPreparation(first)
            store.writeFault = { actual in if actual == stage { throw SetupInjectedFailure.write } }
            #expect(throws: SetupInjectedFailure.write) { try store.recordExplicitPreparation(next) }
            #expect(store.snapshot.highWater == first.identity)
            #expect(throws: (any Error).self) { try store.recordExplicitPreparation(first) }
            #expect(throws: (any Error).self) { try store.savePreferences(first.preferences) }
        }
        let reopened = try PracticeSetupStore(base: fixture.root)
        #expect(reopened.snapshot.highWater == (stage == .afterRename ? next.identity : first.identity))
        // Even a post-rename surviving high-water record carries no reusable acceptance or consent.
        #expect(try reopened.recordExplicitPreparation(next) == (stage == .afterRename ? .duplicate : .recorded))
    }

    @Test func missingAfterInitializationFailsClosedAcrossReopen() throws {
        let fixture = try RecordingDirectoryFixture()
        var file: URL!
        do { file = try PracticeSetupStore(base: fixture.root).directoryURL.appendingPathComponent("state.json") }
        try FileManager.default.removeItem(at: file)
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: fixture.root) }
        #expect(!FileManager.default.fileExists(atPath: file.path))
        let empty = try RecordingDirectoryFixture()
        try FileManager.default.createDirectory(at: empty.root.appendingPathComponent("PracticeSetup-v1"), withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: empty.root) }
    }

    @Test(arguments: [Data("{}".utf8), Data("truncated".utf8), Data(repeating: 0x20, count: 16_385)])
    func corruptionAndOversizeArePreserved(bytes: Data) throws {
        let fixture = try RecordingDirectoryFixture()
        var file: URL!
        do { file = try PracticeSetupStore(base: fixture.root).directoryURL.appendingPathComponent("state.json") }
        try bytes.write(to: file)
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: fixture.root) }
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func checksumCatchesValidJSONMutationAndLiveDeletionFailsClosed() throws {
        let fixture = try RecordingDirectoryFixture()
        var file: URL!
        do {
            let store = try PracticeSetupStore(base: fixture.root)
            try store.saveSuggestion(setupDraft())
            file = store.directoryURL.appendingPathComponent("state.json")
        }
        let original = try Data(contentsOf: file)
        let changed = Data(String(decoding: original, as: UTF8.self)
            .replacingOccurrences(of: "\"usualHand\":\"right\"", with: "\"usualHand\":\"left\"").utf8)
        #expect(changed != original)
        try changed.write(to: file)
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: fixture.root) }
        try original.write(to: file)
        let store = try PracticeSetupStore(base: fixture.root)
        try FileManager.default.removeItem(at: file)
        #expect(throws: (any Error).self) { try store.savePreferences(setupDraft().preferences) }
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func noFollowPathsHardLinksAndCompetingOwner() throws {
        let fixture = try RecordingDirectoryFixture(), other = try RecordingDirectoryFixture()
        let link = fixture.root.appendingPathComponent("linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: other.root)
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: link) }
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: URL(string: "https://example.com/setup")!) }
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: fixture.root.appendingPathComponent("missing")) }
        let store = try PracticeSetupStore(base: fixture.root)
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: fixture.root) }
        let stateFile = store.directoryURL.appendingPathComponent("state.json")
        try FileManager.default.linkItem(at: stateFile, to: fixture.root.appendingPathComponent("hard-link"))
        #expect(throws: (any Error).self) { try store.saveSuggestion(setupDraft()) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: other.root.path).isEmpty)
    }

    @Test func interruptedTemporaryIsBoundedAndOriginalRecordingBytesUnchanged() throws {
        let fixture = try RecordingDirectoryFixture()
        let recordings = fixture.root.appendingPathComponent("Recordings")
        try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: false)
        let rawFile = recordings.appendingPathComponent("retained-original")
        let original = Data([0, 1, 255, 10]); try original.write(to: rawFile)
        var directory: URL!
        do { directory = try PracticeSetupStore(base: fixture.root).directoryURL }
        try Data("interrupted write".utf8).write(to: directory.appendingPathComponent("state.pending"))
        let store = try PracticeSetupStore(base: fixture.root)
        for revision: Int64 in 1...150 { _ = try store.recordExplicitPreparation(setupDraft(revision: revision)) }
        let entries = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(Set(entries) == ["state.json", ".lock"])
        #expect(try Data(contentsOf: directory.appendingPathComponent("state.json")).count < 16_384)
        #expect(try Data(contentsOf: rawFile) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: recordings.path) == ["retained-original"])
    }
    @Test func removedLockPoisonsPreviousOwnerBeforeMutation() throws {
        let fixture = try RecordingDirectoryFixture(), store = try PracticeSetupStore(base: fixture.root)
        try FileManager.default.removeItem(at: store.directoryURL.appendingPathComponent(".lock"))
        #expect(throws: (any Error).self) { try store.saveSuggestion(setupDraft()) }
        #expect(store.snapshot.latestDraft == nil)
    }

    @Test(arguments: ["state.json", "state.pending"])
    func unsafeStateAndTemporaryLinksAreNotFollowed(name: String) throws {
        let fixture = try RecordingDirectoryFixture(), other = try RecordingDirectoryFixture()
        var directory: URL!
        do { directory = try PracticeSetupStore(base: fixture.root).directoryURL }
        let target = other.root.appendingPathComponent("untouched")
        let original = Data("private retained bytes".utf8); try original.write(to: target)
        let path = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }
        try FileManager.default.createSymbolicLink(at: path, withDestinationURL: target)
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: fixture.root) }
        #expect(try Data(contentsOf: target) == original)
    }

    @Test func renamedNamespaceAndUnexpectedEntriesFailClosed() throws {
        let fixture = try RecordingDirectoryFixture(), store = try PracticeSetupStore(base: fixture.root)
        let renamed = fixture.root.appendingPathComponent("preserved-setup")
        try FileManager.default.moveItem(at: store.directoryURL, to: renamed)
        #expect(throws: (any Error).self) { try store.saveSuggestion(setupDraft()) }
        #expect(store.snapshot.latestDraft == nil)
        let other = try RecordingDirectoryFixture()
        var directory: URL!
        do { directory = try PracticeSetupStore(base: other.root).directoryURL }
        try Data().write(to: directory.appendingPathComponent("unexpected"))
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: other.root) }
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("unexpected").path))
        let raw = other.root.appendingPathComponent("Recordings")
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try PracticeSetupStore(base: raw) }
    }

}

private struct SetupCheckedReadFingerprint: Equatable {
    private struct Entry: Equatable {
        let name: String
        let device: dev_t
        let inode: ino_t
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int
        let bytes: Data?
    }
    private let entries: [Entry]

    init(directory: URL) throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        entries = try ([directory] + names.map { directory.appendingPathComponent($0) }).map { path in
            var info = stat()
            try #require(lstat(path.path, &info) == 0)
            return Entry(name: path.lastPathComponent, device: info.st_dev, inode: info.st_ino,
                         modifiedSeconds: info.st_mtimespec.tv_sec,
                         modifiedNanoseconds: info.st_mtimespec.tv_nsec,
                         bytes: info.st_mode & S_IFMT == S_IFREG ? try Data(contentsOf: path) : nil)
        }
    }
}
