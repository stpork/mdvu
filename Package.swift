// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mdv",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "mdv", targets: ["mdv"])],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-cmark.git", exact: "0.8.0")
    ],
    targets: [
        .executableTarget(
            name: "mdv",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark")
            ],
            path: "Sources/mdv",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "mdvTests", dependencies: ["mdv"], path: "Tests/mdvTests")
    ]
)
