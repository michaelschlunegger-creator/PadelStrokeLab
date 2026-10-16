// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PadelCore",
    platforms: [.iOS("27.0"), .watchOS("27.0"), .macOS("27.0")],
    products: [.library(name: "PadelCore", targets: ["PadelCore"])],
    targets: [
        .target(name: "PadelCore"),
        .testTarget(name: "PadelCoreTests", dependencies: ["PadelCore"])
    ]
)
