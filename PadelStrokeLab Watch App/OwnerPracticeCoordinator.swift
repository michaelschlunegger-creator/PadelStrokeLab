import Foundation
import Darwin
import Observation
import PadelCore

extension WatchRuntimeEnvironment {
    var isCoherentFixture: Bool {
        guard let fixtureID, !allowsHardware, failure == nil,
            let expected = try? Self.resolve(arguments: ["--owner-watch-fixture=\(fixtureID.uuidString)"], environment: [:]) else { return false }
        return base == expected.base && preferenceSuite == expected.preferenceSuite
    }
}
/// Untrusted discovery is bounded and descriptor-relative; O6 still owns recovery validation/publication.
nonisolated enum OwnerPracticeRecoveryReader {
    private struct Node: Equatable {
        let device: dev_t, inode: ino_t, mode: mode_t, links: nlink_t, owner: uid_t, size: off_t
        let modifiedSeconds: Int, modifiedNanoseconds: Int, changedSeconds: Int, changedNanoseconds: Int
        init(_ info: stat) {
            device = info.st_dev; inode = info.st_ino; mode = info.st_mode; links = info.st_nlink
            owner = info.st_uid; size = info.st_size
            modifiedSeconds = info.st_mtimespec.tv_sec; modifiedNanoseconds = info.st_mtimespec.tv_nsec
            changedSeconds = info.st_ctimespec.tv_sec; changedNanoseconds = info.st_ctimespec.tv_nsec
        }
        var directory: Bool { mode & S_IFMT == S_IFDIR }
        var regular: Bool { mode & S_IFMT == S_IFREG && links == 1 && owner == getuid() }
    }
    static func forEachCandidate(base: URL, visit: (OwnerPracticeTelemetry) throws -> Void) throws {
        let baseFD = try openBase(base)
        defer { Darwin.close(baseFD) }
        let baseNode = try node(baseFD), markerName = "." + OwnerTelemetryStore.directoryName
        let marker = try named(markerName, in: baseFD)
        let namespaceFD = openat(baseFD, OwnerTelemetryStore.directoryName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard namespaceFD >= 0 else {
            guard errno == ENOENT, marker == nil else { throw OwnerTelemetryError.integrity }
            return
        }
        defer { Darwin.close(namespaceFD) }
        guard let marker, marker.regular, marker.size <= 4096 else { throw OwnerTelemetryError.integrity }
        let namespaceNode = try node(namespaceFD)
        guard namespaceNode.directory, try named(OwnerTelemetryStore.directoryName, in: baseFD) == namespaceNode else {
            throw OwnerTelemetryError.integrity
        }
        // Establish the complete entry/practice budget before decoding or invoking any visitor.
        let entries = try names(in: namespaceFD)
        var practices: [String] = []
        for name in entries {
            let practice = name.hasPrefix(".used-") ? String(name.dropFirst(6)) : name
            guard let id = UUID(uuidString: practice), id.uuidString.lowercased() == practice,
                  entries.contains(practice), entries.contains(".used-" + practice) else { throw OwnerTelemetryError.integrity }
            if !name.hasPrefix(".used-") { practices.append(name) }
        }
        guard practices.count <= 512, entries.count == practices.count * 2 else { throw OwnerTelemetryError.capacity }
        try stableDirectory(namespaceFD, expected: namespaceNode)
        for name in practices.sorted() {
            let witnessName = ".used-" + name
            guard let witness = try named(witnessName, in: namespaceFD), witness.regular, witness.size <= 4096 else {
                throw OwnerTelemetryError.integrity
            }
            let practiceFD = openat(namespaceFD, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard practiceFD >= 0 else { throw OwnerTelemetryError.integrity }
            defer { Darwin.close(practiceFD) }
            let practiceNode = try node(practiceFD)
            guard practiceNode.directory, try named(name, in: namespaceFD) == practiceNode else { throw OwnerTelemetryError.integrity }
            if try named("telemetry.json", in: practiceFD) == nil,
               let practiceID = UUID(uuidString: name),
               try OwnerPracticeDeletionProof.isCompleted(base: base, practiceID: practiceID) {
                let reopened = try openBase(base)
                defer { Darwin.close(reopened) }
                guard try node(practiceFD) == practiceNode, try named(name, in: namespaceFD) == practiceNode,
                      try named(witnessName, in: namespaceFD) == witness,
                      try named(markerName, in: baseFD) == marker,
                      try node(reopened) == baseNode, try node(baseFD) == baseNode,
                      try named(OwnerTelemetryStore.directoryName, in: baseFD) == namespaceNode else {
                    throw OwnerTelemetryError.integrity
                }
                try stableDirectory(namespaceFD, expected: namespaceNode)
                continue
            }
            let payloadFD = openat(practiceFD, "telemetry.json", O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard payloadFD >= 0 else { throw OwnerTelemetryError.integrity }
            defer { Darwin.close(payloadFD) }
            let payloadNode = try node(payloadFD)
            guard payloadNode.regular, payloadNode.size >= 0, payloadNode.size <= off_t(OwnerPracticeTelemetry.maximumBytes),
                  try named("telemetry.json", in: practiceFD) == payloadNode else { throw OwnerTelemetryError.integrity }
            let bytes = try read(payloadFD, size: Int(payloadNode.size))
            guard try node(payloadFD) == payloadNode else { throw OwnerTelemetryError.integrity }
            let candidate = try OwnerPracticeTelemetry.decode(bytes)
            guard candidate.header.practiceID.uuidString.lowercased() == name else { throw OwnerTelemetryError.integrity }
            let reopenedBase = try openBase(base)
            defer { Darwin.close(reopenedBase) }
            try verifyBytes(payloadFD, bytes: bytes)
            guard try node(payloadFD) == payloadNode, try named("telemetry.json", in: practiceFD) == payloadNode,
                  try node(practiceFD) == practiceNode, try named(name, in: namespaceFD) == practiceNode,
                  try named(witnessName, in: namespaceFD) == witness,
                  try named(markerName, in: baseFD) == marker else { throw OwnerTelemetryError.integrity }
            try stableDirectory(namespaceFD, expected: namespaceNode)
            guard try node(reopenedBase) == baseNode, try node(baseFD) == baseNode,
                  try named(OwnerTelemetryStore.directoryName, in: baseFD) == namespaceNode else {
                throw OwnerTelemetryError.integrity
            }
            try visit(candidate)
        }
    }
    private static func openBase(_ base: URL) throws -> Int32 {
        guard base.isFileURL, base.path.hasPrefix("/"), base.path.utf8.count <= Int(PATH_MAX), !base.path.utf8.contains(0),
              !base.pathComponents.contains(".."), !base.pathComponents.contains(".") else { throw OwnerTelemetryError.integrity }
        var current = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard current >= 0 else { throw OwnerTelemetryError.unavailable }
        do {
            for component in base.path.split(separator: "/").map(String.init) {
                let next = openat(current, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard next >= 0 else { throw OwnerTelemetryError.integrity }
                do {
                    let opened = try node(next)
                    guard opened.directory, try named(component, in: current) == opened else { throw OwnerTelemetryError.integrity }
                } catch { Darwin.close(next); throw error }
                Darwin.close(current); current = next
            }
            return current
        } catch { Darwin.close(current); throw error }
    }
    private static func node(_ fd: Int32) throws -> Node {
        var info = stat()
        guard fstat(fd, &info) == 0 else { throw OwnerTelemetryError.integrity }
        return Node(info)
    }
    private static func named(_ name: String, in directory: Int32) throws -> Node? {
        var info = stat()
        if fstatat(directory, name, &info, AT_SYMLINK_NOFOLLOW) != 0 {
            if errno == ENOENT { return nil }
            throw OwnerTelemetryError.integrity
        }
        return Node(info)
    }
    private static func stableDirectory(_ fd: Int32, expected: Node) throws {
        guard try node(fd) == expected else { throw OwnerTelemetryError.integrity }
    }
    private static func names(in directory: Int32) throws -> Set<String> {
        let copy = dup(directory)
        guard copy >= 0 else { throw OwnerTelemetryError.unavailable }
        guard let stream = fdopendir(copy) else { Darwin.close(copy); throw OwnerTelemetryError.unavailable }
        defer { closedir(stream) }
        var result: Set<String> = []
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                guard errno == 0 else { throw OwnerTelemetryError.integrity }
                return result
            }
            let count = Int(entry.pointee.d_namlen)
            let name = withUnsafeBytes(of: entry.pointee.d_name) { String(bytes: $0.prefix(count), encoding: .utf8) }
            guard let name else { throw OwnerTelemetryError.integrity }
            if name == "." || name == ".." { continue }
            guard result.count < 1024, result.insert(name).inserted else { throw OwnerTelemetryError.capacity }
        }
    }
    private static func read(_ fd: Int32, size: Int) throws -> Data {
        var bytes = Data(count: size)
        try bytes.withUnsafeMutableBytes { storage in
            var offset = 0
            while offset < size {
                let count = pread(fd, storage.baseAddress!.advanced(by: offset), size - offset, off_t(offset))
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw OwnerTelemetryError.integrity }
                offset += count
            }
        }
        return bytes
    }
    private static func verifyBytes(_ fd: Int32, bytes: Data) throws {
        var chunk = [UInt8](repeating: 0, count: min(65_536, max(1, bytes.count)))
        var offset = 0
        while offset < bytes.count {
            let count = chunk.withUnsafeMutableBytes { pread(fd, $0.baseAddress!, min($0.count, bytes.count - offset), off_t(offset)) }
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw OwnerTelemetryError.integrity }
            let equal = chunk.withUnsafeBytes { buffer in
                bytes.withUnsafeBytes { memcmp(buffer.baseAddress!, $0.baseAddress!.advanced(by: offset), count) == 0 }
            }
            guard equal else { throw OwnerTelemetryError.integrity }
            offset += count
        }
        var extra: UInt8 = 0
        guard pread(fd, &extra, 1, off_t(bytes.count)) == 0 else { throw OwnerTelemetryError.integrity }
    }
}


/// The only owner of the telemetry directory; filesystem work never runs on MainActor.
nonisolated private final class OwnerPracticeTelemetryWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "PadelStrokeLab.practice-telemetry")
    private var store: OwnerTelemetryStore?
    func create(base: URL, value: OwnerPracticeTelemetry) async throws {
        try await run { self.store = try OwnerTelemetryStore.create(base: base, telemetry: value) }
    }
    func recover(base: URL) async throws -> Bool {
        try await run {
            var unknownClosure = false
            try OwnerPracticeRecoveryReader.forEachCandidate(base: base) { candidate in
                let recovered = try OwnerTelemetryStore.open(base: base, practiceID: candidate.header.practiceID,
                    expectedHeader: candidate.header)
                defer { recovered.close() }
                unknownClosure = unknownClosure || recovered.snapshot.finalization == nil
            }
            return unknownClosure
        }
    }
    func snapshot() async throws -> OwnerPracticeTelemetry {
        try await run { guard let store = self.store else { throw OwnerTelemetryError.unavailable }; return store.snapshot }
    }
    func replace(_ value: OwnerPracticeTelemetry) async throws {
        try await run { guard let store = self.store else { throw OwnerTelemetryError.closed }; try store.update { $0 = value } }
    }
    func close() async { try? await run { self.store?.close(); self.store = nil } }
    func releaseForDeletion(practiceID: UUID) async throws {
        try await run {
            guard let store = self.store, store.snapshot.header.practiceID == practiceID else { return }
            guard store.snapshot.finalization != nil else { throw OwnerTelemetryError.unavailable }
            store.close(); self.store = nil
        }
    }
    private func run<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result(catching: operation)) }
        }
    }
}
@MainActor @Observable final class OwnerPracticeCoordinator {
    enum State { case ready, baseline, activeSet, setClosing, recovery, paused, ending, ended, interrupted }
    private(set) var state: State = .ready
    private(set) var heartRateMessage = "Heart-rate recording is optional"
    private(set) var issue: String?
    private let owner: OwnerCaptureCoordinator
    private let base: URL
    let workout: WatchWorkoutDriver?
    private let heartRate: OwnerHeartRateSource?
    private let clock: @MainActor () throws -> OwnerTelemetryInstant
    private let beforePublication: (@MainActor (OwnerPracticeTelemetry) async throws -> Void)?
    private var worker = OwnerPracticeTelemetryWorker()
    private var publication: Task<Void, any Error>?
    private var recoveryTask: Task<Bool, any Error>?
    private var recoveryChecked = false
    private var recoveredResourcesUnknown = false
    private var beginTask: Task<Void, Never>?
    private var endTask: Task<Void, Never>?
    private var deletionDrains: Set<UUID> = []
    private var timer: Task<Void, Never>?
    private var header: OwnerTelemetryHeader?
    private var authority: OwnerPracticeIdentity?
    private var nativeAttempt = UUID()
    private var segment = UUID()
    private var queryGeneration: UUID?
    private var running = false
    private var startupPending = false
    private var resumeRequested = false
    private var endRequested = false
    private var finalized = false
    private var timedOut = false
    private var endInstant: OwnerTelemetryInstant?
    private var recoveryStart: Double?
    private var setCount = 0
    private var observation: OwnerTelemetryObservation?
    private var currentContext: OwnerRecordingContext?
    private var mapping: SetClockMapping?
    private var stopRecorded = false
    private var requestedStopInstant: OwnerTelemetryInstant?
    private var absenceReasons: Set<OwnerTelemetryReason> = []
    var currentPracticeID: UUID? { header?.practiceID }
    func fail(_ reason: String) { interrupt(reason) }
    var onStopSet: ((String?) -> Void)?
    var onNativeState: ((WatchWorkoutDriver.Kind) -> Void)?
    var onClosureCheck: (() -> Void)?
    var recorderClosed: (() -> Bool)?
    var sourceClosed: (() -> Bool)?
    init(owner: OwnerCaptureCoordinator, base: URL, workout: WatchWorkoutDriver?, heartRate: OwnerHeartRateSource?,
        clock: @escaping @MainActor () throws -> OwnerTelemetryInstant,
        beforePublication: (@MainActor (OwnerPracticeTelemetry) async throws -> Void)?) {
        self.owner = owner; self.base = base; self.workout = workout; self.heartRate = heartRate
        self.clock = clock; self.beforePublication = beforePublication
        owner.retainsPracticeWorkout = true
        owner.canRetainPracticeWorkout = { [weak self] in self?.endRequested == false }
        owner.practiceCallbacksClosed = { [weak self] in (self?.heartRate?.pendingCallbacks ?? 0) == 0 }
        owner.onPracticeRecovery = { [weak self] in
            guard let self else { throw OwnerCaptureFailure.closed }
            if self.recoveryTask == nil {
                let worker = self.worker, base = self.base
                self.recoveryTask = Task { try await worker.recover(base: base) }
            }
            do {
                self.recoveredResourcesUnknown = try await self.recoveryTask!.value
                self.recoveryChecked = true
                if self.recoveredResourcesUnknown {
                    self.state = .interrupted; self.issue = "Prior practice was interrupted. Resource closure is unknown."
                }
                return self.recoveredResourcesUnknown
            } catch {
                self.recoveredResourcesUnknown = true; self.state = .interrupted
                self.issue = "Prior practice evidence could not be checked."
                throw error
            }
        }
        if workout == nil { state = .interrupted; issue = "Practice workout dependency is unavailable." }
        workout?.onEvent = { [weak self] event in self?.native(event) }
        owner.onHeartRateFence = { [weak self] in self?.heartRate?.stop() }
        owner.onHeartRateTransition = { [weak self] before, after, mutation in
            try await self?.reconcile(before: before, after: after, mutation: mutation)
        }
        owner.onPracticeRetirement = { [weak self] in self?.end(interrupted: true) }
        owner.onPracticeStartupInvalidation = { [weak self] in
            guard let self, self.startupPending else { return }
            self.end(interrupted: true)
        }
        heartRate?.onMessage = { [weak self] in self?.heartRateMessage = $0 }
        heartRate?.onInterruption = { [weak self] reason in
            self?.absenceReasons.insert(reason); self?.interrupt("Heart-rate evidence was interrupted: \(reason.rawValue).")
        }
    }
    isolated deinit { timer?.cancel(); beginTask?.cancel(); endTask?.cancel() }
    var canBeginPractice: Bool {
        guard deletionDrains.isEmpty else { return false }
        guard recoveryChecked, !recoveredResourcesUnknown, workout != nil, [.ready, .ended, .interrupted].contains(state), workout?.isClosed == true,
            (heartRate?.pendingCallbacks ?? 0) == 0, recorderClosed?() != false, sourceClosed?() != false,
            let preparation = owner.acceptedPreparation, preparation.authority == owner.authority else { return false }
        return header == nil || (finalized && preparation.practiceID != header?.practiceID)
    }
    var canStartSet: Bool {
        [.baseline, .recovery].contains(state) && running && !endRequested && setCount < 20 &&
        owner.acceptedPreparation?.practiceID == header?.practiceID && sourceClosed?() != false && recorderClosed?() != false
    }
    var permitsResume: Bool { state == .activeSet && running && !endRequested }
    func now() throws -> OwnerTelemetryInstant { try clock() }
    func begin() {
        guard canBeginPractice, let preparation = owner.acceptedPreparation else { return }
        state = .baseline; running = false; resumeRequested = false; endRequested = false; finalized = false; timedOut = false
        issue = nil; absenceReasons = []; setCount = 0; recoveryStart = nil; currentContext = nil; observation = nil; endInstant = nil
        nativeAttempt = UUID(); segment = UUID(); queryGeneration = preparation.authority.heartRateConsent ? UUID() : nil
        authority = preparation.authority; publication = nil; header = nil; startupPending = true
        let token = nativeAttempt, fence = owner.practiceStartupFence, previousWorker = worker
        let startupWorker = OwnerPracticeTelemetryWorker(); worker = startupWorker
        beginTask = Task { [weak self] in
            guard let self else { return }
            do {
                await previousWorker.close()
                guard self.currentStartup(preparation: preparation, token: token, fence: fence) else { return }
                let instant = try self.clock()
                let header = try OwnerTelemetryHeader(authority: preparation.authority, practiceID: preparation.practiceID,
                    clock: RecordingClock(domainID: UUID(), monotonicAnchorSeconds: instant.monotonicSeconds,
                        wallAnchorUnixSeconds: instant.wallUnixSeconds), runtimeGeneration: self.owner.generations.runtimeGeneration,
                    clockUncertaintySeconds: 0)
                self.header = header
                let value = try OwnerPracticeTelemetry(header: header, authority: preparation.authority,
                    initialConsentSegmentID: self.segment, initialQueryGeneration: self.queryGeneration)
                try await startupWorker.create(base: self.base, value: value)
                guard self.currentStartup(preparation: preparation, token: token, fence: fence) else { return }
                try await self.owner.validatePracticeStartup(preparation, expectedFence: fence)
                guard self.currentStartup(preparation: preparation, token: token, fence: fence) else { return }
                self.workout?.start(attemptID: token)
                self.timer = Task { [weak self] in
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(1)) } catch { return }
                        self?.checkDeadlines()
                    }
                }
            } catch {
                guard self.nativeAttempt == token, !self.endRequested else { return }
                self.interrupt("Practice evidence could not be opened: \(error.localizedDescription)")
            }
        }
    }
    private func currentStartup(preparation: OwnerPreparation, token: UUID, fence: UUID) -> Bool {
        guard nativeAttempt == token else { return false }
        guard !Task.isCancelled, !endRequested, owner.practiceStartupFence == fence,
              owner.acceptedPreparation == preparation, owner.authority == preparation.authority else {
            end(interrupted: true)
            return false
        }
        return true
    }
    private func native(_ event: WatchWorkoutDriver.Event) {
        guard event.attemptID == nativeAttempt else { return }
        switch event.kind {
        case .running:
            guard !endRequested else { return }
            let first = startupPending && state == .baseline, resuming = resumeRequested
            guard first || resuming || running else { return }
            running = true; startupPending = false
            if resuming {
                resumeRequested = false
                if state == .paused { state = currentContext == nil ? .baseline : .recovery }
                let kind: OwnerTelemetryObservationKind = state == .activeSet ? .active : currentContext == nil ? .baseline : .recovery
                openObservation(kind, recordingID: currentContext?.recordingID)
            }
            if first { startHeartRate(); openObservation(.baseline, recordingID: nil) }
            onNativeState?(.running)
        case .paused:
            guard !endRequested else { return }
            running = false; closeObservation(.paused)
            if state != .activeSet && state != .setClosing { state = .paused }
            onNativeState?(.paused)
        case .ended, .closedWithoutSession:
            running = false; onNativeState?(event.kind)
            if !endRequested { end(interrupted: true) }
        case .shutdownTimedOut:
            timedOut = true; issue = "Waiting for the actual workout to end."; onNativeState?(event.kind)
        case let .failed(reason): interrupt(reason)
        }
    }
    func pause() {
        guard !endRequested, [.baseline, .activeSet, .recovery].contains(state) else { return }
        closeObservation(.paused); running = false; workout?.pause()
    }
    func resume() {
        guard !endRequested, state == .paused || state == .activeSet else { return }
        resumeRequested = true; workout?.resume()
    }
    func setWillClose() {
        requestedStopInstant = try? clock()
        if !endRequested { state = .setClosing }
        closeObservation(.setStopped, at: requestedStopInstant)
    }
    func setWillStart() throws {
        checkDeadlines()
        guard canStartSet else { throw OwnerCaptureFailure.resourcesOpen }
        // Close the prior observation before raw metadata captures its immutable clock anchor.
        closeObservation(.nextSet)
    }
    func admitSet(context: OwnerRecordingContext, before: Double, after: Double, instant: OwnerTelemetryInstant) async throws {
        checkDeadlines(refresh: false)
        guard canStartSet, let header else { throw OwnerCaptureFailure.resourcesOpen }
        let calibration = try OwnerSetClockCalibration(rawClock: context.metadata.clock, practiceClockDomainID: header.clock.domainID,
            runtimeGeneration: header.runtimeGeneration, rawBeforeSeconds: before, rawAfterSeconds: after,
            practiceMonotonicSeconds: instant.monotonicSeconds, wallUnixSeconds: instant.wallUnixSeconds)
        let mapping = try SetClockMapping(context: context, header: header, calibration: calibration)
        let at = try OwnerTelemetryInstant(wallUnixSeconds: context.metadata.clock.wallAnchorUnixSeconds,
            monotonicSeconds: context.metadata.clock.monotonicAnchorSeconds + mapping.offsetSeconds)
        closeObservation(.nextSet, at: at)
        let segment = self.segment, token = nativeAttempt
        try await publish { try $0.admitSet(context: context, mapping: mapping, consentSegmentID: segment,
            rawStartSeconds: context.metadata.clock.monotonicAnchorSeconds, at: at) }
        guard token == nativeAttempt, !endRequested, running else { throw OwnerCaptureFailure.stale }
        self.mapping = mapping; currentContext = context; stopRecorded = false; setCount += 1
        state = .activeSet; recoveryStart = nil; openObservation(.active, recordingID: context.recordingID, at: at)
    }
    func setStopped(rawTime: Double) {
        guard let context = currentContext, !stopRecorded else { return }
        stopRecorded = true
        let at: OwnerTelemetryInstant
        if let header, rawTime + (mapping?.offsetSeconds ?? 0) > header.clock.monotonicAnchorSeconds + 1800 {
            // The real raw writer retains its stop. O6 cannot claim an in-policy stop for this set.
            absenceReasons.insert(.durationLimit); timedOut = true; return
        }
        guard let requestedStopInstant else {
            interrupt("Actual set closure clock is unavailable."); return
        }
        at = requestedStopInstant
        let token = nativeAttempt
        let stopped = schedule { try $0.stopSet(recordingID: context.recordingID, rawStopSeconds: rawTime, at: at) }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await stopped.value
                guard self.nativeAttempt == token else { return }
                if !self.endRequested { self.state = .recovery; self.recoveryStart = at.monotonicSeconds
                    self.openObservation(.recovery, recordingID: context.recordingID, at: at) }
            } catch { self.interrupt("Set closure evidence could not be saved.") }
        }
    }
    func checkDeadlines(refresh: Bool = true) {
        onClosureCheck?()
        guard let header, !finalized, let at = try? clock() else { return }
        if endRequested {
            if let endInstant, at.monotonicSeconds - endInstant.monotonicSeconds >= 5 { timedOut = true }
            return
        }
        if at.monotonicSeconds - header.clock.monotonicAnchorSeconds >= 1800 {
            absenceReasons.insert(.durationLimit); end(interrupted: true)
        } else if let recoveryStart, at.monotonicSeconds - recoveryStart >= 130, state == .recovery {
            self.recoveryStart = nil; pause()
        } else if refresh { refreshObservation(at: at) }
    }
    func end() { end(interrupted: false, retireLocally: true) }
    /// Release only the requested practice after the existing End path has observed
    /// native, callback, source and writer closure and persisted final telemetry.
    func prepareForDeletion(practiceID: UUID) async throws {
        try Task.checkCancellation()
        let targetsCurrent = header?.practiceID == practiceID ||
            (startupPending && owner.acceptedPreparation?.practiceID == practiceID)
        let retainedWorker = worker, startup = beginTask
        guard targetsCurrent else {
            // A replacement's startup owns closing its previous worker. Observe that
            // handoff without stopping or releasing the replacement practice.
            await startup?.value
            try Task.checkCancellation()
            try await retainedWorker.releaseForDeletion(practiceID: practiceID)
            try Task.checkCancellation()
            return
        }
        let fence = UUID(), attempt = nativeAttempt
        deletionDrains.insert(fence)
        defer { deletionDrains.remove(fence) }
        end() // Fence admission synchronously, before the first suspension.
        await startup?.value
        await endTask?.value
        try Task.checkCancellation()
        try await publication?.value
        try Task.checkCancellation()
        guard nativeAttempt == attempt, worker === retainedWorker,
              header?.practiceID == practiceID, finalized, endRequested,
              workout?.isClosed == true, (heartRate?.pendingCallbacks ?? 0) == 0,
              recorderClosed?() != false, sourceClosed?() != false else {
            throw OwnerCaptureFailure.resourcesOpen
        }
        try await retainedWorker.releaseForDeletion(practiceID: practiceID)
        try Task.checkCancellation()
    }
    private func end(interrupted: Bool, retireLocally: Bool = false) {
        guard !endRequested, !finalized else { return }
        if let header, let at = try? clock(), at.monotonicSeconds - header.clock.monotonicAnchorSeconds >= 1800 {
            absenceReasons.insert(.durationLimit)
        }
        let shouldInterrupt = interrupted || absenceReasons.contains(.durationLimit)
        let practiceID = header?.practiceID ?? (startupPending ? owner.acceptedPreparation?.practiceID : nil)
        endRequested = true; startupPending = false; beginTask?.cancel()
        let retirement: Task<Void, any Error>? = retireLocally ? practiceID.map { id in
            Task { [owner] in try await owner.retireLocalPractice(id) }
        } : nil
        guard header != nil else {
            heartRate?.stop(); workout?.end(); timer?.cancel(); state = .ending
            endTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await retirement?.value
                    self.finalized = true; self.state = shouldInterrupt ? .interrupted : .ended
                } catch { self.state = .interrupted; self.issue = "Practice retirement could not be saved." }
            }
            return
        }
        timedOut = shouldInterrupt; state = .ending; running = false
        heartRate?.stop(); onStopSet?(shouldInterrupt ? "Practice was interrupted." : nil)
        endInstant = try? clock()
        // Raw stopping can cross the limit; finalization must use this same actual End pair.
        if let header, let endInstant, endInstant.monotonicSeconds - header.clock.monotonicAnchorSeconds >= 1800 {
            absenceReasons.insert(.durationLimit); timedOut = true
        }
        closeObservation(timedOut ? .interrupted : .ended, at: endInstant); workout?.end()
        let token = nativeAttempt
        endTask = Task { [weak self] in
            guard let self else { return }
            while self.nativeAttempt == token {
                self.checkDeadlines()
                if self.workout?.isClosed == true && (self.heartRate?.pendingCallbacks ?? 0) == 0 &&
                    self.recorderClosed?() != false && self.sourceClosed?() != false { break }
                do { try await Task.sleep(for: .milliseconds(10)) } catch { return }
            }
            guard self.nativeAttempt == token, let frozen = self.endInstant, let header = self.header else { return }
            do {
                try await retirement?.value
                // The duration cap bounds eligible evidence; it never stands in for actual resource closure.
                let at = self.absenceReasons.contains(.durationLimit)
                    ? try OwnerTelemetryInstant(wallUnixSeconds: header.clock.wallAnchorUnixSeconds + 1800,
                        monotonicSeconds: header.clock.monotonicAnchorSeconds + 1800) : frozen
                let projectedWall = header.clock.wallAnchorUnixSeconds + at.monotonicSeconds - header.clock.monotonicAnchorSeconds
                let discontinuity = abs(at.wallUnixSeconds - projectedWall) > 2
                let terminal: OwnerTelemetryStatus = self.timedOut || discontinuity ? .interrupted : .ended
                var reasons = self.absenceReasons
                if terminal == .interrupted { reasons.insert(.interrupted) }
                if discontinuity { reasons.insert(.clockDiscontinuity) }
                try await self.publish { value in
                    if discontinuity { try value.recordEvent(OwnerTelemetryEvent(id: UUID(), at: at, reason: .clockDiscontinuity, count: 1)) }
                    try value.finalize(status: terminal, at: at, absenceReasons: Array(reasons))
                }
                self.finalized = true; self.state = terminal == .ended ? .ended : .interrupted; self.timer?.cancel()
            } catch { self.state = .interrupted; self.issue = "Practice evidence remains incomplete: \(error.localizedDescription)" }
        }
    }
    private func interrupt(_ reason: String) { issue = reason; if header == nil { state = .interrupted } else { end(interrupted: true) } }
    private func startHeartRate() {
        guard let header, let query = queryGeneration, !endRequested else { return }
        let segment = self.segment, token = nativeAttempt
        heartRate?.begin(header: header) { [weak self] samples, reasons, at in
            guard let self, self.nativeAttempt == token, !self.finalized else { throw OwnerTelemetryError.closed }
            self.checkDeadlines()
            try await self.publish { value in
                var counts = reasons
                let consent = value.consentSegments.first { $0.id == segment && $0.queryGeneration == query }
                let bounded = samples.filter { sample in
                    let start = sample.sourceStart.timeIntervalSince1970, end = sample.sourceEnd.timeIntervalSince1970
                    let reason: OwnerTelemetryReason?
                    if consent?.heartRateEnabled != true || start < (consent?.start.wallUnixSeconds ?? .infinity)
                        || end > (consent?.end?.wallUnixSeconds ?? .infinity) {
                        reason = .consentExcluded
                    } else if end > (self.endInstant?.wallUnixSeconds ?? .infinity) {
                        reason = .outsidePractice
                    } else if !value.observations.contains(where: {
                        $0.consentSegmentID == segment && $0.queryGeneration == query
                            && ![.paused, .ending, .interrupted].contains($0.kind)
                            && start >= $0.start.wallUnixSeconds && end <= $0.end.wallUnixSeconds
                    }) {
                        reason = .incompleteObservation
                    } else { reason = nil }
                    if let reason { counts[reason, default: 0] += 1; return false }
                    return true
                }
                _ = try value.appendPage(bounded, consentSegmentID: segment, queryGeneration: query)
                for (reason, count) in counts.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                    let batches: Set<OwnerTelemetryReason> = [.userEntered, .missingProvenance, .mismatchedProvenance, .sourceDeleted]
                    if batches.contains(reason) {
                        try value.recordEvent(OwnerTelemetryEvent(id: UUID(), at: at, reason: reason, count: count))
                    } else {
                        for _ in 0..<count { try value.recordEvent(OwnerTelemetryEvent(id: UUID(), at: at, reason: reason, count: 1)) }
                    }
                }
            }
        }
    }
    private func reconcile(before: OwnerPracticeIdentity, after: OwnerPracticeIdentity, mutation: OwnerAuthorityMutation) async throws {
        guard header != nil, !finalized else { return }
        guard let header, !endRequested, authority == before, mutation.kind == .heartRate,
            try mutation.resolve(from: before) == after else { throw OwnerCaptureFailure.stale }
        struct Evidence: Decodable { struct Body: Decodable { struct Decision: Decodable { let confirmedAtUnixSeconds: Double }; let lastDecision: Decision }; let body: Body }
        let evidence = try JSONDecoder().decode(Evidence.self, from: after.encoded())
        let decision = try OwnerConsentDecision.heartRate(for: before, allowed: after.heartRateConsent, decisionID: mutation.id,
            confirmedAtUnixSeconds: evidence.body.lastDecision.confirmedAtUnixSeconds, policyDigest: after.policyDigest)
        guard try before.applying(decision) == after else { throw OwnerCaptureFailure.stale }
        let at = try clock(), nextSegment = UUID(), nextQuery = after.heartRateConsent ? UUID() : nil
        closeObservation(.consentChanged, at: at)
        try await publish { try $0.transitionAuthority(to: after, decision: decision, at: at, segmentID: nextSegment, queryGeneration: nextQuery) }
        guard self.header == header, !endRequested else { throw OwnerCaptureFailure.stale }
        authority = after; segment = nextSegment; queryGeneration = nextQuery
        if after.heartRateConsent { startHeartRate(); openObservation(!running ? .paused : state == .activeSet ? .active : .rest,
            recordingID: currentContext?.recordingID, at: at) }
    }
    private func openObservation(_ kind: OwnerTelemetryObservationKind, recordingID: UUID?, at supplied: OwnerTelemetryInstant? = nil) {
        guard let query = queryGeneration, let at = supplied ?? (try? clock()), !endRequested else { return }
        observation = try? OwnerTelemetryObservation(id: UUID(), kind: kind, recordingID: recordingID, consentSegmentID: segment,
            queryGeneration: query, start: at, end: at, closure: .open)
        refreshObservation(at: at)
    }
    private func refreshObservation(at: OwnerTelemetryInstant) {
        guard let old = observation, at.monotonicSeconds >= old.start.monotonicSeconds else { return }
        guard let next = try? OwnerTelemetryObservation(id: old.id, kind: old.kind, recordingID: old.recordingID,
            consentSegmentID: old.consentSegmentID, queryGeneration: old.queryGeneration, start: old.start, end: at, closure: .open) else { return }
        observation = next; enqueue { try $0.recordObservation(next) }
    }
    private func closeObservation(_ closure: OwnerTelemetryClosure, at supplied: OwnerTelemetryInstant? = nil) {
        guard let old = observation, let at = supplied ?? (try? clock()) else { return }
        observation = nil
        // A delayed hardware shutdown cannot fabricate an in-policy observation endpoint.
        if let header, at.monotonicSeconds > header.clock.monotonicAnchorSeconds + 1800 { return }
        guard let next = try? OwnerTelemetryObservation(id: old.id, kind: old.kind, recordingID: old.recordingID,
            consentSegmentID: old.consentSegmentID, queryGeneration: old.queryGeneration, start: old.start, end: at, closure: closure) else { return }
        enqueue { try $0.recordObservation(next) }
    }
    private func enqueue(_ operation: @escaping @MainActor (inout OwnerPracticeTelemetry) throws -> Void) {
        // Link the operation now, before another caller can enqueue an awaited mutation.
        let task = schedule(operation), token = nativeAttempt
        Task { [weak self] in
            do { try await task.value }
            catch { if self?.nativeAttempt == token { self?.interrupt("Telemetry observation could not be saved.") } }
        }
    }
    private func schedule(_ operation: @escaping @MainActor (inout OwnerPracticeTelemetry) throws -> Void) -> Task<Void, any Error> {
        let previous = publication, worker = self.worker, barrier = beforePublication
        let task = Task { @MainActor in
            _ = try? await previous?.value
            var value = try await worker.snapshot()
            let result = Result { try operation(&value) }
            try await barrier?(value)
            try await worker.replace(value)
            try result.get()
        }
        publication = task
        return task
    }
    private func publish(_ operation: @escaping @MainActor (inout OwnerPracticeTelemetry) throws -> Void) async throws {
        try await schedule(operation).value
    }
    func telemetrySnapshot() async throws -> OwnerPracticeTelemetry { try await worker.snapshot() }
    func closeForTesting() async {
        timer?.cancel(); beginTask?.cancel(); endTask?.cancel(); heartRate?.stop(); workout?.end()
        await worker.close()
    }
}
