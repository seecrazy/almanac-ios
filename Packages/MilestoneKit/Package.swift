// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MilestoneKit",
    products: [
        .library(name: "MilestoneKit", targets: ["MilestoneKit"])
    ],
    targets: [
        .target(name: "MilestoneKit"),
        .testTarget(
            name: "MilestoneKitTests",
            dependencies: ["MilestoneKit"],
            path: "Tests/MilestoneKitTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
