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
        WindowGroup(id: "editor", for: URL.self) { $url in
            let contentView = ContentView(path: $url)
            if let url {
                contentView.navigationTitle(url.lastPathComponent)
            } else {
                contentView
            }
        }
        .commands {
            SumerCommands()
        }

        Settings {
            SettingsView()
        }
    }

    static func open(filesOrDocuments: [URL], _ openWindow: OpenWindowAction) {
        // update with logic to identify file system hierarchy
        // replace empty windows

        for fileOrDocument in filesOrDocuments {
            openWindow(value: fileOrDocument)
        }
    }
}
