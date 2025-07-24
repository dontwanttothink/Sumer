// The Swift Programming Language
// https://docs.swift.org/swift-book

import Plow
import SwiftUI

@main
struct SumerApp: App {
    init() {
        NSWindow.allowsAutomaticWindowTabbing = false

        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(path: "hi")
        }
        .commands {
            SidebarCommands()
            TextEditingCommands()
            CommandGroup(after: .newItem) {
                Button("Open…", systemImage: "play") {}.keyboardShortcut("O")
            }
        }

        Settings {
            SettingsView()
        }
    }
}
