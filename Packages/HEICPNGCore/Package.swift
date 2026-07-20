// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HEICPNGCore",
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
        .target(name: "HEICPNGCore"),
        .testTarget(
            name: "HEICPNGCoreTests",
            dependencies: ["HEICPNGCore"]
        )
    ]
)

