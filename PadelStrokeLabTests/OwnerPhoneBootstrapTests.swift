import Darwin
import Foundation
import PadelCore
import Testing
@testable import PadelStrokeLab

private enum BootstrapTestFailure: Error { case injected, body }
private let bootstrapWitness = "OwnerPhoneBootstrap-v1"
private let bootstrapNamespaces = ["PracticeSetup-v1", "OwnerPractice-v1", "OwnerChannel-v2"]

@Suite(.serialized) struct OwnerPhoneBootstrapTests {
    @Test @MainActor func hostUsesExistingTemporaryFixtureAndConnectivityIsolation() throws {
        #expect(ProcessInfo.processInfo.arguments.contains("--motion-statistics-fixture=unavailable"))
        #expect(RecordingLibraryModel().isSyntheticUIReview)
    }

    @Test func freshInitializationAndReopenKeepOneEpochWithoutAuthorityOrRawChanges() throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        let paths = try RecordingPaths(base: f.base)
        let raw = paths.rawRoot.appendingPathComponent("retained-test-recording")
        try Data([0, 255, 19, 3]).write(to: raw)
        let recordings = try f.tree(at: f.base.appendingPathComponent("Recordings"))
        var owner: OwnerPhoneBootstrap? = try OwnerPhoneBootstrap(base: f.base)
        let (setup, channel) = try owner!.withStores { (try $0.checkedSnapshot(), try $1.readSnapshot()) }
        #expect(setup.preferences == nil && setup.latestDraft == nil && setup.highWater == nil)
        #expect(channel.authority == nil && channel.pending == nil && channel.admissionBlocked)
        #expect(try Data(contentsOf: f.witness) == readyWitness(setup.localInstallationEpoch))
        var before = stat(), after = stat()
        try #require(lstat(f.witness.path, &before) == 0)
        for _ in 0..<3 { #expect(try owner!.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch } == setup.localInstallationEpoch) }
        try #require(lstat(f.witness.path, &after) == 0)
        #expect(before.st_ino == after.st_ino && before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec)
        #expect(before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec)
        owner = nil
        let reopened = try OwnerPhoneBootstrap(base: f.base)
        #expect(try reopened.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch } == setup.localInstallationEpoch)
        #expect(try reopened.withStores { try $1.readSnapshot().authority } == nil)
        #expect(try f.tree(at: f.base.appendingPathComponent("Recordings")) == recordings)
    }

    @Test(arguments: [OwnerPhoneBootstrap.Stage.pendingSynced, .preferencesInitialized, .channelInitialized])
    func actualInitializationFaultLeavesPendingAndNeverHeals(stage: OwnerPhoneBootstrap.Stage) throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        var reached = false
        #expect(throws: BootstrapTestFailure.injected) {
            try OwnerPhoneBootstrap(base: f.base) { actual in
                guard actual == stage else { return }
                reached = true
                #expect(try Data(contentsOf: f.witness) == Data("PSLPhoneBootstrap1\npending\n".utf8))
                let expected: Set<String> = stage == .pendingSynced ? [] : stage == .preferencesInitialized
                    ? ["PracticeSetup-v1"] : Set(bootstrapNamespaces)
                let present = Set(try FileManager.default.contentsOfDirectory(atPath: f.base.path))
                #expect(present == expected.union([bootstrapWitness]))
                throw BootstrapTestFailure.injected
            }
        }
        #expect(reached)
        let preserved = try f.tree()
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: f.base) }
        #expect(try f.tree() == preserved)
    }

    @Test(arguments: ["pending", "partial", "unknown-version", "noncanonical", "wrong-epoch", "oversized", "empty"])
    func invalidWitnessNeverReinitializesOrChangesPriorEvidence(kind: String) throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        let epoch = try f.initialize()
        let bytes: Data
        switch kind {
        case "pending": bytes = Data("PSLPhoneBootstrap1\npending\n".utf8)
        case "partial": bytes = Data("PSLPhoneBootstrap1\nready\n".utf8)
        case "unknown-version": bytes = Data("PSLPhoneBootstrap2\nready\n\(epoch.uuidString)\n".utf8)
        case "noncanonical": bytes = Data("PSLPhoneBootstrap1\nready\naabbccdd-0011-2233-4455-66778899aabb\n".utf8)
        case "wrong-epoch": bytes = readyWitness(UUID())
        case "oversized": bytes = Data(repeating: 0x41, count: 129)
        default: bytes = Data()
        }
        try bytes.write(to: f.witness)
        let preserved = try f.tree()
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: f.base) }
        #expect(try f.tree() == preserved)
    }

    @Test(arguments: ["PracticeSetup-v1", "OwnerPractice-v1", "OwnerChannel-v2", "all"])
    func missingInitializedNamespacesNeverRecreateAnInstallation(name: String) throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        _ = try f.initialize()
        for removed in name == "all" ? bootstrapNamespaces : [name] {
            try FileManager.default.removeItem(at: f.base.appendingPathComponent(removed))
        }
        let preserved = try f.tree()
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: f.base) }
        #expect(try f.tree() == preserved)
    }

    @Test(arguments: ["PracticeSetup-v1/state.json", "OwnerPractice-v1/state.json", "OwnerChannel-v2/journal.json"])
    func corruptInitializedStoresRemainPreserved(path: String) throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        _ = try f.initialize()
        try Data("corrupt evidence".utf8).write(to: f.base.appendingPathComponent(path))
        let preserved = try f.tree()
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: f.base) }
        #expect(try f.tree() == preserved)
    }

    @Test(arguments: ["PracticeSetup-v1", "OwnerPractice-v1", "OwnerChannel-v2", "all"])
    func existingNamespaceWithoutWitnessCannotCountAsFirstUse(name: String) throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        if name == "all" {
            _ = try f.initialize()
            try FileManager.default.removeItem(at: f.witness)
        } else {
            try FileManager.default.createDirectory(at: f.base.appendingPathComponent(name), withIntermediateDirectories: false)
        }
        let preserved = try f.tree()
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: f.base) }
        #expect(try f.tree() == preserved)
    }

    @Test(arguments: [OwnerPracticeDevice.phone, .watch])
    func foreignChannelEpochOrRoleIsRejected(device: OwnerPracticeDevice) throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        let epoch: UUID
        do {
            let setup = try PracticeSetupStore(base: f.base)
            epoch = try setup.checkedSnapshot().localInstallationEpoch
            let channel = try PracticeSetupChannel(base: f.base,
                localInstallationEpoch: device == .phone ? UUID() : epoch, device: device, intent: .createNew)
            #expect(try channel.readSnapshot().authority == nil)
        }
        try readyWitness(epoch).write(to: f.witness)
        let preserved = try f.tree()
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: f.base) }
        #expect(try f.tree() == preserved)
    }

    @Test func concurrentSecondOwnerCannotDetachTheFirstLock() throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        let owner = try OwnerPhoneBootstrap(base: f.base)
        let epoch = try owner.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch }
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: f.base) }
        #expect(try owner.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch } == epoch)
    }

    @Test(arguments: ["symlink", "hardlink", "directory", "fifo"])
    func unsafeWitnessTypeIsRejectedWithoutFollowingOrDeleting(kind: String) throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        let outside = f.root.appendingPathComponent("retained-target")
        try Data("untouched".utf8).write(to: outside)
        switch kind {
        case "symlink": try FileManager.default.createSymbolicLink(at: f.witness, withDestinationURL: outside)
        case "hardlink": try FileManager.default.linkItem(at: outside, to: f.witness)
        case "directory": try FileManager.default.createDirectory(at: f.witness, withIntermediateDirectories: false)
        default: try #require(mkfifo(f.witness.path, 0o600) == 0)
        }
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: f.base) }
        #expect(try Data(contentsOf: outside) == Data("untouched".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.base.path) == [bootstrapWitness])
    }

    @Test func symlinkBaseNamespaceAndRecordingsBaseAreRejected() throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        let link = f.root.appendingPathComponent("linked-base")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: f.base)
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: link) }
        let recordings = f.base.appendingPathComponent("Recordings")
        try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: recordings) }
        _ = try f.initialize()
        let original = f.base.appendingPathComponent("PracticeSetup-v1")
        let retained = f.root.appendingPathComponent("retained-setup")
        try FileManager.default.moveItem(at: original, to: retained)
        try FileManager.default.createSymbolicLink(at: original, withDestinationURL: retained)
        #expect(throws: (any Error).self) { try OwnerPhoneBootstrap(base: f.base) }
        #expect(!FileManager.default.fileExists(atPath: recordings.appendingPathComponent(bootstrapWitness).path))
    }

    @Test(arguments: [bootstrapWitness, "PracticeSetup-v1", "OwnerPractice-v1", "OwnerChannel-v2", "base"])
    func liveIdentityReplacementOrDetachmentPoisonsBeforeBody(name: String) throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        let owner = try OwnerPhoneBootstrap(base: f.base)
        let path = name == "base" ? f.base : f.base.appendingPathComponent(name)
        let saved = f.root.appendingPathComponent("detached")
        try FileManager.default.moveItem(at: path, to: saved)
        if name == bootstrapWitness { try Data(contentsOf: saved).write(to: path) }
        else { try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false) }
        var entered = false
        #expect(throws: (any Error).self) { try owner.withStores { _, _ in entered = true } }
        #expect(!entered)
        try FileManager.default.removeItem(at: path)
        try FileManager.default.moveItem(at: saved, to: path)
        #expect(throws: OwnerPhoneBootstrap.Failure.poisoned) { try owner.withStores { _, _ in () } }
    }

    @Test(arguments: ["PracticeSetup-v1/state.json", "OwnerPractice-v1/state.json", "OwnerChannel-v2/journal.json", bootstrapWitness])
    func liveBackingStateIsCheckedBeforeBody(path: String) throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        let owner = try OwnerPhoneBootstrap(base: f.base), file = f.base.appendingPathComponent(path)
        let bytes = try Data(contentsOf: file)
        var before = stat(), after = stat()
        try #require(lstat(file.path, &before) == 0)
        try Data("tampered".utf8).write(to: file)
        try #require(lstat(file.path, &after) == 0)
        #expect(before.st_dev == after.st_dev && before.st_ino == after.st_ino)
        var entered = false
        #expect(throws: (any Error).self) { try owner.withStores { _, _ in entered = true } }
        #expect(!entered)
        try bytes.write(to: file)
        #expect(throws: OwnerPhoneBootstrap.Failure.poisoned) { try owner.withStores { _, _ in () } }
    }

    @Test(arguments: [false, true], ["PracticeSetup-v1/state.json", "OwnerPractice-v1/state.json", "OwnerChannel-v2/journal.json", bootstrapWitness])
    func postCheckDetectsTamperingAfterSuccessfulOrThrowingBody(throwsBody: Bool, path: String) throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        let owner = try OwnerPhoneBootstrap(base: f.base), file = f.base.appendingPathComponent(path)
        let bytes = try Data(contentsOf: file)
        var before = stat(), after = stat()
        try #require(lstat(file.path, &before) == 0)
        do {
            try owner.withStores { _, _ in
                try Data("tampered in body".utf8).write(to: file)
                try #require(lstat(file.path, &after) == 0)
                #expect(before.st_dev == after.st_dev && before.st_ino == after.st_ino)
                if throwsBody { throw BootstrapTestFailure.body }
            }
            Issue.record("A successful result must not escape a failed post-check")
        } catch BootstrapTestFailure.body { Issue.record("Integrity failure must take precedence over the body error") }
        catch { }
        try bytes.write(to: file)
        #expect(throws: OwnerPhoneBootstrap.Failure.poisoned) { try owner.withStores { _, _ in () } }
    }

    @Test func expectedBodyErrorsDoNotPoisonHealthyStorage() throws {
        let f = try BootstrapFixture(); defer { f.remove() }
        let owner = try OwnerPhoneBootstrap(base: f.base)
        #expect(throws: BootstrapTestFailure.body) { try owner.withStores { _, _ -> Void in throw BootstrapTestFailure.body } }
        #expect(try owner.withStores { try $1.readSnapshot().authority } == nil)
    }

    @Test func conflictingRestrictionKeepsItsFenceAndAllowsExplicitResolution() throws {
        let f = try BootstrapFixture(), peer = try BootstrapFixture(); defer { f.remove(); peer.remove() }
        let owner = try OwnerPhoneBootstrap(base: f.base), watchEpoch = UUID()
        let phoneEpoch = try owner.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch }
        let proposed = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: phoneEpoch,
            watchInstallationEpoch: watchEpoch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
            includesHeartRate: true, decisionID: UUID(), confirmedAtUnixSeconds: 1, policyDigest: OwnerPracticePolicy.digest)
        let watch = try PracticeSetupChannel(base: peer.base, localInstallationEpoch: watchEpoch, device: .watch, intent: .createNew)
        let enrollment = try OwnerAuthorityMutation.enrollment(proposed)
        try owner.withStores { _, channel in try channel.request(enrollment); _ = try channel.dispatchPending() }
        let withdrawal = try OwnerAuthorityMutation.withdraw(from: proposed, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        #expect(throws: OwnerChannelError.intentOutstanding) { try owner.withStores { _, channel in try channel.request(withdrawal) } }
        let blocked = try owner.withStores { try $1.readSnapshot() }
        #expect(blocked.unqueuedRestriction == .all && blocked.pending?.mutation == enrollment && blocked.motionAccessBlocked)
        let applied = try watch.sequence(enrollment)
        try watch.acknowledge(owner.withStores { try $1.mirror(applied) })
        let stillBlocked = try owner.withStores { try $1.readSnapshot() }
        #expect(stillBlocked.pending == nil && stillBlocked.unqueuedRestriction == .all && stillBlocked.motionAccessBlocked)
        let current = try #require(stillBlocked.authority)
        let final = try OwnerAuthorityMutation.withdraw(from: current, decisionID: UUID(), confirmedAtUnixSeconds: 3)
        let sent = try owner.withStores { _, channel in try channel.request(final); return try channel.dispatchPending() }
        let withdrawn = try watch.sequence(sent)
        try watch.acknowledge(owner.withStores { try $1.mirror(withdrawn) })
        let resolved = try owner.withStores { try $1.readSnapshot() }
        #expect(resolved.unqueuedRestriction == .none && resolved.authority?.isCollectionAllowed == false)
    }
}

private func readyWitness(_ epoch: UUID) -> Data { Data("PSLPhoneBootstrap1\nready\n\(epoch.uuidString)\n".utf8) }

private struct BootstrapFixture {
    let root: URL
    let base: URL
    var witness: URL { base.appendingPathComponent(bootstrapWitness) }
    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("PSLOwnerBootstrap-" + UUID().uuidString, isDirectory: true)
        base = root.appendingPathComponent("base", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
    func initialize() throws -> UUID {
        let owner = try OwnerPhoneBootstrap(base: base)
        return try owner.withStores { setup, _ in try setup.checkedSnapshot().localInstallationEpoch }
    }
    func tree(at directory: URL? = nil) throws -> [String: Data] {
        let directory = directory ?? base
        var result: [String: Data] = [:]
        for name in try FileManager.default.contentsOfDirectory(atPath: directory.path) {
            let path = directory.appendingPathComponent(name)
            var info = stat(); try #require(lstat(path.path, &info) == 0)
            if info.st_mode & S_IFMT == S_IFDIR {
                result[name + "/"] = Data()
                for (child, bytes) in try tree(at: path) { result[name + "/" + child] = bytes }
            } else if info.st_mode & S_IFMT == S_IFREG { result[name] = try Data(contentsOf: path) }
            else { result[name] = Data("non-regular".utf8) }
        }
        return result
    }
}
