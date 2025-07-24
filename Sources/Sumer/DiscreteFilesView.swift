import SwiftUI

struct DiscreteFilesView: View {
    var path: URL?

    init() {
        self.init(nil)
    }
    init(_ path: URL?) {
        self.path = path
    }

    var body: some View {
        Text("Discrete files view !!")
        if let path = path {
            Text("You are editing " + path.absoluteString + "!")
        }
    }
}
