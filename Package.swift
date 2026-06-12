// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ManagedPreferencesKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ManagedPreferencesKit",
            targets: ["ManagedPreferencesKit"]
        ),
        .library(
            name: "ManagedPreferencesUI",
            targets: ["ManagedPreferencesUI"]
        )
    ],
    targets: [
        .target(name: "ManagedPreferencesKit"),
        .target(
            name: "ManagedPreferencesUI",
            dependencies: ["ManagedPreferencesKit"]
        ),
        .testTarget(
            name: "ManagedPreferencesKitTests",
            dependencies: [
                "ManagedPreferencesKit",
                "ManagedPreferencesUI"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
