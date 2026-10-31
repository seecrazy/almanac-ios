// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "HolidayData",
    products: [
        .library(name: "HolidayData", targets: ["HolidayData"]),
        .executable(name: "holiday-sanity", targets: ["HolidayDataSanity"]),
    ],
    targets: [
        .target(name: "HolidayData", resources: [.copy("Resources/holiday-2026.json")]),
        .executableTarget(name: "HolidayDataSanity", dependencies: ["HolidayData"], path: "Sources/HolidayDataSanity"),
    ]
)
