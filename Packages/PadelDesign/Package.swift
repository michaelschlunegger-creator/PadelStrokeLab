// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PadelDesign",
    platforms: [.iOS("27.0"), .watchOS("27.0")],
    products: [.library(name: "PadelDesign", targets: ["PadelDesign"])],
    targets: [.target(name: "PadelDesign")]
)
