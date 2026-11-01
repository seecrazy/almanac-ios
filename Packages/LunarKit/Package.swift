// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LunarKit",
    products: [
        .library(name: "LunarKit", targets: ["LunarKit"]),
        .executable(name: "lunar-sanity", targets: ["LunarSanity"]),
    ],
    targets: [

        .target(name: "LunarKit"),
        .executableTarget(
            name: "LunarSanity",
            dependencies: ["LunarKit"],
            path: "Sources/LunarSanity"
        ),
        .testTarget(
            name: "LunarKitTests",
            dependencies: ["LunarKit"],
            path: "Tests/LunarKitTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
