import SwiftUI

struct ContentView: View {
	/// The path used to instantiate this `ContentView`. The file or folder at
	/// this location may have since been removed or renamed.
	let initialPath: URL?

	var body: some View {
		if let initialPath {
			let isDirectory = try? initialPath.isDirectory
			if isDirectory != nil && isDirectory == true {
				ProjectView(initialPath)
			} else {
				DiscreteFilesView(paths: [initialPath])
			}
		} else {
			DiscreteFilesView(paths: [])
		}
	}
}
