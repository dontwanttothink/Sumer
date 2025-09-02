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

// note: Ensure that the number of nodes is Θ(n) the length of the string
// (.count, by extended grapheme clusters), or complexity characteristics won't
// hold.

public struct PlowRope {
	/// The root is never a leaf node.
	private var root: PlowRopeNode.ParentalNode

	public var count: Int { root.count }

	public init() {
		self.init(for: "")
	}
	/// - Complexity: Θ(n) (Intended.)
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

		let structure = getStructure(forParts: parts[...]).intoParental()
		self.root = structure
	}

	init(withRoot root: PlowRopeNode.ParentalNode) {
		self.root = root
	}

	/// Call this function before making changes to the tree structure. The root
	/// and its descendants will possibly be copied. Existing bindings cannot be
	/// updated. Thus, if your function uses nodes passed by the caller, do not
	/// call this function — it is the caller's responsibility to perform this
	/// check before accessing the tree structure instead.
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

	/// Inserts a new internode (non-content) in `leaf`'s position. The original
	/// leaf is moved to the new internode's left child.
	///
	/// The resulting tree may be unbalanced. Sizes, heights and balance factors
	/// remain correct.
	///
	/// - Returns: The inserted internode.
	private mutating func insertInternode(at leaf: PlowRopeNode.LeafNode)
		-> PlowRopeNode.ParentalNode
	{
		let oldLeaf = leaf
		let oldParent = leaf.parent!
		let oldPositionIsLeft = oldLeaf.container.isLeftChildOf(oldParent)

		var new = PlowRopeNode(leftChild: oldLeaf.container)

		if oldPositionIsLeft {
			oldParent.left = new
		} else {
			oldParent.right = new
		}
		new.parent = oldParent

		let newParental = new.asParental()
		newParental.recomputePropertiesUntilRoot()

		return newParental
	}

	/// Performs manipulations on the tree to fix imbalances after an internode
	/// insertion. Counts and heights stored remain correct.
	///
	/// The subtree 'new' must be already in AVL shape. Its height must have
	/// increased by one. This is also a loop invariant.
	///
	/// Heights, counts, and balance factors must have already been updated.
	///
	/// - Parameter new: A node rooting a subtree with the characteristics
	/// above, such as the return value of ``insertInternode(at:)``
	private mutating func insertionFixup(dueTo new: PlowRopeNode.ParentalNode) {
		var normalized = new
		while let toNormalize = normalized.parent {
			var newRoot: PlowRopeNode.ParentalNode
			var originalParent: PlowRopeNode.ParentalNode?

			if normalized.isRightChildOf(toNormalize) {
				if toNormalize.balanceFactor > 0 {
					originalParent = toNormalize.parent
					if normalized.balanceFactor < 0 {
						newRoot = toNormalize.rotateRightLeft()
					} else {
						newRoot = toNormalize.rotateLeft()
					}
				} else if toNormalize.balanceFactor < 0 {
					toNormalize.balanceFactor = 0
					break
				} else {
					toNormalize.balanceFactor = 1
					normalized = toNormalize
					continue
				}
			} else {
				if toNormalize.balanceFactor < 0 {
					originalParent = toNormalize.parent
					if normalized.balanceFactor > 0 {
						newRoot = toNormalize.rotateLeftRight()
					} else {
						newRoot = toNormalize.rotateRight()
					}
				} else if toNormalize.balanceFactor > 0 {
					toNormalize.balanceFactor = 0
					break
				} else {
					toNormalize.balanceFactor = -1
					normalized = toNormalize
					continue
				}
			}

			newRoot.parent = originalParent
			if let originalParent {
				if toNormalize.isLeftChildOf(originalParent) {
					originalParent.left = newRoot.container
				} else {
					originalParent.right = newRoot.container
				}
			} else {
				self.root = newRoot
			}
			break
		}
	}

	/// Helper function to join a tall `right` with a short `left`. The
	/// resulting tree is balanced.
	private static func joinLeft(
		left: PlowRopeNode,
		right: PlowRopeNode.ParentalNode
	) -> PlowRopeNode.ParentalNode {
		// 'right' is too tall: two or more levels taller.

		if right.left.height <= left.height + 1 {
			// right.left is the correct height

			let glueChild = PlowRopeNode(
				leftChild: left,
				rightChild: right.left,
			)
			if glueChild.height <= right.right.height + 1 {
				return PlowRopeNode(
					leftChild: glueChild, rightChild: right.right
				).asParental()
			} else {
				return PlowRopeNode(
					leftChild: glueChild.asParental().rotateLeft().container,
					rightChild: right.right,
				).asParental().rotateRight()
			}
		} else {
			// right.left's height is still at least two more than left's

			let glueChildChild = joinLeft(left: left, right: right.left.asParental())
			let glueChild = PlowRopeNode(
				leftChild: glueChildChild.container, rightChild: right.right
			).asParental()

			if glueChildChild.height <= right.right.height + 1 {
				return glueChild
			} else {
				return glueChild.rotateRight()
			}
		}
	}
	/// Helper function to join a tall `left` with a short `right`. The
	/// resulting tree is balanced.
	private static func joinRight(
		left: PlowRopeNode.ParentalNode,
		right: PlowRopeNode
	) -> PlowRopeNode.ParentalNode {
		// 'left' is too tall: two or more levels taller.

		if left.right.height <= right.height + 1 {
			// left.right is the correct height

			let glueChild = PlowRopeNode(
				leftChild: left.right,
				rightChild: right,
			)
			if glueChild.height <= left.left.height + 1 {
				return PlowRopeNode(
					leftChild: left.left, rightChild: glueChild
				).asParental()
			} else {
				return PlowRopeNode(
					leftChild: left.left,
					rightChild: glueChild.asParental().rotateRight().container,
				).asParental().rotateLeft()
			}
		} else {
			// left.right's height is still at least two more than right's

			let glueChildChild = joinRight(left: left.right.asParental(), right: right)
			let glueChild = PlowRopeNode(
				leftChild: left.left, rightChild: glueChildChild.container
			).asParental()

			if glueChildChild.height <= left.left.height + 1 {
				return glueChild
			} else {
				return glueChild.rotateLeft()
			}
		}
	}

	private static func join(left: PlowRopeNode.ParentalNode, right: PlowRopeNode.ParentalNode)
		-> PlowRopeNode.ParentalNode
	{
		if left.height > right.height + 1 {
			return Self.joinRight(
				left: left,
				right: right.container
			)
		}
		if right.height > left.height + 1 {
			return Self.joinLeft(
				left: left.container,
				right: right,
			)
		}
		return PlowRopeNode(
			leftChild: left.container,
			rightChild: right.container,
		).asParental()
	}

	/// Concatenates the content of `right` at the end of this rope.
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
	///
	/// **Internal**
	///
	/// The resulting tree is balanced.
	public mutating func join(with right: consuming PlowRope) {
		ensureSafelyMutable()
		self.root = Self.join(left: self.root, right: right.root)
	}

	/// Possibly update the tree to ensure that the `index` supplied lies at the
	/// beginning or end of a leaf node, rather than in the middle.
	///
	/// The resulting tree is balanced. Heights, balance factors, and counts
	/// remain corrext.
	///
	/// - Returns: the two sides of the boundary, one of which may be a
	/// parental node.
	private mutating func splitLeaf(at absoluteIndex: Int) {
		ensureSafelyMutable()

		let (leaf, pre) = getLeaf(at: absoluteIndex)
		let index = absoluteIndex - pre

		assert(index >= 0 && index <= leaf.count)

		guard index != 0 && index != leaf.count else {
			return
		}

		let parent = insertInternode(at: leaf)
		let splitIndex = leaf.content.index(leaf.content.startIndex, offsetBy: index)

		let leftContent = leaf.content[..<splitIndex]
		let rightContent = leaf.content[splitIndex...]

		leaf.content = String(leftContent)
		parent.right.asLeaf().content = String(rightContent)

		parent.recomputePropertiesUntilRoot()

		insertionFixup(dueTo: parent)

		assert(
			{
				let (leaf, pre) = getLeaf(at: absoluteIndex)
				return absoluteIndex == pre || absoluteIndex - pre == leaf.count
			}(),
			"split: incorrect after"
		)
	}

	/// Splits the rope. The instance on which this method is called is modified
	/// to represent only its first `index` graphemes.
	///
	/// - Returns: An instance representing the rest of the graphemes.
	public mutating func split(at index: Int) -> PlowRope {
		precondition(index >= 0 && index <= count, "Index out of bounds")
		ensureSafelyMutable()
		splitLeaf(at: index)

		/// Requires the leaf to be split at index.
		func _split(from node: PlowRopeNode.ParentalNode, at index: Int)
			-> (PlowRopeNode, PlowRopeNode)
		{
			if node.left.count == index {
				return (node.left, node.right)
			}

			/// Indexing offset for the right subtree
			let offset = node.left.count

			if index < node.left.count {
				assert(node.left.isParental)
				var (l, r) = _split(from: node.left.asParental(), at: index)

				r.parent = nil
				l.parent = nil
				node.right.parent = nil

				return (
					l,
					Self.join(
						left: r.intoParental(),
						right: node.right.intoParental()
					).container,
				)
			}

			assert(node.right.isParental)
			var (l, r) = _split(from: node.right.asParental(), at: index - offset)

			l.parent = nil
			r.parent = nil
			node.left.parent = nil

			return (
				Self.join(
					left: node.left.intoParental(),
					right: l.intoParental()
				).container,
				r
			)
		}

		let (left, right) = _split(from: self.root, at: index)
		self.root = left.intoParental()
		return PlowRope(withRoot: right.intoParental())
	}

	public mutating func insert<C>(contentsOf newElements: C, at index: Index)
	where C: Collection, C.Element == Self.Element {
		ensureSafelyMutable()

		let new = PlowRope(for: String(newElements))
		let rest = split(at: index)

		self.join(with: consume new)
		self.join(with: consume rest)
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

	/// - Complexity: Θ(lg n + m), where 'n' is the length of the rope and 'm'
	/// is the cost of iterating the collection provided. (Intended.)
	public mutating func replaceSubrange<R, C>(_ subrange: R, with newElements: C)
	where C: Collection, R: RangeExpression, Index == R.Bound, Element == C.Element {
		let indices = subrange.relative(to: self)

		let r = self.split(at: indices.endIndex)
		_ = self.split(at: indices.startIndex)

		let new = PlowRope(for: String(newElements))
		self.join(with: consume new)
		self.join(with: consume r)
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
// - "AVL tree" in Wikipedia. https://en.wikipedia.org/w/index.php?title=AVL_tree&oldid=1299115771
// - "Rope (data structure)" in Wikipedia. https://en.wikipedia.org/w/index.php?title=Rope_(data_structure)&oldid=1290031069
// - GNU libavl by Ben Pfaff. https://adtinfo.org/libavl.html/Inserting-into-an-AVL-Tree.html
