// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HEICToPNGWorkspace",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "HEICPNGCore",
            targets: ["HEICPNGCore"]
        )
    ],
    targets: [
        .target(
            name: "HEICPNGCore",
            path: "Packages/HEICPNGCore/Sources/HEICPNGCore"
        ),
        .testTarget(
            name: "HEICPNGCoreTests",
            dependencies: ["HEICPNGCore"],
            path: "Packages/HEICPNGCore/Tests/HEICPNGCoreTests"
        )
    ]
)

