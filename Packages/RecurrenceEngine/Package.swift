// swift-tools-version:6.0
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
        .testTarget(
            name: "RecurrenceEngineTests",
            dependencies: ["RecurrenceEngine"],
            path: "Tests/RecurrenceEngineTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
