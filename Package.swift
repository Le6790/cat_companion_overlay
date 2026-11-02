// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CatCompanionOverlay",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CatCompanionOverlay",
            path: "Sources/CatCompanionOverlay",
            resources: [.copy("sprites")]
        )
    ]
)
