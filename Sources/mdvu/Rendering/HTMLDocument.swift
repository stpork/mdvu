import Foundation

enum HTMLDocument {
    static func make(body: String, title: String, theme: ThemeChoice, fullWidth: Bool = false) -> String {
        return """
        <!doctype html><html class="\(fullWidth ? "full-width" : "")" data-theme="\(theme.rawValue)"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1"><title>\(HTML.escape(title))</title>
        <style>\(ResourceLoader.markdownCSS)</style>
        <style>@media(max-width:900px){article{padding-left:30px;padding-right:30px}}@media(max-width:700px){article{padding-left:22px;padding-right:22px}}</style></head><body><article>\(body)</article>
        <script>\(ResourceLoader.appJavaScript)</script></body></html>
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

    static let markdownCSS = text("markdown", "css")
    static let appJavaScript = text("app", "js")
    static let mermaidJavaScript: String = {
        if let url = bundle.url(forResource: "mermaid", withExtension: "lzma"),
           let compressed = try? Data(contentsOf: url, options: .mappedIfSafe),
           let data = try? (compressed as NSData).decompressed(using: .lzma) as Data {
            return String(decoding: data, as: UTF8.self)
        }
        if let url = bundle.url(forResource: "mermaid", withExtension: "lzfse"),
           let compressed = try? Data(contentsOf: url, options: .mappedIfSafe),
           let data = try? (compressed as NSData).decompressed(using: .lzfse) as Data {
            return String(decoding: data, as: UTF8.self)
        }
        return ""
    }()

    private static func text(_ name: String, _ ext: String) -> String {
        guard let url = bundle.url(forResource: name, withExtension: ext), let value = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return value
    }
}
