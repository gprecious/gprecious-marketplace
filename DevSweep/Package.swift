// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DevSweep",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DevSweepCore", targets: ["DevSweepCore"])
    ],
    targets: [
        .target(name: "DevSweepCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "DevSweepApp", dependencies: ["DevSweepCore"]),
        .testTarget(name: "DevSweepCoreTests", dependencies: ["DevSweepCore"])
    ]
)
