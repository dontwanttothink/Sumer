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

public final class PlowRopeNode {
	public static let maxLeafCount = 1_000_000

	enum Data {
		case Parental(ParentalNode)
		case Leaf(LeafNode)
	}

	var data: Data!

	/// Creates a new leaf.
	init(ownedBy owner: PlowRope, content: String) {
		data = .Leaf(LeafNode(content, ownedBy: owner, forContainer: self))
	}

	/// Creates a new parental node.
	init(
		ownedBy owner: PlowRope, leftChild: PlowRopeNode? = nil,
		rightChild: PlowRopeNode? = nil
	) {
		data = .Parental(
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
		case .Leaf(let content):
			return content.count
		case .Parental(let children):
			return children.count
		}
	}
	var owner: PlowRope {
		switch data! {
		case .Leaf(let leaf):
			return leaf.owner
		case .Parental(let parent):
			return parent.owner
		}
	}
	var parent: ParentalNode? {
		get {
			switch data! {
			case .Leaf(let node):
				return node.parent
			case .Parental(let node):
				return node.parent
			}
		}
		set {
			switch data! {
			case .Leaf(let node):
				node.parent = newValue
			case .Parental(let node):
				node.parent = newValue
			}
		}
	}

	/// Obtain the parental node corresponding to this node. A crash occurs if
	/// this method is called on a leaf.
	func asParental() -> PlowRopeNode.ParentalNode {
		guard case .Parental(let node) = self.data else {
			preconditionFailure("Attempted to use a leaf node as a parental node.")
		}
		return node
	}

	func isRightChildOf(_ node: PlowRopeNode) -> Bool {
		if case .Parental(let data) = node.data,
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
		if case .Parental(let data) = node.data,
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
		var left: PlowRopeNode
		var right: PlowRopeNode

		var balanceFactor: Int

		init(
			ownedBy owner: PlowRope, forContainer container: PlowRopeNode,
			leftChild: PlowRopeNode, rightChild: PlowRopeNode
		) {
			self.owner = owner
			self.container = container

			self.left = leftChild
			self.right = rightChild
			self.count = leftChild.count + rightChild.count
			self.balanceFactor = 0
		}

		// TODO: keep counts correct
		func rotateLeft(with z: ParentalNode) -> ParentalNode {
			assert(z === self.right && z.balanceFactor >= 0)

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
			return z
		}

		func rotateRight(with z: ParentalNode) -> ParentalNode {
			assert(z === self.left && z.balanceFactor <= 0)

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
			return z
		}

		func rotateLeftRight(with z: ParentalNode) -> ParentalNode {
			assert(z == self.left && z.balanceFactor > 0)
		}

		func rotateRightLeft(with z: ParentalNode) -> ParentalNode {
			assert(z == self.right && z.balanceFactor < 0)
		}
	}

	public final class LeafNode {
		unowned let owner: PlowRope
		unowned let container: PlowRopeNode
		weak var parent: ParentalNode?

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

// The root is never a leaf node.
public class PlowRope /* : BidirectionalCollection */ {
	public var count: Int {
		root.count
	}
	var root: PlowRopeNode!

	convenience init() {
		try! self.init(for: "")
	}
	init(for str: String) throws {
	}

	/// Performs manipulations on the tree to fix imbalances after an internode
	/// insertion. Sizes remain correct.
	///
	/// - Parameter new: A ``PlowRopeNode/ParentalNode`` returned by
	/// ``newInternode(at:)``.
	private func insertionFixup(dueTo new: PlowRopeNode) {
		var current = new
		var maybeParent = new.parent
		while let parent = maybeParent {
			var newRoot: PlowRopeNode
			if current.isRightChildOf(parent) {
				if parent.balanceFactor > 0 {
					// right-heavy
					let grandparent = parent.parent
				}
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
	private func insertInternode(at index: Int) throws -> PlowRopeNode {
		precondition(index >= 0 && index <= self.count, "Index out of bounds")

		var current = root!
		var cidx = index
		var parent: PlowRopeNode.ParentalNode!
		var pidx: Int!
		while case .Parental(let children) = current.data {
			parent = children
			pidx = cidx
			if cidx <= current.count {
				current = children.left
			} else {
				cidx -= current.count
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
		return new
	}

	// we can implement concatenations through a split
	// and two joins.
}

// Bibliography:
// - AVL tree in Wikipedia. https://en.wikipedia.org/w/index.php?title=AVL_tree&oldid=1299115771
// - Rope (data structure) in Wikipedia. https://en.wikipedia.org/w/index.php?title=Rope_(data_structure)&oldid=1290031069
