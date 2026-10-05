// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DOTMD",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DOTMD", targets: ["DOTMD"]),
        .executable(name: "dotmd-agent", targets: ["DOTMDAgent"])
    ],
    targets: [
        .executableTarget(
            name: "DOTMD",
            dependencies: ["DOTMDLocalization"],
            path: "Sources/DOTMD",
            resources: [.copy("Resources")]
        ),
        .target(name: "DOTMDLocalization", path: "Sources/DOTMDLocalization"),
        .executableTarget(name: "DOTMDAgent", dependencies: ["DOTMDLocalization"], path: "Sources/DOTMDAgent")
    ]
)
