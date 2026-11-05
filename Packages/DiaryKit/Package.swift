// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DiaryKit",
    products: [
        .library(name: "DiaryKit", targets: ["DiaryKit"])
    ],
    targets: [
        .target(
            name: "DiaryKit",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "DiaryKitTests",
            dependencies: ["DiaryKit"],
            path: "Tests/DiaryKitTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
