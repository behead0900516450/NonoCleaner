// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NonoCleaner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NonoCleaner", targets: ["NonoCleanerApp"])
    ],
    targets: [
        .executableTarget(
            name: "NonoCleanerApp",
            path: "Sources/NonoCleanerApp"
        )
    ],
    swiftLanguageVersions: [.v5]
)
