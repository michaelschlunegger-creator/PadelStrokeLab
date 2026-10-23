import SwiftUI
import Charts
import PadelCore
import PadelDesign

struct OwnerPracticeStatisticsView: View {
    let review: OwnerPracticeReview
    let recordingID: UUID
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Owner practice · revision \(review.snapshot.receipt.revision)")
                .font(.title2.bold()).accessibilityIdentifier("ownerPracticeScope")
            Text("Intended strokes and contact labels are manual owner references. Wrist signals do not measure contact quality or detect shots.")
                .accessibilityIdentifier("ownerPracticeMeasurementNotice")
            Text("\(review.recordings.count) retained sets · \(review.snapshot.status.rawValue.capitalized)")
            ForEach(review.recordings) { recording in
                VStack(alignment: .leading, spacing: 6) {
                    Text(RecordingDrill.recordedTitle(for: recording.report.metadata?.drill ?? "unknown")).font(.headline)
                    Text("\(recording.latestLabels.count) manual attempts · \(recording.streams.reduce(0) { $0 + $1.count }) retained samples")
                    if recording.id != recordingID {
                        NavigationLink("Review this set") { RecordingDetailView(recordingID: recording.id) }
                            .buttonStyle(PracticeActionStyle())
                    }
                }
            }
            Divider()
            Text("Heart rate & observed recovery").font(.title2.bold())
            Text(coverage).accessibilityIdentifier("ownerHeartRateCoverage")
            if review.snapshot.heartRate == .included, let telemetry = review.snapshot.telemetry {
                let samples = telemetry.sampleRecords.filter(\.isEligible)
                if !samples.isEmpty {
                    Chart(Array(samples.enumerated()), id: \.offset) { entry in
                        PointMark(x: .value("Practice seconds", entry.element.sample.sourceEnd.timeIntervalSince1970 - telemetry.header.clock.wallAnchorUnixSeconds),
                                  y: .value("BPM", entry.element.sample.bpm))
                            .foregroundStyle(PracticeTheme.accent(scheme))
                    }
                    .frame(height: 180)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Practice heart rate: \(samples.count) retained observations in beats per minute. Gaps are not interpolated.")
                    .accessibilityIdentifier("ownerHeartRateTrace")
                }
            }
            if let recovery = review.recoveryByRecordingID[recordingID] {
                Text(window("Baseline", recovery.baseline))
                Text(window("Set end", recovery.endReference))
                Text(window("60-second observation", recovery.at60)).accessibilityIdentifier("ownerRecovery60")
                Text(window("120-second observation", recovery.at120)).accessibilityIdentifier("ownerRecovery120")
                Text("Recovery coverage: \(recovery.coverage.rawValue). Differences describe observed heart rate; they are not fitness, readiness or medical scores.")
                    .font(.footnote)
            } else {
                Text("60-second observation: missing — heart rate excluded.").accessibilityIdentifier("ownerRecovery60")
                Text("120-second observation: missing — heart rate excluded.").accessibilityIdentifier("ownerRecovery120")
            }
            if !review.snapshot.absenceReasons.isEmpty {
                Text("Evidence notes: " + review.snapshot.absenceReasons.map(\.rawValue).joined(separator: ", ")).font(.footnote)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(PracticeTheme.ink(scheme))
        .practiceCard()
    }
    private var coverage: String {
        switch review.snapshot.heartRate {
        case .excluded: "Heart rate excluded by the owner. No heart rate or recovery values are available in this revision."
        case .absent: "No accessible heart rate data retained. Missing data does not mean zero heart rate."
        case .included: "Heart rate included: \(review.snapshot.telemetry?.sampleRecords.count ?? 0) retained observations across the practice. Sparse coverage may leave recovery windows missing."
        }
    }
    private func window(_ title: String, _ value: OwnerRecoveryWindow) -> String {
        let bpm = value.medianBPM.map { $0.formatted(.number.precision(.fractionLength(0...1))) + " BPM" }
        let drop = value.dropBPM.map { "; observed drop " + $0.formatted(.number.precision(.fractionLength(0...1))) + " BPM" } ?? ""
        return title + ": " + (bpm ?? value.state.rawValue) + " · \(value.sampleCount) samples" + drop
            + (value.reason.map { " · " + $0.rawValue } ?? "")
    }
}

struct OwnerPracticeExportPreview: View {
    let snapshot: OwnerPracticeBundleSnapshot
    let confirm: () -> Void
    let cancel: () -> Void
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Review practice export").font(.title2.bold())
                Text("Wearer: enrolled owner \(snapshot.scope.ownerID.uuidString).")
                    .accessibilityIdentifier("exportWearer")
                Text("Entire practice, revision \(snapshot.receipt.revision): " + snapshot.sets.map {
                    RecordingDrill.recordedTitle(for: $0.context.metadata.drill)
                }.joined(separator: ", ") + ". Includes original motion samples, timing, capture details and all manual label revisions.")
                    .accessibilityIdentifier("exportPracticeInventory")
                Text("Heart rate: \(snapshot.heartRate.rawValue). This exports the retained revision exactly; excluded data stays excluded.")
                    .accessibilityIdentifier("exportHeartRateInclusion")
                Text("Preparing creates a local file. You choose a recipient separately in the share sheet.")
                Button("Prepare reviewed export", action: confirm).buttonStyle(PracticeActionStyle())
                    .accessibilityIdentifier("confirmPracticeExport")
                Button("Cancel", action: cancel).buttonStyle(PracticeActionStyle())
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .foregroundStyle(PracticeTheme.ink(scheme)).background(PracticeTheme.canvas(scheme))
        .accessibilityIdentifier("ownerPracticeExportPreview")
    }
}
