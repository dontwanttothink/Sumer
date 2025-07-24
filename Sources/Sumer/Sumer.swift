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
                Button("Open…", systemImage: "arrow.up.right") {
                    // open
                }.keyboardShortcut("O")
                Menu {
                    Button("Clear Menu") {}.disabled(true)
                } label: {
                    Label("Open Recent", systemImage: "clock")
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
