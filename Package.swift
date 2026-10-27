// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "simlet",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "simlet", targets: ["simlet"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "simlet",
            dependencies: [
                "SimletKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(name: "SimletKit"),
        .testTarget(name: "SimletKitTests", dependencies: ["SimletKit"]),
    ]
)
