// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sweep",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Sweep", targets: ["Sweep"]),
    ],
    dependencies: [
        // In-app updates. Pinned: the release tools come from the same version.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        // Pure logic: gesture recognition, grid and snap geometry, screen direction mapping.
        // No AppKit/AX calls here, so every rule can be unit-tested headless.
        .target(name: "SweepCore"),
        // The menu bar app: input taps, Accessibility window control, settings UI.
        .executableTarget(
            name: "Sweep",
            dependencies: ["SweepCore", .product(name: "Sparkle", package: "Sparkle")],
            // Sparkle.framework is embedded in Sweep.app/Contents/Frameworks by scripts/bundle.sh.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "SweepCoreTests", dependencies: ["SweepCore"]),
    ]
)
