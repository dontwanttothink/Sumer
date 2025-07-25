import SwiftUI

struct ProjectView: View {
    private let path: URL
    @State private var selection: Set<URL>?

    init(_ path: URL) {
        // assert that the path is a directory
        self.path = path
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ProjectOutlineView()
            }
            .navigationTitle("Sidebar")
        } detail: {
            if selection != nil {
                Text("Selected something")
            } else {
                Text("No selection")
            }
            Text("You are editing " + path.absoluteString + "!")
        }
    }
}
