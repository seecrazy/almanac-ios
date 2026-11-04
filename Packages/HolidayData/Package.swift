// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HolidayData",
    products: [
        .library(name: "HolidayData", targets: ["HolidayData"]),
        .executable(name: "holiday-sanity", targets: ["HolidayDataSanity"]),
    ],
    targets: [

        .target(name: "HolidayData",
                resources: [
                    .copy("Resources/holiday-manifest.json"),
                    .copy("Resources/holiday-2026.json"),
                    .copy("Resources/holiday-2027.json"),
                ],
                swiftSettings: [.define("SWIFTPM")]),
        .executableTarget(name: "HolidayDataSanity", dependencies: ["HolidayData"], path: "Sources/HolidayDataSanity"),
        .testTarget(
            name: "HolidayDataTests",
            dependencies: ["HolidayData"],
            path: "Tests/HolidayDataTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
