import SwiftUI

struct ProjectView: View {
    @State private var path: URL
    @State private var selection: Set<URL>?

    init(_ path: URL) {
        // assert that the path is a directory
        self.path = path
    }

    var body: some View {
        let rootItem = FileItem(path: path)

        NavigationSplitView {
            List(selection: $selection) {
                OutlineGroup(rootItem, children: \.children) { item in
                    Label(
                        "\(item.description)",
                        systemImage: item.children == nil ? "text.page" : "folder")
                }
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
