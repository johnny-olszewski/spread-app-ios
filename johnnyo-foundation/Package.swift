// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "johnnyo-foundation",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "JohnnyOFoundationCore",
            targets: ["JohnnyOFoundationCore"]
        ),
        .library(
            name: "JohnnyOFoundationUI",
            targets: ["JohnnyOFoundationUI"]
        ),
    ],
    targets: [
        .target(
            name: "JohnnyOFoundationCore"
        ),
        .target(
            name: "JohnnyOFoundationUI",
            dependencies: ["JohnnyOFoundationCore"]
        ),
        .testTarget(
            name: "JohnnyOFoundationCoreTests",
            dependencies: ["JohnnyOFoundationCore"]
        ),
        .testTarget(
            name: "JohnnyOFoundationUITests",
            dependencies: ["JohnnyOFoundationUI"]
        ),
    ]
)
