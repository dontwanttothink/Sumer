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

public final class PlowRope /* : BidirectionalCollection */ {
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

	public convenience init() {
		try! self.init(for: "")
	}
	public init(for str: String) throws {
		self._root = PlowRopeNode(
			leftChild: PlowRopeNode(content: str)
		)
	}

	init(withRoot root: PlowRopeNode.ParentalNode) {
		self.root = root
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
		while var x = z.parent {
			var n: PlowRopeNode.ParentalNode
			var g: PlowRopeNode.ParentalNode?

			if case .parental(let xr) = x.right.data, z.isIdentical(to: xr) {
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
			if var g {
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
		while case .parental(let children) = current.data {
			parent = children
			pidx = cidx
			if cidx <= children.left.count {
				current = children.left
			} else {
				cidx -= children.left.count
				current = children.right
			}
		}

		var new = PlowRopeNode(leftChild: current)
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
		while var x = p {
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
			if var g {
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
		while case .parental(let children) = current.data {
			if cidx < children.left.count {
				current = children.left
			} else {
				cidx -= children.left.count
				current = children.right
			}
		}

		let leaf = current
		let parent = leaf.parent!

		var sibling =
			if leaf.isLeftChildOf(parent) {
				parent.right
			} else {
				parent.left
			}

		if var grandparent = sibling.parent!.parent {
			if parent.container.isLeftChildOf(grandparent) {
				grandparent.left = sibling
			} else {
				grandparent.right = sibling
			}
			sibling.parent = grandparent

			return grandparent
		} else {
			root.left = sibling
			root.right = PlowRopeNode(content: "")
			sibling.parent = root

			return root
		}
	}

	public func split() {
	}

	private func joinLeft(
		left: PlowRopeNode.ParentalNode, right: PlowRopeNode.ParentalNode
	) -> PlowRopeNode.ParentalNode {
		// 'right' is too tall: two or more levels taller.

		if right.left.height <= left.height + 1 {
			// right.left is the correct height

			let glueChild = PlowRopeNode(
				leftChild: right.left,
				rightChild: left.container
			)
			if glueChild.height <= right.right.height + 1 {
				return PlowRopeNode(
					leftChild: left.left,
					rightChild: glueChild
				).asParental()
			} else {
				return PlowRopeNode(
					leftChild: left.left,
					rightChild: {
						var r = glueChild.asParental()
						r.rotateLeft()
						return r
					}().container
				).asParental()
			}
		} else {
			// right.left's height is still at least two more than left's

			let glueChild = joinLeft(left: left, right: right.left.asParental())
			var glueChildChild = PlowRopeNode(
				leftChild: glueChild.container, rightChild: right.container
			).asParental()

			if glueChild.height <= right.right.height + 1 {
				return glueChildChild
			} else {
				return glueChildChild.rotateRight()
			}
		}
	}
	private func joinRight(
		left: PlowRopeNode.ParentalNode, right: PlowRopeNode.ParentalNode
	) -> PlowRopeNode.ParentalNode {
		// 'left' is too tall: two or more levels taller.

		if left.right.height <= right.height + 1 {
			// left.right is the correct height

			let glueChild = PlowRopeNode(
				leftChild: left.right,
				rightChild: right.container,
			)
			if glueChild.height <= left.left.height + 1 {
				return PlowRopeNode(
					leftChild: left.left, rightChild: glueChild
				).asParental()
			} else {
				return PlowRopeNode(
					leftChild: left.left,
					rightChild: {
						var r = glueChild.asParental()
						r.rotateRight()
						return r
					}().container,
				).asParental()
			}
		} else {
			// left.right's height is still at least two more than right's

			let glueChild = joinRight(left: left.right.asParental(), right: right)
			var glueChildChild = PlowRopeNode(
				leftChild: left.container, rightChild: glueChild.container
			).asParental()

			if glueChild.height <= left.left.height + 1 {
				return glueChildChild
			} else {
				return glueChildChild.rotateLeft()
			}
		}
	}
	public func join(left: PlowRope, right: PlowRope) -> PlowRope {
		if left.root.height > right.root.height + 1 {
			return PlowRope(
				withRoot:
					joinRight(
						left: left.root,
						right: right.root
					)
			)
		}
		if right.root.height > left.root.height + 1 {
			return PlowRope(
				withRoot:
					joinLeft(
						left: left.root,
						right: right.root
					)
			)
		}

		let out = PlowRope()
		out._root = PlowRopeNode(
			leftChild: left.root.container,
			rightChild: right.root.container,
		)
		return out
	}

	public subscript(index: Int) -> Character {
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
