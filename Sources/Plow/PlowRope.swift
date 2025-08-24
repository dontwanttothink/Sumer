extension String {
	func splitIntoGraphemeParts(of length: Int) -> [Substring] {
		guard length > 0 else { return [] }

		var parts: [Substring] = []
		var currentIndex = startIndex

		while currentIndex < endIndex {
			let nextIndex =
				index(currentIndex, offsetBy: length, limitedBy: endIndex)
				?? endIndex
			parts.append(self[currentIndex..<nextIndex])
			currentIndex = nextIndex
		}

		return parts
	}
}

extension ArraySlice {
	subscript(relative index: Int) -> Element {
		get {
			let actualIndex = startIndex + index
			return self[actualIndex]
		}
		set {
			let actualIndex = startIndex + index
			self[actualIndex] = newValue
		}
	}
	subscript(safeRelative index: Int) -> Element? {
		get {
			guard index >= 0 && index < count else { return nil }
			let actualIndex = startIndex + index
			return self[actualIndex]
		}
	}
}

public struct PlowRope {
	/// The root is never a leaf node.
	private var root: PlowRopeNode.ParentalNode

	public var count: Int { root.count }

	public init() {
		self.init(for: "")
	}
	/// Complexity: Θ(n) (intended)
	public init(for str: String) {
		let parts = str.splitIntoGraphemeParts(
			of: PlowRopeNode.maxLeafCount
		)
		func getStructure(forParts parts: ArraySlice<Substring>) -> PlowRopeNode {
			guard parts.count > 1 else {
				return PlowRopeNode(content: String(parts[safeRelative: 0] ?? ""))
			}

			let half = (parts.startIndex + parts.count / 2)
			return PlowRopeNode(
				leftChild: getStructure(forParts: parts[..<half]),
				rightChild: getStructure(forParts: parts[half...])
			)
		}

		var structure = getStructure(forParts: parts[...])
		if case .leaf = structure {
			structure = PlowRopeNode(leftChild: structure)
		}
		self.root = structure.asParental()
	}

	init(withRoot root: PlowRopeNode.ParentalNode) {
		self.root = root
	}

	/// Call this function before making changes to the tree structure.
	///
	/// - Complexity: Θ(n) in the worst case.
	private mutating func ensureSafelyMutable() {
		// I don't think we can really do better since we need `.parent`. The
		// application shouldn't be doing copies anyway, as far as I can
		// foresee, and in practice the string content itself is not copied
		// until written to (due to Swift's CoW behavior), so the copy shouldn't
		// actually be too large.
		if !isKnownUniquelyReferenced(&root) {
			root = root.copy()
		}
	}

	private func getLeaf(at index: Int) -> (PlowRopeNode.LeafNode, Int) {
		var current = root.container
		var cidx = index
		while case .parental(let children) = current {
			if cidx < children.left.count {
				current = children.left
			} else {
				cidx -= children.left.count
				current = children.right
			}
		}
		return (current.asLeaf(), index - cidx)
	}

	/// Inserts a new internode (non-content) suitable for large text insertion
	/// at `index`.
	///
	/// The leaf containing the character at `index` is replaced with an
	/// internode; the leaf is moved to its left child. The resulting tree may
	/// not be balanced. Sizes remain correct.
	///
	/// Copies are made automatically, if necessary, to avoid corrupting other
	/// structure values sharing the same underlying heap memory.
	///
	/// - Returns: The inserted internode.
	private mutating func insertInternode(at index: Int) -> PlowRopeNode.ParentalNode {
		precondition(index >= 0 && index < self.count, "Index out of bounds")
		ensureSafelyMutable()

		// We query 'index - 1' because we prefer the left node for an insertion
		// at the boundary between two siblings.
		let oldLeaf = getLeaf(at: index - 1).0.container

		var new = PlowRopeNode(leftChild: oldLeaf)
		new.parent = oldLeaf.parent

		let parent = oldLeaf.parent!
		if oldLeaf.isLeftChildOf(parent) {
			parent.left = new
		} else {
			parent.right = new
		}
		return new.asParental()
	}

	/// Performs manipulations on the tree to fix imbalances after an internode
	/// insertion. Counts and heights stored remain correct.
	///
	/// - Parameter new: A ``PlowRopeNode/ParentalNode`` returned by
	/// ``newInternode(at:)``.
	// The subtree 'new' must be already in AVL shape. Its height must have
	// increased by one. This is also a loop invariant.
	private mutating func insertionFixup(dueTo new: PlowRopeNode.ParentalNode) {
		ensureSafelyMutable()

		var z = new
		while let x = z.parent {
			var n: PlowRopeNode.ParentalNode
			var g: PlowRopeNode.ParentalNode?

			if case .parental(let xr) = x.right, z.isIdentical(to: xr) {
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

	/// Deletes the leaf containing the character at the position `index`. To
	/// keep a tree structure, the sibling of the deleted leaf may take the
	/// place of its old parent, or move from being its right child to being its
	/// left child.
	///
	/// The resulting tree may not be balanced.
	///
	/// - Returns: The deleted leaf's sibling's parent after the tree
	/// manipulation, which might not have changed.
	private mutating func deleteLeaf(at index: Int) -> PlowRopeNode.ParentalNode {
		precondition(index >= 0 && index < self.count, "Index out of bounds")
		ensureSafelyMutable()

		var current = root.container
		var cidx = index
		while case .parental(let children) = current {
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
			root.right = PlowRopeNode(content: "")
			sibling.parent = root

			return root
		}
	}

	/// Performs manipulations to fix imbalances caused by a deletion.
	///
	/// - Parameter shortened: Parental node returned by `deleteLeaf(at:)`.
	private mutating func deletionFixup(dueTo shortened: PlowRopeNode.ParentalNode) {
		ensureSafelyMutable()

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

	/// Update the tree such that the `index` supplied lies at the beginning
	/// or end of a leaf node, rather than in the middle.
	///
	/// The resulting tree may not be balanced.
	///
	/// No copies are made.
	///
	/// - Returns: the parent of the leaf containing `index`.
	private mutating func splitLeaf(at index: Int) -> PlowRopeNode.ParentalNode {
		ensureSafelyMutable()

		let (leaf, pre) = getLeaf(at: index)
		guard index != pre || index - pre != leaf.count else {
			return leaf.parent
		}

		let parent = insertInternode(at: index)
		let splitIndex = leaf.content.index(leaf.content.startIndex, offsetBy: index - pre)

		let left = leaf.content[
			..<splitIndex
		]
		let right = leaf.content[splitIndex...]

		leaf.content = String(left)

		parent.right.asLeaf().content = String(right)

		return parent
	}

	/// This instance will be mutated to represent only its first `index + 1`
	/// graphemes.
	///
	/// Returns: An instance representing the rest of the graphemes.
	public consuming func split(at index: Int) -> PlowRope {
		ensureSafelyMutable()

		func _split() -> (PlowRopeNode.ParentalNode, PlowRopeNode.ParentalNode) {
			fatalError("lol")
		}

		let pre = self.root.left.count
		if index == pre {
		}
		fatalError(":p")
	}

	private static func joinLeft(
		left: PlowRopeNode.ParentalNode,
		right: PlowRopeNode.ParentalNode
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
						let r = glueChild.asParental()
						r.rotateLeft()
						return r
					}().container
				).asParental()
			}
		} else {
			// right.left's height is still at least two more than left's

			let glueChild = joinLeft(left: left, right: right.left.asParental())
			let glueChildChild = PlowRopeNode(
				leftChild: glueChild.container, rightChild: right.container
			).asParental()

			if glueChild.height <= right.right.height + 1 {
				return glueChildChild
			} else {
				return glueChildChild.rotateRight()
			}
		}
	}
	private static func joinRight(
		left: PlowRopeNode.ParentalNode,
		right: PlowRopeNode.ParentalNode
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
						let r = glueChild.asParental()
						r.rotateRight()
						return r
					}().container,
				).asParental()
			}
		} else {
			// left.right's height is still at least two more than right's

			let glueChild = joinRight(left: left.right.asParental(), right: right)
			let glueChildChild = PlowRopeNode(
				leftChild: left.container, rightChild: glueChild.container
			).asParental()

			if glueChild.height <= left.left.height + 1 {
				return glueChildChild
			} else {
				return glueChildChild.rotateLeft()
			}
		}
	}

	/// Returns a new rope with the content of `right` after the content of this
	/// rope.
	///
	/// **Avoid expensive copies**
	///
	/// If you will not use `right`, prefix it with `consume` in the function
	/// call.
	///
	/// ```swift
	/// let a = PlowRope()
	/// let b = PlowRope()
	/// a.join(consume b)
	/// ```
	public mutating func join(with right: consuming PlowRope) {
		ensureSafelyMutable()

		if self.root.height > right.root.height + 1 {
			self = PlowRope(
				withRoot:
					Self.joinRight(
						left: self.root,
						right: right.root
					)
			)
		}
		if right.root.height > self.root.height + 1 {
			self = PlowRope(
				withRoot:
					Self.joinLeft(
						left: self.root,
						right: right.root,
					)
			)
		}

		var out = PlowRope()
		out.root = PlowRopeNode(
			leftChild: self.root.container,
			rightChild: right.root.container,
		).asParental()
		self = out
	}

	public subscript(index: Int) -> Character {
		get {
			precondition(index >= startIndex && index < endIndex, "Index out of range")

			let (leaf, start) = getLeaf(at: index)
			let content = leaf.content
			return content[content.index(content.startIndex, offsetBy: index - start)]
		}
		set {
			precondition(index >= startIndex && index < endIndex, "Index out of range")

			let (leaf, start) = getLeaf(at: index)
			let requestedIndex = leaf.content.index(
				leaf.content.startIndex, offsetBy: index - start
			)
			leaf.content.replaceSubrange(
				requestedIndex..<leaf.content.index(after: requestedIndex),
				with: String(newValue)
			)
		}
	}

	public mutating func insert<C>(contentsOf newElements: C)
	where C: Collection, C.Element == Self.Element {
		ensureSafelyMutable()

	}

	// we can implement large insertions through a split
	// and two joins.

}

extension PlowRope: BidirectionalCollection {
	public typealias Index = Int
	public var startIndex: Int { 0 }
	public var endIndex: Int { count }

	public func index(after i: Int) -> Int {
		i + 1
	}
	public func index(before i: Int) -> Int {
		i - 1
	}
}

extension PlowRope: CustomDebugStringConvertible {
	public var debugDescription: String {
		var out = ""
		out += "root (\(count))\n"
		out += "| left (\(root.left.count))\n"
		for line in root.left.debugDescription.split(separator: "\n") {
			out += "| | " + line + "\n"
		}
		out += "| right (\(root.right.count))\n"
		for line in root.right.debugDescription.split(separator: "\n") {
			out += "| | " + line + "\n"
		}
		out += "^ \"\(String(self))\""
		return out
	}
}

// Bibliography:
// - AVL tree in Wikipedia. https://en.wikipedia.org/w/index.php?title=AVL_tree&oldid=1299115771
// - Rope (data structure) in Wikipedia. https://en.wikipedia.org/w/index.php?title=Rope_(data_structure)&oldid=1290031069
