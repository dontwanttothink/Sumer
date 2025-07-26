import SwiftUI

struct ContentView: View {
    @Binding var path: URL?

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
