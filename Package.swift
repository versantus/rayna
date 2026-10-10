// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Rayna",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "RaynaCore", targets: ["RaynaCore"])
    ],
    targets: [
        // Shared, platform-neutral SwiftUI: Rayna drawing, water, confetti, copy, and the shared store.
        .target(name: "RaynaCore", path: "Sources/RaynaCore"),
        // macOS menu-bar app (built by ./build.sh)
        .executableTarget(name: "Rayna", dependencies: ["RaynaCore"], path: "Sources/Rayna")
    ]
)
