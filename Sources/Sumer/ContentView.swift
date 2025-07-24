import SwiftUI

struct ContentView: View {
    var path: String?
    @State private var selectedItem: String?

    var body: some View {
        if let path = path {
            NavigationSplitView {
                List(selection: $selectedItem) {
                    OutlineGroup(data, children: \.children) { item in
                        Text("\(item.description)")
                    }
                }
                .navigationTitle("Sidebar")
            } detail: {
                if let item = selectedItem {
                    Text("Selected: \(item)")
                } else {
                    Text("No selection")
                }
                Text("You are editing " + path + "!")
            }
        } else {
        }
    }
}
