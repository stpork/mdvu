import Darwin
import Foundation
import cmark_gfm
import cmark_gfm_extensions

struct MarkdownParser {
    let diagrams: DiagramRegistry
    let cache: DiagramCache
    let diagramTheme: String

    private static let calloutPattern = try! NSRegularExpression(pattern: #"<blockquote>\s*<p><strong>MDVU-CALLOUT-([A-Z]+)</strong>\s*(.*?)</p>\s*(.*?)</blockquote>"#, options: [.dotMatchesLineSeparators])

    private static let syntaxExtensions: [UnsafeMutablePointer<cmark_syntax_extension>] = {
        cmark_gfm_core_extensions_ensure_registered()
        return ["table", "strikethrough", "autolink", "tagfilter", "tasklist"].compactMap { name in
            name.withCString { cmark_find_syntax_extension($0) }
        }
    }()

    func render(_ source: String) -> RenderedDocument {
        let options = CMARK_OPT_FOOTNOTES | CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE
        guard let parser = cmark_parser_new(options) else {
            return RenderedDocument(body: "<pre>\(HTML.escape(source))</pre>", title: nil)
        }
        defer { cmark_parser_free(parser) }

        for ext in Self.syntaxExtensions {
            _ = cmark_parser_attach_syntax_extension(parser, ext)
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
        if html.contains("MDVU-CALLOUT-") {
            html = replaceCalloutBlocks(html)
        }
        return html
    }

    private func replaceCalloutBlocks(_ input: String) -> String {
        let marker = "MDVU-CALLOUT-"
        var result = ""
        result.reserveCapacity(input.utf8.count)
        var cursor = input.startIndex
        var searchStart = cursor

        while let markerRange = input.range(of: marker, range: searchStart..<input.endIndex) {
            guard let bqStart = input[cursor..<markerRange.lowerBound].range(of: "<blockquote>", options: .backwards) else {
                searchStart = markerRange.upperBound
                continue
            }
            guard let bqEnd = input.range(of: "</blockquote>", range: markerRange.upperBound..<input.endIndex) else {
                searchStart = markerRange.upperBound
                continue
            }

            let block = String(input[bqStart.lowerBound..<bqEnd.upperBound])
            let replaced = RegexHelper.replace(block, regex: Self.calloutPattern) { match in
                let type = match[1].lowercased()
                let calloutTitle = match[2].trimmingCharacters(in: .whitespacesAndNewlines)
                return "<aside class=\"callout callout-\(type)\"><div class=\"callout-title\">\(calloutTitle.isEmpty ? type.capitalized : calloutTitle)</div><div>\(match[3])</div></aside>"
            }

            result.append(contentsOf: input[cursor..<bqStart.lowerBound])
            result.append(replaced)
            cursor = bqEnd.upperBound
            searchStart = cursor
        }

        guard cursor != input.startIndex else { return input }
        result.append(contentsOf: input[cursor...])
        return result
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
        var child = cmark_node_first_child(document)
        while let node = child {
            if cmark_node_get_type(node) == CMARK_NODE_HEADING && cmark_node_get_heading_level(node) == 1 {
                let value = inlineText(cmark_node_first_child(node)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            child = cmark_node_next(node)
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
}

enum RegexHelper {
    static func replace(_ input: String, regex: NSRegularExpression, transform: ([String]) -> String) -> String {
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
    static func escape(_ value: String, attribute: Bool = false) -> String {
        let needsEscape = attribute
            ? value.contains(where: { $0 == "&" || $0 == "<" || $0 == ">" || $0 == "\"" || $0 == "'" })
            : value.contains(where: { $0 == "&" || $0 == "<" || $0 == ">" || $0 == "\"" })
        guard needsEscape else { return value }
        var result = ""
        result.reserveCapacity(value.utf8.count + 16)
        for char in value {
            switch char {
            case "&": result.append("&amp;")
            case "<": result.append("&lt;")
            case ">": result.append("&gt;")
            case "\"": result.append("&quot;")
            case "'": result.append(attribute ? "&#39;" : "'")
            default: result.append(char)
            }
        }
        return result
    }

    static func escapeAttribute(_ value: String) -> String {
        escape(value, attribute: true)
    }

    static func unescape(_ value: String) -> String {
        guard value.contains("&") else { return value }
        var result = ""
        result.reserveCapacity(value.utf8.count)
        var cursor = value.startIndex
        while cursor < value.endIndex {
            if value[cursor] == "&" {
                let rest = value[cursor...]
                if rest.hasPrefix("&quot;") {
                    result.append("\"")
                    cursor = value.index(cursor, offsetBy: 6)
                    continue
                } else if rest.hasPrefix("&#39;") {
                    result.append("'")
                    cursor = value.index(cursor, offsetBy: 5)
                    continue
                } else if rest.hasPrefix("&gt;") {
                    result.append(">")
                    cursor = value.index(cursor, offsetBy: 4)
                    continue
                } else if rest.hasPrefix("&lt;") {
                    result.append("<")
                    cursor = value.index(cursor, offsetBy: 4)
                    continue
                } else if rest.hasPrefix("&amp;") {
                    result.append("&")
                    cursor = value.index(cursor, offsetBy: 5)
                    continue
                }
            }
            result.append(value[cursor])
            cursor = value.index(after: cursor)
        }
        return result
    }
}
