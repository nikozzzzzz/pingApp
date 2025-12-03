// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PingApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PingApp", targets: ["PingApp"]),
        .executable(name: "PingTest", targets: ["PingTest"]),
    ],
    dependencies: [
        // No external dependencies needed - using system ping command
    ],
    targets: [
        .executableTarget(
            name: "PingApp",
            dependencies: [],
            resources: [
                // .process("Resources") 
            ]
        ),
        .executableTarget(
            name: "PingTest",
            dependencies: [],
            path: "Tests/PingTest"
        ),
    ]
)
