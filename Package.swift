// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "health-sync",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "health-sync",
            path: "Sources/health-sync",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=targeted"])
            ]
        )
    ]
)
