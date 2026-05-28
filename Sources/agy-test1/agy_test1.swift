import SwiftUI
import AppKit

@main
struct FinderReplacementApp: App {
    init() {
        // Programmatically set activation policy so a raw command line executable
        // behaves as a normal foreground app and can receive keyboard focus.
        NSApplication.shared.setActivationPolicy(.regular)
        
        // Force the app to become active and come to the front
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    var body: some Scene {
        Window("Agy Finder", id: "main") {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}
