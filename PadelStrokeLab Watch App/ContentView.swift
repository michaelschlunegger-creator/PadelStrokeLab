import SwiftUI
import PadelCore
import PadelDesign

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("practice.playingArm") private var storedArm = PlayingArm.right.rawValue
    @AppStorage("practice.handedness") private var storedHand = PlayingArm.right.rawValue
    @AppStorage("recording.recoveryNotice") private var recoveryNotice = ""
    @State private var recorder = WatchRecorderModel()
    @State private var deletionCandidate: WatchRetainedRecording?
    private var arm: PlayingArm { PlayingArm(rawValue: storedArm) ?? .right }

    var body: some View {
        NavigationStack {
            List {
                VStack(alignment: .leading, spacing: 7) {
                    Label("FIRST DRILL", systemImage: "figure.racquetball")
                        .font(.caption2.weight(.bold)).foregroundStyle(PracticeTheme.yellow)
                    Text(PracticeDrill.forehandGroundstroke.title).font(.headline).foregroundStyle(.white)
                    Text("120 active seconds maximum").font(.caption2).foregroundStyle(.white)
                }
                .fixedSize(horizontal: false, vertical: true).padding(.vertical, 6)
                .listRowBackground(PracticeTheme.royal.clipShape(.rect(cornerRadius: 20)))

                if recorder.canPrepare {
                    Section("Before you play") {
                        Picker("Playing arm", selection: $storedArm) {
                            ForEach(PlayingArm.allCases) { Text($0.title).tag($0.rawValue) }
                        }
                        .pickerStyle(.navigationLink)
                        .accessibilityIdentifier("watchArmPicker")
                        .accessibilityValue(arm.title)
                        .accessibilityHint("Choose the arm holding your racket.")
                        Picker("Handedness", selection: $storedHand) {
                            ForEach(PlayingArm.allCases) { Text($0.title).tag($0.rawValue) }
                        }.pickerStyle(.navigationLink)
                        Text("Watch setting: \(recorder.configuredWrist.title) wrist · \(recorder.crownDescription)")
                            .font(.footnote)
                        Toggle("Watch on this arm", isOn: $recorder.armConfirmed)
                            .tint(PracticeTheme.yellow).accessibilityIdentifier("watchArmConfirmation")
                        Label(recorder.armConfirmed ? "Arm confirmed" : "Check your Watch placement",
                              systemImage: recorder.armConfirmed ? "checkmark.circle.fill" : "applewatch")
                            .font(.footnote).accessibilityIdentifier("watchSetupStatus")
                        if arm != recorder.configuredWrist {
                            Text("Match the Watch wrist setting to your playing arm before recording.")
                                .font(.footnote).foregroundStyle(PracticeTheme.yellow)
                        }
                    }
                    .listRowBackground(PracticeTheme.watchSurface.clipShape(.rect(cornerRadius: 20)))
                }

                Section("Capture") {
                    if !recoveryNotice.isEmpty {
                        Text(recoveryNotice).font(.footnote)
                        Button("Dismiss recovery notice") { recoveryNotice = "" }
                    }
                    Text(recorder.state.rawValue.capitalized)
                        .font(.title3.bold()).foregroundStyle(PracticeTheme.yellow)
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
                .listRowBackground(PracticeTheme.watchSurface.clipShape(.rect(cornerRadius: 20)))

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
                .listRowBackground(PracticeTheme.watchSurface.clipShape(.rect(cornerRadius: 20)))
            }
            .listStyle(.carousel).scrollContentBackground(.hidden)
            .background(PracticeTheme.navy.ignoresSafeArea())
            .navigationTitle("Practice").containerBackground(PracticeTheme.navy, for: .navigation)
            .onChange(of: storedArm) { _, _ in recorder.armConfirmed = false }
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
        .tint(PracticeTheme.royal)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { recorder.refreshPreparation() }
        }
    }

    @ViewBuilder private var controls: some View {
        if recorder.state == .ready {
            Button("Start recording", systemImage: "record.circle") {
                recorder.start(arm: arm, handedness: PlayingArm(rawValue: storedHand) ?? .right)
            }
            .disabled(!recorder.canStart(arm: arm)).accessibilityIdentifier("watchStartRecording")
        }
        if recorder.state == .recording {
            Button("Pause", systemImage: "pause.fill") { recorder.pause() }.accessibilityIdentifier("watchPauseRecording")
        }
        if recorder.state == .paused {
            Button("Resume", systemImage: "play.fill") { recorder.resume() }.accessibilityIdentifier("watchResumeRecording")
        }
        if [.starting, .recording, .paused, .resuming].contains(recorder.state) {
            Button("Stop and save", systemImage: "stop.fill", role: .destructive) { recorder.stop() }
                .accessibilityIdentifier("watchStopRecording")
        }
        if recorder.state.isTerminal {
            Button("Prepare new set") { recorder.newSet() }.accessibilityIdentifier("watchNewSet")
        }
    }
}

#Preview { ContentView() }
