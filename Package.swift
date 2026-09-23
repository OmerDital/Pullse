// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pullse",
    platforms: [.macOS(.v14)],
    targets: [
        // Everything that doesn't need AppKit/SwiftUI: GitHub access, models and the
        // event detector. Kept separate so it can be unit-tested.
        .target(name: "PullseCore"),
        .executableTarget(name: "Pullse", dependencies: ["PullseCore"]),
        .testTarget(name: "PullseTests", dependencies: ["PullseCore"]),
    ]
)
