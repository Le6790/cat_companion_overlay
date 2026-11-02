// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CatPartnerOverlay",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CatPartnerOverlay",
            path: "Sources/CatPartnerOverlay",
            resources: [.copy("sprites")]
        )
    ]
)
