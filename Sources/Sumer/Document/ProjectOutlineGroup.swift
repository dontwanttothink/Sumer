import SwiftUI

func getSystemImage(for fileItem: TrackedDirectory.FileItem) -> String {
	return switch fileItem.kind {
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

		switch item.kind {
		case .Leaf:
			Label(item.url.lastPathComponent, systemImage: image)
		case .NonLeaf(let children):
			let expandedBinding = Binding(
				get: { children.areExpanded },
				set: { newValue in children.areExpanded = newValue })

			DisclosureGroup(isExpanded: expandedBinding) {
				if case .Available(let childrenItems) = children.items {
					let items: [TrackedDirectory.FileItem] = Array(
						childrenItems.values
					).sorted()
					ForEach(items) { (item: TrackedDirectory.FileItem) in
						ProjectItemView(item: item, level: level + 1)
					}
				}
			} label: {
				Label(item.url.lastPathComponent, systemImage: image)
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
			switch root.items {
			case .Available(let items):
				ForEach(Array(items.values).sorted()) {
					(item: TrackedDirectory.FileItem) in
					ProjectItemView(item: item)
				}
			case .Unavailable:
				Text("anothererrorlollll")
			case .Failed:
				Text("ERror lol")
			}
		}
	}
}
