// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "EventKitMapping",
    products: [
        .library(name: "EventKitMapping", targets: ["EventKitMapping"])
    ],
    targets: [
        .target(name: "EventKitMapping"),
        .testTarget(
            name: "EventKitMappingTests",
            dependencies: ["EventKitMapping"],
            path: "Tests/EventKitMappingTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
