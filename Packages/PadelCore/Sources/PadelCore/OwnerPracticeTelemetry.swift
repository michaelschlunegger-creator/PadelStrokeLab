import Foundation

public enum OwnerTelemetryError: Error, Equatable, Sendable {
    case invalid(String), capacity, closed, integrity, unavailable
}

public enum OwnerTelemetryReason: String, Codable, CaseIterable, Sendable {
    case bpmOutOfRange, invalidDate, unorderedInterval, outsidePractice, wrongInstallationEpoch
    case wrongQuery, consentExcluded, sampleConflict, pageLimit, sampleLimit, setLimit
    case eventLimit, byteLimit, durationLimit, reopenedPartial, interrupted, insufficientSamples
    case noAccessibleHeartRateData, incompleteObservation, missingReference, missingCalibration
    case ambiguousClock, clockDiscontinuity, userEntered, missingProvenance, mismatchedProvenance
    case sourceDeleted, sourceError

    var permitsCount: Bool {
        [.userEntered, .missingProvenance, .mismatchedProvenance, .sourceDeleted].contains(self)
    }
}

public struct OwnerTelemetryInstant: Codable, Equatable, Sendable {
    public let wallUnixSeconds: Double
    public let monotonicSeconds: Double
    public init(wallUnixSeconds: Double, monotonicSeconds: Double) throws {
        guard wallUnixSeconds.isFinite, monotonicSeconds.isFinite, monotonicSeconds >= 0 else {
            throw OwnerTelemetryError.invalid("instant")
        }
        self.wallUnixSeconds = wallUnixSeconds; self.monotonicSeconds = monotonicSeconds
    }
    func validate() throws { _ = try Self(wallUnixSeconds: wallUnixSeconds, monotonicSeconds: monotonicSeconds) }
}

/// Initial immutable authority and clock evidence; this value never authorizes acquisition.
public struct OwnerTelemetryHeader: Equatable, Sendable {
    private struct Body: Codable, Equatable, Sendable {
        let schemaVersion: Int, calculationVersion: Int
        let acquisitionMode: String
        let ownerID: UUID, phoneInstallationEpoch: UUID, watchInstallationEpoch: UUID, practiceID: UUID
        let initialAuthorityRevision: Int64
        let initialAuthorityDigest: String
        let clockDomainID: UUID, runtimeGeneration: UUID
        let monotonicAnchorSeconds: Double, wallAnchorUnixSeconds: Double, clockUncertaintySeconds: Double
    }
    private let body: Body
    public let clock: RecordingClock
    public var ownerID: UUID { body.ownerID }
    public var phoneInstallationEpoch: UUID { body.phoneInstallationEpoch }
    public var watchInstallationEpoch: UUID { body.watchInstallationEpoch }
    public var practiceID: UUID { body.practiceID }
    public var runtimeGeneration: UUID { body.runtimeGeneration }
    public var initialAuthorityRevision: Int64 { body.initialAuthorityRevision }
    public var initialAuthorityDigest: String { body.initialAuthorityDigest }
    public var clockUncertaintySeconds: Double { body.clockUncertaintySeconds }

    public init(authority: OwnerPracticeIdentity, practiceID: UUID, clock: RecordingClock,
                runtimeGeneration: UUID, clockUncertaintySeconds: Double) throws {
        try clock.validate()
        guard authority.isCollectionAllowed, clockUncertaintySeconds.isFinite, clockUncertaintySeconds >= 0 else {
            throw OwnerTelemetryError.invalid("header authority or uncertainty")
        }
        self.clock = clock
        body = Body(schemaVersion: 1, calculationVersion: 1, acquisitionMode: OwnerRecordingContext.acquisitionMode,
            ownerID: authority.ownerID, phoneInstallationEpoch: authority.phoneInstallationEpoch,
            watchInstallationEpoch: authority.watchInstallationEpoch, practiceID: practiceID,
            initialAuthorityRevision: authority.revision, initialAuthorityDigest: Self.digest(try authority.encoded()),
            clockDomainID: clock.domainID, runtimeGeneration: runtimeGeneration,
            monotonicAnchorSeconds: clock.monotonicAnchorSeconds, wallAnchorUnixSeconds: clock.wallAnchorUnixSeconds,
            clockUncertaintySeconds: clockUncertaintySeconds)
    }
    public func encoded() throws -> Data { try OwnerCanonical.encode(body, domain: "PSLOwnerTelemetryHeader1", limit: 4096) }
    public static func decode(_ bytes: Data, authority: OwnerPracticeIdentity) throws -> Self {
        let body: Body = try OwnerCanonical.decode(bytes, domain: "PSLOwnerTelemetryHeader1", limit: 4096)
        let value = try Self(authority: authority, practiceID: body.practiceID,
            clock: RecordingClock(domainID: body.clockDomainID, monotonicAnchorSeconds: body.monotonicAnchorSeconds,
                wallAnchorUnixSeconds: body.wallAnchorUnixSeconds), runtimeGeneration: body.runtimeGeneration,
            clockUncertaintySeconds: body.clockUncertaintySeconds)
        guard value.body == body else { throw OwnerTelemetryError.integrity }
        return value
    }
    static func digest(_ bytes: Data) -> String { RecordingChunkCodec.digest(bytes) }
    func matches(_ context: OwnerRecordingContext) -> Bool {
        context.ownerID == ownerID && context.phoneInstallationEpoch == phoneInstallationEpoch
            && context.watchInstallationEpoch == watchInstallationEpoch && context.practiceID == practiceID
            && context.generations.runtimeGeneration == runtimeGeneration
    }
}

public struct OwnerSetClockCalibration: Codable, Equatable, Sendable {
    public let rawClock: RecordingClock
    public let practiceClockDomainID: UUID, runtimeGeneration: UUID
    public let rawBeforeSeconds: Double, rawAfterSeconds: Double, practiceMonotonicSeconds: Double, wallUnixSeconds: Double
    public init(rawClock: RecordingClock, practiceClockDomainID: UUID, runtimeGeneration: UUID,
                rawBeforeSeconds: Double, rawAfterSeconds: Double, practiceMonotonicSeconds: Double,
                wallUnixSeconds: Double) throws {
        try rawClock.validate()
        guard [rawBeforeSeconds, rawAfterSeconds, practiceMonotonicSeconds, wallUnixSeconds].allSatisfy(\.isFinite),
              rawBeforeSeconds >= 0, rawAfterSeconds >= rawBeforeSeconds, practiceMonotonicSeconds >= 0,
              rawBeforeSeconds <= rawClock.monotonicAnchorSeconds,
              rawAfterSeconds >= rawClock.monotonicAnchorSeconds else { throw OwnerTelemetryError.invalid("calibration") }
        self.rawClock = rawClock; self.practiceClockDomainID = practiceClockDomainID; self.runtimeGeneration = runtimeGeneration
        self.rawBeforeSeconds = rawBeforeSeconds; self.rawAfterSeconds = rawAfterSeconds
        self.practiceMonotonicSeconds = practiceMonotonicSeconds; self.wallUnixSeconds = wallUnixSeconds
    }
}

public struct SetClockMapping: Equatable, Sendable {
    private struct Body: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let recordingID: UUID, practiceClockDomainID: UUID, runtimeGeneration: UUID
        let contextDigest: String
        let rawClock: RecordingClock
        let calibration: OwnerSetClockCalibration
        let offsetSeconds: Double, uncertaintySeconds: Double
    }
    private let body: Body
    public var offsetSeconds: Double { body.offsetSeconds }
    public var uncertaintySeconds: Double { body.uncertaintySeconds }
    public var contextDigest: String { body.contextDigest }
    public init(context: OwnerRecordingContext, header: OwnerTelemetryHeader, calibration: OwnerSetClockCalibration) throws {
        let c = calibration
        _ = try OwnerSetClockCalibration(rawClock: c.rawClock, practiceClockDomainID: c.practiceClockDomainID,
            runtimeGeneration: c.runtimeGeneration, rawBeforeSeconds: c.rawBeforeSeconds, rawAfterSeconds: c.rawAfterSeconds,
            practiceMonotonicSeconds: c.practiceMonotonicSeconds, wallUnixSeconds: c.wallUnixSeconds)
        let half = (c.rawAfterSeconds - c.rawBeforeSeconds) / 2
        let offset = c.practiceMonotonicSeconds - (c.rawBeforeSeconds + half)
        let uncertainty = half + header.clockUncertaintySeconds
        let expectedWall = header.clock.wallAnchorUnixSeconds + c.practiceMonotonicSeconds - header.clock.monotonicAnchorSeconds
        guard header.matches(context), c.rawClock == context.metadata.clock,
              c.practiceClockDomainID == header.clock.domainID, c.runtimeGeneration == header.runtimeGeneration,
              offset.isFinite, uncertainty.isFinite, abs(c.wallUnixSeconds - expectedWall) <= 2,
              abs(c.wallUnixSeconds - c.rawClock.wallAnchorUnixSeconds) <= 2 else {
            throw OwnerTelemetryError.invalid("clock mapping scope or discontinuity")
        }
        body = Body(schemaVersion: 1, recordingID: context.recordingID, practiceClockDomainID: c.practiceClockDomainID,
            runtimeGeneration: c.runtimeGeneration, contextDigest: OwnerTelemetryHeader.digest(try context.encoded()),
            rawClock: c.rawClock, calibration: c, offsetSeconds: offset, uncertaintySeconds: uncertainty)
    }
    public func encoded() throws -> Data { try OwnerCanonical.encode(body, domain: "PSLOwnerSetClockMapping1", limit: 8192) }
    public static func decode(_ bytes: Data, context: OwnerRecordingContext, header: OwnerTelemetryHeader) throws -> Self {
        let body: Body = try OwnerCanonical.decode(bytes, domain: "PSLOwnerSetClockMapping1", limit: 8192)
        let value = try Self(context: context, header: header, calibration: body.calibration)
        guard value.body == body else { throw OwnerTelemetryError.integrity }
        return value
    }
}

public struct OwnerHeartRateProvenance: Codable, Equatable, Sendable {
    public let sourceBundleIdentifier: String, sourceVersion: String, operatingSystem: String, productType: String
    public let manufacturer: String, model: String, hardwareVersion: String, softwareVersion: String
    public let watchInstallationEpoch: UUID
    public init(sourceBundleIdentifier: String, sourceVersion: String, operatingSystem: String, productType: String,
                manufacturer: String, model: String, hardwareVersion: String, softwareVersion: String,
                watchInstallationEpoch: UUID) throws {
        self.sourceBundleIdentifier = sourceBundleIdentifier; self.sourceVersion = sourceVersion
        self.operatingSystem = operatingSystem; self.productType = productType; self.manufacturer = manufacturer
        self.model = model; self.hardwareVersion = hardwareVersion; self.softwareVersion = softwareVersion
        self.watchInstallationEpoch = watchInstallationEpoch
        try validate()
    }
    func validate() throws {
        for text in [sourceBundleIdentifier, sourceVersion, operatingSystem, productType, manufacturer,
                     model, hardwareVersion, softwareVersion] {
            guard !text.isEmpty, text.utf8.count <= 128,
                  !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw OwnerTelemetryError.invalid("machine provenance")
            }
        }
    }
}

/// Rejected native values may exist transiently; only validated records enter canonical storage.
public struct OwnerHeartRateSample: Equatable, Sendable {
    public let id: UUID
    public let bpm: Double
    public let sourceStart: Date, sourceEnd: Date, arrival: Date
    public let provenance: OwnerHeartRateProvenance
    public init(id: UUID, bpm: Double, sourceStart: Date, sourceEnd: Date, arrival: Date,
                provenance: OwnerHeartRateProvenance) {
        self.id = id; self.bpm = bpm; self.sourceStart = sourceStart; self.sourceEnd = sourceEnd
        self.arrival = arrival; self.provenance = provenance
    }
    private struct Identity: Codable {
        let id: UUID
        let bpm: Double, sourceStartUnixSeconds: Double, sourceEndUnixSeconds: Double
        let provenance: OwnerHeartRateProvenance
    }
    public func canonicalIdentityBytes() throws -> Data {
        try provenance.validate()
        guard bpm.isFinite, bpm > 0, bpm <= 300, sourceStart.timeIntervalSince1970.isFinite,
              sourceEnd.timeIntervalSince1970.isFinite, sourceStart <= sourceEnd else {
            throw OwnerTelemetryError.invalid("native identity")
        }
        return try PracticeSetupJSON.encode(Identity(id: id, bpm: bpm, sourceStartUnixSeconds: sourceStart.timeIntervalSince1970,
            sourceEndUnixSeconds: sourceEnd.timeIntervalSince1970, provenance: provenance))
    }
    func arriving(_ date: Date) -> Self {
        Self(id: id, bpm: bpm, sourceStart: sourceStart, sourceEnd: sourceEnd, arrival: date, provenance: provenance)
    }
}

public struct OwnerTelemetrySampleRecord: Equatable, Sendable {
    public let sample: OwnerHeartRateSample
    public let consentSegmentID: UUID, queryGeneration: UUID
    public let isEligible: Bool
    public let identityDigest: String
    let identityBytes: Data
}
public struct OwnerTelemetryConflictGroup: Equatable, Sendable {
    public let sampleID: UUID
    public let versions: [OwnerTelemetrySampleRecord]
}
public struct OwnerTelemetryPageResult: Equatable, Sendable {
    public let admittedCount: Int, deduplicatedCount: Int
    public let excluded: [OwnerTelemetryReason: Int]
}
public enum OwnerTelemetryStatus: String, Codable, Sendable { case open, ended, interrupted }
public enum OwnerTelemetryObservationKind: String, Codable, Sendable { case baseline, active, recovery, rest, paused, ending, interrupted }
public enum OwnerTelemetryClosure: String, Codable, Sendable { case open, setStarted, setStopped, nextSet, paused, ended, interrupted, consentChanged }
public struct OwnerTelemetryObservation: Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: OwnerTelemetryObservationKind
    public let recordingID: UUID?
    public let consentSegmentID: UUID, queryGeneration: UUID
    public let start: OwnerTelemetryInstant, end: OwnerTelemetryInstant
    public let closure: OwnerTelemetryClosure
    public init(id: UUID, kind: OwnerTelemetryObservationKind, recordingID: UUID?, consentSegmentID: UUID,
                queryGeneration: UUID, start: OwnerTelemetryInstant, end: OwnerTelemetryInstant, closure: OwnerTelemetryClosure) throws {
        try start.validate(); try end.validate()
        guard start.monotonicSeconds <= end.monotonicSeconds, start.wallUnixSeconds <= end.wallUnixSeconds else {
            throw OwnerTelemetryError.invalid("observation order")
        }
        self.id = id; self.kind = kind; self.recordingID = recordingID; self.consentSegmentID = consentSegmentID
        self.queryGeneration = queryGeneration; self.start = start; self.end = end; self.closure = closure
    }
    var clockDiscontinuous: Bool {
        abs((end.wallUnixSeconds - start.wallUnixSeconds) - (end.monotonicSeconds - start.monotonicSeconds)) > 2
    }
}
public struct OwnerTelemetryEvent: Codable, Equatable, Sendable {
    public let id: UUID
    public let at: OwnerTelemetryInstant
    public let reason: OwnerTelemetryReason
    public let count: Int
    public init(id: UUID, at: OwnerTelemetryInstant, reason: OwnerTelemetryReason, count: Int = 1) throws {
        try at.validate()
        guard (1...256).contains(count), count == 1 || reason.permitsCount else { throw OwnerTelemetryError.invalid("event count") }
        self.id = id; self.at = at; self.reason = reason; self.count = count
    }
}
public struct OwnerTelemetryConsentSegment: Equatable, Sendable {
    public let id: UUID
    public let authority: OwnerPracticeIdentity
    public let queryGeneration: UUID?
    public let start: OwnerTelemetryInstant
    public internal(set) var end: OwnerTelemetryInstant?
    let transition: OwnerAuthorityMutation?
    public var authorityRevision: Int64 { authority.revision }
    public var authorityDigest: String { get throws { OwnerTelemetryHeader.digest(try authority.encoded()) } }
    public var heartRateEnabled: Bool { authority.isCollectionAllowed && authority.heartRateConsent }
}
public struct OwnerTelemetrySet: Equatable, Sendable {
    public let context: OwnerRecordingContext, mapping: SetClockMapping?
    public let consentSegmentID: UUID
    public let rawStartSeconds: Double, startedAt: OwnerTelemetryInstant
    public internal(set) var rawStopSeconds: Double?, stoppedAt: OwnerTelemetryInstant?
}
public struct OwnerTelemetryFinalization: Codable, Equatable, Sendable {
    public let status: OwnerTelemetryStatus
    public let endedAt: OwnerTelemetryInstant
    public let absenceReasons: [OwnerTelemetryReason]
    public let recordingIDs: [UUID]
    public let sampleCount: Int, eventCount: Int
}

/// Bounded historical evidence. Every mutation is staged before canonical size validation.
public struct OwnerPracticeTelemetry: Equatable, Sendable {
    public static let maximumBytes = 2 * 1024 * 1024
    public let header: OwnerTelemetryHeader
    public private(set) var sets: [OwnerTelemetrySet] = []
    public private(set) var consentSegments: [OwnerTelemetryConsentSegment]
    public private(set) var sampleRecords: [OwnerTelemetrySampleRecord] = []
    public private(set) var observations: [OwnerTelemetryObservation] = []
    public private(set) var events: [OwnerTelemetryEvent] = []
    public private(set) var exclusionCounts: [OwnerTelemetryReason: Int] = [:]
    public private(set) var incompleteReasons: Set<OwnerTelemetryReason> = []
    public private(set) var status: OwnerTelemetryStatus = .open
    public private(set) var finalization: OwnerTelemetryFinalization?
    public var eventCount: Int { consentSegments.count + observations.count + events.count }
    public var canonicalContentByteCount: Int { (try? encoded().count) ?? Self.maximumBytes + 1 }
    public var conflictGroups: [OwnerTelemetryConflictGroup] {
        Dictionary(grouping: sampleRecords, by: { $0.sample.id }).filter { $0.value.count > 1 }
            .map { OwnerTelemetryConflictGroup(sampleID: $0.key, versions: $0.value) }
            .sorted { $0.sampleID.uuidString < $1.sampleID.uuidString }
    }
    public init(header: OwnerTelemetryHeader, authority: OwnerPracticeIdentity,
                initialConsentSegmentID: UUID, initialQueryGeneration: UUID?) throws {
        guard try OwnerTelemetryHeader.decode(header.encoded(), authority: authority) == header,
              authority.heartRateConsent == (initialQueryGeneration != nil) else {
            throw OwnerTelemetryError.invalid("initial consent scope")
        }
        self.header = header
        consentSegments = [OwnerTelemetryConsentSegment(id: initialConsentSegmentID, authority: authority,
            queryGeneration: initialQueryGeneration, start: try OwnerTelemetryInstant(
                wallUnixSeconds: header.clock.wallAnchorUnixSeconds, monotonicSeconds: header.clock.monotonicAnchorSeconds),
            end: nil, transition: nil)]
    }
    private func mutable() throws {
        guard finalization == nil, status != .interrupted else { throw OwnerTelemetryError.closed }
    }
    @discardableResult private func instant(_ at: OwnerTelemetryInstant) throws -> Double {
        try at.validate()
        let elapsed = at.monotonicSeconds - header.clock.monotonicAnchorSeconds
        guard elapsed >= 0, elapsed <= 1800 else { throw OwnerTelemetryError.invalid("practice time") }
        return elapsed
    }
    private mutating func refuse(_ reason: OwnerTelemetryReason) throws -> Never {
        incompleteReasons.insert(reason)
        throw OwnerTelemetryError.capacity
    }
    private mutating func accept(_ candidate: Self) throws {
        // Reserve bounded room for refusal and terminal inventory, without evicting admitted evidence.
        guard let size = try? candidate.encoded().count, size <= Self.maximumBytes - 2048 else {
            try refuse(.byteLimit)
        }
        self = candidate
    }
    private mutating func eventRoom() throws {
        guard eventCount < 512 else { try refuse(.eventLimit) }
    }
    private func segment(_ id: UUID) throws -> OwnerTelemetryConsentSegment {
        guard let value = consentSegments.first(where: { $0.id == id }) else { throw OwnerTelemetryError.invalid("consent identity") }
        return value
    }
    func contains(_ sample: OwnerHeartRateSample, in segment: OwnerTelemetryConsentSegment) -> Bool {
        let start = sample.sourceStart.timeIntervalSince1970, end = sample.sourceEnd.timeIntervalSince1970
        return segment.heartRateEnabled && start >= segment.start.wallUnixSeconds
            && (end > segment.start.wallUnixSeconds || segment.id == consentSegments.first?.id)
            && (segment.end.map { end <= $0.wallUnixSeconds } ?? true)
    }
    private func checkSet(_ context: OwnerRecordingContext, mapping: SetClockMapping?,
                          consent: OwnerTelemetryConsentSegment, raw: Double, at: OwnerTelemetryInstant) throws {
        try instant(at)
        guard header.matches(context), consent.authority.isCollectionAllowed,
              context.authorityRevision == consent.authorityRevision,
              try context.authorityDigest == consent.authorityDigest,
              context.heartRateConsent == consent.authority.heartRateConsent,
              at.monotonicSeconds >= consent.start.monotonicSeconds,
              consent.end.map({ at.monotonicSeconds < $0.monotonicSeconds }) ?? true,
              raw.isFinite, raw >= context.metadata.clock.monotonicAnchorSeconds else {
            throw OwnerTelemetryError.invalid("set context scope")
        }
        if let mapping {
            _ = try SetClockMapping.decode(mapping.encoded(), context: context, header: header)
            guard abs(raw + mapping.offsetSeconds - at.monotonicSeconds) <= mapping.uncertaintySeconds + 0.000_001 else {
                throw OwnerTelemetryError.invalid("raw start calibration")
            }
        }
    }
    public mutating func admitSet(context: OwnerRecordingContext, mapping: SetClockMapping?, consentSegmentID: UUID,
                                 rawStartSeconds: Double, at: OwnerTelemetryInstant) throws {
        try mutable()
        guard status == .open, consentSegments.last?.id == consentSegmentID,
              !sets.contains(where: { $0.context.recordingID == context.recordingID }) else {
            throw OwnerTelemetryError.invalid("set admission identity")
        }
        try checkSet(context, mapping: mapping, consent: segment(consentSegmentID), raw: rawStartSeconds, at: at)
        if let prior = sets.last {
            guard let stop = prior.stoppedAt, at.monotonicSeconds >= stop.monotonicSeconds else {
                throw OwnerTelemetryError.invalid("overlapping sets")
            }
        }
        guard sets.count < 20 else { try refuse(.setLimit) }
        var next = self
        next.sets.append(OwnerTelemetrySet(context: context, mapping: mapping, consentSegmentID: consentSegmentID,
            rawStartSeconds: rawStartSeconds, startedAt: at, rawStopSeconds: nil, stoppedAt: nil))
        try accept(next)
    }
    public mutating func stopSet(recordingID: UUID, rawStopSeconds: Double, at: OwnerTelemetryInstant) throws {
        try mutable(); try instant(at)
        guard let index = sets.firstIndex(where: { $0.context.recordingID == recordingID }) else {
            throw OwnerTelemetryError.invalid("unknown set")
        }
        let set = sets[index]
        guard rawStopSeconds.isFinite, rawStopSeconds >= set.rawStartSeconds,
              at.monotonicSeconds >= set.startedAt.monotonicSeconds else { throw OwnerTelemetryError.invalid("set stop order") }
        if let mapping = set.mapping {
            guard abs(rawStopSeconds + mapping.offsetSeconds - at.monotonicSeconds) <= mapping.uncertaintySeconds + 0.000_001 else {
                throw OwnerTelemetryError.invalid("raw stop calibration")
            }
        }
        if set.stoppedAt != nil {
            guard set.stoppedAt == at, set.rawStopSeconds == rawStopSeconds else { throw OwnerTelemetryError.invalid("set stop conflict") }
            return
        }
        var next = self
        next.sets[index].rawStopSeconds = rawStopSeconds; next.sets[index].stoppedAt = at
        try accept(next)
    }
    public mutating func transitionAuthority(to authority: OwnerPracticeIdentity, decision: OwnerConsentDecision?,
                                            at: OwnerTelemetryInstant, segmentID: UUID, queryGeneration: UUID?) throws {
        try mutable(); try instant(at)
        guard status == .open, let previous = consentSegments.last,
              !consentSegments.contains(where: { $0.id == segmentID }),
              queryGeneration.map({ q in !consentSegments.contains(where: { $0.queryGeneration == q }) }) ?? true,
              authority.heartRateConsent == (queryGeneration != nil), at.monotonicSeconds >= previous.start.monotonicSeconds else {
            throw OwnerTelemetryError.invalid("authority segment identity")
        }
        let mutation: OwnerAuthorityMutation
        if let decision {
            guard try previous.authority.applying(decision) == authority else { throw OwnerTelemetryError.invalid("authority decision") }
            // Read only the checked decision's original wall time, then use the existing command validator.
            struct Evidence: Decodable {
                struct Body: Decodable {
                    struct Decision: Decodable { let confirmedAtUnixSeconds: Double }
                    let lastDecision: Decision
                }
                let body: Body
            }
            let time = try JSONDecoder().decode(Evidence.self, from: authority.encoded()).body.lastDecision.confirmedAtUnixSeconds
            mutation = try authority.isCollectionAllowed
                ? .heartRate(from: previous.authority, allowed: authority.heartRateConsent, decisionID: decision.id, confirmedAtUnixSeconds: time)
                : .withdraw(from: previous.authority, decisionID: decision.id, confirmedAtUnixSeconds: time)
        } else {
            mutation = try .advance(from: previous.authority, mutationID: segmentID)
        }
        guard try mutation.resolve(from: previous.authority) == authority else { throw OwnerTelemetryError.invalid("authority transition") }
        try eventRoom()
        var next = self
        next.consentSegments[next.consentSegments.count - 1].end = at
        next.consentSegments.append(OwnerTelemetryConsentSegment(id: segmentID, authority: authority,
            queryGeneration: queryGeneration, start: at, end: nil, transition: mutation))
        if !authority.isCollectionAllowed { next.status = .ended }
        next.normalizeSamples()
        try accept(next)
    }
    private func exclusion(_ sample: OwnerHeartRateSample, consent: OwnerTelemetryConsentSegment?, query: UUID) -> OwnerTelemetryReason? {
        guard sample.bpm.isFinite, sample.bpm > 0, sample.bpm <= 300 else { return .bpmOutOfRange }
        let start = sample.sourceStart.timeIntervalSince1970, end = sample.sourceEnd.timeIntervalSince1970
        guard [start, end, sample.arrival.timeIntervalSince1970].allSatisfy(\.isFinite) else { return .invalidDate }
        guard start <= end else { return .unorderedInterval }
        guard start >= header.clock.wallAnchorUnixSeconds, end <= header.clock.wallAnchorUnixSeconds + 1800 else { return .outsidePractice }
        guard sample.provenance.watchInstallationEpoch == header.watchInstallationEpoch else { return .wrongInstallationEpoch }
        guard let consent, consent.heartRateEnabled else { return .consentExcluded }
        guard consent.queryGeneration == query else { return .wrongQuery }
        guard contains(sample, in: consent) else { return .consentExcluded }
        return nil
    }
    private mutating func normalizeSamples() {
        let counts = Dictionary(grouping: sampleRecords, by: { $0.sample.id }).mapValues(\.count)
        sampleRecords = sampleRecords.map { record in
            let eligible = counts[record.sample.id] == 1
                && (finalization.map { record.sample.sourceEnd.timeIntervalSince1970 <= $0.endedAt.wallUnixSeconds } ?? true)
                && consentSegments.first(where: { $0.id == record.consentSegmentID }).map { contains(record.sample, in: $0) } == true
            return OwnerTelemetrySampleRecord(sample: record.sample, consentSegmentID: record.consentSegmentID,
                queryGeneration: record.queryGeneration, isEligible: eligible,
                identityDigest: record.identityDigest, identityBytes: record.identityBytes)
        }.sorted {
            if $0.sample.id != $1.sample.id { return $0.sample.id.uuidString < $1.sample.id.uuidString }
            if $0.identityDigest != $1.identityDigest { return $0.identityDigest < $1.identityDigest }
            return $0.identityBytes.lexicographicallyPrecedes($1.identityBytes)
        }
        if counts.values.contains(where: { $0 > 1 }) { incompleteReasons.insert(.sampleConflict) }
    }
    @discardableResult public mutating func appendPage(_ samples: [OwnerHeartRateSample], consentSegmentID: UUID,
                                                     queryGeneration: UUID) throws -> OwnerTelemetryPageResult {
        try mutable()
        guard samples.count <= 256 else { try refuse(.pageLimit) }
        var next = self, admitted = 0, duplicates = 0
        var excluded: [OwnerTelemetryReason: Int] = [:]
        let consent = consentSegments.first(where: { $0.id == consentSegmentID })
        for sample in samples {
            if let reason = exclusion(sample, consent: consent, query: queryGeneration) {
                excluded[reason, default: 0] += 1; continue
            }
            let bytes = try sample.canonicalIdentityBytes(), digest = OwnerTelemetryHeader.digest(bytes)
            if let index = next.sampleRecords.firstIndex(where: { $0.sample.id == sample.id && $0.identityBytes == bytes }) {
                let old = next.sampleRecords[index]
                guard old.consentSegmentID == consentSegmentID, old.queryGeneration == queryGeneration else {
                    throw OwnerTelemetryError.invalid("sample scope rebound")
                }
                next.sampleRecords[index] = OwnerTelemetrySampleRecord(sample: sample.arriving(min(sample.arrival, old.sample.arrival)),
                    consentSegmentID: consentSegmentID, queryGeneration: queryGeneration, isEligible: old.isEligible,
                    identityDigest: digest, identityBytes: bytes)
                duplicates += 1
            } else {
                next.sampleRecords.append(OwnerTelemetrySampleRecord(sample: sample, consentSegmentID: consentSegmentID,
                    queryGeneration: queryGeneration, isEligible: true, identityDigest: digest, identityBytes: bytes))
                admitted += 1
            }
        }
        guard next.sampleRecords.count <= 8192 else { try refuse(.sampleLimit) }
        guard exclusionCounts.values.reduce(0, +) <= 512 * 256 - excluded.values.reduce(0, +) else { try refuse(.eventLimit) }
        for (reason, count) in excluded { next.exclusionCounts[reason, default: 0] += count }
        next.normalizeSamples()
        try accept(next)
        return OwnerTelemetryPageResult(admittedCount: admitted, deduplicatedCount: duplicates, excluded: excluded)
    }
    public mutating func recordObservation(_ value: OwnerTelemetryObservation) throws {
        try mutable(); try instant(value.start); try instant(value.end)
        _ = try OwnerTelemetryObservation(id: value.id, kind: value.kind, recordingID: value.recordingID,
            consentSegmentID: value.consentSegmentID, queryGeneration: value.queryGeneration,
            start: value.start, end: value.end, closure: value.closure)
        let consent = try segment(value.consentSegmentID)
        guard consent.heartRateEnabled, consent.queryGeneration == value.queryGeneration,
              value.start.monotonicSeconds >= consent.start.monotonicSeconds,
              consent.end.map({ value.end.monotonicSeconds <= $0.monotonicSeconds }) ?? true else {
            throw OwnerTelemetryError.invalid("observation consent")
        }
        if let id = value.recordingID {
            guard let set = sets.first(where: { $0.context.recordingID == id }) else { throw OwnerTelemetryError.invalid("observation set") }
            if value.kind == .active {
                guard value.start.monotonicSeconds >= set.startedAt.monotonicSeconds,
                      set.stoppedAt.map({ value.end.monotonicSeconds <= $0.monotonicSeconds }) ?? true else {
                    throw OwnerTelemetryError.invalid("active bounds")
                }
            } else if value.kind == .recovery || value.kind == .rest {
                guard let stop = set.stoppedAt, value.start.monotonicSeconds >= stop.monotonicSeconds else {
                    throw OwnerTelemetryError.invalid("recovery before stop")
                }
            }
        } else if value.kind != .baseline { throw OwnerTelemetryError.invalid("missing observation set") }
        let index = observations.firstIndex(where: { $0.id == value.id })
        if let index {
            let old = observations[index]
            if old == value { return }
            guard old.closure == .open, old.kind == value.kind, old.recordingID == value.recordingID,
                  old.consentSegmentID == value.consentSegmentID, old.queryGeneration == value.queryGeneration,
                  old.start == value.start, value.end.monotonicSeconds >= old.end.monotonicSeconds,
                  value.end.wallUnixSeconds >= old.end.wallUnixSeconds else { throw OwnerTelemetryError.invalid("observation rebound") }
        }
        guard !observations.contains(where: { other in
            other.id != value.id && max(other.start.monotonicSeconds, value.start.monotonicSeconds)
                < min(other.end.monotonicSeconds, value.end.monotonicSeconds)
        }) else { throw OwnerTelemetryError.invalid("overlapping observations") }
        if index == nil { try eventRoom() }
        var next = self
        if let index { next.observations[index] = value } else { next.observations.append(value) }
        next.observations.sort { $0.start.monotonicSeconds == $1.start.monotonicSeconds
            ? $0.id.uuidString < $1.id.uuidString : $0.start.monotonicSeconds < $1.start.monotonicSeconds }
        if value.clockDiscontinuous { next.incompleteReasons.insert(.clockDiscontinuity) }
        try accept(next)
    }
    public mutating func recordEvent(_ event: OwnerTelemetryEvent) throws {
        try mutable(); try instant(event.at)
        _ = try OwnerTelemetryEvent(id: event.id, at: event.at, reason: event.reason, count: event.count)
        if let old = events.first(where: { $0.id == event.id }) {
            guard old == event else { throw OwnerTelemetryError.invalid("event identity conflict") }
            return
        }
        try eventRoom()
        guard exclusionCounts.values.reduce(0, +) <= 512 * 256 - event.count else { try refuse(.eventLimit) }
        var next = self
        next.events.append(event)
        next.events.sort { $0.at.monotonicSeconds == $1.at.monotonicSeconds
            ? $0.id.uuidString < $1.id.uuidString : $0.at.monotonicSeconds < $1.at.monotonicSeconds }
        next.exclusionCounts[event.reason, default: 0] += event.count
        if [.sourceDeleted, .sourceError, .interrupted, .clockDiscontinuity].contains(event.reason) {
            next.incompleteReasons.insert(event.reason)
        }
        try accept(next)
    }
    public mutating func finalize(status: OwnerTelemetryStatus, at: OwnerTelemetryInstant,
                                  absenceReasons: [OwnerTelemetryReason]) throws {
        let reasons = Array(Set(absenceReasons)).sorted { $0.rawValue < $1.rawValue }
        let value = OwnerTelemetryFinalization(status: status, endedAt: at, absenceReasons: reasons,
            recordingIDs: sets.map { $0.context.recordingID }, sampleCount: sampleRecords.count, eventCount: eventCount)
        if let finalization {
            guard finalization == value else { throw OwnerTelemetryError.closed }
            return
        }
        try mutable(); try at.validate()
        guard at.monotonicSeconds - header.clock.monotonicAnchorSeconds <= 1800 else { try refuse(.durationLimit) }
        try instant(at)
        let projectedWall = header.clock.wallAnchorUnixSeconds + at.monotonicSeconds - header.clock.monotonicAnchorSeconds
        let interruptedClock = status == .interrupted && reasons.contains(.clockDiscontinuity)
            && abs(at.wallUnixSeconds - projectedWall) > 2
            && events.contains { $0.reason == .clockDiscontinuity && $0.at.monotonicSeconds <= at.monotonicSeconds }
        let sourceUpperBound = interruptedClock ? max(at.wallUnixSeconds, projectedWall) : at.wallUnixSeconds
        guard status != .open, status == .interrupted || sets.allSatisfy({ $0.stoppedAt != nil }),
              status != .interrupted || reasons.contains(.interrupted),
              sets.allSatisfy({ ($0.stoppedAt ?? $0.startedAt).monotonicSeconds <= at.monotonicSeconds }),
              observations.allSatisfy({ $0.end.monotonicSeconds <= at.monotonicSeconds }),
              events.allSatisfy({ $0.at.monotonicSeconds <= at.monotonicSeconds }),
              consentSegments.allSatisfy({ $0.start.monotonicSeconds <= at.monotonicSeconds }),
              sampleRecords.allSatisfy({ $0.sample.sourceEnd.timeIntervalSince1970 <= sourceUpperBound }) else {
            throw OwnerTelemetryError.invalid("terminal boundary")
        }
        var next = self
        next.status = status; next.finalization = value
        next.normalizeSamples()
        if status == .interrupted { next.incompleteReasons.insert(.interrupted) }
        try accept(next)
    }
    mutating func markReopenedPartial() {
        status = .interrupted; incompleteReasons.insert(.reopenedPartial)
    }

    private struct ConsentWire: Codable {
        let id: UUID, authority: Data, queryGeneration: UUID?, start: OwnerTelemetryInstant, end: OwnerTelemetryInstant?
        let transition: Data?
    }
    private struct SetWire: Codable {
        let context: Data, rawMetadata: Data, mapping: Data?, consentSegmentID: UUID
        let rawStartSeconds: Double, startedAt: OwnerTelemetryInstant
        let rawStopSeconds: Double?, stoppedAt: OwnerTelemetryInstant?
    }
    /// Repeated machine provenance and consent are interned; conflicts cost one row per native version.
    private struct SampleWire: Codable {
        let id: UUID
        let bpm: Double, start: Double, end: Double, arrival: Double
        let provenance: Int, consent: Int
        init(_ record: OwnerTelemetrySampleRecord, provenance: Int, consent: Int) {
            id = record.sample.id; bpm = record.sample.bpm
            start = record.sample.sourceStart.timeIntervalSince1970; end = record.sample.sourceEnd.timeIntervalSince1970
            arrival = record.sample.arrival.timeIntervalSince1970; self.provenance = provenance; self.consent = consent
        }
        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            id = try c.decode(UUID.self); bpm = try c.decode(Double.self); start = try c.decode(Double.self)
            end = try c.decode(Double.self); arrival = try c.decode(Double.self)
            provenance = try c.decode(Int.self); consent = try c.decode(Int.self)
            guard c.isAtEnd else { throw OwnerTelemetryError.integrity }
        }
        func encode(to encoder: any Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(id); try c.encode(bpm); try c.encode(start); try c.encode(end); try c.encode(arrival)
            try c.encode(provenance); try c.encode(consent)
        }
    }
    private struct Body: Codable {
        let schemaVersion: Int, header: Data
        let consentSegments: [ConsentWire], sets: [SetWire], provenance: [OwnerHeartRateProvenance], samples: [SampleWire]
        let observations: [OwnerTelemetryObservation], events: [OwnerTelemetryEvent]
        let exclusionCounts: [String: Int], incompleteReasons: [OwnerTelemetryReason]
        let status: OwnerTelemetryStatus, finalization: OwnerTelemetryFinalization?
    }
    public func encoded() throws -> Data {
        var table: [Data: OwnerHeartRateProvenance] = [:]
        for record in sampleRecords { table[try PracticeSetupJSON.encode(record.sample.provenance)] = record.sample.provenance }
        let keys = table.keys.sorted { $0.lexicographicallyPrecedes($1) }
        let indices = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($0.element, $0.offset) })
        let provenance = keys.compactMap { table[$0] }
        let consentIndices = Dictionary(uniqueKeysWithValues: consentSegments.enumerated().map { ($0.element.id, $0.offset) })
        let rows = try sampleRecords.map { record in
            guard let p = indices[try PracticeSetupJSON.encode(record.sample.provenance)],
                  let c = consentIndices[record.consentSegmentID] else { throw OwnerTelemetryError.integrity }
            return SampleWire(record, provenance: p, consent: c)
        }
        let consents = try consentSegments.map {
            ConsentWire(id: $0.id, authority: try $0.authority.encoded(), queryGeneration: $0.queryGeneration,
                start: $0.start, end: $0.end, transition: try $0.transition?.encoded())
        }
        let setRows = try sets.map {
            SetWire(context: try $0.context.encoded(), rawMetadata: try RecordingChunkCodec.encodeMetadata($0.context.metadata),
                mapping: try $0.mapping?.encoded(), consentSegmentID: $0.consentSegmentID,
                rawStartSeconds: $0.rawStartSeconds, startedAt: $0.startedAt,
                rawStopSeconds: $0.rawStopSeconds, stoppedAt: $0.stoppedAt)
        }
        let body = Body(schemaVersion: 1, header: try header.encoded(), consentSegments: consents, sets: setRows,
            provenance: provenance, samples: rows, observations: observations, events: events,
            exclusionCounts: Dictionary(uniqueKeysWithValues: exclusionCounts.map { ($0.key.rawValue, $0.value) }),
            incompleteReasons: incompleteReasons.sorted { $0.rawValue < $1.rawValue }, status: status, finalization: finalization)
        return try OwnerCanonical.encode(body, domain: "PSLOwnerPracticeTelemetry1", limit: Self.maximumBytes)
    }
    public static func decode(_ bytes: Data) throws -> Self {
        let body: Body = try OwnerCanonical.decode(bytes, domain: "PSLOwnerPracticeTelemetry1", limit: maximumBytes)
        guard body.schemaVersion == 1, let first = body.consentSegments.first, first.transition == nil,
              body.consentSegments.count + body.observations.count + body.events.count <= 512,
              body.sets.count <= 20, body.samples.count <= 8192, body.provenance.count <= body.samples.count else {
            throw OwnerTelemetryError.integrity
        }
        let owner = try OwnerPracticeIdentity.decode(first.authority)
        let header = try OwnerTelemetryHeader.decode(body.header, authority: owner)
        var result = try Self(header: header, authority: owner, initialConsentSegmentID: first.id,
            initialQueryGeneration: first.queryGeneration)
        guard first.start == result.consentSegments[0].start else { throw OwnerTelemetryError.integrity }
        for item in body.consentSegments.dropFirst() {
            guard let transition = item.transition, let prior = result.consentSegments.last else { throw OwnerTelemetryError.integrity }
            let command = try OwnerAuthorityMutation.decode(transition)
            let authority = try OwnerPracticeIdentity.decode(item.authority)
            guard try command.resolve(from: prior.authority) == authority else { throw OwnerTelemetryError.integrity }
            let decision = try command.isRevisionOnly ? nil : command.consentDecision(for: prior.authority)
            try result.transitionAuthority(to: authority, decision: decision, at: item.start,
                segmentID: item.id, queryGeneration: item.queryGeneration)
        }
        for item in body.sets {
            let context = try OwnerRecordingContext.decode(item.context, rawMetadataBytes: item.rawMetadata)
            let mapping = try item.mapping.map { try SetClockMapping.decode($0, context: context, header: header) }
            try result.checkSet(context, mapping: mapping, consent: result.segment(item.consentSegmentID),
                raw: item.rawStartSeconds, at: item.startedAt)
            guard !result.sets.contains(where: { $0.context.recordingID == context.recordingID }),
                  result.sets.last.map({ $0.stoppedAt.map { $0.monotonicSeconds <= item.startedAt.monotonicSeconds } ?? false }) ?? true,
                  (item.rawStopSeconds == nil) == (item.stoppedAt == nil) else { throw OwnerTelemetryError.integrity }
            result.sets.append(OwnerTelemetrySet(context: context, mapping: mapping, consentSegmentID: item.consentSegmentID,
                rawStartSeconds: item.rawStartSeconds, startedAt: item.startedAt, rawStopSeconds: nil, stoppedAt: nil))
            if let raw = item.rawStopSeconds, let at = item.stoppedAt {
                try result.stopSet(recordingID: context.recordingID, rawStopSeconds: raw, at: at)
            }
        }
        for provenance in body.provenance { try provenance.validate() }
        var nativeIdentities = Set<Data>()
        for row in body.samples {
            guard body.provenance.indices.contains(row.provenance), result.consentSegments.indices.contains(row.consent),
                  row.arrival.isFinite else { throw OwnerTelemetryError.integrity }
            let consent = result.consentSegments[row.consent]
            guard consent.heartRateEnabled, let query = consent.queryGeneration else { throw OwnerTelemetryError.integrity }
            let sample = OwnerHeartRateSample(id: row.id, bpm: row.bpm, sourceStart: Date(timeIntervalSince1970: row.start),
                sourceEnd: Date(timeIntervalSince1970: row.end), arrival: Date(timeIntervalSince1970: row.arrival),
                provenance: body.provenance[row.provenance])
            let reason = result.exclusion(sample, consent: consent, query: query)
            guard reason == nil || (reason == .consentExcluded && row.start >= consent.start.wallUnixSeconds) else {
                throw OwnerTelemetryError.integrity
            }
            let identity = try sample.canonicalIdentityBytes()
            guard nativeIdentities.insert(identity).inserted else { throw OwnerTelemetryError.integrity }
            result.sampleRecords.append(OwnerTelemetrySampleRecord(sample: sample, consentSegmentID: consent.id,
                queryGeneration: query, isEligible: true, identityDigest: OwnerTelemetryHeader.digest(identity), identityBytes: identity))
        }
        result.normalizeSamples()
        for observation in body.observations { try result.recordObservation(observation) }
        for event in body.events { try result.recordEvent(event) }
        var counts: [OwnerTelemetryReason: Int] = [:], total = 0
        for (key, count) in body.exclusionCounts {
            guard let reason = OwnerTelemetryReason(rawValue: key), count > 0, count <= 512 * 256 - total else {
                throw OwnerTelemetryError.integrity
            }
            counts[reason] = count; total += count
        }
        guard result.exclusionCounts.allSatisfy({ counts[$0.key, default: 0] >= $0.value }),
              result.incompleteReasons.isSubset(of: Set(body.incompleteReasons)) else { throw OwnerTelemetryError.integrity }
        result.exclusionCounts = counts; result.incompleteReasons = Set(body.incompleteReasons)
        if let final = body.finalization {
            try result.finalize(status: final.status, at: final.endedAt, absenceReasons: final.absenceReasons)
            guard result.finalization == final else { throw OwnerTelemetryError.integrity }
        } else if body.status == .interrupted, result.incompleteReasons.contains(.reopenedPartial) {
            result.markReopenedPartial()
        }
        guard result.status == body.status, try result.encoded() == bytes else { throw OwnerTelemetryError.integrity }
        return result
    }
}
