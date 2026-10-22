import SwiftUI
import PadelCore
import PadelDesign

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorder = WatchRecorderModel()
    @State private var deletionCandidate: WatchRetainedRecording?

    var body: some View {
        NavigationStack {
            if recorder.state == .ready, recorder.preparation.step != nil {
                WatchPreparationView(recorder: recorder)
            } else {
            List {
                if let practice = recorder.practice {
                    Section("Practice") {
                        if practice.canBeginPractice {
                            Button("Begin practice") {
                                if recorder.state.isTerminal { recorder.newSet() }
                                practice.begin()
                            }.accessibilityIdentifier("watchBeginPractice")
                        }
                        Text(practice.heartRateMessage).font(.footnote)
                        if let issue = practice.issue { Text(issue).font(.footnote) }
                        if practice.state == .baseline || practice.state == .recovery {
                            Button("Pause practice") { practice.pause() }
                        } else if practice.state == .paused {
                            Button("Resume practice") { practice.resume() }
                        }
                        if [.baseline, .activeSet, .setClosing, .recovery, .paused].contains(practice.state) {
                            Button("End practice", role: .destructive) { practice.end() }
                                .accessibilityIdentifier("watchEndPractice")
                        }
                        Text("Up to 20 sets in 30 minutes. Recovery observations use available heart-rate samples.")
                            .font(.caption2)
                    }
                }
                if recorder.state == .ready {
                    Button { recorder.beginPreparation() } label: {
                        Label("Check Watch", systemImage: "play.fill")
                            .font(.title3.bold()).padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundStyle(PracticeTheme.onAccent)
                    .listRowBackground(PracticeTheme.accentColor.clipShape(.rect(cornerRadius: 20)))
                    .accessibilityIdentifier("watchLetsPlay")
                        .disabled(!recorder.canPrepare)
                    Text(recorder.ownerStatus).font(.footnote).accessibilityIdentifier("watchOwnerStatus")
                        .listRowBackground(Color.clear)
                    if let issue = recorder.ownerIssue { Text(issue).font(.footnote) }
                    if recorder.isSyntheticFixture {
                        Text("Synthetic fixture · sensors disabled").font(.caption2)
                            .accessibilityIdentifier("watchFixtureBanner")
                    }
                }
                VStack(alignment: .leading, spacing: 7) {
                    Label("TRAINING SET", systemImage: "figure.racquetball")
                        .font(.caption2.weight(.bold)).foregroundStyle(PracticeTheme.accentColor)
                    Text("Intended shot type").font(.caption2).foregroundStyle(.white)
                    Text(recorder.displayedDrillTitle).font(.headline).foregroundStyle(.white)
                        .accessibilityIdentifier("watchIntendedShotType")
                    Text("120 active seconds maximum").font(.caption2).foregroundStyle(.white)
                }
                .fixedSize(horizontal: false, vertical: true).padding(.vertical, 6)
                .listRowBackground(PracticeTheme.elevatedSurface.clipShape(.rect(cornerRadius: 20)))

                Section("Capture") {
                    if !recorder.recoveryNotice.isEmpty {
                        Text(recorder.recoveryNotice).font(.footnote)
                        Button("Dismiss recovery notice") { recorder.recoveryNotice = "" }
                    }
                    Text(recorder.state.rawValue.capitalized)
                        .font(.title3.bold()).foregroundStyle(PracticeTheme.accentColor)
                        .accessibilityIdentifier("watchCaptureState")
                    if let issue = recorder.capabilityIssue {
                        Text(issue).font(.footnote).accessibilityIdentifier("watchCapabilityIssue")
                    }
                    if let snapshot = recorder.snapshot {
                        Text("\(snapshot.activeSeconds, specifier: "%.1f") / 120 active seconds")
                            .monospacedDigit().accessibilityIdentifier("watchActiveTime")
                        Text("Accepted acceleration \(snapshot.accelerometerCount)\nAccepted motion \(snapshot.deviceMotionCount)\n\(snapshot.chunks) durable chunks")
                            .font(.footnote).monospacedDigit().accessibilityIdentifier("watchSampleCounts")
                        Text("Outside capture windows: \(snapshot.excludedBeforeWindow) before, \(snapshot.excludedAfterCutoff) after").font(.caption2)
                        Text("Last source times: \(snapshot.lastAccelerometerTimestamp.map { String(format: "%.2f", $0) } ?? "waiting") / \(snapshot.lastDeviceMotionTimestamp.map { String(format: "%.2f", $0) } ?? "waiting")")
                            .font(.caption2)
                    }
                    if let message = recorder.message { Text(message).font(.footnote).accessibilityIdentifier("watchCaptureMessage") }
                    controls
                    if recorder.state == .saved {
                        Text("Saved and verified on this Watch. Originals retained. Phone verification is separate.")
                            .font(.footnote)
                    }
                    if let snapshot = recorder.snapshot, let transfer = recorder.transfers[snapshot.recordingID] {
                        Text("Phone: \(transfer)").font(.footnote)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .listRowBackground(PracticeTheme.surface(.dark).clipShape(.rect(cornerRadius: 20)))

                Section("Know before starting") {
                    Text("Recording uses a workout for background motion. No workout summary is saved by this app; system activity metrics may still change. End other workouts first.")
                    Text(recorder.frequencyDescription)
                    Text("Live counts show accepted samples; durable chunks are written separately. Counts do not measure hit quality. The final sensor-buffer tail is unknown. Frequent pauses may reach the chunk limit before 120 seconds.")
                }
                .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(.dark))
                .listRowBackground(Color.clear)

                Section("On this Watch") {
                    if let status = recorder.deletionStatus { Text(status).font(.footnote).accessibilityIdentifier("watchDeletionStatus") }
                    if recorder.retained.isEmpty { Text(recorder.refreshing ? "Inspecting recordings…" : "No retained recordings").font(.footnote) }
                    ForEach(recorder.retained) { recording in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(recording.status).font(.headline)
                            if let drill = recording.intendedDrill {
                                Text("Intended shot type: \(RecordingDrill.recordedTitle(for: drill))").font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(recording.id.uuidString.prefix(8)).font(.caption2).monospaced()
                            Text("\(recording.samples) retained samples").font(.footnote)
                            if let transfer = recorder.transfers[recording.id] { Text(transfer).font(.footnote) }
                            Button("Send to iPhone") { recorder.retryTransfer(recording) }
                                .disabled(!recording.canTransfer || recorder.deletingRecordingID != nil)
                            Button("Delete Watch copy", role: .destructive) { deletionCandidate = recording }
                                .disabled(!recorder.canDelete(recording))
                                .accessibilityIdentifier("watchDeleteCopy-\(recording.id.uuidString)")
                        }
                    }
                    Button("Refresh retained recordings") { recorder.refreshRetained() }.disabled(recorder.refreshing || !recorder.canPrepare)
                    Text("Watch originals stay here after transfer. Interrupted recordings require review on iPhone.").font(.caption2)
                }
                .listRowBackground(PracticeTheme.surface(.dark).clipShape(.rect(cornerRadius: 20)))
            }
            .listStyle(.carousel).scrollContentBackground(.hidden)
            .background(PracticeTheme.canvas(.dark).ignoresSafeArea())
            .navigationTitle("Practice").containerBackground(PracticeTheme.canvas(.dark), for: .navigation)
            .confirmationDialog("Delete this Watch copy?", isPresented: Binding(
                get: { deletionCandidate != nil }, set: { if !$0 { deletionCandidate = nil } }), titleVisibility: .visible) {
                if let recording = deletionCandidate {
                    Button("Delete Watch copy", role: .destructive) {
                        recorder.deleteWatchCopy(recording); deletionCandidate = nil
                    }.accessibilityIdentifier("watchConfirmDeleteCopy")
                }
                Button("Cancel", role: .cancel) { deletionCandidate = nil }
            } message: {
                Text("Deletes only this Watch's recording, notes and queued transfer copy. Any copy already on iPhone and independent exports remain.")
            }
            }
        }
        .tint(PracticeTheme.navigationFill)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { recorder.refreshPreparation() }
            else { recorder.preparationLeftForeground() }
        }
    }

    @ViewBuilder private var controls: some View {
        if recorder.state == .recording {
            Button("Pause", systemImage: "pause.fill") { recorder.pause() }.accessibilityIdentifier("watchPauseRecording")
        }
        if recorder.state == .paused {
            Button("Resume", systemImage: "play.fill") { recorder.resume() }.accessibilityIdentifier("watchResumeRecording")
        }
        if [.starting, .recording, .pausing, .paused, .resuming].contains(recorder.state) {
            Button("Stop and save", systemImage: "stop.fill", role: .destructive) { recorder.stop() }
                .accessibilityIdentifier("watchStopRecording")
        }
        if recorder.state.isTerminal {
            Button("Prepare new set") { recorder.newSet() }.accessibilityIdentifier("watchNewSet")
                .disabled(!recorder.canBeginNextSet)
        }
    }
}

#Preview { ContentView() }
