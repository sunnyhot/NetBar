// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NetBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NetBar", targets: ["NetBar"])
    ],
    targets: [
        .executableTarget(
            name: "NetBar",
            path: "Sources/NetBar",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "NetBarTests",
            dependencies: ["NetBar"],
            path: "Tests/NetBarTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
