import Foundation

enum HTMLDocument {
    static func make(body: String, title: String, theme: ThemeChoice, fullWidth: Bool = false) -> String {
        return """
        <!doctype html><html class="\(fullWidth ? "full-width" : "")" data-theme="\(theme.rawValue)"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1"><title>\(HTML.escape(title))</title>
        <style>\(ResourceLoader.markdownCSS)</style></head><body><article>\(body)</article>
        <script>\(ResourceLoader.appJavaScript)</script></body></html>
        """
    }
}

enum ResourceLoader {
    static let markdownCSS = text("markdown", "css")
    static let appJavaScript = text("app", "js")
    static let mermaidJavaScript: String = {
        guard let url = Bundle.module.url(forResource: "mermaid", withExtension: "lzfse"),
              let compressed = try? Data(contentsOf: url, options: .mappedIfSafe),
              let data = try? (compressed as NSData).decompressed(using: .lzfse) as Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }()

    private static func text(_ name: String, _ ext: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext), let value = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return value
    }
}
