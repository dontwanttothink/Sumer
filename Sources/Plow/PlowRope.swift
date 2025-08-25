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
	/// - Complexity: Θ(n)
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
	/// The resulting tree is balanced. Sizes remain correct.
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
		let oldParent = oldLeaf.parent!

		var new = PlowRopeNode(leftChild: oldLeaf)
		new.parent = oldParent

		if oldLeaf.isLeftChildOf(oldParent) {
			oldParent.left = new
		} else {
			oldParent.right = new
		}

		let newParental = new.asParental()
		newParental.recomputePropertiesUntilRoot()
		insertionFixup(dueTo: newParental)
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
	/// above.
	private mutating func insertionFixup(dueTo new: PlowRopeNode.ParentalNode) {
		ensureSafelyMutable()

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
	/// Helper function to join a tall `left` with a short `right`. The
	/// resulting tree is balanced.
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

	private static func join(left: PlowRopeNode.ParentalNode, right: PlowRopeNode.ParentalNode)
		-> PlowRopeNode.ParentalNode
	{
		if left.height > right.height + 1 {
			return Self.joinRight(
				left: left,
				right: right
			)
		}
		if right.height > left.height + 1 {
			return Self.joinLeft(
				left: left,
				right: right,
			)
		}
		return PlowRopeNode(
			leftChild: left.container,
			rightChild: right.container,
		).asParental()
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
	///
	/// **Internal**
	///
	/// The resulting tree is balanced.
	public mutating func join(with right: consuming PlowRope) {
		ensureSafelyMutable()
		self = PlowRope(withRoot: Self.join(left: self.root, right: right.root))
	}

	/// Possibly update the tree to ensure that the `index` supplied lies at the
	/// beginning or end of a leaf node, rather than in the middle.
	///
	/// The resulting tree is balanced.
	///
	/// - Returns: the parent of the leaf containing `index`.
	@discardableResult private mutating func splitLeaf(at index: Int)
		-> PlowRopeNode.ParentalNode
	{
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

	/// Splits the rope. The instance on which this method is called is modified
	/// to represent only its first `index` graphemes.
	///
	/// - Returns: An instance representing the rest of the graphemes.
	public consuming func split(at index: Int) -> PlowRope {
		ensureSafelyMutable()
		splitLeaf(at: index)

		/// Requires the leaf to be split at index.
		func _split(from node: PlowRopeNode.ParentalNode, at index: Int) -> (
			PlowRopeNode, PlowRopeNode
		) {
			if index == node.left.count {
				return (node.left, node.right)
			}

			/// Indexing offset for the right subtree
			let offset = node.left.count

			// Due to the leaf split, this should be safe.
			let nlp = node.left.asParental()
			let nrp = node.right.asParental()

			if index < node.left.count {
				let (l, r) = _split(from: nlp, at: index)

				let rp = r.intoParental()
				return (l, Self.join(left: rp, right: nrp).container)
			}

			let (l, r) = _split(from: nrp, at: index - offset)

			let lp = l.intoParental()
			return (Self.join(left: nlp, right: lp).container, r)
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

	public mutating func replaceSubrange<R, C>(_ subrange: R, with newElements: C)
	where C: Collection, R: RangeExpression, Element == C.Element, Index == R.Bound {
		fatalError("unimplemented")
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
