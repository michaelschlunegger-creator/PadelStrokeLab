//
//  ContentView.swift
//  PadelStrokeLab
//
//  Created by Michael Schlunegger on 24/08/2026.
//

import SwiftUI
import PadelCore

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Your personal practice lab", systemImage: "figure.racquetball")
                        .font(.headline)
                    Text("Start with familiar forehands and use your own judgement of contact.")
                }

                Section("First drill") {
                    Text(PracticeDrill.forehandGroundstroke.title)
                    Label("Watch on your playing arm", systemImage: "applewatch")
                }

                Section("Reference labels") {
                    ForEach(ContactCategory.allCases) { category in
                        Text(category.title)
                    }
                    Text("A clean contact and a ball landing in are different observations. Choose Uncertain whenever you cannot tell.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("This build") {
                    Label("Practice preparation", systemImage: "checklist")
                    Text("Motion recording is not available yet. No hits are recorded or scored in this build.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("PadelStrokeLab")
        }
    }
}

#Preview {
    ContentView()
}
