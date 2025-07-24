// The Swift Programming Language
// https://docs.swift.org/swift-book

import Plow
import SwiftUI

@main
struct SumerApp: App {
    init() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: SumerDocument()) { file in
            ContentView(path: file.fileURL?.path)
        }
        // WindowGroup {
        //     ContentView(path: "hi")
        // }
    }
}
