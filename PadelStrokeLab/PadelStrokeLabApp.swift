//
//  PadelStrokeLabApp.swift
//  PadelStrokeLab
//
//  Created by Michael Schlunegger on 24/08/2026.
//

import SwiftUI

@main
struct PadelStrokeLabApp: App {
    @State private var recordings = RecordingLibraryModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(recordings)
                .preferredColorScheme(.dark)
                .task { await recordings.practiceSetup?.load() }
        }
    }
}
