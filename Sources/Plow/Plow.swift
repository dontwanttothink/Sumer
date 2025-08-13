extension String {
	func inserted<C>(
		contentsOf newElements: C,
		at i: Index,
		withLimit limit: Int,
	) -> (String, String?)
	where C: Collection, Self.Element == C.Element {
		var new = self
		new.insert(contentsOf: newElements, at: i)

		if new.count > limit {
			let border = new.index(new.startIndex, offsetBy: limit)
			return (String(new[..<border]), String(new[border...]))
		}
		return (new, nil)
	}
}

final class PlowRopeNode {
	public static let maxLeafCount = 1_000_000

	enum Data {
		case parental(ParentalNode)
		case leaf(LeafNode)
	}

	var data: Data!

	/// Creates a new leaf.
	init(ownedBy owner: PlowRope, content: String) {
		data = .leaf(LeafNode(content, ownedBy: owner, forContainer: self))
	}

	/// Creates a new parental node. You may omit or pass `nil` to the
	/// `leftChild` and `rightChild` parameters. In that case, empty leaves will
	/// take their place.
	///
	/// The new node's `count`, `height` and `balanceFactor` properties are set
	/// automatically based on the children supplied. If you manually make
	/// changes to the children, you must update these properties yourself.
	init(
		ownedBy owner: PlowRope, leftChild: PlowRopeNode? = nil,
		rightChild: PlowRopeNode? = nil
	) {
		data = .parental(
			ParentalNode(
				ownedBy: owner,
				forContainer: self,
				leftChild: leftChild ?? PlowRopeNode(ownedBy: owner, content: ""),
				rightChild: rightChild ?? PlowRopeNode(ownedBy: owner, content: ""),
			)
		)
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
	var owner: PlowRope {
		switch data! {
		case .leaf(let leaf):
			return leaf.owner
		case .parental(let parent):
			return parent.owner
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
			case .leaf(let node):
				node.parent = newValue
			case .parental(let node):
				node.parent = newValue
			}
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
			data.right === self
		{
			return true
		}
		return false
	}
	func isRightChildOf(_ data: PlowRopeNode.ParentalNode) -> Bool {
		if data.right === self {
			return true
		}
		return false
	}
	func isLeftChildOf(_ node: PlowRopeNode) -> Bool {
		if case .parental(let data) = node.data,
			data.left === self
		{
			return true
		}
		return false
	}
	func isLeftChildOf(_ data: PlowRopeNode.ParentalNode) -> Bool {
		if data.left === self {
			return true
		}
		return false
	}

	public final class ParentalNode {
		unowned let owner: PlowRope
		unowned let container: PlowRopeNode
		weak var parent: ParentalNode?

		var count: Int
		var height: Int
		var left: PlowRopeNode
		var right: PlowRopeNode

		var balanceFactor: Int

		/// `count, `height`, `balanceFactor` are automatically set based on
		/// the children supplied.
		init(
			ownedBy owner: PlowRope, forContainer container: PlowRopeNode,
			leftChild: PlowRopeNode, rightChild: PlowRopeNode
		) {
			self.owner = owner
			self.container = container

			self.left = leftChild
			self.right = rightChild
			self.count = leftChild.count + rightChild.count
			self.height = max(leftChild.height, rightChild.height) + 1
			self.balanceFactor = -self.left.height + self.right.height
		}

		private func updateCount() {
			self.count = self.right.count + self.left.count
		}

		// NOTE: `height`, `count` and `balanceFactor` must be kept consistent
		// in rotation methods below.

		// https://en.wikipedia.org/wiki/File:AVL-simple-left_K.svg
		func rotateLeft() -> ParentalNode {
			let z = self.right.asParental()
			assert(z.balanceFactor >= 0)

			let inner = z.left
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
		func rotateRight() -> ParentalNode {
			let z = self.left.asParental()
			assert(z.balanceFactor <= 0)

			let inner = z.right
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
		func rotateLeftRight() -> ParentalNode {
			let z = self.left.asParental()
			assert(z.balanceFactor > 0)

			_ = z.rotateLeft()
			return self.rotateRight()
		}

		// https://commons.wikimedia.org/wiki/File:AVL-double-rl_K.svg
		func rotateRightLeft() -> ParentalNode {
			let z = self.right.asParental()
			assert(z.balanceFactor < 0)

			_ = z.rotateRight()
			return self.rotateLeft()
		}
	}

	public final class LeafNode {
		unowned let owner: PlowRope
		unowned let container: PlowRopeNode
		weak var parent: ParentalNode?

		var height: Int {
			0
		}

		var count: Int {
			content.count
		}
		var content: String

		init(
			_ content: String, ownedBy owner: PlowRope,
			forContainer container: PlowRopeNode
		) {
			self.owner = owner
			self.container = container

			self.content = content
		}
	}
}

public class PlowRope /* : BidirectionalCollection */ {
	public let startIndex = 0
	public var endIndex: Int {
		count - 1
	}

	public var count: Int {
		root.count
	}

	/// The root is never a leaf node.
	///
	/// The setter for this property stores a strong reference to the
	/// ``PlowRopeNode/ParentalNode``'s' `.container` property.
	var root: PlowRopeNode.ParentalNode {
		get {
			_root.asParental()
		}
		set {
			_root = newValue.container
		}
	}
	private var _root: PlowRopeNode!

	convenience init() {
		try! self.init(for: "")
	}
	init(for str: String) throws {
		self._root = PlowRopeNode(
			ownedBy: self,
			leftChild: PlowRopeNode(ownedBy: self, content: str)
		)
	}

	/// Performs manipulations on the tree to fix imbalances after an internode
	/// insertion. Counts and heights stored remain correct.
	///
	/// - Parameter new: A ``PlowRopeNode/ParentalNode`` returned by
	/// ``newInternode(at:)``.
	// The subtree 'new' must be already in AVL shape. Its height must have
	// increased by one. This is also a loop invariant.
	private func insertionFixup(dueTo new: PlowRopeNode.ParentalNode) {
		var z = new
		while let x = z.parent {
			var n: PlowRopeNode.ParentalNode
			var g: PlowRopeNode.ParentalNode?

			if z === x.right {
				if x.balanceFactor > 0 {
					g = x.parent
					if z.balanceFactor < 0 {
						n = x.rotateRightLeft()
					} else {
						n = x.rotateLeft()
					}
				} else if x.balanceFactor < 0 {
					x.balanceFactor = 0
					break
				} else {
					x.balanceFactor = 1
					continue
				}
			} else {
				if x.balanceFactor < 0 {
					g = x.parent
					if z.balanceFactor > 0 {
						n = x.rotateLeftRight()
					} else {
						n = x.rotateRight()
					}
				} else if x.balanceFactor > 0 {
					x.balanceFactor = 0
					break
				} else {
					x.balanceFactor = -1
					z = x
					continue
				}
			}
			n.parent = g
			if let g {
				if x.container.isLeftChildOf(g) {
					g.left = n.container
				} else {
					g.right = n.container
				}
			} else {
				self.root = n
			}
		}
	}

	/// Inserts a new internode (non-content) suitable for large text insertion
	/// at `index`.
	///
	/// The leaf containing the character at `index` is replaced with an
	/// internode; the leaf is moved to its left child. The resulting tree may
	/// not be balanced. Sizes remain correct.
	///
	/// - Returns: The inserted internode.
	private func insertInternode(at index: Int) -> PlowRopeNode.ParentalNode {
		precondition(index >= 0 && index < self.count, "Index out of bounds")

		var current = root.container
		var cidx = index
		var parent: PlowRopeNode.ParentalNode!
		var pidx: Int!
		while case .Parental(let children) = current.data {
			parent = children
			pidx = cidx
			if cidx <= children.left.count {
				current = children.left
			} else {
				cidx -= children.left.count
				current = children.right
			}
		}

		let new = PlowRopeNode(ownedBy: self, leftChild: current)
		new.parent = parent
		current.parent = new.asParental()

		if pidx <= parent.left.count {
			parent.left = new
		} else {
			parent.right = new
		}
		return new.asParental()
	}

	/// Performs manipulations to fix imbalances caused by a deletion.
	///
	/// - Parameter shortened: Parental node returned by `deleteLeaf(at:)`.
	private func deletionFixup(dueTo shortened: PlowRopeNode.ParentalNode) {
		var n = shortened
		var p = shortened.parent
		while let x = p {
			let g = x.parent

			var b: Int
			if n.container.isLeftChildOf(x) {
				if x.balanceFactor > 0 {
					let z = x.right.asParental()
					b = z.balanceFactor
					if b < 0 {
						n = x.rotateRightLeft()
					} else {
						n = x.rotateLeft()
					}
				} else if x.balanceFactor == 0 {
					x.balanceFactor = 1
					break
				} else {
					n = x
					n.balanceFactor = 0
					p = g
					continue
				}
			} else {
				if x.balanceFactor < 0 {
					let z = x.left.asParental()
					b = z.balanceFactor
					if b > 0 {
						n = x.rotateLeft()
					} else {
						n = x.rotateRight()
					}
				} else if x.balanceFactor == 0 {
					x.balanceFactor = -1
					break
				} else {
					n = x
					n.balanceFactor = 0
					p = g
					continue
				}
			}
			n.parent = g
			if let g {
				if x.container.isLeftChildOf(g) {
					g.left = n.container
				} else {
					g.right = n.container
				}
			} else {
				self.root = n
			}

			if b == 0 {
				break
			}

			p = g
		}
	}

	/// Deletes the leaf containing the character at the position `index`. To
	/// keep a valid tree structure, the sibling of the deleted leaf may take
	/// the place of its old parent, or move from being its right child to
	/// being its left child.
	///
	/// - Returns: The deleted leaf's sibling's parent after the tree
	/// manipulation, which might not have changed.
	private func deleteLeaf(at index: Int) -> PlowRopeNode.ParentalNode {
		precondition(index >= 0 && index < self.count, "Index out of bounds")

		var current = root.container
		var cidx = index
		while case .Parental(let children) = current.data {
			if cidx < children.left.count {
				current = children.left
			} else {
				cidx -= children.left.count
				current = children.right
			}
		}

		let leaf = current
		let parent = leaf.parent!

		let sibling =
			if leaf.isLeftChildOf(parent) {
				parent.right
			} else {
				parent.left
			}

		if let grandparent = sibling.parent!.parent {
			if parent.container.isLeftChildOf(grandparent) {
				grandparent.left = sibling
			} else {
				grandparent.right = sibling
			}
			sibling.parent = grandparent

			return grandparent
		} else {
			root.left = sibling
			root.right = PlowRopeNode(ownedBy: self, content: "")
			sibling.parent = root

			return root
		}
	}

	public func split() {
	}

	private func joinRight(left: PlowRope, right: PlowRope) {
	}
	public func join() {

	}

	public subscript() -> Character {
		return "a"
	}

	public func insert<C>(contentsOf newElements: C)
	where C: Collection /* , C.Element == Self.Element */ {}

	// we can implement large insertions through a split
	// and two joins.
}

// Bibliography:
// - AVL tree in Wikipedia. https://en.wikipedia.org/w/index.php?title=AVL_tree&oldid=1299115771
// - Rope (data structure) in Wikipedia. https://en.wikipedia.org/w/index.php?title=Rope_(data_structure)&oldid=1290031069
