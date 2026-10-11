// swift-tools-version: 6.0
// The app itself is built with TheNewBible.xcodeproj. This package exposes the
// UI-independent core (models, parsers, data loading) so it can be tested with
// `swift test` on macOS or Linux.
import PackageDescription

let package = Package(
    name: "TheNewBibleCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BibleCore", targets: ["BibleCore"]),
    ],
    targets: [
        .target(
            name: "BibleCore",
            path: "TheNewBible/Core"
        ),
        .testTarget(
            name: "BibleCoreTests",
            dependencies: ["BibleCore"],
            path: "Tests/BibleCoreTests"
        ),
    ]
)
