import SwiftUI
import PadelCore
import PadelDesign

struct WatchPreparationView: View {
    let recorder: WatchRecorderModel
    var body: some View {
        List {
            Section {
                Text("Quick Watch check").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("watchSetupProgress")
                Text(recorder.displayedDrillTitle).font(.headline)
                Text("Phone preparation accepted. Wear the Watch on your \(recorder.preparation.arm == .left ? "left" : "right") racket arm.")
                    .font(.footnote).accessibilityIdentifier("watchAcceptedSetup")
            }.listRowBackground(PracticeTheme.elevatedSurface.clipShape(.rect(cornerRadius: 20)))
            Section {
                Button(recorder.preparation.placementConfirmed ? "Racket arm checked" : "Watch is on my racket arm") {
                    recorder.confirmPlacement()
                }.accessibilityIdentifier("watchConfirmPlacement")
                Text("Watch setting: \(recorder.configuredWrist?.rawValue ?? "unavailable") wrist · \(recorder.crownDescription)")
                    .font(.footnote).accessibilityIdentifier("watchOrientationSummary")
                Button(recorder.preparation.orientationConfirmed ? "Orientation checked" : "Confirm wrist and crown") {
                    recorder.confirmOrientation()
                }.disabled(!recorder.preparation.placementConfirmed)
                    .accessibilityIdentifier("watchConfirmOrientation")
                Text("If the setting differs from your racket arm, change Watch Orientation in Settings, then return.")
                    .font(.footnote)
                Button(recorder.preparation.fitConfirmed ? "Fit checked" : "Snug, comfortable fit") { recorder.confirmFit() }
                    .disabled(!recorder.preparation.orientationConfirmed)
                    .accessibilityIdentifier("watchConfirmFit")
                if let issue = recorder.capabilityIssue {
                    Text(issue).font(.footnote).accessibilityIdentifier("watchCapabilityIssue")
                }
                Button("Start set", systemImage: "record.circle") { recorder.start() }
                    .disabled(!recorder.canStart).accessibilityIdentifier("watchStart")
                    .foregroundStyle(PracticeTheme.onAccent)
                    .listRowBackground(PracticeTheme.accentColor.clipShape(.rect(cornerRadius: 20)))
                Text("120 active seconds maximum. Start is always your choice on this Watch.").font(.footnote)
            }.listRowBackground(PracticeTheme.surface(.dark).clipShape(.rect(cornerRadius: 20)))
            Button("Cancel check") { recorder.cancelPreparation() }.accessibilityIdentifier("watchSetupCancel")
        }
        .listStyle(.carousel).scrollContentBackground(.hidden)
        .background(PracticeTheme.canvas(.dark).ignoresSafeArea())
        .navigationTitle("Watch check").navigationBarBackButtonHidden()
    }
}
