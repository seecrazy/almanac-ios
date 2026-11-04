// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NaturalInput",
    products: [
        .library(name: "NaturalInput", targets: ["NaturalInput"])
    ],
    targets: [
        .target(
            name: "NaturalInput",
            resources: [
                .process("Resources/natural-input-rules.json")
            ]
        ),
        .testTarget(
            name: "NaturalInputTests",
            dependencies: ["NaturalInput"],
            path: "Tests/NaturalInputTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
