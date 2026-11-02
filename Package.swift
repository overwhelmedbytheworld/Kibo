// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kibo",
    platforms: [.macOS(.v15)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "KiboKit"),
        .executableTarget(
            name: "Kibo",
            dependencies: ["KiboKit"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "KiboKitTests", dependencies: ["KiboKit"]),
    ]
)
