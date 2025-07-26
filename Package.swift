// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TodoMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "TodoMenuBar",
            targets: ["TodoMenuBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "TodoMenuBar",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "TodoMenuBarTests",
            dependencies: ["TodoMenuBar"]
        )
    ]
)