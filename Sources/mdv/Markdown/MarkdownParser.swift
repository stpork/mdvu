import Darwin
import Foundation
import cmark_gfm
import cmark_gfm_extensions

struct MarkdownParser {
    let diagrams: DiagramRegistry
    let cache: DiagramCache
    let diagramTheme: String

    private static let calloutPattern = try! NSRegularExpression(pattern: #"<blockquote>\s*<p><strong>MDV-CALLOUT-([A-Z]+)</strong>\s*(.*?)</p>\s*(.*?)</blockquote>"#, options: [.dotMatchesLineSeparators])

    private static let prepareCMark: Void = {
        cmark_gfm_core_extensions_ensure_registered()
    }()

    func render(_ source: String) -> RenderedDocument {
        _ = Self.prepareCMark
        let options = CMARK_OPT_VALIDATE_UTF8 | CMARK_OPT_FOOTNOTES | CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE
        guard let parser = cmark_parser_new(options) else {
            return RenderedDocument(body: "<pre>\(HTML.escape(source))</pre>", title: nil)
        }
        defer { cmark_parser_free(parser) }

        for name in ["table", "strikethrough", "autolink", "tagfilter", "tasklist"] {
            name.withCString { pointer in
                if let ext = cmark_find_syntax_extension(pointer) { _ = cmark_parser_attach_syntax_extension(parser, ext) }
            }
        }

        let byteCount = source.utf8.count
        source.withCString { bytes in
            cmark_parser_feed(parser, bytes, byteCount)
        }
        guard let document = cmark_parser_finish(parser) else {
            return RenderedDocument(body: "<pre>\(HTML.escape(source))</pre>", title: nil)
        }
        defer { cmark_node_free(document) }
        let title = documentTitle(document)

        guard let rendered = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser)) else {
            return RenderedDocument(body: "<pre>\(HTML.escape(source))</pre>", title: nil)
        }
        defer { free(rendered) }
        return RenderedDocument(body: postprocess(String(cString: rendered)), title: title)
    }

    private func postprocess(_ input: String) -> String {
        var html = input
        if !diagrams.renderers.isEmpty, html.contains(#"<pre><code class="language-"#) {
            html = replaceDiagramBlocks(html)
        }
        if html.contains("MDV-CALLOUT-") {
            html = replace(html, regex: Self.calloutPattern) { match in
                let type = match[1].lowercased()
                let calloutTitle = match[2].trimmingCharacters(in: .whitespacesAndNewlines)
                return "<aside class=\"callout callout-\(type)\"><div class=\"callout-title\">\(calloutTitle.isEmpty ? type.capitalized : calloutTitle)</div><div>\(match[3])</div></aside>"
            }
        }
        return html
    }

    private func replaceDiagramBlocks(_ input: String) -> String {
        let prefix = #"<pre><code class="language-"#
        let suffix = "</code></pre>"
        var result = ""
        result.reserveCapacity(input.utf8.count)
        var cursor = input.startIndex
        var searchStart = cursor
        while let opening = input.range(of: prefix, range: searchStart..<input.endIndex),
              let classEnd = input[opening.upperBound...].firstIndex(of: "\""),
              let contentStart = input[classEnd...].firstIndex(of: ">"),
              let closing = input.range(of: suffix, range: input.index(after: contentStart)..<input.endIndex) {
            let language = HTML.unescape(String(input[opening.upperBound..<classEnd])).lowercased()
            guard let renderer = diagrams.renderer(for: language) else {
                searchStart = closing.upperBound
                continue
            }
            result += input[cursor..<opening.lowerBound]
            let encodedSource = String(input[input.index(after: contentStart)..<closing.lowerBound])
            result += renderer.placeholder(source: HTML.unescape(encodedSource).trimmingCharacters(in: .newlines), theme: diagramTheme, cache: cache)
            cursor = closing.upperBound
            searchStart = cursor
        }
        guard cursor != input.startIndex else { return input }
        result += input[cursor...]
        return result
    }

    private func documentTitle(_ document: UnsafeMutablePointer<cmark_node>) -> String? {
        guard let iterator = cmark_iter_new(document) else { return nil }
        defer { cmark_iter_free(iterator) }
        while cmark_iter_next(iterator) != CMARK_EVENT_DONE {
            guard let node = cmark_iter_get_node(iterator),
                  cmark_node_get_type(node) == CMARK_NODE_HEADING,
                  cmark_node_get_heading_level(node) == 1 else { continue }
            let value = inlineText(cmark_node_first_child(node)).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private func inlineText(_ first: UnsafeMutablePointer<cmark_node>?) -> String {
        var result = ""
        var node = first
        while let current = node {
            if let literal = cmark_node_get_literal(current) { result += String(cString: literal) }
            if let child = cmark_node_first_child(current) { result += inlineText(child) }
            node = cmark_node_next(current)
        }
        return result
    }

    private func replace(_ input: String, regex: NSRegularExpression, transform: ([String]) -> String) -> String {
        let original = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: original.length))
        guard !matches.isEmpty else { return input }
        var result = ""; result.reserveCapacity(original.length)
        var cursor = 0
        for match in matches {
            result += original.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let groups = (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : original.substring(with: match.range(at: $0)) }
            result += transform(groups)
            cursor = match.range.location + match.range.length
        }
        result += original.substring(from: cursor)
        return result
    }
}

enum HTML {
    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    static func escapeAttribute(_ value: String) -> String { escape(value).replacingOccurrences(of: "'", with: "&#39;") }
    static func unescape(_ value: String) -> String {
        value.replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&amp;", with: "&")
    }
}
