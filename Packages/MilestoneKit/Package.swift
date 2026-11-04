// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MilestoneKit",
    products: [
        .library(name: "MilestoneKit", targets: ["MilestoneKit"])
    ],
    dependencies: [
        .package(path: "../LunarKit")
    ],
    targets: [
        .target(
            name: "MilestoneKit",
            dependencies: [
                .product(name: "LunarKit", package: "lunarkit")
            ]
        ),
        .testTarget(
            name: "MilestoneKitTests",
            dependencies: ["MilestoneKit"],
            path: "Tests/MilestoneKitTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
