import Testing

@testable import Plow

@Test func hi() throws {
	let pr = try PlowRope(for: "hello how are you?")
	let new = try pr.insertInternode(at: 3)
	pr.insertionFixup(dueTo: new)
}
