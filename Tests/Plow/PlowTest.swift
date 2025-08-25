import Testing

@testable import Plow

@Suite("Rope: Small Strings")
struct SmallRope {
	@Test("Can be indexed correctly") func indexing() {
		let pr = PlowRope(for: "Hello, how are you?")

		#expect(pr[0] == "H")
		#expect(pr[1] == "e")
		#expect(pr[pr.count - 1] == "?")
	}

	@Test("Can be converted into a string") func convertToString() {
		let pr = PlowRope(for: "I'm okay.")
		#expect(String(pr) == "I'm okay.")
	}

	@Test("Can be joined together (left bigger than right)") func joinedTogetherLeftRight() {
		var a = PlowRope(for: "I used to believe wholeheartedly that everything was okay.")
		let b = PlowRope(for: " But is it really?")

		Attachment.record(a.debugDescription, named: "small_join_a.txt")
		Attachment.record(b.debugDescription, named: "small_join_b.txt")

		a.join(with: consume b)
		Attachment.record(
			a.debugDescription, named: "small_join_result_rightbig.txt")

		#expect(
			String(a)
				== "I used to believe wholeheartedly that everything was okay. But is it really?"
		)
	}

	@Test("Can be joined together (right bigger than left)") func joinedTogetherRightLeft() {
		var a = PlowRope(for: "I tried to demonstrate it. ")
		let b = PlowRope(
			for: "But it's difficult to ascertain that their intention was malicious.")

		a.join(with: consume b)
		Attachment.record(a.debugDescription, named: "small_join_result_leftbig.txt")
		#expect(
			String(a)
				== "I tried to demonstrate it. But it's difficult to ascertain that their intention was malicious."
		)
	}

	@Test("Can be joined together (same sizes)") func joinedTogetherSameSize() {
		var a = PlowRope(for: "If time is meant for liv-")
		let b = PlowRope(for: "ing, why's it killing me?")
		a.join(with: consume b)

		Attachment.record(
			a.debugDescription, named: "small_join_result_samesize.txt")
		#expect(String(a) == "If time is meant for liv-ing, why's it killing me?")
	}

	@Test("Does not share mutations") func doesNotShareMutations() {
		var a = PlowRope(for: "If time is meant for liv-")
		var c = a
		var b = PlowRope(for: "ing, why's it killing me?")
		a.join(with: b)
		b.join(with: c)
		c.join(with: a)

		#expect(String(a) == "If time is meant for liv-ing, why's it killing me?")
		#expect(String(b) == "ing, why's it killing me?If time is meant for liv-")
		#expect(
			String(c)
				== "If time is meant for liv-If time is meant for liv-ing, why's it killing me?"
		)
	}

	@Test("Can be split") func canSplit() {
		var a = PlowRope(for: "ABCDEFGH")
		let b = a.split(at: 4)
		#expect(String(a) == "ABCD")
		#expect(String(b) == "EFGH")
	}

	@Test("Handles insertions") func canInsert() {
		var a = PlowRope(for: "I'm the worst in the world.")
		a.insert(contentsOf: "liar ", at: 14)
		#expect(String(a) == "I'm the worst liar in the world.")
	}

	@Test("Can produce a debug representation example") func debugRepresentation() {
		let p = PlowRope(
			for:
				"""
				This is the representation of an example PlowRope. The size of
				leaves is contingent on the build configuration, so you may see
				more or fewer leaves than you expect. For example, a release
				build would place this entire text in a single leaf, because
				more leaves would be unnecessary. A debug build helps debug more
				complex trees by using more leaves, as should be shown here.
				"""
		)
		Attachment.record(p.debugDescription, named: "representation_example.txt")
	}
}
