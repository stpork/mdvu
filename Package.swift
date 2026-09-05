// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mdvu",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "mdvu", targets: ["mdvu"])],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-cmark.git", exact: "0.8.0")
    ],
    targets: [
        .executableTarget(
            name: "mdvu",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark")
            ],
            path: "Sources/mdvu",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "mdvuTests", dependencies: ["mdvu"], path: "Tests/mdvuTests")
    ]
)
