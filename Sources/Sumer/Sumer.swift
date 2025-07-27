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
		// if various files are given with the same direct ancestor, open those
		// files in a project with the sidebar collapsed

		// open (the rest) of the files separately (or, in the future, in a
		// project-less tabbed view)

		// open a project for each folder

		for fileOrDocument in filesOrDocuments {
			openWindow(value: fileOrDocument)
		}
	}
}
