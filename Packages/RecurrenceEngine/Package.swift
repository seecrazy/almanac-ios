// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "RecurrenceEngine",
    products: [
        .library(name: "RecurrenceEngine", targets: ["RecurrenceEngine"]),
        .executable(name: "recurrence-sanity", targets: ["RecurrenceSanity"]),
    ],
    targets: [
        .target(name: "RecurrenceEngine"),
        .executableTarget(name: "RecurrenceSanity", dependencies: ["RecurrenceEngine"], path: "Sources/RecurrenceSanity"),
    ]
)
