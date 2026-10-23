import CryptoKit
import Foundation
import Testing
@testable import PadelCore

// O6 tests-first contract. No HealthKit, native-session acknowledgement, runtime admission,
// raw-schema changes or capture permission is supplied by these values.
// All fixture data is synthetic. Shared helpers live only in these three O6 test files.
// Canonical domains: PSLOwnerTelemetryHeader1, PSLOwnerSetClockMapping1,
// PSLOwnerPracticeTelemetry1 and PSLOwnerTelemetryManifest1; envelopes use body + sha256.
let o6Owner = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
let o6Phone = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
let o6Watch = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
let o6Practice = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
let o6Runtime = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
let o6PracticeClock = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
let o6Consent = o6ID(1)
let o6Query = o6ID(2)
let o6Wall = 1_800_000_000.0
let o6Mono = 1_000.0

func o6ID(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "A0000000-0000-0000-0000-%012X", value))!
}

func o6Authority(heartRate: Bool = true) throws -> OwnerPracticeIdentity {
    try OwnerPracticeIdentity.enrolled(ownerID: o6Owner, phoneInstallationEpoch: o6Phone,
        watchInstallationEpoch: o6Watch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
        includesHeartRate: heartRate,
        decisionID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        confirmedAtUnixSeconds: o6Wall, policyDigest: OwnerPracticePolicy.digest)
}

func o6Header(authority: OwnerPracticeIdentity? = nil, uncertainty: Double = 0,
              monotonicAnchor: Double = o6Mono) throws -> OwnerTelemetryHeader {
    try OwnerTelemetryHeader(authority: authority ?? o6Authority(), practiceID: o6Practice,
        clock: RecordingClock(domainID: o6PracticeClock, monotonicAnchorSeconds: monotonicAnchor,
            wallAnchorUnixSeconds: o6Wall),
        runtimeGeneration: o6Runtime, clockUncertaintySeconds: uncertainty)
}

func o6Instant(_ seconds: Double, wallAdjustment: Double = 0) throws -> OwnerTelemetryInstant {
    try OwnerTelemetryInstant(wallUnixSeconds: o6Wall + seconds + wallAdjustment,
        monotonicSeconds: o6Mono + seconds)
}

func o6Context(_ number: Int = 10, authority: OwnerPracticeIdentity? = nil,
               rawAnchor: Double = 10, wallOffset: Double = 0,
               runtime: UUID = o6Runtime, practiceID: UUID = o6Practice) throws -> OwnerRecordingContext {
    let owner = try authority ?? o6Authority()
    let metadata = try RecordingMetadata(recordingID: o6ID(number),
        clock: RecordingClock(domainID: o6ID(number + 100_000),
            monotonicAnchorSeconds: rawAnchor, wallAnchorUnixSeconds: o6Wall + wallOffset),
        appBuild: "7", protocolVersion: RecordingDrill.protocolVersion,
        deviceModel: "synthetic-watch", operatingSystem: "watchOS 27", handedness: .right,
        playingArm: .right, watchWrist: .right, watchOrientation: "Crown left",
        playingArmConfirmed: true, drill: RecordingDrill.forehandGroundstroke.rawValue,
        capabilityReport: "synthetic supported",
        streams: try RecordingStream.allCases.map {
            try RecordingStreamConfiguration(stream: $0, supported: true,
                requestedRateHz: nil, knownSensorLimit: nil)
        })
    let draft = try PracticeSetupDraft(originInstallationEpoch: owner.phoneInstallationEpoch,
        preparationID: o6ID(number + 200_000), revision: 1,
        preferences: PracticeSetupPreferences(currentRacketArm: .right, usualHand: .right,
            intendedDrill: .forehandGroundstroke))
    return try OwnerRecordingContext.bind(rawMetadataBytes: RecordingChunkCodec.encodeMetadata(metadata),
        authority: owner, practiceID: practiceID, acceptedSetup: draft,
        generations: PracticeSetupGenerations(runtimeGeneration: runtime,
            preparationGeneration: o6ID(number + 300_000))).context
}

func o6Calibration(_ context: OwnerRecordingContext, radius: Double = 0,
                   runtime: UUID = o6Runtime, practiceDomain: UUID = o6PracticeClock,
                   wallAdjustment: Double = 0) throws -> OwnerSetClockCalibration {
    let clock = context.metadata.clock
    let practiceSeconds = o6Mono + clock.wallAnchorUnixSeconds - o6Wall
    return try OwnerSetClockCalibration(rawClock: clock, practiceClockDomainID: practiceDomain,
        runtimeGeneration: runtime, rawBeforeSeconds: clock.monotonicAnchorSeconds - radius,
        rawAfterSeconds: clock.monotonicAnchorSeconds + radius,
        practiceMonotonicSeconds: practiceSeconds,
        wallUnixSeconds: clock.wallAnchorUnixSeconds + wallAdjustment)
}

func o6Mapping(_ context: OwnerRecordingContext, header: OwnerTelemetryHeader? = nil,
               radius: Double = 0) throws -> SetClockMapping {
    try SetClockMapping(context: context, header: header ?? o6Header(),
        calibration: o6Calibration(context, radius: radius))
}

func o6Telemetry(heartRate: Bool = true, uncertainty: Double = 0,
                 monotonicAnchor: Double = o6Mono) throws -> OwnerPracticeTelemetry {
    let owner = try o6Authority(heartRate: heartRate)
    return try OwnerPracticeTelemetry(header: o6Header(authority: owner, uncertainty: uncertainty, monotonicAnchor: monotonicAnchor),
        authority: owner, initialConsentSegmentID: o6Consent,
        initialQueryGeneration: heartRate ? o6Query : nil)
}

func o6Provenance(epoch: UUID = o6Watch, padding: Int = 0) throws -> OwnerHeartRateProvenance {
    // Padding is permitted bounded machine-descriptor text, never a device display name.
    let part = String(repeating: "x", count: padding)
    return try OwnerHeartRateProvenance(sourceBundleIdentifier: "com.synthetic.hr" + part,
        sourceVersion: "1" + part, operatingSystem: "watchOS 27" + part,
        productType: "WatchSynthetic" + part, manufacturer: "Synthetic" + part,
        model: "Watch" + part, hardwareVersion: "1" + part, softwareVersion: "1" + part,
        watchInstallationEpoch: epoch)
}

func o6Sample(_ number: Int, end: Double, bpm: Double = 100, start: Double? = nil,
              arrival: Double = 1_000, epoch: UUID = o6Watch, padding: Int = 0) throws -> OwnerHeartRateSample {
    OwnerHeartRateSample(id: o6ID(number), bpm: bpm,
        sourceStart: Date(timeIntervalSince1970: o6Wall + (start ?? end)),
        sourceEnd: Date(timeIntervalSince1970: o6Wall + end),
        arrival: Date(timeIntervalSince1970: o6Wall + arrival),
        provenance: try o6Provenance(epoch: epoch, padding: padding))
}

@discardableResult
func o6Append(_ samples: [OwnerHeartRateSample], to telemetry: inout OwnerPracticeTelemetry,
              consent: UUID = o6Consent, query: UUID = o6Query) throws -> OwnerTelemetryPageResult {
    try telemetry.appendPage(samples, consentSegmentID: consent, queryGeneration: query)
}

func o6Admit(_ number: Int = 10, start: Double = 30, stop: Double? = 60,
             to telemetry: inout OwnerPracticeTelemetry, authority: OwnerPracticeIdentity? = nil,
             consent: UUID = o6Consent, calibrated: Bool = true,
             rawAnchor: Double = 10, wallOffset: Double = 0, radius: Double = 0) throws -> OwnerRecordingContext {
    let context = try o6Context(number, authority: authority, rawAnchor: rawAnchor, wallOffset: wallOffset)
    let mapping = try calibrated ? o6Mapping(context, header: telemetry.header, radius: radius) : nil
    try telemetry.admitSet(context: context, mapping: mapping, consentSegmentID: consent,
        rawStartSeconds: rawAnchor + start - wallOffset, at: o6Instant(start))
    if let stop {
        try telemetry.stopSet(recordingID: context.recordingID,
            rawStopSeconds: rawAnchor + stop - wallOffset, at: o6Instant(stop))
    }
    return context
}

func o6Observation(_ number: Int, kind: OwnerTelemetryObservationKind, set: UUID? = nil,
                   start: Double, end: Double, closure: OwnerTelemetryClosure = .open,
                   consent: UUID = o6Consent, query: UUID = o6Query,
                   wallAdjustment: Double = 0) throws -> OwnerTelemetryObservation {
    try OwnerTelemetryObservation(id: o6ID(number), kind: kind, recordingID: set,
        consentSegmentID: consent, queryGeneration: query, start: o6Instant(start),
        end: o6Instant(end, wallAdjustment: wallAdjustment), closure: closure)
}

func o6JSON(_ bytes: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
}

func o6CanonicalJSON(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
}

func o6SHA(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func o6RewriteEnvelope(_ bytes: Data, domain: String,
                       mutate: (inout [String: Any]) throws -> Void) throws -> Data {
    var envelope = try o6JSON(bytes)
    var body = try #require(envelope["body"] as? [String: Any])
    try mutate(&body)
    envelope["body"] = body
    envelope["sha256"] = try o6SHA(Data((domain + "\n").utf8) + o6CanonicalJSON(body))
    return try o6CanonicalJSON(envelope)
}

@Suite struct OwnerPracticeTelemetryTests {
    @Test func literalCanonicalHeaderBindsInitialAuthorityAndBothClockAnchors() throws {
        let expected = Data(#"{"body":{"acquisitionMode":"ownerBatchedWorkout","calculationVersion":1,"clockDomainID":"99999999-9999-9999-9999-999999999999","clockUncertaintySeconds":0,"initialAuthorityDigest":"dae6241f88a4e959e6f16a7080fbaa67af6071191a982194300422b5f87de584","initialAuthorityRevision":1,"monotonicAnchorSeconds":1000,"ownerID":"11111111-1111-1111-1111-111111111111","phoneInstallationEpoch":"22222222-2222-2222-2222-222222222222","practiceID":"55555555-5555-5555-5555-555555555555","runtimeGeneration":"66666666-6666-6666-6666-666666666666","schemaVersion":1,"wallAnchorUnixSeconds":1800000000,"watchInstallationEpoch":"33333333-3333-3333-3333-333333333333"},"sha256":"c1efe23d2ee2143c42b81237d0fece47d7197a383591de7758aba0bbc54269f1"}"#.utf8)
        let header = try o6Header()
        #expect(try header.encoded() == expected)
        #expect(try OwnerTelemetryHeader.decode(expected, authority: o6Authority()) == header)
        #expect(header.initialAuthorityRevision == 1)
        #expect(try header.clock.domainID != o6Context().metadata.clock.domainID)
    }

    @Test(arguments: ["schemaVersion", "calculationVersion", "acquisitionMode", "ownerID",
                      "phoneInstallationEpoch", "watchInstallationEpoch", "initialAuthorityRevision",
                      "initialAuthorityDigest", "monotonicAnchorSeconds", "clockUncertaintySeconds"])
    func recomputedHeaderChecksumDoesNotBypassSemanticValidation(field: String) throws {
        let corrupted = try o6RewriteEnvelope(o6Header().encoded(), domain: "PSLOwnerTelemetryHeader1") {
            switch field {
            case "schemaVersion", "calculationVersion": $0[field] = 2
            case "initialAuthorityRevision": $0[field] = 0
            case "monotonicAnchorSeconds", "clockUncertaintySeconds": $0[field] = -1
            case "acquisitionMode": $0[field] = "guest"
            case "initialAuthorityDigest": $0[field] = String(repeating: "0", count: 64)
            default: $0[field] = o6ID(999).uuidString
            }
        }
        #expect(throws: (any Error).self) {
            try OwnerTelemetryHeader.decode(corrupted, authority: o6Authority())
        }
    }

    @Test func noncanonicalDuplicateUnknownAndMalformedHeaderBytesAreRejected() throws {
        let canonical = try o6Header().encoded()
        let text = try #require(String(data: canonical, encoding: .utf8))
        let unknown = try o6RewriteEnvelope(canonical, domain: "PSLOwnerTelemetryHeader1") { $0["unknown"] = 1 }
        let duplicate = Data(text.replacingOccurrences(of: #""schemaVersion":1"#,
            with: #""schemaVersion":1,"schemaVersion":1"#).utf8)
        for bytes in [Data(), Data("{}".utf8), Data(canonical.dropLast()), Data([32]) + canonical,
                      duplicate, unknown] {
            #expect(throws: (any Error).self) {
                try OwnerTelemetryHeader.decode(bytes, authority: o6Authority())
            }
        }
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity, -1])
    func nonfiniteOrNegativeMonotonicAndUncertaintyAreRejected(value: Double) throws {
        #expect(throws: (any Error).self) {
            try OwnerTelemetryInstant(wallUnixSeconds: o6Wall, monotonicSeconds: value)
        }
        #expect(throws: (any Error).self) { try o6Header(uncertainty: value) }
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
    func nonfiniteWallTimesAreRejected(value: Double) throws {
        #expect(throws: (any Error).self) {
            try OwnerTelemetryInstant(wallUnixSeconds: value, monotonicSeconds: 1)
        }
    }

    @Test func rawDomainsAndImmutableContextBytesSurviveExplicitMapping() throws {
        var telemetry = try o6Telemetry()
        let first = try o6Admit(to: &telemetry)
        let second = try o6Admit(11, start: 120, stop: 150, to: &telemetry,
            rawAnchor: 500, wallOffset: 90)
        let firstBytes = try first.encoded()
        let secondBytes = try second.encoded()
        #expect(first.metadata.clock.domainID != second.metadata.clock.domainID)
        #expect(first.metadata.clock.domainID != telemetry.header.clock.domainID)
        #expect(telemetry.sets[0].mapping?.offsetSeconds == 990)
        #expect(telemetry.sets[1].mapping?.offsetSeconds == 590)
        #expect(telemetry.sets[0].startedAt.monotonicSeconds == o6Mono + 30)
        let decoded = try OwnerPracticeTelemetry.decode(telemetry.encoded())
        #expect(try decoded.sets[0].context.encoded() == firstBytes)
        #expect(try decoded.sets[1].context.encoded() == secondBytes)
        #expect(try RecordingChunkCodec.encodeMetadata(decoded.sets[0].context.metadata)
            == RecordingChunkCodec.encodeMetadata(first.metadata))
    }

    @Test func calibrationBindsExactContextRawAnchorsPracticeDomainAndRuntime() throws {
        let header = try o6Header()
        let context = try o6Context()
        let mapping = try o6Mapping(context, radius: 0.25)
        #expect(mapping.offsetSeconds == 990)
        #expect(mapping.uncertaintySeconds == 0.25)
        #expect(try mapping.contextDigest == o6SHA(context.encoded()))
        #expect(try SetClockMapping.decode(mapping.encoded(), context: context, header: header) == mapping)
        for calibration in [
            try o6Calibration(context, runtime: o6ID(990)),
            try o6Calibration(context, practiceDomain: o6ID(991)),
            try o6Calibration(context, wallAdjustment: 2.000_001)
        ] {
            #expect(throws: (any Error).self) {
                try SetClockMapping(context: context, header: header, calibration: calibration)
            }
        }
        // Exactly two seconds is the documented detection boundary, not ">=".
        _ = try SetClockMapping(context: context, header: header,
            calibration: o6Calibration(context, wallAdjustment: 2))
        let other = try o6Context(11)
        #expect(throws: (any Error).self) {
            try SetClockMapping.decode(mapping.encoded(), context: other, header: header)
        }
        #expect(throws: (any Error).self) {
            try SetClockMapping(context: other, header: header, calibration: o6Calibration(context))
        }
    }

    @Test(arguments: ["rawClock", "contextDigest", "recordingID", "offsetSeconds",
                      "runtimeGeneration", "practiceClockDomainID"])
    func recomputedMappingChecksumCannotRebindCopiedEvidence(field: String) throws {
        let context = try o6Context()
        let corrupted = try o6RewriteEnvelope(o6Mapping(context).encoded(),
            domain: "PSLOwnerSetClockMapping1") {
            switch field {
            case "rawClock":
                var raw = try #require($0[field] as? [String: Any])
                raw["monotonicAnchorSeconds"] = 11
                $0[field] = raw
            case "contextDigest": $0[field] = String(repeating: "0", count: 64)
            case "offsetSeconds": $0[field] = 991
            default: $0[field] = o6ID(999).uuidString
            }
        }
        #expect(throws: (any Error).self) {
            try SetClockMapping.decode(corrupted, context: context, header: o6Header())
        }
    }

    @Test func setAdmissionRejectsWrongPracticeRuntimeAuthorityAndReusedRecording() throws {
        var telemetry = try o6Telemetry()
        let original = try o6Admit(to: &telemetry)
        let before = try telemetry.encoded()
        let advanced = try o6Authority().advancingRevision(expectedRevision: 1)
        for context in [
            try o6Context(12, practiceID: o6ID(998)),
            try o6Context(13, runtime: o6ID(997)),
            try o6Context(14, authority: advanced),
            original
        ] {
            #expect(throws: (any Error).self) {
                try telemetry.admitSet(context: context, mapping: nil, consentSegmentID: o6Consent,
                    rawStartSeconds: 100, at: o6Instant(90))
            }
        }
        #expect(try telemetry.encoded() == before)
    }

    @Test func immutableConsentSegmentsRetainOldContextsAndCapturedQueryIdentity() throws {
        var telemetry = try o6Telemetry()
        let context = try o6Admit(start: 10, stop: 20, to: &telemetry)
        let oldContext = try context.encoded()
        let owner = try o6Authority()
        let revoke = try OwnerConsentDecision.heartRate(for: owner, allowed: false,
            decisionID: o6ID(40), confirmedAtUnixSeconds: o6Wall + 25, policyDigest: OwnerPracticePolicy.digest)
        let excluded = try owner.applying(revoke)
        try telemetry.transitionAuthority(to: excluded, decision: revoke, at: o6Instant(25),
            segmentID: o6ID(41), queryGeneration: nil)
        let grant = try OwnerConsentDecision.heartRate(for: excluded, allowed: true,
            decisionID: o6ID(42), confirmedAtUnixSeconds: o6Wall + 40, policyDigest: OwnerPracticePolicy.digest)
        let regranted = try excluded.applying(grant)
        try telemetry.transitionAuthority(to: regranted, decision: grant, at: o6Instant(40),
            segmentID: o6ID(43), queryGeneration: o6ID(44))
        // Delayed old-query data stays old; a newer callback cannot relabel its interval.
        _ = try o6Append([o6Sample(50, end: 24, arrival: 60)], to: &telemetry)
        let stale = try o6Append([o6Sample(51, end: 45)], to: &telemetry)
        let rebound = try o6Append([o6Sample(52, end: 24)], to: &telemetry,
            consent: o6ID(43), query: o6ID(44))
        _ = try o6Append([o6Sample(53, end: 45)], to: &telemetry, consent: o6ID(43), query: o6ID(44))
        #expect(stale.excluded[.consentExcluded] == 1)
        #expect(rebound.excluded[.consentExcluded] == 1)
        #expect(telemetry.sampleRecords.count == 2)
        #expect(telemetry.sampleRecords.first { $0.sample.id == o6ID(50) }?.consentSegmentID == o6Consent)
        #expect(telemetry.sampleRecords.first { $0.sample.id == o6ID(53) }?.consentSegmentID == o6ID(43))
        #expect(telemetry.header.initialAuthorityRevision == 1)
        #expect(telemetry.consentSegments.map(\.authorityRevision) == [1, 2, 3])
        #expect(telemetry.consentSegments.map(\.heartRateEnabled) == [true, false, true])
        #expect(try telemetry.consentSegments[0].end == o6Instant(25))
        #expect(try telemetry.sets[0].context.encoded() == oldContext)
        #expect(try OwnerPracticeTelemetry.decode(telemetry.encoded()).encoded() == telemetry.encoded())
        _ = try o6Admit(11, start: 50, stop: 60, to: &telemetry,
            authority: regranted, consent: o6ID(43))
    }

    @Test func authorityAdvanceIsCheckedWithoutInventingAnotherConsentDecision() throws {
        var telemetry = try o6Telemetry()
        let authority = try o6Authority()
        let advanced = try authority.advancingRevision(expectedRevision: authority.revision)
        try telemetry.transitionAuthority(to: advanced, decision: nil, at: o6Instant(5),
            segmentID: o6ID(41), queryGeneration: o6ID(42))
        _ = try o6Admit(start: 10, stop: 20, to: &telemetry, authority: advanced, consent: o6ID(41))
        #expect(telemetry.sets[0].context.authorityRevision == 2)
        #expect(telemetry.header.initialAuthorityRevision == 1)
        #expect(try telemetry.consentSegments[1].authorityDigest == o6SHA(advanced.encoded()))
        let skipped = try advanced.advancingRevision(expectedRevision: advanced.revision)
            .advancingRevision(expectedRevision: advanced.revision + 1)
        #expect(throws: (any Error).self) {
            try telemetry.transitionAuthority(to: skipped, decision: nil, at: o6Instant(25),
                segmentID: o6ID(43), queryGeneration: o6ID(44))
        }
    }

    @Test func consentTransitionRejectsReplayWrongEpochAndReusedQuery() throws {
        var telemetry = try o6Telemetry()
        let owner = try o6Authority()
        let decision = try OwnerConsentDecision.heartRate(for: owner, allowed: false,
            decisionID: o6ID(40), confirmedAtUnixSeconds: o6Wall + 20, policyDigest: OwnerPracticePolicy.digest)
        let revoked = try owner.applying(decision)
        try telemetry.transitionAuthority(to: revoked, decision: decision, at: o6Instant(20),
            segmentID: o6ID(41), queryGeneration: nil)
        let grant = try OwnerConsentDecision.heartRate(for: revoked, allowed: true,
            decisionID: o6ID(42), confirmedAtUnixSeconds: o6Wall + 40, policyDigest: OwnerPracticePolicy.digest)
        let restored = try revoked.applying(grant)
        #expect(throws: (any Error).self) {
            try telemetry.transitionAuthority(to: restored, decision: grant, at: o6Instant(40),
                segmentID: o6ID(43), queryGeneration: o6Query)
        }
        #expect(throws: (any Error).self) {
            try telemetry.transitionAuthority(to: owner, decision: nil, at: o6Instant(40),
                segmentID: o6ID(43), queryGeneration: o6ID(44))
        }
        let foreign = try OwnerPracticeIdentity.enrolled(ownerID: o6Owner, phoneInstallationEpoch: o6Phone,
            watchInstallationEpoch: o6ID(999), attestsWatchAccountOwner: true, acceptsMotionStudy: true,
            includesHeartRate: true, decisionID: o6ID(998), confirmedAtUnixSeconds: o6Wall,
            policyDigest: OwnerPracticePolicy.digest)
        #expect(throws: (any Error).self) {
            try telemetry.transitionAuthority(to: foreign, decision: nil, at: o6Instant(40),
                segmentID: o6ID(43), queryGeneration: o6ID(44))
        }
    }

    @Test func collectionWithdrawalEndsEligibilityWithoutGrantingNativeClosure() throws {
        var telemetry = try o6Telemetry()
        let owner = try o6Authority()
        let withdrawal = try OwnerConsentDecision.withdraw(for: owner, decisionID: o6ID(40),
            confirmedAtUnixSeconds: o6Wall + 20)
        try telemetry.transitionAuthority(to: owner.applying(withdrawal), decision: withdrawal,
            at: o6Instant(20), segmentID: o6ID(41), queryGeneration: nil)
        #expect(telemetry.status == .ended)
        #expect(telemetry.finalization == nil) // Metadata End is not drained/finalized/native-ended proof.
        #expect(throws: (any Error).self) { try o6Admit(start: 30, to: &telemetry) }
        let result = try o6Append([o6Sample(50, end: 19), o6Sample(51, end: 21)], to: &telemetry)
        #expect(result.admittedCount == 1)
        #expect(result.excluded[.consentExcluded] == 1)
    }

    @Test func exactNativeDuplicateRetainsMinimumArrivalAndCanonicalIdentityOmitsArrival() throws {
        var telemetry = try o6Telemetry()
        let late = try o6Sample(50, end: 10, arrival: 100)
        let early = try o6Sample(50, end: 10, arrival: 20)
        #expect(try late.canonicalIdentityBytes() == early.canonicalIdentityBytes())
        _ = try o6Append([late], to: &telemetry)
        let result = try o6Append([early, late], to: &telemetry)
        #expect(result.admittedCount == 0)
        #expect(result.deduplicatedCount == 2)
        #expect(telemetry.sampleRecords.count == 1)
        #expect(telemetry.sampleRecords[0].sample.arrival == Date(timeIntervalSince1970: o6Wall + 20))
    }

    @Test func literalNativeIdentityIncludesOnlyBoundedMachineProvenance() throws {
        let bytes = try o6Sample(50, end: 10, bpm: 120, start: 9).canonicalIdentityBytes()
        let expected = Data(#"{"bpm":120,"id":"A0000000-0000-0000-0000-000000000032","provenance":{"hardwareVersion":"1","manufacturer":"Synthetic","model":"Watch","operatingSystem":"watchOS 27","productType":"WatchSynthetic","softwareVersion":"1","sourceBundleIdentifier":"com.synthetic.hr","sourceVersion":"1","watchInstallationEpoch":"33333333-3333-3333-3333-333333333333"},"sourceEndUnixSeconds":1800000010,"sourceStartUnixSeconds":1800000009}"#.utf8)
        #expect(bytes == expected)
        // Machine descriptor equality is deliberately not a physical-device admission API.
        #expect(try o6Provenance().model == "Watch")
        #expect(throws: (any Error).self) { try o6Provenance(padding: 129) }
        #expect(throws: (any Error).self) {
            try OwnerHeartRateProvenance(sourceBundleIdentifier: "com.synthetic.hr\nsecret",
                sourceVersion: "1", operatingSystem: "watchOS 27", productType: "WatchSynthetic",
                manufacturer: "Synthetic", model: "Watch", hardwareVersion: "1", softwareVersion: "1",
                watchInstallationEpoch: o6Watch)
        }
    }

    @Test func allNativeConflictVersionsBecomeIneligibleAndEvidenceIsPermutationInvariant() throws {
        let samples = try [o6Sample(50, end: 10, bpm: 100, arrival: 80),
            o6Sample(50, end: 10, bpm: 101, arrival: 70),
            o6Sample(50, end: 10, bpm: 100, arrival: 20),
            o6Sample(51, end: 11, bpm: 90, arrival: 30)]
        var outputs = [Data]()
        for order in [[0, 1, 2, 3], [3, 2, 1, 0], [1, 3, 0, 2], [2, 0, 3, 1]] {
            var telemetry = try o6Telemetry()
            for index in order { _ = try o6Append([samples[index]], to: &telemetry) }
            #expect(telemetry.sampleRecords.count == 3)
            #expect(telemetry.sampleRecords.filter(\.isEligible).map { $0.sample.id } == [o6ID(51)])
            #expect(telemetry.conflictGroups.count == 1)
            #expect(telemetry.conflictGroups[0].sampleID == o6ID(50))
            let versions = telemetry.conflictGroups[0].versions
            #expect(versions.count == 2)
            #expect(versions.map(\.identityDigest) == versions.map(\.identityDigest).sorted())
            #expect(telemetry.incompleteReasons.contains(.sampleConflict))
            outputs.append(try telemetry.encoded())
        }
        #expect(Set(outputs).count == 1)
        var onePage = try o6Telemetry()
        _ = try o6Append(samples, to: &onePage)
        #expect(try onePage.encoded() == outputs[0])
    }

    @Test(arguments: [0.0, -1, 300.000_001, Double.nan, Double.infinity, -Double.infinity])
    func technicalBPMRejectionIsCountedAndNeverClipped(bpm: Double) throws {
        var telemetry = try o6Telemetry()
        let result = try o6Append([o6Sample(50, end: 10, bpm: bpm)], to: &telemetry)
        #expect(result.admittedCount == 0)
        #expect(result.excluded[.bpmOutOfRange] == 1)
        #expect(telemetry.exclusionCounts[.bpmOutOfRange] == 1)
        #expect(telemetry.sampleRecords.isEmpty)
    }

    @Test func inclusiveBPMCeilingAndPositiveSubunitAreRetainedWithoutConversion() throws {
        var telemetry = try o6Telemetry()
        _ = try o6Append([o6Sample(50, end: 10, bpm: 0.5), o6Sample(51, end: 11, bpm: 300)], to: &telemetry)
        #expect(telemetry.sampleRecords.map { $0.sample.bpm }.sorted() == [0.5, 300])
    }

    @Test func malformedIntervalsOutsidePracticeWrongEpochAndWrongQueryAreExplicit() throws {
        var telemetry = try o6Telemetry()
        let malformed = OwnerHeartRateSample(id: o6ID(51), bpm: 100,
            sourceStart: Date(timeIntervalSince1970: .nan), sourceEnd: Date(timeIntervalSince1970: o6Wall + 10),
            arrival: Date(timeIntervalSince1970: o6Wall + 20), provenance: try o6Provenance())
        let result = try o6Append([o6Sample(50, end: 10, start: 11), malformed,
            o6Sample(52, end: -1), o6Sample(53, end: 1_800.001),
            o6Sample(54, end: 10, epoch: o6ID(999))], to: &telemetry)
        #expect(result.excluded[.unorderedInterval] == 1)
        #expect(result.excluded[.invalidDate] == 1)
        #expect(result.excluded[.outsidePractice] == 2)
        #expect(result.excluded[.wrongInstallationEpoch] == 1)
        let wrong = try o6Append([o6Sample(55, end: 10)], to: &telemetry, query: o6ID(999))
        #expect(wrong.excluded[.wrongQuery] == 1)
        #expect(telemetry.sampleRecords.isEmpty)
    }

    @Test func optionalHRExclusionIsDistinctFromAnEmptyAccessibleQuery() throws {
        var excluded = try o6Telemetry(heartRate: false)
        let result = try o6Append([o6Sample(50, end: 10)], to: &excluded)
        #expect(result.excluded[.consentExcluded] == 1)
        var empty = try o6Telemetry()
        _ = try o6Append([], to: &empty)
        #expect(empty.exclusionCounts[.consentExcluded] == nil)
        #expect(empty.sampleRecords.isEmpty)
    }

    @Test func pageCapAccepts256AndRejects257WithoutAdmittingPrefixOrConflict() throws {
        var telemetry = try o6Telemetry()
        let full = try (0..<256).map { try o6Sample(1_000 + $0, end: 10, bpm: 100) }
        _ = try o6Append(full, to: &telemetry)
        #expect(telemetry.sampleRecords.count == 256)
        var oversized = try (0..<256).map { try o6Sample(2_000 + $0, end: 20) }
        oversized.insert(try o6Sample(1_000, end: 10, bpm: 101), at: 0)
        #expect(throws: (any Error).self) { try o6Append(oversized, to: &telemetry) }
        #expect(telemetry.sampleRecords.count == 256)
        let allEligible = telemetry.sampleRecords.allSatisfy(\.isEligible)
        #expect(allEligible)
        #expect(telemetry.conflictGroups.isEmpty)
        #expect(telemetry.incompleteReasons.contains(.pageLimit))
    }

    @Test func all8192DistinctVersionsCountIncludingConflictsAndOverflowIsAtomic() throws {
        var telemetry = try o6Telemetry()
        for page in 0..<32 {
            let samples = try (0..<256).map { index in
                // Two distinct contents per UUID: 4,096 conflict groups / 8,192 versions.
                let version = page * 256 + index
                return try o6Sample(10_000 + version / 2, end: 10, bpm: version.isMultiple(of: 2) ? 100 : 101)
            }
            _ = try o6Append(samples, to: &telemetry)
        }
        #expect(telemetry.sampleRecords.count == 8_192)
        #expect(telemetry.conflictGroups.count == 4_096)
        #expect(telemetry.sampleRecords.allSatisfy { !$0.isEligible })
        _ = try o6Append([o6Sample(10_000, end: 10, bpm: 100, arrival: 20)], to: &telemetry)
        #expect(telemetry.sampleRecords.count == 8_192)
        #expect(throws: (any Error).self) {
            try o6Append([o6Sample(10_000, end: 10, bpm: 102), o6Sample(99_999, end: 11)], to: &telemetry)
        }
        #expect(telemetry.sampleRecords.count == 8_192)
        #expect(telemetry.conflictGroups.first { $0.sampleID == o6ID(10_000) }?.versions.count == 2)
        #expect(telemetry.incompleteReasons.contains(.sampleLimit))
    }

    @Test(arguments: [false, true])
    func fractionalAnchorAcceptsCanonicalDeadlineAndPreviousInstant(justBefore: Bool) throws {
        let anchor = 3234.779933041667
        let deadline = anchor + 1800
        // This observed CI anchor makes subtracting the exact deadline round above 1800.
        #expect(deadline - anchor > 1800)
        let end = try OwnerTelemetryInstant(wallUnixSeconds: o6Wall + 1800,
            monotonicSeconds: justBefore ? deadline.nextDown : deadline)
        var telemetry = try o6Telemetry(monotonicAnchor: anchor)
        let start = try OwnerTelemetryInstant(wallUnixSeconds: o6Wall, monotonicSeconds: anchor)
        let observation = try OwnerTelemetryObservation(id: o6ID(80_001), kind: .baseline,
            recordingID: nil, consentSegmentID: o6Consent, queryGeneration: o6Query,
            start: start, end: end, closure: .ended)
        try telemetry.recordObservation(observation)
        try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(80_002), at: end, reason: .userEntered, count: 1))
        try telemetry.finalize(status: .ended, at: end, absenceReasons: [.noAccessibleHeartRateData])
        #expect(telemetry.observations == [observation])
        #expect(telemetry.finalization?.endedAt == end)
        #expect(telemetry.status == .ended)
        #expect(try OwnerPracticeTelemetry.decode(telemetry.encoded()) == telemetry)
    }

    @Test func fractionalAnchorRejectsNextInstantAfterDeadlineWithoutLosingEvidence() throws {
        let anchor = 3234.779933041667
        let deadline = anchor + 1800
        var telemetry = try o6Telemetry(monotonicAnchor: anchor)
        let start = try OwnerTelemetryInstant(wallUnixSeconds: o6Wall, monotonicSeconds: anchor)
        let retained = try OwnerTelemetryEvent(id: o6ID(80_003), at: start, reason: .userEntered, count: 1)
        try telemetry.recordEvent(retained)
        let before = telemetry
        let outside = try OwnerTelemetryInstant(wallUnixSeconds: o6Wall + 1800, monotonicSeconds: deadline.nextUp)
        #expect(throws: (any Error).self) {
            try telemetry.recordObservation(OwnerTelemetryObservation(id: o6ID(80_004), kind: .baseline,
                recordingID: nil, consentSegmentID: o6Consent, queryGeneration: o6Query,
                start: start, end: outside, closure: .ended))
        }
        #expect(telemetry == before)
        #expect(throws: (any Error).self) {
            try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(80_005), at: outside, reason: .userEntered, count: 1))
        }
        #expect(telemetry == before)
        let tooEarly = try OwnerTelemetryInstant(wallUnixSeconds: o6Wall, monotonicSeconds: anchor.nextDown)
        #expect(throws: (any Error).self) {
            try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(80_006), at: tooEarly, reason: .userEntered, count: 1))
        }
        #expect(telemetry == before)
        #expect(throws: OwnerTelemetryError.capacity) {
            try telemetry.finalize(status: .ended, at: outside, absenceReasons: [])
        }
        #expect(telemetry.finalization == nil && telemetry.status == .open)
        #expect(telemetry.events == [retained] && telemetry.observations.isEmpty)
        #expect(telemetry.incompleteReasons == [.durationLimit])
        #expect(try OwnerPracticeTelemetry.decode(telemetry.encoded()) == telemetry)
    }

    @Test func twentySetsAcceptedTwentyFirstRefusedAndDurationHasExactBoundary() throws {
        var telemetry = try o6Telemetry()
        for index in 0..<20 {
            _ = try o6Admit(1_000 + index, start: Double(index * 60 + 1),
                stop: Double(index * 60 + 30), to: &telemetry)
        }
        #expect(telemetry.sets.count == 20)
        #expect(throws: (any Error).self) {
            try o6Admit(1_020, start: 1_300, stop: 1_310, to: &telemetry)
        }
        #expect(telemetry.sets.count == 20)
        #expect(telemetry.incompleteReasons.contains(.setLimit))
        var exact = try o6Telemetry()
        try exact.finalize(status: .ended, at: o6Instant(1_800), absenceReasons: [.noAccessibleHeartRateData])
        #expect(try exact.finalization?.endedAt == o6Instant(1_800))
        var over = try o6Telemetry()
        #expect(throws: (any Error).self) {
            try over.finalize(status: .ended, at: o6Instant(1_800.001), absenceReasons: [])
        }
        #expect(over.finalization == nil)
        #expect(over.incompleteReasons.contains(.durationLimit))
    }

    @Test func all512EventsIncludeConsentSegmentsAndOverflowKeepsPriorInventory() throws {
        var telemetry = try o6Telemetry()
        #expect(telemetry.eventCount >= 1) // Initial authority segment also consumes the shared budget.
        var number = 1_000
        while telemetry.eventCount < 512 {
            try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(number), at: o6Instant(10),
                reason: .noAccessibleHeartRateData))
            number += 1
        }
        #expect(telemetry.eventCount == 512)
        #expect(throws: (any Error).self) {
            try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(number), at: o6Instant(10),
                reason: .noAccessibleHeartRateData))
        }
        #expect(telemetry.eventCount == 512)
        #expect(telemetry.incompleteReasons.contains(.eventLimit))
        let owner = try o6Authority()
        let next = try owner.advancingRevision(expectedRevision: owner.revision)
        #expect(throws: (any Error).self) {
            try telemetry.transitionAuthority(to: next, decision: nil, at: o6Instant(20),
                segmentID: o6ID(9_000), queryGeneration: o6ID(9_001))
        }
        #expect(telemetry.consentSegments.count == 1)
    }

    @Test func canonicalContentByteCapRejectsWholePageWithNoSampleEviction() throws {
        var telemetry = try o6Telemetry()
        var number = 10_000
        var refused = false
        // Unique padded machine provenance prevents interning from making this a sample-count test.
        while !refused && number < 18_000 {
            let page = try (0..<64).map { index -> OwnerHeartRateSample in
                let sampleID = number + index
                let descriptor = "s" + String(sampleID) + String(repeating: "x", count: 90)
                let provenance = try OwnerHeartRateProvenance(sourceBundleIdentifier: "com.synthetic." + descriptor,
                    sourceVersion: descriptor, operatingSystem: descriptor, productType: descriptor,
                    manufacturer: descriptor, model: descriptor, hardwareVersion: descriptor,
                    softwareVersion: descriptor, watchInstallationEpoch: o6Watch)
                return OwnerHeartRateSample(id: o6ID(sampleID), bpm: 100,
                    sourceStart: Date(timeIntervalSince1970: o6Wall + 10),
                    sourceEnd: Date(timeIntervalSince1970: o6Wall + 10),
                    arrival: Date(timeIntervalSince1970: o6Wall + 20), provenance: provenance)
            }
            let previous = telemetry.sampleRecords
            do { _ = try o6Append(page, to: &telemetry) }
            catch {
                refused = true
                #expect(telemetry.sampleRecords == previous)
                #expect(telemetry.incompleteReasons.contains(.byteLimit))
            }
            #expect(telemetry.canonicalContentByteCount <= 2 * 1_024 * 1_024)
            number += 64
        }
        #expect(refused)
        #expect(telemetry.sampleRecords.count < 8_192)
        #expect(try telemetry.encoded().count <= 2 * 1_024 * 1_024)
    }

    @Test func finalizationIsImmutableIdempotentAndRejectsLateOrConflictingMutation() throws {
        var telemetry = try o6Telemetry()
        _ = try o6Admit(to: &telemetry)
        _ = try o6Append([o6Sample(50, end: 10)], to: &telemetry)
        try telemetry.finalize(status: .ended, at: o6Instant(200), absenceReasons: [.insufficientSamples])
        let frozen = try telemetry.encoded()
        try telemetry.finalize(status: .ended, at: o6Instant(200), absenceReasons: [.insufficientSamples])
        #expect(try telemetry.encoded() == frozen)
        #expect(throws: (any Error).self) { try o6Append([o6Sample(51, end: 190)], to: &telemetry) }
        #expect(throws: (any Error).self) { try o6Append([o6Sample(50, end: 10, arrival: 5)], to: &telemetry) }
        #expect(throws: (any Error).self) {
            try telemetry.finalize(status: .interrupted, at: o6Instant(200), absenceReasons: [.interrupted])
        }
        #expect(throws: (any Error).self) {
            try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(99), at: o6Instant(199), reason: .interrupted))
        }
        #expect(try telemetry.encoded() == frozen)
        #expect(try OwnerPracticeTelemetry.decode(frozen).encoded() == frozen)
    }

    @Test func checkedTerminalBoundaryRejectsActiveSetOrEarlierEndAndInterruptionIsExplicit() throws {
        var telemetry = try o6Telemetry()
        _ = try o6Admit(start: 30, stop: nil, to: &telemetry)
        #expect(throws: (any Error).self) {
            try telemetry.finalize(status: .ended, at: o6Instant(40), absenceReasons: [])
        }
        #expect(throws: (any Error).self) {
            try telemetry.finalize(status: .interrupted, at: o6Instant(20), absenceReasons: [.interrupted])
        }
        #expect(telemetry.finalization == nil)
        try telemetry.finalize(status: .interrupted, at: o6Instant(40), absenceReasons: [.interrupted])
        #expect(telemetry.status == .interrupted)
        #expect(telemetry.finalization?.absenceReasons.contains(.interrupted) == true)
    }
    @Test func rawStartAndStopMustAgreeWithExplicitMappingAndOrderedSetBoundaries() throws {
        var telemetry = try o6Telemetry()
        let context = try o6Context()
        let mapping = try o6Mapping(context)
        let before = try telemetry.encoded()
        #expect(throws: (any Error).self) {
            try telemetry.admitSet(context: context, mapping: mapping, consentSegmentID: o6Consent,
                rawStartSeconds: 45, at: o6Instant(30)) // Correct calibrated raw Start is 40.
        }
        #expect(try telemetry.encoded() == before)
        try telemetry.admitSet(context: context, mapping: mapping, consentSegmentID: o6Consent,
            rawStartSeconds: 40, at: o6Instant(30))
        let admitted = try telemetry.encoded()
        #expect(throws: (any Error).self) {
            try telemetry.stopSet(recordingID: context.recordingID, rawStopSeconds: 30, at: o6Instant(20))
        }
        #expect(throws: (any Error).self) {
            try telemetry.stopSet(recordingID: context.recordingID, rawStopSeconds: .nan, at: o6Instant(60))
        }
        #expect(throws: (any Error).self) {
            try telemetry.stopSet(recordingID: context.recordingID, rawStopSeconds: 75, at: o6Instant(60))
        }
        #expect(try telemetry.encoded() == admitted)
    }

    @Test(arguments: ["start", "end", "arrival"])
    func everyNativeDateMustBeFiniteBeforeCanonicalStorage(field: String) throws {
        var telemetry = try o6Telemetry()
        let valid = Date(timeIntervalSince1970: o6Wall + 10)
        let invalid = Date(timeIntervalSince1970: .infinity)
        let sample = OwnerHeartRateSample(id: o6ID(50), bpm: 100,
            sourceStart: field == "start" ? invalid : valid,
            sourceEnd: field == "end" ? invalid : valid,
            arrival: field == "arrival" ? invalid : valid, provenance: try o6Provenance())
        let result = try o6Append([sample], to: &telemetry)
        #expect(result.excluded[.invalidDate] == 1)
        #expect(telemetry.sampleRecords.isEmpty)
        #expect(try OwnerPracticeTelemetry.decode(telemetry.encoded()).encoded() == telemetry.encoded())
    }

    @Test func exactPracticeUpperBoundaryIsAdmittedAndLaterSourceIsExcluded() throws {
        var telemetry = try o6Telemetry()
        let result = try o6Append([o6Sample(50, end: 1_800),
            o6Sample(51, end: 1_800.000_1)], to: &telemetry)
        #expect(result.admittedCount == 1)
        #expect(result.excluded[.outsidePractice] == 1)
        #expect(telemetry.sampleRecords.map { $0.sample.id } == [o6ID(50)])
    }

    @Test func aggregateDecoderRejectsUnknownFieldsNoncanonicalBytesAndRecomputedVersion() throws {
        var telemetry = try o6Telemetry()
        _ = try o6Admit(to: &telemetry)
        _ = try o6Append([o6Sample(50, end: 10)], to: &telemetry)
        let bytes = try telemetry.encoded()
        let badVersion = try o6RewriteEnvelope(bytes, domain: "PSLOwnerPracticeTelemetry1") {
            $0["schemaVersion"] = 2
        }
        let unknownPrivateData = try o6RewriteEnvelope(bytes, domain: "PSLOwnerPracticeTelemetry1") {
            $0["userDeviceName"] = "Synthetic display name must not become provenance"
        }
        for invalid in [badVersion, unknownPrivateData, Data([32]) + bytes, Data(bytes.dropLast())] {
            #expect(throws: (any Error).self) { try OwnerPracticeTelemetry.decode(invalid) }
        }
    }


    @Test(arguments: [OwnerTelemetryReason.userEntered, .missingProvenance, .mismatchedProvenance, .sourceDeleted])
    func countedNativeEventsAreBoundedIdempotentAndAtomic(reason: OwnerTelemetryReason) throws {
        var telemetry = try o6Telemetry()
        let event = try OwnerTelemetryEvent(id: o6ID(900), at: o6Instant(10), reason: reason, count: 256)
        let initialCount = telemetry.eventCount
        try telemetry.recordEvent(event)
        #expect(telemetry.eventCount == initialCount + 1)
        #expect(telemetry.exclusionCounts[reason] == 256)
        let bytes = try telemetry.encoded()
        try telemetry.recordEvent(event)
        #expect(try telemetry.encoded() == bytes)
        #expect(try OwnerPracticeTelemetry.decode(bytes).encoded() == bytes)
        for count in [0, 255, 257] {
            #expect(throws: (any Error).self) {
                try telemetry.recordEvent(OwnerTelemetryEvent(id: count == 255 ? event.id : o6ID(2_000 + count), at: o6Instant(10), reason: reason, count: count))
            }
        }
        #expect(try telemetry.encoded() == bytes)
        let envelope = try o6JSON(bytes)
        let body = try #require(envelope["body"] as? [String: Any])
        let events = try #require(body["events"] as? [[String: Any]])
        let eventKeys = try #require(events.first).keys
        #expect(Set(eventKeys) == ["id", "at", "reason", "count"])
        var next = 901
        while telemetry.eventCount < 512 {
            try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(next), at: o6Instant(10), reason: reason, count: 256))
            next += 1
        }
        let retained = telemetry.exclusionCounts
        #expect(retained[reason] == (512 - initialCount) * 256)
        #expect((retained[reason] ?? 0) <= 512 * 256)
        #expect(throws: (any Error).self) {
            try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(next), at: o6Instant(10), reason: reason, count: 256))
        }
        #expect(telemetry.eventCount == 512 && telemetry.exclusionCounts == retained)
    }

    @Test(arguments: [OwnerTelemetryReason.interrupted, .clockDiscontinuity, .noAccessibleHeartRateData])
    func lifecycleAndClockEventsCannotPretendToBeBatchedNativeRejections(reason: OwnerTelemetryReason) throws {
        var telemetry = try o6Telemetry()
        let before = try telemetry.encoded()
        #expect(throws: (any Error).self) {
            try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(900), at: o6Instant(10), reason: reason, count: 2))
        }
        #expect(try telemetry.encoded() == before)
    }
}
