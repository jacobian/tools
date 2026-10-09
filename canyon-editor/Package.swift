// swift-tools-version: 6.0
import PackageDescription

// No dependencies: SQLite comes from the system library, the UI from SwiftUI.
let package = Package(
    name: "CanyonEditor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "CanyonEditor", path: "Sources/CanyonEditor")
    ]
)
