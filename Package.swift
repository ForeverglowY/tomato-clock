// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TomatoClock",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TomatoClock", targets: ["TomatoClock"])
    ],
    targets: [
        .executableTarget(name: "TomatoClock")
    ]
)
