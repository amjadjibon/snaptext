// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SnapText",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "snaptext",
            targets: ["SnapText"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SnapText",
            dependencies: ["SnapTextCommandLine"]
        ),
        // macOS only: argument parsing, screen capture, and the version stamp.
        .target(
            name: "SnapTextCommandLine",
            dependencies: ["SnapTextKit"],
            plugins: ["VersionStamp"]
        ),
        .target(
            name: "SnapTextKit"
        ),
        .plugin(
            name: "VersionStamp",
            capability: .buildTool()
        ),
        .testTarget(
            name: "SnapTextKitTests",
            dependencies: ["SnapTextKit", "SnapTextCommandLine"]
        )
    ]
)
