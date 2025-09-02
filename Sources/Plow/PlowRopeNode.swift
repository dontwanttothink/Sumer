/// A node inside a ``PlowRope``.
///
/// Copies of this enumeration's values do not result in copies of the
/// underlying data, which is stored dynamically as a class. Therefore, any
/// changes made through an instance of this enum are visible to copies of it.
enum PlowRopeNode {
	/// The maximum size (`count`) of a leaf. In release builds, this value is
	/// equal to one million. Debug builds use a much smaller value to simulate
	/// large strings.
	public static var maxLeafCount: Int {
		#if !DEBUG
			1_000_000
		#else
			5
		#endif
	}

	case parental(ParentalNode)
	case leaf(LeafNode)

	/// Creates a new leaf. `content.count` must not exceed `maxLeafCount`.
	init(content: String) {
		assert(content.count <= Self.maxLeafCount)
		self = .leaf(LeafNode(content))
	}

	/// Creates a new parental node. You may omit or pass `nil` to the
	/// `leftChild` and `rightChild` parameters. In that case, empty leaves will
	/// take their place.
	///
	/// This initializer sets the  `parent` property on any passed children.
	/// This means you must perform copies on the arguments passed if the
	/// originals cannot be modified, for example, because they are shared.
	///
	/// The new node's `count`, `height` and `balanceFactor` properties are set
	/// automatically based on the children supplied. If you manually make
	/// changes to the children, you must update these properties yourself.
	init(
		leftChild: PlowRopeNode? = nil,
		rightChild: PlowRopeNode? = nil
	) {
		self = .parental(
			ParentalNode(
				leftChild: leftChild ?? PlowRopeNode(content: ""),
				rightChild: rightChild ?? PlowRopeNode(content: ""),
			)
		)
	}

	private init(withData data: PlowRopeNode) {
		self = data
	}

	// Maybe: make this a macro
	var count: Int {
		switch self {
		case .leaf(let content):
			return content.count
		case .parental(let children):
			return children.count
		}
	}
	var parent: ParentalNode? {
		get {
			switch self {
			case .leaf(let node):
				return node.parent
			case .parental(let node):
				return node.parent
			}
		}
		set {
			switch self {
			case .leaf(let node):
				node.parent = newValue
			case .parental(let node):
				node.parent = newValue
			}
		}
	}

	/// Avoid using this property; it is only necessary in rare cases. Instead,
	/// perform pattern-matching on `.data`.
	var isParental: Bool {
		switch self {
		case .leaf:
			return false
		case .parental:
			return true
		}
	}

	var height: Int {
		switch self {
		case .leaf(let leaf):
			return leaf.height
		case .parental(let parent):
			return parent.height
		}
	}

	func isKnownUniquelyReferenced() -> Bool {
		switch self {
		case .leaf(var l):
			return Swift.isKnownUniquelyReferenced(&l)
		case .parental(var p):
			return Swift.isKnownUniquelyReferenced(&p)
		}
	}

	private func isIdentical(to other: PlowRopeNode) -> Bool {
		switch self {
		case .leaf(let leaf):
			if case .leaf(let otherLeaf) = other,
				leaf.isIdentical(to: otherLeaf)
			{
				return true
			}
		case .parental(let parental):
			if case .parental(let otherParental) = other,
				parental.isIdentical(to: otherParental)
			{
				return true
			}
		}
		return false
	}

	/// Obtain the parental node corresponding to this node. A crash occurs if
	/// this method is called on a leaf.
	///
	/// If error handling is needed, use pattern matching on the `data` property
	/// instead.
	func asParental() -> PlowRopeNode.ParentalNode {
		guard case .parental(let node) = self else {
			preconditionFailure("Attempted to use a leaf node as a parental node.")
		}
		return node
	}

	/// Infallibly produces a parental node based on this node. If the node is
	/// already parental, no changes are made. If the node is a leaf, it is
	/// wrapped in a parental node of which it becomes the left child. In the
	/// latter case, any existing structure the leaf may have been a part of
	/// becomes invalid.
	func intoParental() -> PlowRopeNode.ParentalNode {
		switch self {
		case .parental(let p):
			return p
		case .leaf:
			return PlowRopeNode(leftChild: self).asParental()
		}
	}

	/// Obtain the leaf node corresponding to this node. A crash occurs if this
	/// method is called on a parental node.
	///
	/// If error handling is needed, use pattern matching on the `data` property
	/// instead.
	func asLeaf() -> PlowRopeNode.LeafNode {
		guard case .leaf(let node) = self else {
			preconditionFailure("Attempted to use a parental node as a leaf node.")
		}
		return node
	}

	func isRightChildOf(_ node: PlowRopeNode) -> Bool {
		if case .parental(let data) = node,
			data.right.isIdentical(to: self)
		{
			return true
		}
		return false
	}
	func isRightChildOf(_ data: PlowRopeNode.ParentalNode) -> Bool {
		if data.right.isIdentical(to: self) {
			return true
		}
		return false
	}
	func isLeftChildOf(_ node: PlowRopeNode) -> Bool {
		if case .parental(let data) = node,
			data.left.isIdentical(to: self)
		{
			return true
		}
		return false
	}
	func isLeftChildOf(_ data: PlowRopeNode.ParentalNode) -> Bool {
		if data.left.isIdentical(to: self) {
			return true
		}
		return false
	}

	final class ParentalNode {
		var container: PlowRopeNode {
			PlowRopeNode(withData: .parental(self))
		}

		/// `count, `height`, `balanceFactor` are automatically set based on
		/// the children supplied.
		///
		/// `parent` is set on the children supplied.
		init(
			leftChild: PlowRopeNode,
			rightChild: PlowRopeNode
		) {
			var left = leftChild
			var right = rightChild

			self.left = left
			self.right = right

			self.count = left.count + right.count
			self.height = max(left.height, right.height) + 1
			self.balanceFactor = -left.height + right.height

			left.parent = self
			right.parent = self
		}

		weak var parent: ParentalNode?

		var count: Int
		var height: Int
		var left: PlowRopeNode
		var right: PlowRopeNode

		var balanceFactor: Int

		// MARK: Define reference equality
		func isIdentical(to other: ParentalNode) -> Bool {
			self === other
		}

		// MARK: Implement operations
		func updateCount() {
			self.count = self.right.count + self.left.count
		}
		private func updateHeight() {
			self.height = max(self.left.height, self.right.height) + 1
		}
		private func updateBalanceFactor() {
			self.balanceFactor = -self.left.height + self.right.height
		}

		func recomputeProperties() {
			updateCount()
			updateHeight()
			updateBalanceFactor()
		}

		func recomputePropertiesUntilRoot() {
			var current: PlowRopeNode.ParentalNode? = self
			while let c = current {
				c.recomputeProperties()
				current = c.parent
			}
		}

		func isRightChildOf(_ other: ParentalNode) -> Bool {
			guard case .parental(let o) = other.right else {
				return false
			}
			return self === o
		}
		func isLeftChildOf(_ other: ParentalNode) -> Bool {
			guard case .parental(let o) = other.left else {
				return false
			}
			return self === o
		}

		// NOTE: `height`, `count` and `balanceFactor` must be kept consistent
		// in rotation methods below. Copies must also be made if necessary.

		// https://en.wikipedia.org/wiki/File:AVL-simple-left_K.svg
		@discardableResult func rotateLeft() -> ParentalNode {
			let z = self.right.asParental()
			assert(z.balanceFactor >= 0)

			var inner = z.left
			self.right = inner
			inner.parent = self

			z.left = self.container
			self.parent = z

			if z.balanceFactor == 0 {
				self.balanceFactor = 1
				z.balanceFactor = -1
			} else {
				self.balanceFactor = 0
				z.balanceFactor = 0
			}

			swap(&self.height, &z.height)

			self.updateCount()
			z.updateCount()
			// ^must be done in this order since we are now z's child

			return z
		}

		// https://en.wikipedia.org/wiki/File:AVL-simple-left_K.svg
		@discardableResult func rotateRight() -> ParentalNode {
			let z = self.left.asParental()
			assert(z.balanceFactor <= 0)

			var inner = z.right

			self.left = inner
			inner.parent = self

			z.right = self.container
			self.parent = z

			if z.balanceFactor == 0 {
				self.balanceFactor = -1
				z.balanceFactor = 1
			} else {
				self.balanceFactor = 0
				z.balanceFactor = 0
			}

			swap(&self.height, &z.height)

			self.updateCount()
			z.updateCount()

			return z
		}

		// https://commons.wikimedia.org/wiki/File:AVL-double-rl_K.svg
		@discardableResult func rotateLeftRight() -> ParentalNode {
			let z = self.left.asParental()
			assert(z.balanceFactor > 0)

			_ = z.rotateLeft()
			return self.rotateRight()
		}

		// https://commons.wikimedia.org/wiki/File:AVL-double-rl_K.svg
		@discardableResult
		func rotateRightLeft(  // copyingWith beforeModify: (PlowRopeNode) -> Void
			) -> ParentalNode
		{
			let z = self.right.asParental()
			assert(z.balanceFactor < 0)

			_ = z.rotateRight()
			return self.rotateLeft()
		}

		func copy() -> ParentalNode {
			ParentalNode(leftChild: left, rightChild: right)
		}
	}

	/// A leaf node.
	final class LeafNode {
		weak var parent: ParentalNode!

		var height: Int {
			0
		}

		var count: Int {
			content.count
		}
		/// The leaf's content.
		///
		/// If you update this property, you must update the leaf's parent's
		/// `count`, for example, with `updateCount()`. You do not have to
		/// update the leaf's `count`, because it is a computed property.
		var content: String

		var container: PlowRopeNode {
			PlowRopeNode(withData: .leaf(self))
		}

		convenience init(_ content: String) {
			self.init(content, withParent: nil)
		}
		init(
			_ content: String,
			withParent parent: ParentalNode?
		) {
			self.content = content
			self.parent = parent
		}

		func isIdentical(to other: LeafNode) -> Bool {
			self === other
		}

		func copy() -> LeafNode {
			LeafNode(content, withParent: parent)
		}
	}
}

extension PlowRopeNode: CustomDebugStringConvertible {
	var debugDescription: String {
		guard case .parental(let p) = self else {
			return "\"\(self.asLeaf().content)\""
		}

		var out = ""
		out += "left (\(p.left.count))\n"
		for line in p.left.debugDescription.split(separator: "\n") {
			out += "| " + line + "\n"
		}
		out += "right (\(p.right.count))\n"
		for line in p.right.debugDescription.split(separator: "\n") {
			out += "| " + line + "\n"
		}
		return out
	}
}
