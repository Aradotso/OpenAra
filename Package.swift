// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OpenAra",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "OpenAraKit",
            targets: ["OpenAraKit"]
        ),
        .executable(
            name: "OpenAra",
            targets: ["OpenAra"]
        ),
        .executable(
            name: "OpenAraFixture",
            targets: ["OpenAraFixture"]
        ),
        .executable(
            name: "OpenAraSmokeSuite",
            targets: ["OpenAraSmokeSuite"]
        ),
        .executable(
            name: "CursorMotion",
            targets: ["CursorMotion"]
        ),
        .executable(
            name: "StandaloneCursor",
            targets: ["StandaloneCursor"]
        ),
        .executable(
            name: "OpenAraCursorNarrator",
            targets: ["OpenAraCursorNarrator"]
        ),
    ],
    targets: [
        .target(
            name: "OpenAraKit",
            path: "packages/OpenAraKit/Sources/OpenAraKit",
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "OpenAra",
            dependencies: ["OpenAraKit"],
            path: "apps/OpenAra/Sources/OpenAra"
        ),
        .executableTarget(
            name: "OpenAraFixture",
            dependencies: ["OpenAraKit"],
            path: "apps/OpenAraFixture/Sources/OpenAraFixture"
        ),
        .executableTarget(
            name: "OpenAraSmokeSuite",
            dependencies: ["OpenAraKit"],
            path: "apps/OpenAraSmokeSuite/Sources/OpenAraSmokeSuite"
        ),
        .executableTarget(
            name: "CursorMotion",
            path: "experiments/CursorMotion/Sources/CursorMotion"
        ),
        .target(
            name: "StandaloneCursorSupport",
            path: "experiments/StandaloneCursor/Sources/StandaloneCursorSupport"
        ),
        .executableTarget(
            name: "StandaloneCursor",
            dependencies: ["StandaloneCursorSupport"],
            path: "experiments/StandaloneCursor/Sources/StandaloneCursor"
        ),
        .executableTarget(
            name: "OpenAraCursorNarrator",
            dependencies: ["OpenAraKit"],
            path: "apps/OpenAraCursorNarrator/Sources/OpenAraCursorNarrator"
        ),
        .testTarget(
            name: "OpenAraKitTests",
            dependencies: ["OpenAraKit"],
            path: "packages/OpenAraKit/Tests/OpenAraKitTests"
        ),
        .testTarget(
            name: "StandaloneCursorSupportTests",
            dependencies: ["StandaloneCursorSupport"],
            path: "experiments/StandaloneCursor/Tests/StandaloneCursorSupportTests"
        ),
    ]
)
