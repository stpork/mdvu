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
        <style>@media(max-width:900px){article{padding-left:30px;padding-right:30px}}@media(max-width:700px){article{padding-left:22px;padding-right:22px}}</style>
        <script nonce="\(nonce)">\(ResourceLoader.appJavaScript)</script></head><body><article>\(body)</article>
        \(engines)</body></html>
        """
    }
}

enum ResourceLoader {
    static let bundle: Bundle = {
        let candidates: [URL?] = [
            AppBundle.main.resourceURL?.appendingPathComponent("mdvu_mdvu.bundle"),
            AppBundle.main.resourceURL,
            AppBundle.main.bundleURL.appendingPathComponent("mdvu_mdvu.bundle"),
            AppBundle.main.bundleURL.appendingPathComponent("Contents/Resources/mdvu_mdvu.bundle"),
            AppBundle.main.bundleURL
        ]
        for candidate in candidates {
            if let candidate, let b = Bundle(url: candidate), b.url(forResource: "diagram-renderer", withExtension: "js") != nil {
                return b
            }
        }
        return Bundle.module
    }()

    static let markdownCSS: String = MdvuCoreBridge.shared.markdownCSS ?? ""
    static let appJavaScript: String = MdvuCoreBridge.shared.appJavaScript ?? ""
    static let tocTreeJavaScript = text("toc-tree", "js")
    static let sidebarPolicyJSON = text("sidebar-policy", "json")
    static let diagramRendererJavaScript = text("diagram-renderer", "js")
    static var mermaidJavaScript: String { MdvuCoreBridge.shared.mermaidJavaScript ?? "" }
    static var plantumlJavaScript: String { MdvuCoreBridge.shared.plantumlJavaScript ?? "" }
    static var katexJavaScript: String { MdvuCoreBridge.shared.katexJavaScript ?? "" }

    private static func text(_ name: String, _ ext: String) -> String {
        guard let url = bundle.url(forResource: name, withExtension: ext), let value = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return value
    }
}
