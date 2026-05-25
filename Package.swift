// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FocusGuard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FocusGuard", targets: ["FocusGuard"]),
        .executable(name: "FocusGuardChecks", targets: ["FocusGuardChecks"]),
        .library(name: "FocusGuardCore", targets: ["FocusGuardCore"])
    ],
    targets: [
        .target(
            name: "FocusGuardCore"
        ),
        .executableTarget(
            name: "FocusGuard",
            dependencies: ["FocusGuardCore"],
            path: "Sources/FocusGuardApp"
        ),
        .executableTarget(
            name: "FocusGuardChecks",
            dependencies: ["FocusGuardCore"],
            path: "Tests/FocusGuardChecks"
        )
    ]
)
