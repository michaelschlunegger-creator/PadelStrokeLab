import SwiftUI
import PadelCore
import PadelDesign

struct RecordingLibraryView: View {
    @Environment(RecordingLibraryModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    PracticeEyebrow("Your recordings")
                    Text("Small sets.\nUseful evidence.")
                        .font(.largeTitle.bold())
                    Text("Record on your Watch, then review and label your attempts here.")
                }
                .foregroundStyle(.white)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PracticeTheme.hero, in: .rect(cornerRadius: 28))

                Label(model.transferMessage, systemImage: "applewatch.radiowaves.left.and.right")
                    .font(.footnote)
                    .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                    .accessibilityIdentifier("transferStatus")
                if let message = model.practiceDeletionMessage {
                    Text(message).fixedSize(horizontal: false, vertical: true).practiceCard()
                        .accessibilityIdentifier("practiceDeletionStatus")
                }
                if model.loading && model.recordings.isEmpty { ProgressView("Inspecting recordings…") }
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).practiceCard()
                }
                if !model.loading && model.recordings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "applewatch").font(.largeTitle).foregroundStyle(PracticeTheme.accent(scheme))
                        Text("Record your first set on your Watch").font(.title2.bold())
                        Text("Wear your Watch on your racket arm. For the first test, record one intended shot per set, then stop and label it here. You do not need to touch a screen during the swing.")
                        Text("Keep both apps available for transfer. Your Watch keeps its original recording.")
                            .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
                    }
                    .practiceCard()
                    .accessibilityIdentifier("recordingsEmptyState")
                }
                ForEach(model.recordings) { recording in
                    NavigationLink {
                        RecordingDetailView(recordingID: recording.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(recordingDate(recording)).font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right").accessibilityHidden(true)
                            }
                            Text("\(recording.status) · \(recording.streams.reduce(0) { $0 + $1.count }) retained samples")
                                .font(.subheadline)
                            Text("\(recording.latestLabels.count) owner attempts · \(recording.receiptVerified ? "Verified receipt" : "Receipt not verified")")
                                .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
                        }
                        .practiceCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recording-\(recording.id.uuidString)")
                }
            }
            .padding(24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(PracticeTheme.canvas(scheme))
        .accessibilityIdentifier("recordingsScreen")
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                .disabled(model.loading || model.busy)
                .accessibilityIdentifier("refreshRecordings")
        }
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
    }

    private func recordingDate(_ recording: RecordingReview) -> String {
        guard let seconds = recording.report.metadata?.clock.wallAnchorUnixSeconds else { return "Recording needs attention" }
        return Date(timeIntervalSince1970: seconds).formatted(date: .abbreviated, time: .shortened)
    }
}
