// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "CollectionConcurrencyKit",
	platforms: [
		.iOS("17.5"),
		.macOS(.v14),
		.macCatalyst(.v14),
		.visionOS(.v1),
		.watchOS(.v7),
	],
    products: [
        .library(
            name: "CollectionConcurrencyKit",
            targets: ["CollectionConcurrencyKit"]
		),
    ],
    targets: [
        .target(
            name: "CollectionConcurrencyKit",
            path: "Sources"
        ),
        .testTarget(
            name: "CollectionConcurrencyKitTests",
            dependencies: ["CollectionConcurrencyKit"],
            path: "Tests"
        ),
    ],
	swiftLanguageModes: [
		.v5,
		.v6,
	]
)
