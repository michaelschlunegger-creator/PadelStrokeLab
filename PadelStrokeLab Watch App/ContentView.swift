//
//  ContentView.swift
//  PadelStrokeLab Watch App
//
//  Created by Michael Schlunegger on 24/08/2026.
//

import SwiftUI
import PadelCore

struct ContentView: View {
    @AppStorage("practice.playingArm") private var storedArm = PlayingArm.right.rawValue
    @State private var armConfirmed = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Playing arm") {
                    Picker("Arm", selection: $storedArm) {
                        ForEach(PlayingArm.allCases) { arm in
                            Text(arm.title).tag(arm.rawValue)
                        }
                    }
                    Toggle("Watch is on this arm", isOn: $armConfirmed)
                        .accessibilityHint("Confirm the Watch is on the arm you use to hold your racket.")
                }

                Section("First drill") {
                    Text(PracticeDrill.forehandGroundstroke.title)
                }

                Section {
                    Text(armConfirmed ? "Arm confirmed" : "Check your Watch placement")
                    Text("Preparation only. Recording is not available in this build.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Practice setup")
            .onChange(of: storedArm) { _, _ in armConfirmed = false }
        }
    }
}

#Preview {
    ContentView()
}
