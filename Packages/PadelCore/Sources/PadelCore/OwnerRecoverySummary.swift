import Foundation

public enum OwnerRecoveryState: String, Codable, Sendable { case available, missing, pending }
public enum OwnerRecoveryCoverage: String, Codable, Sendable { case valid, partial, invalid }
public struct OwnerRecoverySourceSpan: Equatable, Sendable {
    public let startUnixSeconds: Double, endUnixSeconds: Double
}
public struct OwnerRecoveryWindow: Equatable, Sendable {
    public let state: OwnerRecoveryState
    public let reason: OwnerTelemetryReason?
    public let medianBPM: Double?
    public let sampleCount: Int
    public let sourceSpan: OwnerRecoverySourceSpan?
    public internal(set) var dropBPM: Double?, dropReason: OwnerTelemetryReason?
}

/// Descriptive observed HR differences, never a physiological recovery or readiness claim.
public struct OwnerRecoverySummary: Equatable, Sendable {
    public let baseline: OwnerRecoveryWindow, endReference: OwnerRecoveryWindow, at60: OwnerRecoveryWindow, at120: OwnerRecoveryWindow
    public let baselineDifferenceBPM: Double?
    public let baselineDifferenceReason: OwnerTelemetryReason?
    public let coverage: OwnerRecoveryCoverage

    public static func calculate(telemetry: OwnerPracticeTelemetry, recordingID: UUID) throws -> Self {
        guard let set = telemetry.sets.first(where: { $0.context.recordingID == recordingID }) else {
            throw OwnerTelemetryError.invalid("recovery recording")
        }
        let calculator = Calculator(telemetry: telemetry, set: set)
        let baseline = calculator.window(kind: .baseline)
        let end = calculator.window(kind: .active)
        var at60 = calculator.window(kind: .recovery, target: 60)
        var at120 = calculator.window(kind: .recovery, target: 120)
        for target in [60, 120] {
            var value = target == 60 ? at60 : at120
            if let reference = end.medianBPM, let later = value.medianBPM { value.dropBPM = reference - later }
            else { value.dropReason = end.medianBPM == nil ? .missingReference : value.reason }
            if target == 60 { at60 = value } else { at120 = value }
        }
        let difference = baseline.medianBPM.flatMap { first in end.medianBPM.map { $0 - first } }
        let invalid = telemetry.incompleteReasons.contains(.sampleConflict) || calculator.globalFailure != nil
            || [baseline, end, at60, at120].contains { window in
                window.reason.map { [OwnerTelemetryReason.clockDiscontinuity, .ambiguousClock, .missingCalibration].contains($0) } ?? false
            }
        let coverage: OwnerRecoveryCoverage = invalid ? .invalid
            : ([baseline, end, at60, at120].allSatisfy { $0.state == .available } ? .valid : .partial)
        return Self(baseline: baseline, endReference: end, at60: at60, at120: at120,
            baselineDifferenceBPM: difference, baselineDifferenceReason: difference == nil ? .missingReference : nil, coverage: coverage)
    }
    private struct Calculator {
        let telemetry: OwnerPracticeTelemetry
        let set: OwnerTelemetrySet
        var globalFailure: OwnerTelemetryReason? {
            let reasons: [OwnerTelemetryReason] = [.sourceDeleted, .sourceError, .pageLimit, .sampleLimit, .byteLimit, .eventLimit, .durationLimit]
            if let reason = reasons.first(where: { telemetry.incompleteReasons.contains($0) }) { return reason }
            if let terminal = telemetry.finalization, terminal.status == .interrupted,
               terminal.absenceReasons.contains(.clockDiscontinuity), badClock(terminal.endedAt) {
                return .clockDiscontinuity
            }
            return nil
        }
        func missing(_ reason: OwnerTelemetryReason, count: Int = 0, span: OwnerRecoverySourceSpan? = nil,
                     state: OwnerRecoveryState = .missing) -> OwnerRecoveryWindow {
            OwnerRecoveryWindow(state: state, reason: reason, medianBPM: nil, sampleCount: count,
                sourceSpan: span, dropBPM: nil, dropReason: nil)
        }
        func wall(_ instant: OwnerTelemetryInstant) -> Double {
            telemetry.header.clock.wallAnchorUnixSeconds + instant.monotonicSeconds - telemetry.header.clock.monotonicAnchorSeconds
        }
        func badClock(_ instant: OwnerTelemetryInstant) -> Bool { abs(instant.wallUnixSeconds - wall(instant)) > 2 }
        func badClock(_ observation: OwnerTelemetryObservation) -> Bool {
            observation.clockDiscontinuous || badClock(observation.start) || badClock(observation.end)
        }
        func end(_ observation: OwnerTelemetryObservation) -> Double {
            var end = wall(observation.end)
            if let consent = telemetry.consentSegments.first(where: { $0.id == observation.consentSegmentID }), let closure = consent.end {
                end = min(end, wall(closure))
            }
            if observation.kind == .recovery || observation.kind == .rest,
               let id = observation.recordingID, let sourceSet = telemetry.sets.first(where: { $0.context.recordingID == id }) {
                for next in telemetry.sets where next.startedAt.monotonicSeconds > sourceSet.startedAt.monotonicSeconds {
                    end = min(end, wall(next.startedAt))
                }
            }
            if let final = telemetry.finalization { end = min(end, wall(final.endedAt)) }
            return end
        }
        func isLive(_ observation: OwnerTelemetryObservation) -> Bool {
            guard observation.closure == .open, telemetry.status == .open, telemetry.finalization == nil,
                  let consent = telemetry.consentSegments.first(where: { $0.id == observation.consentSegmentID }),
                  consent.end == nil, consent.heartRateEnabled, consent.queryGeneration == observation.queryGeneration,
                  let index = telemetry.sets.firstIndex(where: { $0.context.recordingID == observation.recordingID }),
                  index == telemetry.sets.count - 1 else { return false }
            return !telemetry.observations.contains {
                $0.id != observation.id && $0.start.monotonicSeconds >= observation.end.monotonicSeconds
                    && $0.end.monotonicSeconds > observation.end.monotonicSeconds
            }
        }
        func window(kind: OwnerTelemetryObservationKind, target: Double = 0) -> OwnerRecoveryWindow {
            if let reason = globalFailure { return missing(reason) }
            guard let mapping = set.mapping else { return missing(.missingCalibration) }
            let point: OwnerTelemetryInstant
            if kind == .baseline { point = set.startedAt }
            else if let stop = set.stoppedAt { point = stop }
            else { return missing(.incompleteObservation, state: telemetry.finalization == nil && telemetry.status == .open ? .pending : .missing) }
            guard !badClock(point) else { return missing(.clockDiscontinuity) }
            let anchor = wall(point)
            let lower = anchor + (kind == .baseline ? -30 : kind == .active ? -10 : target - 10)
            let upper = anchor + (kind == .recovery ? target + 10 : 0)
            let observations = telemetry.observations.filter { observation in
                if kind == .baseline {
                    return (observation.kind == .baseline || observation.kind == .recovery || observation.kind == .rest)
                        && wall(observation.start) < upper && end(observation) <= anchor
                }
                return observation.recordingID == set.context.recordingID
                    && (kind == .active ? observation.kind == .active : observation.kind == .recovery || observation.kind == .rest)
            }
            let touching = observations.filter { wall($0.start) < upper && end($0) > lower }
            // Compare BOTH endpoints with the frozen practice anchor: equal wall shifts are discontinuities too.
            if touching.contains(where: badClock) || telemetry.events.contains(where: {
                $0.reason == .clockDiscontinuity && wall($0.at) >= lower && wall($0.at) <= upper
            }) { return missing(.clockDiscontinuity) }
            if kind == .recovery {
                let complete = touching.contains { wall($0.start) <= lower && end($0) >= upper }
                if !complete {
                    let pending = touching.contains {
                        isLive($0) && wall($0.start) <= lower && end($0) < upper && end($0) == wall($0.end)
                    }
                    // An open observation may not yet reach even the target's lower boundary.
                    let earlierOpen = observations.contains {
                        isLive($0) && wall($0.start) <= lower && end($0) <= lower && end($0) == wall($0.end)
                    }
                    return missing(.incompleteObservation, state: pending || earlierOpen ? .pending : .missing)
                }
                if mapping.uncertaintySeconds > 0 && !touching.contains(where: {
                    wall($0.start) <= lower - mapping.uncertaintySeconds && end($0) >= upper + mapping.uncertaintySeconds
                }) { return missing(.ambiguousClock) }
            }
            let uncertainty = mapping.uncertaintySeconds
            var selected: [OwnerTelemetrySampleRecord] = []
            var conflict = false, ambiguous = false
            let conflicted = Set(telemetry.conflictGroups.map(\.sampleID))
            for record in telemetry.sampleRecords {
                let sample = record.sample, start = record.sample.sourceStart.timeIntervalSince1970, stop = record.sample.sourceEnd.timeIntervalSince1970
                guard stop + uncertainty > lower, stop - uncertainty <= upper else { continue }
                let scopes = touching.filter {
                    $0.consentSegmentID == record.consentSegmentID && $0.queryGeneration == record.queryGeneration
                        && stop > wall($0.start) && start >= wall($0.start) && stop <= end($0)
                }
                guard !scopes.isEmpty else { continue }
                if uncertainty > 0 && (stop - uncertainty <= lower || stop + uncertainty > upper || !scopes.contains(where: {
                    start - uncertainty >= wall($0.start) && stop + uncertainty <= end($0)
                })) { ambiguous = true; continue }
                guard stop > lower, stop <= upper else { continue }
                if conflicted.contains(sample.id) { conflict = true }
                else if record.isEligible { selected.append(record) }
            }
            let span = selected.isEmpty ? nil : OwnerRecoverySourceSpan(
                startUnixSeconds: selected.map { $0.sample.sourceStart.timeIntervalSince1970 }.min()!,
                endUnixSeconds: selected.map { $0.sample.sourceEnd.timeIntervalSince1970 }.max()!)
            if conflict { return missing(.sampleConflict, count: selected.count, span: span) }
            if ambiguous { return missing(.ambiguousClock, count: selected.count, span: span) }
            guard selected.count >= 2 else {
                return missing(selected.isEmpty ? .noAccessibleHeartRateData : .insufficientSamples, count: selected.count, span: span)
            }
            let values = selected.map { $0.sample.bpm }.sorted(), middle = selected.count / 2
            let median = selected.count.isMultiple(of: 2) ? (values[middle - 1] + values[middle]) / 2 : values[middle]
            return OwnerRecoveryWindow(state: .available, reason: nil, medianBPM: median, sampleCount: selected.count,
                sourceSpan: span, dropBPM: nil, dropReason: nil)
        }
    }
}
