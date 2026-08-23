// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HotkeyDetective",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "Engine"),
        .target(name: "Probe", dependencies: ["Engine"]),
        .executableTarget(name: "HotkeyDetective", dependencies: ["Engine", "Probe"]),
        .testTarget(name: "EngineTests", dependencies: ["Engine"], resources: [.copy("Fixtures")]),
    ],
    swiftLanguageVersions: [.v5]
)
