import Testing

@testable import Plow

@Test func keepsValue() throws {
	let pr = PlowRope(for: "hello how are you?")
	#expect(pr[0] == "h")
	#expect(String(pr) == "hello how are you")
}
