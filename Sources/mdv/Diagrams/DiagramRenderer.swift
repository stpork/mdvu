import CryptoKit
import Foundation

struct DiagramRenderOptions { let theme: String }
struct DiagramResult { let svg: String }

protocol DiagramRenderer {
    var identifier: String { get }
    var version: String { get }
    func canRender(language: String) -> Bool
    func render(source: String, options: DiagramRenderOptions) async throws -> DiagramResult
    func placeholder(source: String, theme: String, cache: DiagramCache) -> String
}

struct DiagramRegistry {
    let renderers: [any DiagramRenderer]
    func renderer(for language: String) -> (any DiagramRenderer)? { renderers.first { $0.canRender(language: language.lowercased()) } }
}

struct MermaidRenderer: DiagramRenderer {
    let identifier = "mermaid"; let version = "11.12.2"
    func canRender(language: String) -> Bool { language == "mermaid" }
    func render(source: String, options: DiagramRenderOptions) async throws -> DiagramResult { throw MermaidError.webRuntimeRequired }
    func placeholder(source: String, theme: String, cache: DiagramCache) -> String {
        let key = cache.key(renderer: identifier, version: version, source: source, theme: theme, options: "strict")
        if let svg = cache.read(key: key) { return "<figure class=\"diagram diagram-cached\">\(svg)</figure>" }
        return "<figure class=\"diagram diagram-pending\" data-renderer=\"mermaid\" data-cache-key=\"\(key)\"><pre>\(HTML.escape(source))</pre><div class=\"diagram-status\">Rendering diagram…</div></figure>"
    }
    enum MermaidError: Error { case webRuntimeRequired }
}

final class DiagramCache: @unchecked Sendable {
    private let directory: URL
    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("com.mdv.viewer/diagrams", isDirectory: true)
    }
    func key(renderer: String, version: String, source: String, theme: String, options: String) -> String {
        SHA256.hash(data: Data("\(renderer)\u{0}\(version)\u{0}\(source)\u{0}\(theme)\u{0}\(options)".utf8)).map { String(format: "%02x", $0) }.joined()
    }
    func read(key: String) -> String? { try? String(contentsOf: directory.appendingPathComponent(key + ".svg"), encoding: .utf8) }
    func write(key: String, svg: String) {
        guard key.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil, svg.hasPrefix("<svg"), svg.utf8.count < 10_000_000 else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? svg.write(to: directory.appendingPathComponent(key + ".svg"), atomically: true, encoding: .utf8)
    }
}
