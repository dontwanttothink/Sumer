import Testing

@testable import Plow

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

@Test("Can be joined together") func joinedTogether() {
	let a = PlowRope(for: "Everything is okay.")
	let b = PlowRope(for: " But…")
	let c = a.join(with: b)

	#expect(String(c) == "Everything is okay. But…")
}
