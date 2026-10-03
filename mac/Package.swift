// swift-tools-version: 6.0
// Swaybles — native Mac app. Open this file in Xcode (⌘R to run, ⌘U to test),
// or from Terminal: `swift run Swaybles`, `swift test`, `scripts/make-app.sh`.
import PackageDescription

let package = Package(
    name: "Swaybles",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Swaybles", targets: ["Swaybles"])
    ],
    targets: [
        // Pure logic, no AppKit: rope physics, day counter, catalog, settings, copy.
        .target(name: "SwayblesCore"),
        // The app: menu bar, transparent overlay, Studio window.
        .executableTarget(name: "Swaybles", dependencies: ["SwayblesCore"]),
        .testTarget(name: "SwayblesCoreTests", dependencies: ["SwayblesCore"]),
        // The app layer: AppModel (state, focus, idle, what each charm says) and the overlay's geometry.
        .testTarget(name: "SwayblesAppTests", dependencies: ["Swaybles", "SwayblesCore"])
    ],
    swiftLanguageModes: [.v5]
)
