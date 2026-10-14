// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [
    .library(name: "SidecarCore", targets: ["SidecarCore"]),
    .executable(name: "sidecar-compare", targets: ["SidecarCLI"])
]
var targets: [Target] = [
    .target(name: "SidecarCore"),
    .executableTarget(name: "SidecarCLI", dependencies: ["SidecarCore"]),
    .testTarget(name: "SidecarCoreTests", dependencies: ["SidecarCore"])
]
#if os(macOS)
products.append(.executable(name: "SidecarCompare", targets: ["SidecarCompare"]))
targets.append(.executableTarget(name: "SidecarCompare", dependencies: ["SidecarCore"]))
#endif

let package = Package(
    name: "SidecarCompare",
    platforms: [.macOS(.v15)],
    products: products,
    targets: targets,
    swiftLanguageModes: [.v6]
)
