// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TodoMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "TodoCLI",
            targets: ["TodoCLI"]),
        .executable(
            name: "TodoApp",
            targets: ["TodoApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3")
    ],
    targets: [
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ]
        ),
        .executableTarget(
            name: "TodoCLI",
            dependencies: [
                "Shared",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "TodoApp",
            dependencies: ["Shared"]
        ),
        .testTarget(
            name: "TodoMenuBarTests",
            dependencies: ["Shared"]
        )
    ]
)