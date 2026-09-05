import CryptoKit
import Foundation

struct DiagramRenderOptions { let theme: String }
struct DiagramResult { let svg: String }

protocol DiagramRenderer {
    var identifier: String { get }
    var version: String { get }
    func canRender(language: some StringProtocol) -> Bool
    func render(source: String, options: DiagramRenderOptions) async throws -> DiagramResult
    func placeholder(source: String, theme: String, cache: DiagramCache) -> String
}

struct DiagramRegistry {
    let renderers: [any DiagramRenderer]
    func renderer(for language: some StringProtocol) -> (any DiagramRenderer)? {
        renderers.first { $0.canRender(language: language) }
    }
}

struct MermaidRenderer: DiagramRenderer {
    let identifier = "mermaid"; let version = "11.17.2"
    func canRender(language: some StringProtocol) -> Bool {
        language.compare("mermaid", options: .caseInsensitive) == .orderedSame
    }
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
    func canRender(language: some StringProtocol) -> Bool {
        language.compare("plantuml", options: .caseInsensitive) == .orderedSame ||
        language.compare("puml", options: .caseInsensitive) == .orderedSame
    }
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
    private let directoryPath: String
    private let memoryCache = NSCache<NSString, NSString>()
    private static let hexDigits: [UInt8] = Array("0123456789abcdef".utf8)

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("com.mdvu.viewer/diagrams", isDirectory: true)
        directory = dir
        directoryPath = dir.path
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        memoryCache.countLimit = 128
    }

    func key(renderer: String, version: String, source: String, theme: String, options: String) -> String {
        var hasher = SHA256()
        var zero: UInt8 = 0
        func appendSegment(_ str: String) {
            str.withCString { ptr in
                hasher.update(bufferPointer: UnsafeRawBufferPointer(start: ptr, count: str.utf8.count))
            }
            withUnsafeBytes(of: &zero) { hasher.update(bufferPointer: $0) }
        }
        appendSegment(renderer)
        appendSegment(version)
        appendSegment(source)
        appendSegment(theme)
        appendSegment(options)
        let digest = hasher.finalize()

        return String(unsafeUninitializedCapacity: 64) { buffer in
            var idx = 0
            for byte in digest {
                buffer[idx] = Self.hexDigits[Int(byte >> 4)]
                buffer[idx + 1] = Self.hexDigits[Int(byte & 0x0f)]
                idx += 2
            }
            return 64
        }
    }

    func read(key: String) -> String? {
        let nsKey = key as NSString
        if let cached = memoryCache.object(forKey: nsKey) { return cached as String }
        let filePath = directoryPath + "/" + key + ".svg"
        guard access(filePath, R_OK) == 0 else { return nil }
        guard let diskContent = try? String(contentsOfFile: filePath, encoding: .utf8) else { return nil }
        memoryCache.setObject(diskContent as NSString, forKey: nsKey)
        return diskContent
    }

    func write(key: String, svg: String) {
        guard key.utf8.count == 64 && key.allSatisfy({ $0.isHexDigit }), svg.hasPrefix("<svg"), svg.utf8.count < 10_000_000 else { return }
        memoryCache.setObject(svg as NSString, forKey: key as NSString)
        let filePath = directoryPath + "/" + key + ".svg"
        try? svg.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
}
