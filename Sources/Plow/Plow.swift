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

public class PlowRopeNode {
	enum InitializationError: Error {
		case TooLong
	}

	public static let maxLeafLength = 1_000_000

	enum Color {
		case Red, Black
	}

	unowned let owner: PlowRope

	var color: Color

	var left: PlowRopeNode?
	var right: PlowRopeNode?
	var parent: PlowRopeNode?

	var weight: Int?
	// possible: scalarWeight
	var content: String?

	var isLeaf: Bool {
		return content != nil
	}
	var isEmpty: Bool {
		return content != nil && content!.isEmpty
	}

	/// Create a new internode.
	init(ownedBy owner: PlowRope, color: Color) {
		self.owner = owner
		self.color = color

		self.weight = 0
	}

	/// Create a new leaf.
	init(ownedBy owner: PlowRope, content: String) throws {
		self.owner = owner
		self.color = .Black

		if content.count > Self.maxLeafLength {
			throw InitializationError.TooLong
		}

		self.content = content
	}

	// TODO: should these methods be updated to keep weights
	// accurate?
	/// Applies a left rotation operation from Red-Black Trees on this node. A
	/// crash occurs if `self.right == nil`.
	///
	/// See ``rightRotate()``.
	func leftRotate() {
		let y = self.right!

		self.right = y.left
		if let yl = y.left {
			yl.parent = self
		}

		y.parent = self.parent

		if let parent = self.parent {
			if self === parent.left {
				parent.left = y
			} else {
				parent.right = y
			}
		} else {
			owner.root = y
		}

		y.left = self
		self.parent = y
	}

	/// Applies a right rotation operation from Red-Black Trees on this node. A
	/// crash occurs if `self.left == nil`.
	///
	/// See ``leftRotate()``.
	func rightRotate() {
		let x = self.left!

		self.left = x.right
		if let xr = x.right {
			xr.parent = self
		}

		x.parent = self.parent

		if let parent = self.parent {
			if self === parent.left {
				parent.left = x
			} else {
				parent.right = x
			}
		} else {
			owner.root = x
		}

		x.right = self
		self.parent = x
	}
}

public class PlowRope /* : BidirectionalCollection */ {
	public var count: Int
	var root: PlowRopeNode?

	init(for str: String) throws {
		self.count = str.count
		self.root = try PlowRopeNode(ownedBy: self, content: str)
	}

	/// Performs manipulations on the tree to fix imbalances after an internode
	/// insertion.
	///
	/// - Parameter new: A ``PlowRopeNode`` returned by ``newInternode(at:)``.
	/// - Returns: A leaf, _A_, such that the path from the root to _A_ includes
	/// every node whose ``PlowRopeNode/weight`` is newly inconsistent.
	private func redBlackFixup(dueTo new: PlowRopeNode) {
	}

	/// Inserts a new internode (non-content) suitable for large text insertion
	/// at `index`.
	///
	/// The leaf containing the character at `index` is replaced with an
	/// internode; the leaf is moved to its left child. The resulting tree may
	/// not be balanced. Weights remain correct.
	///
	/// - Returns: The inserted internode.
	private func newInternode(at index: Int) throws -> PlowRopeNode {
	}

	// we can implement concatenations through a split
	// and two joins.
}

// Bibliography:
// - Cormen, T. H., et al. Introduction to Algorithms, 4th ed., MIT Press, 2022. Red-Black Trees, Chapter 13
// - Rope (data structure) in Wikipedia. https://en.wikipedia.org/w/index.php?title=Rope_(data_structure)&oldid=1290031069
