/// A node inside a ``PlowRope``.
// This structure does not contain any data directly. Instead, its `data`
// property holds a CoW structure that owns an instance of
// `PlowRope.ParentalNodeData` or `PlowRope.LeafNodeData` with the actual node
// data.
struct PlowRopeNode {
	public static let maxLeafCount = 1_000_000

	enum Data {
		case parental(ParentalNode)
		case leaf(LeafNode)
	}

	var data: Data!

	/// Creates a new leaf. `content.count` must not exceed `maxLeafCount`.
	init(content: String) {
		assert(content.count <= Self.maxLeafCount)
		data = .leaf(LeafNode(content))
	}

	/// Creates a new parental node. You may omit or pass `nil` to the
	/// `leftChild` and `rightChild` parameters. In that case, empty leaves will
	/// take their place.
	///
	/// This initializer sets the  `parent` property on any passed children,
	/// which may incur an expensive copy unless you indicate that they be
	/// consumed using the `consume` Swift keyword.
	///
	/// The new node's `count`, `height` and `balanceFactor` properties are set
	/// automatically based on the children supplied. If you manually make
	/// changes to the children, you must update these properties yourself.
	init(
		leftChild: PlowRopeNode? = nil,
		rightChild: PlowRopeNode? = nil
	) {
		data = .parental(
			ParentalNode(
				leftChild: leftChild ?? PlowRopeNode(content: ""),
				rightChild: rightChild ?? PlowRopeNode(content: ""),
			)
		)
	}

	private init(withData data: Data) {
		self.data = data
	}

	// Maybe: make this a macro
	var count: Int {
		switch data! {
		case .leaf(let content):
			return content.count
		case .parental(let children):
			return children.count
		}
	}
	var parent: ParentalNode? {
		get {
			switch data! {
			case .leaf(let node):
				return node.parent
			case .parental(let node):
				return node.parent
			}
		}
		set {
			switch data! {
			case .leaf(var node):
				node.parent = newValue
			case .parental(var node):
				node.parent = newValue
			}
		}
	}

	/// Avoid using this property; it is only necessary in rare cases. Instead,
	/// perform pattern-matching on `.data`.
	var isParental: Bool {
		switch data! {
		case .leaf:
			return false
		case .parental:
			return true
		}
	}

	var height: Int {
		switch data! {
		case .leaf(let leaf):
			return leaf.height
		case .parental(let parent):
			return parent.height
		}
	}

	func isIdentical(to other: PlowRopeNode) -> Bool {
		switch data! {
		case .leaf(let leaf):
			if case .leaf(let otherLeaf) = other.data,
				leaf.isIdentical(to: otherLeaf)
			{
				return true
			}
		case .parental(let parental):
			if case .parental(let otherParental) = other.data,
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
		guard case .parental(let node) = self.data else {
			preconditionFailure("Attempted to use a leaf node as a parental node.")
		}
		return node
	}
	/// Obtain the leaf node corresponding to this node. A crash occurs if this
	/// method is called on a parental node.
	///
	/// If error handling is needed, use pattern matching on the `data` property
	/// instead.
	func asLeaf() -> PlowRopeNode.LeafNode {
		guard case .leaf(let node) = self.data else {
			preconditionFailure("Attempted to use a parental node as a leaf node.")
		}
		return node
	}

	func isRightChildOf(_ node: PlowRopeNode) -> Bool {
		if case .parental(let data) = node.data,
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
		if case .parental(let data) = node.data,
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

	struct ParentalNode {
		fileprivate var data: ParentalNodeData

		var container: PlowRopeNode {
			PlowRopeNode(withData: .parental(self))
		}

		/// `count, `height`, `balanceFactor` are automatically set based on
		/// the children supplied.
		init(
			leftChild: PlowRopeNode,
			rightChild: PlowRopeNode
		) {
			self.data = ParentalNodeData(leftChild: leftChild, rightChild: rightChild)
		}

		fileprivate init(withData data: ParentalNodeData) {
			self.data = data
		}

		private mutating func onWrite() {
			if !isKnownUniquelyReferenced(&data) {
				data = data.copy()
			}
		}

		// MARK: Expose the underlying data structure's properties
		var parent: ParentalNode? {
			get {
				guard let p = data.parent else {
					return nil
				}
				return ParentalNode(withData: p)
			}
			set {
				onWrite()
				data.parent = newValue?.data
			}
		}

		var count: Int {
			get { data.count }
			set {
				onWrite()
				data.count = newValue
			}
		}
		var height: Int {
			get { data.height }
			set {
				onWrite()
				data.height = newValue
			}
		}
		var left: PlowRopeNode {
			get { data.left }
			set {
				onWrite()
				data.left = newValue
			}
		}
		var right: PlowRopeNode {
			get { data.right }
			set {
				onWrite()
				data.right = newValue
			}
		}

		var balanceFactor: Int {
			get { data.balanceFactor }
			set {
				onWrite()
				data.balanceFactor = newValue
			}
		}

		// MARK: Define reference equality
		func isIdentical(to other: ParentalNode) -> Bool {
			data === other.data
		}

		// MARK: Implement operations
		private mutating func updateCount() {
			self.count = self.right.count + self.left.count
		}
		private mutating func updateHeight() {
			self.height = max(self.left.height, self.right.height) + 1
		}
		private mutating func updateBalanceFactor() {
			self.balanceFactor = -self.left.height + self.right.height
		}

		mutating func recomputeProperties() {
			updateCount()
			updateHeight()
			updateBalanceFactor()
		}

		// NOTE: `height`, `count` and `balanceFactor` must be kept consistent
		// in rotation methods below.

		// https://en.wikipedia.org/wiki/File:AVL-simple-left_K.svg
		@discardableResult mutating func rotateLeft() -> ParentalNode {
			var z = self.right.asParental()
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
		@discardableResult mutating func rotateRight() -> ParentalNode {
			var z = self.left.asParental()
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
		@discardableResult mutating func rotateLeftRight() -> ParentalNode {
			var z = self.left.asParental()
			assert(z.balanceFactor > 0)

			_ = z.rotateLeft()
			return self.rotateRight()
		}

		// https://commons.wikimedia.org/wiki/File:AVL-double-rl_K.svg
		@discardableResult mutating func rotateRightLeft() -> ParentalNode {
			var z = self.right.asParental()
			assert(z.balanceFactor < 0)

			_ = z.rotateRight()
			return self.rotateLeft()
		}
	}

	final fileprivate class ParentalNodeData {
		weak var parent: ParentalNodeData?

		var count: Int
		var height: Int
		var left: PlowRopeNode
		var right: PlowRopeNode

		var balanceFactor: Int

		init(
			leftChild: PlowRopeNode,
			rightChild: PlowRopeNode
		) {
			self.left = leftChild
			self.right = rightChild

			self.count = leftChild.count + rightChild.count
			self.height = max(leftChild.height, rightChild.height) + 1
			self.balanceFactor = -leftChild.height + rightChild.height
		}

		func copy() -> ParentalNodeData {
			ParentalNodeData(leftChild: left, rightChild: right)
		}
	}

	/// A leaf node.
	struct LeafNode {
		fileprivate var data: LeafNodeData

		init(_ content: String) {
			self.init(content, withParent: nil)
		}

		init(
			_ content: String,
			withParent parent: ParentalNode?
		) {
			self.data = LeafNodeData(content, withParent: parent?.data)
		}

		func isIdentical(to other: LeafNode) -> Bool {
			data === other.data
		}

		private mutating func onWrite() {
			if !isKnownUniquelyReferenced(&data) {
				data = data.copy()
			}
		}

		var container: PlowRopeNode {
			PlowRopeNode(withData: .leaf(self))
		}

		/// Only a weak reference is kept to the parent.
		var parent: ParentalNode? {
			get {
				guard let p = data.parent else {
					return nil
				}
				return ParentalNode(withData: p)
			}
			set {
				onWrite()
				data.parent = newValue?.data
			}
		}

		var height: Int {
			data.height
		}

		var count: Int {
			data.count
		}
		var content: String {
			get { data.content }
			set {
				onWrite()
				data.content = newValue
			}
		}
	}

	fileprivate final class LeafNodeData {
		weak var parent: ParentalNodeData?

		var height: Int {
			0
		}

		var count: Int {
			content.count
		}
		var content: String

		init(
			_ content: String,
			withParent parent: ParentalNodeData?
		) {
			self.content = content
			self.parent = parent
		}

		func copy() -> LeafNodeData {
			LeafNodeData(content, withParent: parent)
		}
	}
}
