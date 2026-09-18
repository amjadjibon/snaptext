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
            dependencies: ["SnapTextKit"]
        ),
        .target(
            name: "SnapTextKit",
            plugins: ["VersionStamp"]
        ),
        .plugin(
            name: "VersionStamp",
            capability: .buildTool()
        ),
        .testTarget(
            name: "SnapTextKitTests",
            dependencies: ["SnapTextKit"]
        )
    ]
)
