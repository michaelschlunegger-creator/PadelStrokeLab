//
//  PadelStrokeLabApp.swift
//  PadelStrokeLab Watch App
//
//  Created by Michael Schlunegger on 24/08/2026.
//

import SwiftUI
import WatchKit

@main
struct PadelStrokeLab_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WatchApplicationDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
