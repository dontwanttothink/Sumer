import SwiftUI

struct ProjectOutlineGroup: View {
    let path: URL
    private let fileItem: FileItem
    @Binding var selection: Set<URL>

    init(withRoot path: URL, selection: Binding<Set<URL>>) {
        self.path = path
        self.fileItem = FileItem(root: path)
        self._selection = selection
    }

    static func getSystemImage(for fileItem: FileItem) -> String {
        return switch fileItem.children {
        case .Supported:
            "folder"
        case .NotSupported:
            "text.page"
        case .Failed:
            "exclamationmark.triangle.text.page"
        }
    }

    var body: some View {
        switch fileItem.children {
        case .Supported(let items):
            List(selection: $selection) {
                OutlineGroup(items, children: \.simplifiedChildren) { item in
                    Label(item.name, systemImage: Self.getSystemImage(for: item))
                }
            }
        default:
            ZStack {
                Color.clear  // force full-size layout
                Text("Failed to load elements")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

//Text("Double-click me")
//    .onTapGesture(count: 2) {
//        print("Double-click detected")
//    }
