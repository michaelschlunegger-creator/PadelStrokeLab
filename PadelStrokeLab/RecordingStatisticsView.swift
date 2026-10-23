import SwiftUI
import Charts
import PadelCore
import PadelDesign

struct RecordingStatisticsView: View {
    let statistics: MotionStatistics?
    let unavailableReason: String?
    let isInterrupted: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: PracticeTheme.Space.large) {
            VStack(alignment: .leading, spacing: PracticeTheme.Space.small) {
                Text("Motion signals").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                if isInterrupted {
                    Text("Retained portion — interrupted").font(.headline)
                        .accessibilityIdentifier("motionInterruptedNotice")
                }
                Text("Calculated from retained samples in known active intervals. These wrist-motion values do not measure contact quality.")
                    .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
            }
            if let statistics {
                metricCard(statistics.summary(for: .userAcceleration), anchor: statistics.anchor)
                metricCard(statistics.summary(for: .rotationRate), anchor: statistics.anchor)
                DisclosureGroup {
                    metricContent(statistics.summary(for: .rawAcceleration), anchor: statistics.anchor)
                        .padding(.top, PracticeTheme.Space.medium)
                } label: {
                    Text("Raw acceleration details")
                        .accessibilityIdentifier("rawAccelerationDisclosure")
                }
                .tint(PracticeTheme.accent(scheme))
                .practiceCard()
            } else {
                Text(unavailableReason ?? "Motion statistics are unavailable.")
                    .fixedSize(horizontal: false, vertical: true)
                    .practiceCard()
                    .accessibilityIdentifier("motionStatisticsUnavailable")
            }
        }
        .foregroundStyle(PracticeTheme.ink(scheme))
    }

    private func metricCard(_ summary: MotionStatisticSummary, anchor: Double) -> some View {
        metricContent(summary, anchor: anchor).practiceCard()
    }

    private func metricContent(_ summary: MotionStatisticSummary, anchor: Double) -> some View {
        VStack(alignment: .leading, spacing: PracticeTheme.Space.medium) {
            Text(title(summary.metric)).font(.headline).accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            Text(explanation(summary.metric)).font(.footnote)
                .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                .fixedSize(horizontal: false, vertical: true)
            if let peak = summary.peak, let rms = summary.sampleRMS,
               let displayPeak = summary.metric.displayValue(peak),
               let displayRMS = summary.metric.displayValue(rms) {
                VStack(alignment: .leading, spacing: PracticeTheme.Space.small) {
                    value("Peak", value: displayPeak, metric: summary.metric, identifier: "peak")
                    value("RMS of retained samples", value: displayRMS, metric: summary.metric, identifier: "rms")
                }
                trace(summary, anchor: anchor)
            } else {
                Text(summary.unavailableReason ?? "No eligible retained samples.")
                    .font(.callout)
                    .accessibilityIdentifier("\(summary.metric.rawValue)Unavailable")
            }
            Text("\(summary.sampleCount.formatted()) eligible retained samples")
                .font(.caption).foregroundStyle(PracticeTheme.secondaryInk(scheme))
                .accessibilityIdentifier("\(summary.metric.rawValue)SampleCount")
        }
    }

    private func value(_ title: String, value: Double, metric: MotionStatisticMetric, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline)
            Text("\(number(value)) \(unit(metric))").font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(metric.rawValue)-\(identifier)")
    }

    private func trace(_ summary: MotionStatisticSummary, anchor: Double) -> some View {
        VStack(alignment: .leading, spacing: PracticeTheme.Space.small) {
            Chart(Array(summary.points.enumerated()), id: \.offset) { entry in
                if let value = summary.metric.displayValue(entry.element.value) {
                    PointMark(x: .value("Seconds from recording start", entry.element.timestamp - anchor),
                              y: .value(unit(summary.metric), value))
                        .foregroundStyle(PracticeTheme.accent(scheme))
                        .symbolSize(10)
                }
            }
            .chartXAxisLabel("Seconds from recording start")
            .chartYAxisLabel(unit(summary.metric))
            .frame(height: 180)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title(summary.metric)) trace")
            .accessibilityValue("Selected retained samples. \(summary.sampleCount) eligible samples; peak and RMS are listed above. Pauses and missing samples are not connected.")
            .accessibilityIdentifier("\(summary.metric.rawValue)Trace")
            Text("Dots preserve observed peaks and times. Pauses and gaps are not connected.")
                .font(.caption).foregroundStyle(PracticeTheme.secondaryInk(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func title(_ metric: MotionStatisticMetric) -> String {
        switch metric {
        case .userAcceleration: "Wrist acceleration"
        case .rotationRate: "Wrist rotation rate"
        case .rawAcceleration: "Raw acceleration"
        }
    }

    private func explanation(_ metric: MotionStatisticMetric) -> String {
        switch metric {
        case .userAcceleration: "Magnitude of gravity-removed wrist acceleration, in g."
        case .rotationRate: "Magnitude of wrist angular rate, in degrees per second."
        case .rawAcceleration: "Accelerometer magnitude including gravity, in g."
        }
    }

    private func unit(_ metric: MotionStatisticMetric) -> String { metric == .rotationRate ? "°/s" : "g" }

    private func number(_ value: Double) -> String {
        if value >= 1_000_000 || (value > 0 && value < 0.001) {
            return value.formatted(.number.notation(.scientific).precision(.significantDigits(3)))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
