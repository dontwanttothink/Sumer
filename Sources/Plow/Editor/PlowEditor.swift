import AppKit
import SwiftUI

public struct PlowEditor: NSViewRepresentable {
	public init() {}

	public func makeNSView(context: Context) -> some NSView {
		PlowEditorRepresented()
	}

	public func updateNSView(_ nsView: NSViewType, context: Context) {
	}
}

// The editor is implemented in AppKit.
class PlowEditorRepresented: NSView {
	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)

		guard let context = NSGraphicsContext.current?.cgContext else { return }

		let text = "Hello, Core Text on macOS!"
		let attributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.systemFont(ofSize: 24),
			.foregroundColor: NSColor.blue,
		]
		let attributedString = NSAttributedString(
			string: text, attributes: attributes
		)
		let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
		let path = CGPath(rect: self.bounds, transform: nil)
		let frame = CTFramesetterCreateFrame(
			framesetter,
			CFRange(location: 0, length: 0),
			path,
			nil
		)
		CTFrameDraw(frame, context)
	}
}
