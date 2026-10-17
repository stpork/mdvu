import Foundation

enum HTMLDocument {
    static func make(body: String, title: String, theme: ThemeChoice, fullWidth: Bool = false, baseURL: URL? = nil, embedEngines: Bool = false) -> String {
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var engines = ""
        if embedEngines {
            if body.contains("math-inline") || body.contains("math-display") { engines += "<script nonce=\"\(nonce)\">\(ResourceLoader.katexJavaScript)</script>" }
            if body.contains("data-renderer=\"mermaid\"") { engines += "<script nonce=\"\(nonce)\">\(ResourceLoader.mermaidJavaScript)</script>" }
            if body.contains("data-renderer=\"plantuml\"") { engines += "<script nonce=\"\(nonce)\">\(ResourceLoader.plantumlJavaScript)</script>" }
        }
        let baseTag = baseURL.map { "<base href=\"\($0.absoluteString)\">" } ?? ""
        return """
        <!doctype html><html class="\(fullWidth ? "full-width" : "")" data-theme="\(theme.rawValue)"><head><meta charset="utf-8">
        <meta name="mdvu-script-nonce" content="\(nonce)">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-\(nonce)' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'unsafe-inline' data: file:; img-src file: data: blob: https: http:; font-src file: data:; worker-src blob:; connect-src 'none'; frame-src about:; object-src 'none'; form-action 'none'">
        \(baseTag)
        <meta name="viewport" content="width=device-width,initial-scale=1"><title>\(HTML.escape(title))</title>
        <style>\(ResourceLoader.markdownCSS)</style>
        <style>@media(max-width:900px){article{padding-left:30px;padding-right:30px}}@media(max-width:700px){article{padding-left:22px;padding-right:22px}}</style></head><body><article>\(body)</article>
        \(engines)<script nonce="\(nonce)">\(ResourceLoader.appJavaScript)</script></body></html>
        """
    }
}

enum ResourceLoader {
    static let bundle: Bundle = {
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("mdvu_mdvu.bundle"),
            Bundle.main.resourceURL,
            Bundle.main.bundleURL.appendingPathComponent("mdvu_mdvu.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/mdvu_mdvu.bundle"),
            Bundle.main.bundleURL
        ]
        for candidate in candidates {
            if let candidate, let b = Bundle(url: candidate), b.url(forResource: "markdown", withExtension: "css") != nil {
                return b
            }
        }
        return Bundle.module
    }()

    static let markdownCSS: String = MdvuCoreBridge.shared.markdownCSS ?? text("markdown", "css")
    static let appJavaScript: String = MdvuCoreBridge.shared.appJavaScript ?? text("app", "js")
    static let tocTreeJavaScript = text("toc-tree", "js")
    static let sidebarPolicyJSON = text("sidebar-policy", "json")
    static let diagramRendererJavaScript = text("diagram-renderer", "js")
    static var mermaidJavaScript: String {
        if let script = MdvuCoreBridge.shared.mermaidJavaScript { return script }
        let source = compressedText("mermaid")
        let data = try! JSONSerialization.data(withJSONObject: source, options: [.fragmentsAllowed])
        let literal = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "<", with: "\\u003c")
        return "(()=>{const load=()=>window.__mdvuLoadMermaid(\(literal));if(window.__mdvuLoadMermaid)load();else document.addEventListener('DOMContentLoaded',load,{once:true})})();"
    }
    static var plantumlJavaScript: String { MdvuCoreBridge.shared.plantumlJavaScript ?? compressedText("plantuml") }
    static var katexJavaScript: String { MdvuCoreBridge.shared.katexJavaScript ?? compressedText("katex") }

    private static func compressedText(_ name: String) -> String {
        // Keep only the reusable String; promptly drain temporary NSData buffers.
        autoreleasepool {
            for format in ["lzma", "lzfse"] {
                if let url = bundle.url(forResource: name, withExtension: format),
                   let compressed = try? Data(contentsOf: url, options: .mappedIfSafe),
                   let data = try? (compressed as NSData).decompressed(using: format == "lzma" ? .lzma : .lzfse) as Data {
                    return String(decoding: data, as: UTF8.self)
                }
            }
            return ""
        }
    }

    private static func text(_ name: String, _ ext: String) -> String {
        guard let url = bundle.url(forResource: name, withExtension: ext), let value = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return value
    }
}
