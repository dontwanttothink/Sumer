// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Sumer",
	platforms: [
		.macOS(.v26)
	],
	targets: [
		.target(
			name: "BridgedC",
			path: "Sources/C",
			publicHeadersPath: "include"
		),
		.target(
			name: "Plow",
			swiftSettings: [
				.strictMemorySafety()
			]
		),
		.executableTarget(
			name: "Sumer",
			dependencies: ["BridgedC", "Plow"],
			swiftSettings: [
				.strictMemorySafety()
			]
		),
		.testTarget(name: "PlowTests", dependencies: ["Plow"], path: "Tests/Plow"),
	]
)
