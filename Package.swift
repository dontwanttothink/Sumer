// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Sumer",
	platforms: [
		.macOS(.v26)
	],
	targets: [
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
