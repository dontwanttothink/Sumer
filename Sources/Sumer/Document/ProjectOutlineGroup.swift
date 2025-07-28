import SwiftUI

func getSystemImage(for fileItem: TrackedDirectory.FileItem) -> String {
	return switch fileItem {
	case .NonLeaf:
		"folder"
	case .Leaf:
		"text.page"
	}
}

struct ProjectItemView: View {
	var item: TrackedDirectory.FileItem
	var level: Int = 0

	var body: some View {
		let image = getSystemImage(for: item)

		switch item {
		case .Leaf(let leafItem):
			Label(leafItem.path.lastPathComponent, systemImage: image)
		case .NonLeaf(let nonLeafItem):
			let expandedBinding = Binding(
				get: { nonLeafItem.isExpanded },
				set: { newValue in nonLeafItem.isExpanded = newValue })

			DisclosureGroup(isExpanded: expandedBinding) {
				if case .Available(let children) = nonLeafItem.children {
					let items: [TrackedDirectory.FileItem] = Array(
						children.values)
					ForEach(items) { (item: TrackedDirectory.FileItem) in
						ProjectItemView(item: item, level: level + 1)
					}
				}
			} label: {
				Label(nonLeafItem.path.lastPathComponent, systemImage: image)
			}
		}
	}
}

struct ProjectOutlineGroup: View {
	@State private var root: TrackedDirectory
	@Binding var selection: Set<UUID>

	init(withRoot directory: TrackedDirectory, selection: Binding<Set<UUID>>) {
		self._selection = selection
		self.root = directory
	}

	var body: some View {
		List(selection: $selection) {
			ForEach(root.items) { (item: TrackedDirectory.FileItem) in
				ProjectItemView(item: item)
			}
		}
	}
}
