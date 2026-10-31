// swift-tools-version:5.3
// 注：testTarget 待安装完整 Xcode 后恢复（见 Tests/LunarKitTests）
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
    ]
)
