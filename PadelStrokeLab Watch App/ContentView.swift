import SwiftUI
import PadelCore
import PadelDesign

struct ContentView: View {
    @AppStorage("practice.playingArm") private var storedArm = PlayingArm.right.rawValue
    @State private var armConfirmed = false

    private var status: String {
        armConfirmed ? "Arm confirmed" : "Check your Watch placement"
    }

    var body: some View {
        NavigationStack {
            List {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Image(systemName: "figure.racquetball")
                        Text("FIRST DRILL")
                            .tracking(1.2)
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PracticeTheme.yellow)
                    Text(PracticeDrill.forehandGroundstroke.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
                .listRowBackground(PracticeTheme.royal.clipShape(.rect(cornerRadius: 20)))

                Section {
                    Picker("Playing arm", selection: $storedArm) {
                        ForEach(PlayingArm.allCases) { arm in
                            Text(arm.title).tag(arm.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("watchArmPicker")
                    .accessibilityValue(PlayingArm(rawValue: storedArm)?.title ?? "Choose an arm")
                    .accessibilityHint("Choose the arm you use to hold your racket.")

                    Toggle(isOn: $armConfirmed) {
                        Text("Watch on this arm")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tint(PracticeTheme.yellow)
                    .accessibilityIdentifier("watchArmConfirmation")
                    .accessibilityHint("Confirm the Watch is on the arm you use to hold your racket.")
                } header: {
                    Text("Before you play")
                        .foregroundStyle(PracticeTheme.yellow)
                }
                .listRowBackground(PracticeTheme.watchSurface.clipShape(.rect(cornerRadius: 20)))

                VStack(alignment: .leading, spacing: 10) {
                    Label(status, systemImage: armConfirmed ? "checkmark.circle.fill" : "applewatch")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(armConfirmed ? PracticeTheme.yellow : .white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Preparation only. Recording is not available yet.")
                        .font(.footnote)
                        .foregroundStyle(PracticeTheme.secondaryInk(.dark))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("watchSetupStatus")
                .padding(.vertical, 5)
                .listRowBackground(Color.clear)
            }
            .listStyle(.carousel)
            .scrollContentBackground(.hidden)
            .background(PracticeTheme.navy.ignoresSafeArea())
            .navigationTitle("Practice")
            .containerBackground(PracticeTheme.navy, for: .navigation)
            .onChange(of: storedArm) { _, _ in armConfirmed = false }
        }
        .tint(PracticeTheme.yellow)
    }
}

#Preview {
    ContentView()
}
