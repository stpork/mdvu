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
    let identifier = "mermaid"; let version = "11.17.2"
    func canRender(language: String) -> Bool { language == "mermaid" }
    func render(source: String, options: DiagramRenderOptions) async throws -> DiagramResult { throw MermaidError.webRuntimeRequired }
    func placeholder(source: String, theme: String, cache: DiagramCache) -> String {
        let key = cache.key(renderer: identifier, version: version, source: source, theme: theme, options: "strict-transparent-v1")
        if let svg = cache.read(key: key) { return "<figure class=\"diagram diagram-cached\">\(svg)</figure>" }
        return "<figure class=\"diagram diagram-pending\" data-renderer=\"mermaid\" data-cache-key=\"\(key)\"><pre>\(HTML.escape(source))</pre><div class=\"diagram-status\">Rendering diagram…</div></figure>"
    }
    enum MermaidError: Error { case webRuntimeRequired }
}

struct PlantUMLRenderer: DiagramRenderer {
    let identifier = "plantuml"; let version = "1.2026.7"
    func canRender(language: String) -> Bool { language == "plantuml" || language == "puml" }
    func render(source: String, options: DiagramRenderOptions) async throws -> DiagramResult { throw PlantUMLError.webRuntimeRequired }
    func placeholder(source: String, theme: String, cache: DiagramCache) -> String {
        let key = cache.key(renderer: identifier, version: version, source: source, theme: theme, options: "plantuml-transparent-v1")
        if let svg = cache.read(key: key) { return "<figure class=\"diagram diagram-cached\">\(svg)</figure>" }
        return "<figure class=\"diagram diagram-pending\" data-renderer=\"plantuml\" data-cache-key=\"\(key)\"><pre>\(HTML.escape(source))</pre><div class=\"diagram-status\">Rendering diagram…</div></figure>"
    }
    enum PlantUMLError: Error { case webRuntimeRequired }
}


final class DiagramCache: @unchecked Sendable {
    private let directory: URL
    private let memoryCache = NSCache<NSString, NSString>()

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("com.mdvu.viewer/diagrams", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memoryCache.countLimit = 128
    }

    func key(renderer: String, version: String, source: String, theme: String, options: String) -> String {
        var hasher = SHA256()
        renderer.withCString { hasher.update(bufferPointer: UnsafeRawBufferPointer(start: $0, count: strlen($0))) }
        hasher.update(data: [0])
        version.withCString { hasher.update(bufferPointer: UnsafeRawBufferPointer(start: $0, count: strlen($0))) }
        hasher.update(data: [0])
        source.withCString { hasher.update(bufferPointer: UnsafeRawBufferPointer(start: $0, count: strlen($0))) }
        hasher.update(data: [0])
        theme.withCString { hasher.update(bufferPointer: UnsafeRawBufferPointer(start: $0, count: strlen($0))) }
        hasher.update(data: [0])
        options.withCString { hasher.update(bufferPointer: UnsafeRawBufferPointer(start: $0, count: strlen($0))) }
        let digest = hasher.finalize()

        return digest.reduce(into: "") { str, byte in
            let hi = byte >> 4
            let lo = byte & 0x0f
            str.append(Character(UnicodeScalar(hi < 10 ? 48 + hi : 87 + hi)))
            str.append(Character(UnicodeScalar(lo < 10 ? 48 + lo : 87 + lo)))
        }
    }

    func read(key: String) -> String? {
        let nsKey = key as NSString
        if let cached = memoryCache.object(forKey: nsKey) { return cached as String }
        guard let diskContent = try? String(contentsOf: directory.appendingPathComponent(key + ".svg"), encoding: .utf8) else { return nil }
        memoryCache.setObject(diskContent as NSString, forKey: nsKey)
        return diskContent
    }

    func write(key: String, svg: String) {
        guard key.utf8.count == 64 && key.allSatisfy({ $0.isHexDigit }), svg.hasPrefix("<svg"), svg.utf8.count < 10_000_000 else { return }
        memoryCache.setObject(svg as NSString, forKey: key as NSString)
        try? svg.write(to: directory.appendingPathComponent(key + ".svg"), atomically: true, encoding: .utf8)
    }
}
