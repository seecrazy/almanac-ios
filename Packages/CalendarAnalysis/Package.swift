// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CalendarAnalysis",
    products: [
        .library(name: "CalendarAnalysis", targets: ["CalendarAnalysis"])
    ],
    targets: [
        .target(name: "CalendarAnalysis"),
        .testTarget(
            name: "CalendarAnalysisTests",
            dependencies: ["CalendarAnalysis"],
            path: "Tests/CalendarAnalysisTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
