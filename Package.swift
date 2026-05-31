// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Haze",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "Haze",
            path: "Sources/Haze",
            resources: [
                .process("Shaders")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
