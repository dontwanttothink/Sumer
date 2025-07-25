import SwiftUI

struct ContentView: View {
    @State private var path: URL?

    init(path: URL?) {
        self.path = path
    }

    var body: some View {
        if let path {
            let isDirectory = try? path.isDirectory
            if isDirectory != nil && isDirectory == true {
                ProjectView(path)
            } else {
                DiscreteFilesView(paths: [path])
            }
        } else {
            DiscreteFilesView(paths: [])
        }
    }
}
