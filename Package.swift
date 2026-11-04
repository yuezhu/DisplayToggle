// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DisplayToggle",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DisplayToggleCore"),
        .testTarget(name: "DisplayToggleCoreTests", dependencies: ["DisplayToggleCore"]),
    ]
)
