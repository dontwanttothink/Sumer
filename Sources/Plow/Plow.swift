indirect enum PlowRope {
	struct ParentData {
		var weight: Int
		var scalarWeight: Int
	}

	case Leaf(String)
	case Parent(PlowRope, ParentData, PlowRope?)

	private func collect(into: inout String) {
		switch self {
		case .Leaf(let str):
			into += str
		case .Parent(let left, _, let right):
			left.collect(into: &into)
			if let right = right {
				right.collect(into: &into)
			}
		}
	}

	func collect() -> String {
		var out = ""
		collect(into: &out)
		return out
	}

	func index() -> Character {
		Character("a")
	}
	func index() -> UnicodeScalar {
		UnicodeScalar(0)
	}

	/// - Parameter at: index of an extended grapheme cluster
	func split(at: Int) -> (PlowRope, PlowRope) {
		(.Leaf("hi"), .Leaf("hi"))
	}
}
