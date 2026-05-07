// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MousePhone",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "MousePhoneShared",
            targets: ["MousePhoneShared"]
        )
    ],
    targets: [
        .target(
            name: "MousePhoneShared",
            path: "Sources/MousePhoneShared"
        ),
        .testTarget(
            name: "MousePhoneSharedTests",
            dependencies: ["MousePhoneShared"],
            path: "Tests/MousePhoneSharedTests"
        )
    ]
)
