// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FocusToggle",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "FocusToggle",
            path: "Sources/FocusToggle"
        ),
        .testTarget(
            name: "FocusToggleTests",
            dependencies: ["FocusToggle"],
            path: "Tests/FocusToggleTests"
        )
    ]
)
