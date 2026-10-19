// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mdvu",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "mdvu", targets: ["mdvu"])],
    targets: [
        .executableTarget(
            name: "mdvu",
            path: ".",
            exclude: ["assets/app.js", "assets/diagram-output.js", "assets/plantuml-adapter.mjs", "assets/markdown.css", "assets/mermaid.lzma", "assets/plantuml.lzma", "assets/katex.lzma", "src/core", "src/windows", "tests", "packaging", "scripts", "dist", "target", "test-results", ".github", "README.md", "ARCHITECTURE.md", "COMPARISON.md", "CHANGELOG.md", "LICENSE", "Makefile", "Cargo.toml", "Cargo.lock", "version.txt", "build.sh", "build.ps1", "build.cmd"],
            sources: ["src/macos"],
            resources: [.process("assets/diagram-renderer.js"), .process("assets/sidebar-policy.json"), .process("assets/toc-tree.js")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "mdvuTests", dependencies: ["mdvu"], path: "tests/macos")
    ]
)
