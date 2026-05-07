// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Kord",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Kord",
            dependencies: ["Yams"],
            path: "Sources/Kord",
            resources: [
                .copy("Resources/default_dictionary.yaml")
            ]
        ),
        .testTarget(
            name: "KordTests",
            dependencies: ["Kord"],
            path: "Tests/KordTests"
        )
    ]
)
