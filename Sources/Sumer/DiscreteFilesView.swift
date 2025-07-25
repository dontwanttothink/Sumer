import SwiftUI

struct DiscreteFilesView: View {
    var paths: [URL]

    var body: some View {
        Text("Discrete files view !!")
        if !paths.isEmpty {
            Text("You are editing " + paths.map({ $0.lastPathComponent }).joined(separator: ", "))
        }
    }
}
