// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "EventSearchKit",
    products: [
        .library(name: "EventSearchKit", targets: ["EventSearchKit"])
    ],
    targets: [
        .target(
            name: "EventSearchKit",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "EventSearchKitTests",
            dependencies: ["EventSearchKit"],
            path: "Tests/EventSearchKitTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
