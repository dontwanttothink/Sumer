import SwiftUI

struct ContentView: View {
    var path: URL?
    var body: some View {
        if let path {
            let isDirectory = try? path.isDirectory
            if isDirectory != nil && isDirectory == true {
                ProjectView(path)
            } else {
                DiscreteFilesView(path)
            }
        } else {
            DiscreteFilesView()
        }
    }
}
