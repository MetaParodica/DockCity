// swift-tools-version: 6.0
import PackageDescription

// Dock City follows the system Dock. Portable models are tested on Linux;
// the read-only tracker, decoration window and app require macOS 14+.
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
    .library(name: "DockKit", targets: ["DockKit"]),
    .executable(name: "dock-city", targets: ["Dockman"]),
    .executable(name: "dock-city-overlay-probe", targets: ["DockCityOverlayProbe"]),
]
targets += [
    .target(name: "DockKit", dependencies: ["ConfigKit", "CityKit"], swiftSettings: v5),
    .executableTarget(name: "Dockman", dependencies: ["DockKit", "ConfigKit"], swiftSettings: v5),
    .executableTarget(name: "DockCityOverlayProbe", dependencies: ["DockKit", "CityKit"], swiftSettings: v5),
    .testTarget(name: "DockKitTests", dependencies: ["DockKit", "ConfigKit", "CityKit"], swiftSettings: v5),
]
#endif
let package = Package(
    name: "DockCity",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
