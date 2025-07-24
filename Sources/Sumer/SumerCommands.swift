import SwiftUI

struct SumerCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        SidebarCommands()
        TextEditingCommands()
        CommandGroup(replacing: .newItem) {
            Button("New", systemImage: "plus") {
                openWindow(id: "editor")
            }
            .keyboardShortcut("N")
            Button("Open…", systemImage: "arrow.up.right") {
                guard let window = NSApplication.shared.mainWindow else { return }

                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = true
                panel.allowsMultipleSelection = true

                panel.beginSheetModal(for: window) { response in
                    if response == .OK {
                        Task {
                            @MainActor in
                            let selectedURLs = panel.urls
                            SumerApp.open(filesOrDocuments: selectedURLs, openWindow)
                        }
                    }
                }
            }.keyboardShortcut("O")
            Menu {
                Button("Clear Menu") {}.disabled(true)
            } label: {
                Label("Open Recent", systemImage: "clock")
            }
        }
        CommandGroup(after: .saveItem) {
            Button("Save", systemImage: "square.and.arrow.down") {
                // save
            }.keyboardShortcut("S")
            Button("Duplicate", systemImage: "plus.square.on.square") {
                // duplicate
            }.keyboardShortcut("S", modifiers: [.command, .shift])
            Button("Rename…", systemImage: "pencil") {}
            Button("Move To…", systemImage: "folder") {}
        }
    }
}
