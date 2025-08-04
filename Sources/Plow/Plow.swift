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
		self.color = .Black

		if content.count > Self.maxLeafLength {
			throw InitializationError.TooLong
		}

		self.content = content
	}

	/// assumes that self.right != nil
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

	/// assumes that self.left != nil
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

	// we can implement concatenations through a split
	// and two joins.
}

public class PlowRope: BidirectionalCollection {
	public var count: Int
	var root: PlowRopeNode?

	init(for str: String) throws {
		root = try PlowRopeNode(ownedBy: self, content: str)
	}

	private func rb_insert_fixup(new node: PlowRopeNode) {
		var n = node
		while let p = n.parent, p.color == .Red {
			if let ppl = p.parent?.left,
				p === ppl
			{
				let uncle = p.parent!.right
				if uncle?.color ?? .Black == .Red {
					p.color = .Black
					uncle?.color = .Black
					p.parent!.color = .Red
					n = p.parent!  // ? probably incorrect
				} else {
					if let pr = n.parent?.right, n === pr {
						n = n.parent!
						n.leftRotate()
					}
					n.parent?.color = .Black
					n.parent?.parent?.color = .Red
					n.parent?.parent?.rightRotate()
				}
			} else {
				let uncle = p.parent?.left
				if uncle?.color ?? .Black == .Red {
					p.color = .Black
					uncle!.color = .Black
					p.parent?.color = .Red
					n = p.parent!  // ditto
				} else {
					if n === n.parent?.left {
						n = p
						n.rightRotate()
					}
					p.color = .Black
					p.parent!.color = .Red
					n.parent!.parent!.leftRotate()
				}
			}
		}
		self.root!.color = .Black
	}

	private func insert(str: String, at idx: Int) throws {
		let strCount = str.count

		var current = root

		var parentData: (PlowRopeNode, Int)? = nil
		var cidx = idx
		while let c = current, !c.isLeaf {
			parentData = (c, cidx)
			if cidx == 0 || cidx < c.weight! {
				current = c.left
			} else {
				cidx -= c.weight!
				current = c.right
			}
		}

		if current == nil || current!.isEmpty {
			// There's an empty leaf available for this position.
			let new = try PlowRopeNode(ownedBy: self, content: str)

			if let (parent, _) = parentData {
				if parent.right === current {
					// most likely I believe, if not always the case
					// (because why would we have a node with weight 0??)
					parent.right = new
				} else {
					parent.weight = str.count
					parent.left = new
				}
			} else {
				// No root exists, so we need to make one.
				self.root = PlowRopeNode(ownedBy: self, color: .Black)

				self.count = strCount
				root!.weight = strCount
				root!.left = new
			}

			self.count += strCount
			return
		}

		// 'current' is not nil and non-empty; thus it is also a leaf with a
		// parent
		let content = current!.content!
		let (parent, pidx) = parentData!

		let insertionIndex = content.index(content.startIndex, offsetBy: pidx)
		let (left, right) = content.inserted(
			contentsOf: str,
			at: insertionIndex,
			withLimit: PlowRopeNode.maxLeafLength
		)

		if let right {
			// We need to create a new internal node.
			let new = PlowRopeNode(ownedBy: self, color: .Red)
			new.parent = parent

			new.weight = left.count  // = maxLeafLength
			new.left = try PlowRopeNode(ownedBy: self, content: left)
			new.right = try PlowRopeNode(ownedBy: self, content: right)

			if pidx < parent.weight! {
				parent.left = new
			} else {
				parent.right = new
			}

			// fix weights
			var c = new
			while let p = c.parent, p.left === c {
				p.weight! += strCount
				c = p
			}
		} else {
			var c = current!
			c.content = left

			// fix weights
			while let p = c.parent, p.left === c {
				p.weight! += strCount
				c = p
			}
		}

		self.count += strCount

		rb_insert_fixup(new)
	}
}

// Bibliography:
// - Cormen, T. H., et al. Introduction to Algorithms, 4th ed., MIT Press, 2022. Red-Black Trees, Chapter 13
// - Rope (data structure) in Wikipedia. https://en.wikipedia.org/w/index.php?title=Rope_(data_structure)&oldid=1290031069
