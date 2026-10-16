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
            path: ".",
            exclude: ["src/core", "src/windows", "tests", "vendor", "packaging", "scripts", "dist", "target", "test-results", ".github", "README.md", "ARCHITECTURE.md", "COMPARISON.md", "CHANGELOG.md", "LICENSE", "Makefile", "Cargo.toml", "Cargo.lock", "version.txt", "build.sh", "build.ps1", "build.cmd"],
            sources: ["src/macos"],
            resources: [.process("assets")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "mdvuTests", dependencies: ["mdvu"], path: "tests/macos")
    ]
)
