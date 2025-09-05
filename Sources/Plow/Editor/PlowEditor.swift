import AppKit
import SwiftUI

public struct PlowEditor: NSViewRepresentable {
	public init() {}

	public func makeNSView(context: Context) -> some NSView {
		return PlowEditorView()
	}

	public func updateNSView(_ nsView: NSViewType, context: Context) {
	}
}

class PlowEditorView: NSView {
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)

		let scrollView = NSScrollView()
		scrollView.hasVerticalScroller = true
		scrollView.hasHorizontalScroller = true
		scrollView.borderType = .noBorder
		scrollView.autoresizingMask = [.width, .height]

		let editorBase = PlowEditorBase(frame: NSRect(x: 0, y: 0, width: 500, height: 40))

		scrollView.documentView = editorBase
		addSubview(scrollView)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

/// An editor implemented in AppKit using Core Text.
class PlowEditorBase: NSView {
	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)

		// Set background color to red with 30% opacity
		NSColor.red.withAlphaComponent(0.3).setFill()
		dirtyRect.fill()

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
