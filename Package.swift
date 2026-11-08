// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "GitDesk",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "GitDeskCore", targets: ["GitDeskCore"]),
        .executable(name: "GitDeskApp", targets: ["GitDeskApp"]),
        .executable(name: "gitdesk", targets: ["gitdesk"]),
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "GitDeskCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "GitDeskApp", dependencies: ["GitDeskCore"]),
        .executableTarget(name: "gitdesk", dependencies: ["GitDeskCore"]),
        .testTarget(name: "GitDeskCoreTests", dependencies: ["GitDeskCore"]),
    ]
)
