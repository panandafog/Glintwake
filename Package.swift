// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Glintwake",
    platforms: [.macOS(.v14)],
    products: [.library(name: "GlintwakeCore", targets: ["GlintwakeCore"])],
    targets: [
        .target(name: "GlintwakeCore", path: "Sources/Core"),
        .testTarget(name: "GlintwakeCoreTests", dependencies: ["GlintwakeCore"], path: "Tests/CoreTests")
    ]
)
