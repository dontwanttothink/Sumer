import CoreText
import Plow
import SwiftUI

struct DiscreteFileView: View {
	var paths: [URL]

	var body: some View {
		Text("Discrete file view !!")
		if !paths.isEmpty {
			Text(
				"You are editing "
					+ paths.map({ $0.lastPathComponent }).joined(
						separator: ", "))
		}
		PlowEditor().frame(minWidth: 60, minHeight: 60)
	}
}
