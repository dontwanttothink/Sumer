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

	// TODO: These methods should be updated to keep weight numbers accurate.
	//
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
	/// insertion. Weights remain correct.
	///
	/// - Parameter new: A ``PlowRopeNode`` returned by ``newInternode(at:)``.
	private func redBlackFixup(dueTo new: PlowRopeNode) {
		var current = new
		while let parent = current.parent, parent.color == .Red {
			let grandparent = parent.parent
			if let grandparent, parent === grandparent.left {
				if let uncle = grandparent.right, uncle.color == .Red {
					parent.color = .Black
					uncle.color = .Black
					grandparent.color = .Red
					current = grandparent
				} else {
					if current === parent.right {
						current = parent
						current.leftRotate()
					}
					current.parent!.color = .Black
					current.parent!.parent!.color = .Red
					current.parent!.parent!.rightRotate()
				}
			} else {
				// symmetrical, with 'left' and 'right' exchanged
				if let grandparent,
					let uncle = grandparent.left,
					uncle.color == .Red
				{
					parent.color = .Black
					uncle.color = .Black
					grandparent.color = .Red
					current = grandparent
				} else {
					if current === parent.left {
						current = parent
						current.rightRotate()
					}
					current.parent!.color = .Black
					current.parent!.parent!.color = .Red
					current.parent!.parent!.leftRotate()
				}
			}
		}
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
