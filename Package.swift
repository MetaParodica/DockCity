// swift-tools-version: 6.0
import PackageDescription

// Dockman — additional, per-Space macOS Docks. See /docs for the specification.
// Phase 0: SpacesKit + dockman-spike (the validated feasibility gate).
// Phase 1: ConfigKit + DockKit + the `dockman` agent app (walking skeleton).
//
// Targets use the v5 language mode for now; docs/03 §5 calls for tightening to
// Swift 6 strict concurrency in the hardening phase.
let v5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

var products: [Product] = [
    .library(name: "ConfigKit", targets: ["ConfigKit"]),
    .library(name: "CityKit", targets: ["CityKit"]),
]
var targets: [Target] = [
    .target(name: "ConfigKit", swiftSettings: v5),
    .target(name: "CityKit", dependencies: ["ConfigKit"], swiftSettings: v5),
    .testTarget(name: "ConfigKitTests", dependencies: ["ConfigKit"], swiftSettings: v5),
    .testTarget(name: "CityKitTests", dependencies: ["CityKit", "ConfigKit"], swiftSettings: v5),
]
#if os(macOS)
products += [
    .library(name: "SpacesKit", targets: ["SpacesKit"]),
    .library(name: "DockKit", targets: ["DockKit"]),
    .executable(name: "dock-city", targets: ["Dockman"]),
    .executable(name: "dockman-spike", targets: ["DockmanSpike"]),
]
targets += [
    .target(name: "SpacesKit", swiftSettings: v5),
    .target(name: "DockKit", dependencies: ["SpacesKit", "ConfigKit", "CityKit"], swiftSettings: v5),
    .executableTarget(name: "Dockman", dependencies: ["DockKit", "SpacesKit", "ConfigKit"], swiftSettings: v5),
    .executableTarget(name: "DockmanSpike", dependencies: ["SpacesKit"], swiftSettings: v5),
    .testTarget(name: "SpacesKitTests", dependencies: ["SpacesKit"], swiftSettings: v5),
    .testTarget(name: "DockKitTests", dependencies: ["DockKit", "SpacesKit", "ConfigKit", "CityKit"], swiftSettings: v5),
]
#endif
let package = Package(
    name: "DockCity",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
