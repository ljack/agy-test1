// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "agy-test1",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "agy-test1"
        ),
        .testTarget(
            name: "agy-test1Tests",
            dependencies: ["agy-test1"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
