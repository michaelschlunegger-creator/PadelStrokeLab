import SwiftUI
import PadelCore
import PadelDesign

struct RecordingDetailView: View {
    let recordingID: UUID
    @Environment(RecordingLibraryModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var labelEditor: LabelEditorSelection?
    @State private var showDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let review = model.selected, review.id == recordingID {
                    summary(review)
                    coverage(review)
                    labels(review)
                    metadata(review)
                    exportAndDelete(review)
                } else if model.loading {
                    ProgressView("Checking retained data…")
                }
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle").practiceCard()
                }
            }
            .padding(24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(PracticeTheme.canvas(scheme))
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("recordingDetailScreen")
        .task(id: recordingID) { await model.open(recordingID) }
        .onDisappear { model.closeDetail() }
        .sheet(item: $labelEditor) { selection in
            if let review = model.selected {
                RecordingLabelEditor(review: review, existing: selection.label)
            }
        }
        .confirmationDialog("Delete this iPhone copy?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete iPhone copy", role: .destructive) {
                Task { if await model.confirmDeletion(recordingID) { dismiss() } }
            }
            Button("Cancel", role: .cancel) { model.cancelDeletion() }
        } message: {
            Text("This removes this iPhone's raw recording and owner labels. The Watch original stays on your Watch. Exported or shared copies remain outside this deletion.")
        }
    }

    private func summary(_ review: RecordingReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PracticeEyebrow("Retained recording")
            Text(review.status).font(.largeTitle.bold())
            Text(review.receiptVerified ? "Verified receipt on this iPhone" : "No verified receipt is recorded on this iPhone")
            if let first = review.first, let last = review.last {
                Text("\(number(last - first)) s from first to last retained sample")
            }
            Text("\(ByteCountFormatter.string(fromByteCount: Int64(review.bytes), countStyle: .file)) stored locally")
            Text("Stop-tail coverage is unverified. A saved file does not prove that every last sensor sample was delivered.")
                .font(.footnote)
            if let warning = review.annotationWarning { Text(warning).font(.footnote.bold()) }
            ForEach(Array(review.report.issues.enumerated()), id: \.offset) { _, issue in
                Text("\(issue.kind.rawValue.capitalized): \(issue.fileName)").font(.footnote)
            }
            if let timeline = review.timeline {
                ForEach(timeline.events.filter { [.interruption, .bufferOverflow, .writeFailure, .limitReached].contains($0.kind) }, id: \.id) { event in
                    Text("\(event.kind.rawValue): \(event.detail ?? "No further detail")").font(.footnote.bold())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PracticeTheme.hero, in: .rect(cornerRadius: 28))
    }

    private func coverage(_ review: RecordingReview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Signals & coverage").font(.title2.bold())
            if review.segments.isEmpty {
                Text("Active segments are unknown. Rates and maximum intervals are withheld because pauses cannot be separated safely.")
            } else {
                let active = review.segments.reduce(0) { $0 + max(0, $1.end - $1.start) }
                Text("\(review.segments.count) active segment(s) · \(number(active)) s on the capture timeline")
                Text("Rates use retained timestamps within each segment. Pauses are excluded. A maximum interval is an observation, not a dropout diagnosis.")
                    .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
            }
            ForEach(review.streams) { stream in
                Divider()
                Text(stream.stream == .accelerometer ? "Accelerometer" : "Device motion").font(.headline)
                Text("\(stream.count) retained samples")
                if let first = stream.first, let last = stream.last, let clock = review.report.metadata?.clock {
                    Text("Bounds: \(number(first - clock.monotonicAnchorSeconds))–\(number(last - clock.monotonicAnchorSeconds)) s from recording anchor")
                        .font(.footnote)
                }
                ForEach(stream.segments) { segment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Segment \(segment.id + 1): \(segment.count) samples")
                        Text("Observed rate: \(segment.rate.map { number($0) + " Hz" } ?? "insufficient samples")")
                        Text("Maximum interval: \(segment.maximumInterval.map { number($0 * 1_000) + " ms" } ?? "unknown")")
                    }.font(.footnote)
                }
            }
        }.practiceCard()
    }

    private func labels(_ review: RecordingReview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your attempts").font(.title2.bold())
            let matched = review.latestLabels.filter { $0.startTimestamp != nil }.count
            Text("\(review.latestLabels.count) entered · \(matched) time matched · \(review.latestLabels.count - matched) unmatched")
            Text("Total attempted shots is not detected. Add each attempt you remember after the set. Your assessment is not independent ground truth.")
                .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
            ForEach(review.latestLabels, id: \.attemptID) { label in
                Button {
                    labelEditor = .init(label: label)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Attempt \(label.ordinal) · \(label.category.title)").font(.headline)
                        Text(label.startTimestamp == nil ? "Unmatched / uncertain for analysis" : "Owner-supplied time interval")
                            .font(.subheadline)
                        Text("Owner self assessment · revision \(label.revision)").font(.caption)
                        if let note = label.note { Text(note).font(.footnote) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Edit this attempt. Earlier revisions are retained.")
                Divider()
            }
            Button("Add attempt", systemImage: "plus") { labelEditor = .init(label: nil) }
                .buttonStyle(PracticeActionStyle())
                .disabled(model.busy || review.annotationWarning != nil || review.report.metadata == nil)
                .accessibilityIdentifier("addAttempt")
            Text("\(review.labels.count) revisions retained. No shot times are inferred from attempt numbers.")
                .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
        }.practiceCard()
    }

    @ViewBuilder private func metadata(_ review: RecordingReview) -> some View {
        if let metadata = review.report.metadata {
            VStack(alignment: .leading, spacing: 12) {
                Text("Capture details").font(.title2.bold())
                Text("\(metadata.deviceModel) · \(metadata.operatingSystem)")
                Text("Build \(metadata.appBuild) · protocol \(metadata.protocolVersion)")
                Text("Playing arm: \(metadata.playingArm.rawValue). Watch wrist: \(metadata.watchWrist.rawValue). Orientation: \(metadata.watchOrientation).")
                Text("Handedness: \(metadata.handedness.rawValue)")
                VStack(alignment: .leading, spacing: 5) {
                    Text("Intended shot type").font(.headline)
                    Text(RecordingDrill.recordedTitle(for: metadata.drill))
                        .accessibilityIdentifier("recordedIntendedShotType")
                    Text("Stored value: \(metadata.drill)").font(.caption.monospaced())
                        .textSelection(.enabled).accessibilityIdentifier("recordedDrillRawValue")
                    Text("Protocol: \(metadata.protocolVersion)").font(.caption.monospaced())
                        .textSelection(.enabled).accessibilityIdentifier("recordedProtocolVersion")
                    Text("Manual intent is separate from contact labels and automatic shot recognition.").font(.footnote)
                }
                .fixedSize(horizontal: false, vertical: true)
                Text(metadata.capabilityReport)
                ForEach(metadata.streams, id: \.stream.rawValue) { stream in
                    Text("\(stream.stream == .accelerometer ? "Accelerometer" : "Device motion"): declared supported \(stream.supported ? "yes" : "no"); reported sensor limit \(stream.knownSensorLimit.map { number($0) + " Hz" } ?? "unknown"); requested rate \(stream.requestedRateHz.map { number($0) + " Hz" } ?? "not configurable / unspecified").")
                        .font(.footnote)
                }
                Text("Recording ID: \(review.id.uuidString)").font(.caption.monospaced()).textSelection(.enabled)
            }.practiceCard()
        }
    }

    private func exportAndDelete(_ review: RecordingReview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your data").font(.title2.bold())
            Text("Export includes original samples, capture details, timing and every label revision. Choose who receives it in the share sheet.")
                .font(.subheadline)
            Button("Prepare export", systemImage: "square.and.arrow.up") {
                Task { await model.prepareExport(recordingID) }
            }
            .buttonStyle(.glass)
            .disabled(model.busy || review.timeline == nil || review.annotationWarning != nil)
            .accessibilityIdentifier("prepareRecordingExport")
            if model.busy { ProgressView("Working with your recording…") }
            if let url = model.exportURL {
                ShareLink(item: url) { Label("Share recording bundle", systemImage: "square.and.arrow.up") }
                    .buttonStyle(PracticeActionStyle())
                    .accessibilityIdentifier("shareRecordingExport")
            }
            Text("Nothing is automatically uploaded to a public or shared folder.")
                .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
            Divider()
            Button("Delete iPhone copy", role: .destructive) {
                model.requestDeletion(recordingID); showDelete = true
            }
            .disabled(model.busy)
            .accessibilityIdentifier("deletePhoneRecording")
        }.practiceCard()
    }

    private func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...3))) }
}

private struct LabelEditorSelection: Identifiable {
    let id = UUID()
    let label: RecordingAttemptLabel?
}

private struct RecordingLabelEditor: View {
    let review: RecordingReview
    let existing: RecordingAttemptLabel?
    @Environment(RecordingLibraryModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var draft = RecordingLabelDraft()

    var body: some View {
        NavigationStack {
            Form {
                Section("Owner self assessment") {
                    Picker("Contact", selection: $draft.category) {
                        ForEach(ContactCategory.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Confidence", selection: $draft.confidence) {
                        ForEach([RecordingLabelConfidence.unspecified, .low, .medium, .high], id: \.rawValue) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Picker("Evidence", selection: $draft.evidence) {
                        Text("Owner recall").tag(RecordingLabelEvidence.ownerRecall)
                        Text("Ordered notes").tag(RecordingLabelEvidence.orderedNotes)
                        Text("Video").tag(RecordingLabelEvidence.video)
                        Text("Observer record").tag(RecordingLabelEvidence.observer)
                    }
                    TextField("Optional note (up to 1,024 UTF-8 bytes)", text: $draft.note, axis: .vertical)
                    Text("You remain the label author, including when consulting video or an observer's record.").font(.footnote)
                }
                Section("Optional time match") {
                    Text("Enter seconds from the original recording anchor only when you can establish the match. Leave both fields empty otherwise.").font(.footnote)
                    TextField("Start seconds", text: $draft.relativeStart).keyboardType(.decimalPad)
                    TextField("End seconds", text: $draft.relativeEnd).keyboardType(.decimalPad)
                    if let clock = review.report.metadata?.clock {
                        ForEach(review.segments) { segment in
                            Text("Segment \(segment.id + 1): \(seconds(segment.start - clock.monotonicAnchorSeconds))–\(seconds(segment.end - clock.monotonicAnchorSeconds)) s")
                                .font(.footnote)
                        }
                        if let first = review.first, let last = review.last {
                            Text("Retained sample bounds: \(seconds(first - clock.monotonicAnchorSeconds))–\(seconds(last - clock.monotonicAnchorSeconds)) s. The match must fit these bounds and one segment.")
                                .font(.footnote)
                        }
                    }
                    Text("An unmatched attempt keeps your contact category, but remains unmatched / uncertain for analysis. Attempt order does not establish timing.")
                        .font(.footnote)
                }
                if let error = model.error { Section { Text(error).foregroundStyle(.red) } }
            }
            .scrollContentBackground(.hidden)
            .background(PracticeTheme.canvas(scheme))
            .navigationTitle(existing == nil ? "Add attempt" : "Edit attempt \(existing!.ordinal)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(model.busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { if await model.save(draft, recordingID: review.id) { dismiss() } }
                    }.disabled(model.busy || draft.note.utf8.count > 1_024)
                }
            }
            .interactiveDismissDisabled(model.busy)
            .onAppear {
                model.error = nil
                if let existing {
                    draft.attemptID = existing.attemptID
                    draft.category = existing.category
                    draft.confidence = existing.confidence
                    draft.evidence = existing.evidence
                    draft.note = existing.note ?? ""
                    if let anchor = review.report.metadata?.clock.monotonicAnchorSeconds {
                        draft.relativeStart = existing.startTimestamp.map { String($0 - anchor) } ?? ""
                        draft.relativeEnd = existing.endTimestamp.map { String($0 - anchor) } ?? ""
                    }
                }
            }
        }.tint(PracticeTheme.accent(scheme))
    }
    private func seconds(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...3))) }
}
