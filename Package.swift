// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HotkeyDetective",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "Engine"),
        .target(name: "Probe", dependencies: ["Engine"]),
        .executableTarget(name: "HotkeyDetective", dependencies: ["Engine", "Probe"],
                          resources: [.process("Resources")]),
        .testTarget(name: "AppTests", dependencies: ["HotkeyDetective"]),
        .testTarget(name: "EngineTests", dependencies: ["Engine"], resources: [.copy("Fixtures")]),
    ],
    swiftLanguageVersions: [.v5]
)
