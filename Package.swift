// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Rayna",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Rayna", path: "Sources/Rayna")
    ]
)
