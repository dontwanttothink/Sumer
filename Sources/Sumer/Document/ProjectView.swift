import SwiftUI

struct ProjectView: View {
	private let path: URL
	@State private var selection: Set<URL> = []

	init(_ path: URL) {
		self.path = path
	}

	var body: some View {
		NavigationSplitView {
			ProjectOutlineGroup(withRoot: self.path, selection: $selection)
				.navigationTitle("Sidebar")
		} detail: {
			if selection.count > 0 {
				Text("Selected something")
			} else {
				Text("No selection")
			}
			Text("You are editing " + path.absoluteString)
		}
	}
}
