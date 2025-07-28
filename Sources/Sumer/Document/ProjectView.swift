import SwiftUI

struct ProjectView: View {
	private let root: TrackedDirectory?
	private let error: (any Error)?
	@State private var selection: Set<UUID> = []

	init(_ path: URL) {
		do {
			self.root = try TrackedDirectory(path: path)
			self.error = nil
		} catch {
			self.error = error
			self.root = nil
		}
	}

	var body: some View {
		if let root {
			NavigationSplitView {
				ProjectOutlineGroup(withRoot: root, selection: $selection)
					.navigationTitle("Sidebar")
			} detail: {
				if selection.count > 0 {
					Text("Selected something")
				} else {
					Text("No selection")
				}
				Text("You are editing " + root.path.absoluteString)
			}
		} else {
			if let error {
				Text("Something went wrong: \(error.localizedDescription)")
			} else {
				Text("Something went wrong.")
			}
		}
	}
}
