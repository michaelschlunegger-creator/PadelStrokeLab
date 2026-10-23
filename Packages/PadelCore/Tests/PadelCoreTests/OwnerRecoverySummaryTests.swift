import Foundation
import Testing
@testable import PadelCore

// Calculation v1: source END membership is (lower, upper]; the WHOLE source interval must
// fit one eligible observation and consent/query scope. A completed target additionally needs
// its complete statistical window inside one uninterrupted recovery observation.
// Available medians need >= 2 distinct eligible native identities. No history/interpolation.

func o6RecoveryFixture(through: Double = 190, closure: OwnerTelemetryClosure = .open,
                       calibrated: Bool = true, radius: Double = 0,
                       baseline: Bool = true, endReference: Bool = true) throws -> OwnerPracticeTelemetry {
    var telemetry = try o6Telemetry()
    let context = try o6Admit(to: &telemetry, calibrated: calibrated, radius: radius)
    if baseline {
        try telemetry.recordObservation(o6Observation(200, kind: .baseline, start: 0, end: 30,
            closure: .setStarted))
        _ = try o6Append([o6Sample(1_000, end: 10, bpm: 90), o6Sample(1_001, end: 20, bpm: 110)], to: &telemetry)
    }
    if endReference {
        try telemetry.recordObservation(o6Observation(201, kind: .active, set: context.recordingID,
            start: 30, end: 60, closure: .setStopped))
        _ = try o6Append([o6Sample(1_002, end: 55, bpm: 160), o6Sample(1_003, end: 59, bpm: 180)], to: &telemetry)
    }
    try telemetry.recordObservation(o6Observation(202, kind: .recovery, set: context.recordingID,
        start: 60, end: through, closure: closure))
    return telemetry
}

func o6Summary(_ telemetry: OwnerPracticeTelemetry, set: UUID = o6ID(10)) throws -> OwnerRecoverySummary {
    try OwnerRecoverySummary.calculate(telemetry: telemetry, recordingID: set)
}

@Suite struct OwnerRecoverySummaryTests {
    @Test func literalWindowBoundariesMediansCountsSpansAndSignedDifferences() throws {
        var telemetry = try o6Telemetry()
        _ = try o6Admit(to: &telemetry)
        try telemetry.recordObservation(o6Observation(200, kind: .baseline, start: 0, end: 30, closure: .setStarted))
        try telemetry.recordObservation(o6Observation(201, kind: .active, set: o6ID(10),
            start: 30, end: 60, closure: .setStopped))
        try telemetry.recordObservation(o6Observation(202, kind: .recovery, set: o6ID(10), start: 60, end: 190))
        _ = try o6Append([
            o6Sample(1_000, end: 0, bpm: 299), // baseline lower bound excluded
            o6Sample(1_001, end: 1, bpm: 90, start: 0.5),
            o6Sample(1_002, end: 30, bpm: 110),
            o6Sample(1_003, end: 30.001, bpm: 299),
            o6Sample(1_004, end: 50, bpm: 299), // end-reference lower bound excluded
            o6Sample(1_005, end: 51, bpm: 160, start: 49), // interval may precede statistical lower bound
            o6Sample(1_006, end: 60, bpm: 180),
            o6Sample(1_007, end: 110, bpm: 299),
            o6Sample(1_008, end: 111, bpm: 130, start: 109),
            o6Sample(1_009, end: 130, bpm: 150),
            o6Sample(1_010, end: 130.001, bpm: 299),
            o6Sample(1_011, end: 170, bpm: 299),
            o6Sample(1_012, end: 171, bpm: 100),
            o6Sample(1_013, end: 190, bpm: 120)
        ], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.baseline.state == .available)
        #expect(result.baseline.medianBPM == 100)
        #expect(result.baseline.sampleCount == 2)
        #expect(result.baseline.sourceSpan?.startUnixSeconds == o6Wall + 0.5)
        #expect(result.baseline.sourceSpan?.endUnixSeconds == o6Wall + 30)
        #expect(result.endReference.medianBPM == 170)
        #expect(result.endReference.sampleCount == 2)
        #expect(result.endReference.sourceSpan?.startUnixSeconds == o6Wall + 49)
        #expect(result.endReference.sourceSpan?.endUnixSeconds == o6Wall + 60)
        #expect(result.at60.medianBPM == 140)
        #expect(result.at60.sampleCount == 2)
        #expect(result.at60.sourceSpan?.startUnixSeconds == o6Wall + 109)
        #expect(result.at60.sourceSpan?.endUnixSeconds == o6Wall + 130)
        #expect(result.at60.dropBPM == 30)
        #expect(result.at120.medianBPM == 110)
        #expect(result.at120.dropBPM == 60)
        #expect(result.baselineDifferenceBPM == 70)
        #expect(result.coverage == .valid)
    }

    @Test(arguments: [0, 1, 2])
    func zeroOneAndTwoSamplesStayDistinctWithoutInterpolation(count: Int) throws {
        var telemetry = try o6RecoveryFixture()
        let candidates = try [o6Sample(2_000, end: 111, bpm: 130), o6Sample(2_001, end: 120, bpm: 150)]
        _ = try o6Append(Array(candidates.prefix(count)), to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.at60.sampleCount == count)
        if count < 2 {
            #expect(result.at60.state == .missing)
            #expect(result.at60.reason == (count == 0 ? .noAccessibleHeartRateData : .insufficientSamples))
            #expect(result.at60.medianBPM == nil)
            #expect(result.at60.dropBPM == nil)
        } else {
            #expect(result.at60.state == .available)
            #expect(result.at60.medianBPM == 140)
            #expect(result.at60.dropBPM == 30)
        }
    }

    @Test func oddAndEvenMediansUseDistinctSamplesAndPreserveNegativeRecovery() throws {
        var telemetry = try o6RecoveryFixture()
        _ = try o6Append([o6Sample(2_000, end: 111, bpm: 190),
            o6Sample(2_001, end: 120, bpm: 210), o6Sample(2_002, end: 129, bpm: 200),
            o6Sample(2_003, end: 171, bpm: 220), o6Sample(2_004, end: 180, bpm: 240)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.at60.medianBPM == 200)
        #expect(result.at60.dropBPM == -30)
        #expect(result.at120.medianBPM == 230)
        #expect(result.at120.dropBPM == -60)
    }

    @Test func targetRemainsPendingUntilFullUpperBoundaryThenBecomesAvailable() throws {
        var telemetry = try o6RecoveryFixture(through: 129.999)
        _ = try o6Append([o6Sample(2_000, end: 111, bpm: 130), o6Sample(2_001, end: 120, bpm: 150)], to: &telemetry)
        let pending = try o6Summary(telemetry)
        #expect(pending.at60.state == .pending)
        #expect(pending.at60.medianBPM == nil)
        #expect(pending.at60.dropBPM == nil)
        #expect(pending.at120.state == .pending)
        // Extension of the same open immutable identity cannot change its kind/start/scope.
        try telemetry.recordObservation(o6Observation(202, kind: .recovery, set: o6ID(10),
            start: 60, end: 130))
        let complete = try o6Summary(telemetry)
        #expect(complete.at60.state == .available)
        #expect(complete.at60.medianBPM == 140)
        #expect(complete.at120.state == .pending)
    }

    @Test(arguments: [OwnerTelemetryClosure.paused, .ended, .interrupted, .nextSet])
    func earlyClosureMakesIncompleteTargetMissingEvenWithTwoInteriorSamples(closure: OwnerTelemetryClosure) throws {
        var telemetry = try o6RecoveryFixture(through: 125, closure: closure)
        _ = try o6Append([o6Sample(2_000, end: 111, bpm: 130), o6Sample(2_001, end: 120, bpm: 150)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.at60.state == .missing)
        #expect(result.at60.reason == .incompleteObservation)
        #expect(result.at60.medianBPM == nil)
        #expect(result.at60.dropBPM == nil)
        #expect(result.at120.state == .missing)
    }

    @Test(arguments: [false, true], [OwnerTelemetryClosure.open, .nextSet])
    func plus50And54ThenNextSetAt55NeverPublishesPlus60(includeExtraInteriorSample: Bool, closure: OwnerTelemetryClosure) throws {
        var telemetry = try o6RecoveryFixture(through: 115, closure: closure)
        var samples = try [o6Sample(2_000, end: 110, bpm: 130), o6Sample(2_001, end: 114, bpm: 140)]
        if includeExtraInteriorSample { samples.append(try o6Sample(2_002, end: 111, bpm: 135)) }
        _ = try o6Append(samples, to: &telemetry)
        _ = try o6Admit(11, start: 115, stop: 145, to: &telemetry)
        try telemetry.recordObservation(o6Observation(203, kind: .active, set: o6ID(11),
            start: 115, end: 145, closure: .setStopped))
        // Later-set HR is not allowed to fill the first set's unfinished target.
        _ = try o6Append([o6Sample(2_003, end: 120, bpm: 150), o6Sample(2_004, end: 129, bpm: 160)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.at60.state == .missing)
        #expect(result.at60.reason == .incompleteObservation)
        #expect(result.at60.medianBPM == nil)
        #expect(result.at60.dropBPM == nil)
        #expect(result.at120.state == .missing)
    }

    @Test func plus120NeedsFull130SecondsEvenWhenPlus60AlreadyCompleted() throws {
        var telemetry = try o6RecoveryFixture(through: 189.999)
        _ = try o6Append([o6Sample(2_000, end: 111), o6Sample(2_001, end: 120),
            o6Sample(2_002, end: 171), o6Sample(2_003, end: 180)], to: &telemetry)
        #expect(try o6Summary(telemetry).at60.state == .available)
        #expect(try o6Summary(telemetry).at120.state == .pending)
        try telemetry.recordObservation(o6Observation(202, kind: .recovery, set: o6ID(10),
            start: 60, end: 190, closure: .paused))
        #expect(try o6Summary(telemetry).at120.state == .available)
    }

    @Test func wholeSourceIntervalCrossingSetStopIsIneligibleDespiteWindowEnd() throws {
        var telemetry = try o6RecoveryFixture()
        _ = try o6Append([o6Sample(2_000, end: 111, bpm: 130, start: 59),
            o6Sample(2_001, end: 120, bpm: 150)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.at60.sampleCount == 1)
        #expect(result.at60.state == .missing)
        #expect(result.at60.reason == .insufficientSamples)
    }

    @Test func pauseSplitsObservationAndCrossPauseSourceCannotFillLaterWindow() throws {
        var telemetry = try o6RecoveryFixture(through: 115, closure: .paused)
        try telemetry.recordObservation(o6Observation(203, kind: .paused, set: o6ID(10),
            start: 115, end: 125, closure: .paused))
        try telemetry.recordObservation(o6Observation(204, kind: .recovery, set: o6ID(10),
            start: 125, end: 190))
        _ = try o6Append([o6Sample(2_000, end: 111, bpm: 130), o6Sample(2_001, end: 129, bpm: 150),
            o6Sample(2_002, end: 171, bpm: 90, start: 114),
            o6Sample(2_003, end: 180, bpm: 110)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.at60.state == .missing)
        #expect(result.at60.reason == .incompleteObservation)
        #expect(result.at120.sampleCount == 1)
        #expect(result.at120.medianBPM == nil)
        #expect(result.at120.reason == .insufficientSamples)
    }

    @Test func sourceIntervalCrossingEndIsNotRecoveredFromItsEndTimestamp() throws {
        var telemetry = try o6RecoveryFixture(through: 120, closure: .ended)
        try telemetry.recordObservation(o6Observation(203, kind: .ending, set: o6ID(10),
            start: 120, end: 125, closure: .ended))
        _ = try o6Append([o6Sample(2_000, end: 119, bpm: 130),
            o6Sample(2_001, end: 121, bpm: 150, start: 119)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.at60.state == .missing)
        #expect(result.at60.reason == .incompleteObservation)
        #expect(result.at60.medianBPM == nil)
    }

    @Test(arguments: [OwnerTelemetryObservationKind.paused, .ending, .interrupted])
    func ineligibleObservationKindsCannotManufactureRecovery(kind: OwnerTelemetryObservationKind) throws {
        var telemetry = try o6RecoveryFixture(through: 60, closure: .interrupted)
        try telemetry.recordObservation(o6Observation(203, kind: kind, set: o6ID(10),
            start: 60, end: 190, closure: .interrupted))
        _ = try o6Append([o6Sample(2_000, end: 111), o6Sample(2_001, end: 120)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.at60.state == .missing)
        #expect(result.at60.medianBPM == nil)
        #expect(result.at60.dropBPM == nil)
    }

    @Test func missingBaselineOnlyRemovesItsDependentComparison() throws {
        var telemetry = try o6RecoveryFixture(baseline: false)
        _ = try o6Append([o6Sample(1_000, end: 10, bpm: 90), o6Sample(1_001, end: 20, bpm: 110),
            o6Sample(2_000, end: 111, bpm: 130), o6Sample(2_001, end: 120, bpm: 150)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.baseline.state == .missing)
        #expect(result.baselineDifferenceBPM == nil)
        #expect(result.baselineDifferenceReason == .missingReference)
        #expect(result.endReference.medianBPM == 170)
        #expect(result.at60.medianBPM == 140)
        #expect(result.at60.dropBPM == 30)
    }

    @Test func missingEndReferenceDoesNotBorrowBaselineOrUnobservedSamples() throws {
        var telemetry = try o6RecoveryFixture(endReference: false)
        _ = try o6Append([o6Sample(1_002, end: 55, bpm: 160), o6Sample(1_003, end: 59, bpm: 180),
            o6Sample(2_000, end: 111, bpm: 130), o6Sample(2_001, end: 120, bpm: 150)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.baseline.medianBPM == 100)
        #expect(result.endReference.state == .missing)
        #expect(result.at60.medianBPM == 140)
        #expect(result.at60.dropBPM == nil)
        #expect(result.at60.dropReason == .missingReference)
        #expect(result.baselineDifferenceBPM == nil)
    }

    @Test func baselineCanUseObservedPriorRestButNotPriorActiveOrUnobservedHistory() throws {
        var telemetry = try o6Telemetry()
        _ = try o6Admit(10, start: 10, stop: 50, to: &telemetry)
        _ = try o6Admit(11, start: 60, stop: 90, to: &telemetry)
        try telemetry.recordObservation(o6Observation(200, kind: .active, set: o6ID(10),
            start: 10, end: 50, closure: .setStopped))
        try telemetry.recordObservation(o6Observation(201, kind: .recovery, set: o6ID(10),
            start: 50, end: 60, closure: .nextSet))
        try telemetry.recordObservation(o6Observation(202, kind: .active, set: o6ID(11),
            start: 60, end: 90, closure: .setStopped))
        _ = try o6Append([o6Sample(2_000, end: 49, bpm: 250),
            o6Sample(2_001, end: 51, bpm: 90), o6Sample(2_002, end: 59, bpm: 110),
            o6Sample(2_003, end: 85, bpm: 150), o6Sample(2_004, end: 89, bpm: 170)], to: &telemetry)
        let result = try o6Summary(telemetry, set: o6ID(11))
        #expect(result.baseline.medianBPM == 100)
        #expect(result.baseline.sampleCount == 2)
        #expect(result.endReference.medianBPM == 160)
        #expect(result.baselineDifferenceBPM == 60)
    }

    @Test func zeroDurationIntervalsAndAdjacentScopesAreDeterministicAndNonduplicating() throws {
        var telemetry = try o6Telemetry()
        _ = try o6Admit(to: &telemetry)
        try telemetry.recordObservation(o6Observation(200, kind: .baseline,
            start: 0, end: 30, closure: .setStarted))
        try telemetry.recordObservation(o6Observation(201, kind: .baseline,
            start: 30, end: 30, closure: .setStarted))
        try telemetry.recordObservation(o6Observation(202, kind: .active, set: o6ID(10),
            start: 30, end: 60, closure: .setStopped))
        try telemetry.recordObservation(o6Observation(203, kind: .recovery, set: o6ID(10),
            start: 60, end: 130))
        _ = try o6Append([o6Sample(2_000, end: 10, bpm: 90),
            o6Sample(2_001, end: 30, bpm: 110), // zero-duration native interval on shared boundary
            o6Sample(2_002, end: 55, bpm: 160),
            o6Sample(2_003, end: 60, bpm: 180),
            o6Sample(2_004, end: 111, bpm: 130),
            o6Sample(2_005, end: 130, bpm: 150)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.baseline.sampleCount == 2)
        #expect(result.baseline.medianBPM == 100)
        #expect(result.endReference.sampleCount == 2)
        #expect(result.at60.sampleCount == 2)
        #expect(result.at60.medianBPM == 140)
    }

    @Test func unorderedOverlappingOrReboundObservationsCannotReplaceEvidence() throws {
        var telemetry = try o6RecoveryFixture(through: 120)
        let before = try telemetry.encoded()
        #expect(throws: (any Error).self) {
            try telemetry.recordObservation(o6Observation(203, kind: .recovery, set: o6ID(10),
                start: 130, end: 120))
        }
        #expect(throws: (any Error).self) {
            try telemetry.recordObservation(o6Observation(203, kind: .active, set: o6ID(10),
                start: 110, end: 130))
        }
        #expect(throws: (any Error).self) {
            try telemetry.recordObservation(o6Observation(202, kind: .recovery, set: o6ID(11),
                start: 60, end: 130))
        }
        #expect(throws: (any Error).self) {
            try telemetry.recordObservation(o6Observation(202, kind: .recovery, set: o6ID(10),
                start: 61, end: 130))
        }
        #expect(throws: (any Error).self) {
            try telemetry.recordObservation(o6Observation(202, kind: .recovery, set: o6ID(10),
                start: 60, end: 119))
        }
        #expect(try telemetry.encoded() == before)
    }

    @Test func missingSetCalibrationMakesAlignmentExplicitlyUnavailable() throws {
        var telemetry = try o6RecoveryFixture(calibrated: false)
        _ = try o6Append([o6Sample(2_000, end: 111), o6Sample(2_001, end: 120)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.at60.state == .missing)
        #expect(result.at60.reason == .missingCalibration)
        #expect(result.at60.medianBPM == nil)
        #expect(result.at60.dropBPM == nil)
    }

    @Test func measuredUncertaintyRejectsAmbiguousBoundariesWithoutDiscardingInteriorAlignment() throws {
        var telemetry = try o6RecoveryFixture(through: 191, radius: 0.25)
        _ = try o6Append([o6Sample(2_000, end: 111, bpm: 130),
            o6Sample(2_001, end: 120, bpm: 150)], to: &telemetry)
        #expect(try o6Summary(telemetry).at60.medianBPM == 140)
        _ = try o6Append([o6Sample(2_002, end: 130, bpm: 170)], to: &telemetry)
        let ambiguous = try o6Summary(telemetry)
        #expect(ambiguous.at60.state == .missing)
        #expect(ambiguous.at60.reason == .ambiguousClock)
        #expect(ambiguous.at60.medianBPM == nil)
    }

    @Test func wallMonotonicDiscontinuityOverTwoSecondsCannotBeBridged() throws {
        var telemetry = try o6RecoveryFixture(through: 120)
        try telemetry.recordObservation(o6Observation(202, kind: .recovery, set: o6ID(10),
            start: 60, end: 190, wallAdjustment: 2.000_001))
        _ = try o6Append([o6Sample(2_000, end: 111), o6Sample(2_001, end: 120)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.at60.state == .missing)
        #expect(result.at60.reason == .clockDiscontinuity)
        #expect(result.at60.dropBPM == nil)
        #expect(result.baseline.medianBPM == 100) // Earlier immutable alignment is not rewritten.
    }

    @Test func consentRevocationAndRegrantSplitWindowsWithoutRelabelingPriorSamples() throws {
        var telemetry = try o6RecoveryFixture(through: 120, closure: .consentChanged)
        _ = try o6Append([o6Sample(2_000, end: 111, bpm: 130),
            o6Sample(2_001, end: 119, bpm: 150)], to: &telemetry)
        let contextBytes = try telemetry.sets[0].context.encoded()
        let owner = try o6Authority()
        let revoke = try OwnerConsentDecision.heartRate(for: owner, allowed: false,
            decisionID: o6ID(40), confirmedAtUnixSeconds: o6Wall + 120, policyDigest: OwnerPracticePolicy.digest)
        let excluded = try owner.applying(revoke)
        try telemetry.transitionAuthority(to: excluded, decision: revoke, at: o6Instant(120),
            segmentID: o6ID(41), queryGeneration: nil)
        let grant = try OwnerConsentDecision.heartRate(for: excluded, allowed: true,
            decisionID: o6ID(42), confirmedAtUnixSeconds: o6Wall + 125, policyDigest: OwnerPracticePolicy.digest)
        try telemetry.transitionAuthority(to: excluded.applying(grant), decision: grant, at: o6Instant(125),
            segmentID: o6ID(43), queryGeneration: o6ID(44))
        try telemetry.recordObservation(o6Observation(203, kind: .recovery, set: o6ID(10),
            start: 125, end: 190, consent: o6ID(43), query: o6ID(44)))
        let rejected = try o6Append([o6Sample(2_002, end: 121, start: 119)], to: &telemetry)
        #expect(rejected.excluded[.consentExcluded] == 1)
        _ = try o6Append([o6Sample(2_003, end: 171, bpm: 100),
            o6Sample(2_004, end: 180, bpm: 120)], to: &telemetry, consent: o6ID(43), query: o6ID(44))
        let result = try o6Summary(telemetry)
        #expect(result.at60.state == .missing)
        #expect(result.at60.reason == .incompleteObservation)
        #expect(result.at120.medianBPM == 110)
        #expect(result.at120.dropBPM == 60)
        #expect(try telemetry.sets[0].context.encoded() == contextBytes)
        #expect(telemetry.sampleRecords.first { $0.sample.id == o6ID(2_000) }?.consentSegmentID == o6Consent)
    }

    @Test func lateConflictRecomputesProvisionalMedianAndQuarantinesEveryVersion() throws {
        var telemetry = try o6RecoveryFixture()
        _ = try o6Append([o6Sample(2_000, end: 111, bpm: 130),
            o6Sample(2_001, end: 120, bpm: 150)], to: &telemetry)
        #expect(try o6Summary(telemetry).at60.medianBPM == 140)
        _ = try o6Append([o6Sample(2_001, end: 120, bpm: 160)], to: &telemetry)
        let revised = try o6Summary(telemetry)
        #expect(revised.at60.state == .missing)
        #expect(revised.at60.reason == .sampleConflict)
        #expect(revised.at60.medianBPM == nil)
        #expect(revised.at60.dropBPM == nil)
        #expect(revised.coverage == .invalid)
        #expect(telemetry.sampleRecords.filter { $0.sample.id == o6ID(2_001) }.allSatisfy { !$0.isEligible })
    }

    @Test func conflictInvalidatesOnlyAffectedWindowAndItsDependentComparisons() throws {
        var telemetry = try o6RecoveryFixture()
        _ = try o6Append([o6Sample(2_000, end: 111, bpm: 130),
            o6Sample(2_001, end: 120, bpm: 150),
            o6Sample(1_000, end: 10, bpm: 95)], to: &telemetry)
        let result = try o6Summary(telemetry)
        #expect(result.baseline.reason == .sampleConflict)
        #expect(result.baseline.medianBPM == nil)
        #expect(result.baselineDifferenceBPM == nil)
        #expect(result.endReference.medianBPM == 170)
        #expect(result.at60.medianBPM == 140)
        #expect(result.at60.dropBPM == 30)
        #expect(result.coverage == .invalid)
    }

    @Test func duplicateAndArrivalOrderCannotWeightMedianOrChangeSummary() throws {
        let samples = try [o6Sample(2_000, end: 111, bpm: 130, arrival: 160),
            o6Sample(2_001, end: 120, bpm: 150, arrival: 150),
            o6Sample(2_000, end: 111, bpm: 130, arrival: 140)]
        var summaries = [OwnerRecoverySummary]()
        for order in [[0, 1, 2], [2, 1, 0], [1, 0, 2]] {
            var telemetry = try o6RecoveryFixture()
            for index in order { _ = try o6Append([samples[index]], to: &telemetry) }
            let result = try o6Summary(telemetry)
            #expect(result.at60.sampleCount == 2)
            #expect(result.at60.medianBPM == 140)
            summaries.append(result)
        }
        #expect(summaries[0] == summaries[1])
        #expect(summaries[0] == summaries[2])
    }

    @Test func lateNativeArrivalUsesSourceDatesAndFinalizationFreezesRecovery() throws {
        var telemetry = try o6RecoveryFixture(through: 190, closure: .ended)
        _ = try o6Append([o6Sample(2_000, end: 111, bpm: 130, arrival: 204),
            o6Sample(2_001, end: 120, bpm: 150, arrival: 204)], to: &telemetry)
        let expected = try o6Summary(telemetry)
        #expect(expected.at60.medianBPM == 140)
        try telemetry.finalize(status: .ended, at: o6Instant(200), absenceReasons: [.insufficientSamples])
        let bytes = try telemetry.encoded()
        #expect(throws: (any Error).self) {
            try o6Append([o6Sample(2_001, end: 120, bpm: 190, arrival: 206)], to: &telemetry)
        }
        #expect(try telemetry.encoded() == bytes)
        #expect(try o6Summary(telemetry) == expected)
    }

    @Test func nativeDeletionInvalidatesEveryProvisionalWindowWithoutRewritingEvidence() throws {
        var telemetry = try o6RecoveryFixture()
        _ = try o6Append([o6Sample(2_000, end: 111), o6Sample(2_001, end: 120),
            o6Sample(2_002, end: 171), o6Sample(2_003, end: 180)], to: &telemetry)
        let original = try o6Summary(telemetry)
        #expect([original.baseline, original.endReference, original.at60, original.at120].allSatisfy { $0.state == .available })
        let samples = telemetry.sampleRecords, context = try telemetry.sets[0].context.encoded()
        try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(900), at: o6Instant(195), reason: .sourceDeleted, count: 256))
        let invalid = try o6Summary(telemetry)
        for window in [invalid.baseline, invalid.endReference, invalid.at60, invalid.at120] {
            #expect(window.state == .missing && window.reason == .sourceDeleted)
            #expect(window.medianBPM == nil && window.dropBPM == nil)
        }
        #expect(invalid.coverage == .invalid && invalid.baselineDifferenceBPM == nil)
        let retainedContext = try telemetry.sets[0].context.encoded()
        #expect(telemetry.sampleRecords == samples && retainedContext == context)
        let decodedSummary = try o6Summary(OwnerPracticeTelemetry.decode(telemetry.encoded()))
        #expect(decodedSummary == invalid)
        try telemetry.finalize(status: .ended, at: o6Instant(200), absenceReasons: [.sourceDeleted])
        let frozen = try telemetry.encoded()
        #expect(throws: (any Error).self) {
            try telemetry.recordEvent(OwnerTelemetryEvent(id: o6ID(901), at: o6Instant(200), reason: .sourceDeleted))
        }
        #expect(try telemetry.encoded() == frozen)
    }

    @Test func openObservationAtKnownConsentClosureCannotRemainPending() throws {
        var telemetry = try o6RecoveryFixture(through: 125)
        _ = try o6Append([o6Sample(2_000, end: 111), o6Sample(2_001, end: 120)], to: &telemetry)
        let owner = try o6Authority()
        let revoke = try OwnerConsentDecision.heartRate(for: owner, allowed: false,
            decisionID: o6ID(900), confirmedAtUnixSeconds: o6Wall + 125, policyDigest: OwnerPracticePolicy.digest)
        try telemetry.transitionAuthority(to: owner.applying(revoke), decision: revoke, at: o6Instant(125),
            segmentID: o6ID(901), queryGeneration: nil)
        let summary = try o6Summary(telemetry)
        #expect(summary.at60.state == .missing && summary.at60.reason == .incompleteObservation)
        #expect(summary.at120.state == .missing && summary.at60.medianBPM == nil && summary.at60.dropBPM == nil)
    }

    @Test(arguments: ["observation", "setStop"])
    func commonWallShiftCannotHideBehindAnUnchangedIntervalDuration(location: String) throws {
        var telemetry = try o6Telemetry()
        let context = try o6Admit(stop: nil, to: &telemetry)
        try telemetry.stopSet(recordingID: context.recordingID, rawStopSeconds: 70,
            at: o6Instant(60, wallAdjustment: location == "setStop" ? 3 : 0))
        try telemetry.recordObservation(o6Observation(200, kind: .baseline, start: 0, end: 30, closure: .setStarted))
        try telemetry.recordObservation(o6Observation(201, kind: .active, set: context.recordingID,
            start: 30, end: 60, closure: .setStopped))
        let shift = location == "observation" ? 3.0 : 0
        try telemetry.recordObservation(OwnerTelemetryObservation(id: o6ID(202), kind: .recovery,
            recordingID: context.recordingID, consentSegmentID: o6Consent, queryGeneration: o6Query,
            start: o6Instant(60, wallAdjustment: shift), end: o6Instant(190, wallAdjustment: shift), closure: .open))
        _ = try o6Append([o6Sample(1_000, end: 10, bpm: 90), o6Sample(1_001, end: 20, bpm: 110),
            o6Sample(2_000, end: 111), o6Sample(2_001, end: 120)], to: &telemetry)
        let summary = try o6Summary(telemetry)
        #expect(summary.baseline.medianBPM == 100)
        #expect(summary.at60.state == .missing && summary.at60.reason == .clockDiscontinuity)
        #expect(summary.at60.medianBPM == nil && summary.at60.dropBPM == nil && summary.coverage == .invalid)
    }
}
