// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MDAnyWhere",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MDAnyWhere", targets: ["MDAnyWhere"]),
        .executable(name: "md-any-where-agent", targets: ["MDAnyWhereAgent"])
    ],
    targets: [
        .executableTarget(
            name: "MDAnyWhere",
            dependencies: ["MDAnyWhereLocalization"],
            path: "Sources/MDAnyWhere",
            resources: [.copy("Resources")]
        ),
        .target(name: "MDAnyWhereLocalization", path: "Sources/MDAnyWhereLocalization"),
        .executableTarget(name: "MDAnyWhereAgent", dependencies: ["MDAnyWhereLocalization"], path: "Sources/MDAnyWhereAgent")
    ]
)
