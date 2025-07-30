// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Sumer",
	platforms: [
		.macOS(.v26)
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(name: "Plow", path: "Sources/Plow"),
		.target(
			name: "BridgedC",
			path: "Sources/C",
			publicHeadersPath: "include"
		),
		.executableTarget(
			name: "Sumer",
			dependencies: ["BridgedC", "Plow"]
		),
		.testTarget(name: "SumerTests", dependencies: ["Sumer"], path: "Tests"),
	]
)
