import Darwin
import Foundation
import cmark_gfm
import cmark_gfm_extensions

struct MarkdownParser {
    let diagrams: DiagramRegistry
    let cache: DiagramCache
    let diagramTheme: String

    private static let calloutPattern = try! NSRegularExpression(pattern: #"<blockquote>\s*<p><strong>MDVU-CALLOUT-([A-Z]+)</strong>\s*(.*?)</p>\s*(.*?)</blockquote>"#, options: [.dotMatchesLineSeparators])
    private static let styleTagPattern = try! NSRegularExpression(pattern: #"&lt;(?i)(/?style(\s[^>]*)?)>"#)

    private static let syntaxExtensions: [UnsafeMutablePointer<cmark_syntax_extension>] = {
        cmark_gfm_core_extensions_ensure_registered()
        return ["table", "strikethrough", "autolink", "tagfilter", "tasklist"].compactMap { name in
            name.withCString { cmark_find_syntax_extension($0) }
        }
    }()

    func render(_ source: String) -> RenderedDocument {
        let options = CMARK_OPT_FOOTNOTES | CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE | CMARK_OPT_UNSAFE
        guard let parser = cmark_parser_new(options) else {
            return RenderedDocument(body: "<pre>\(HTML.escape(source))</pre>", title: nil)
        }
        defer { cmark_parser_free(parser) }

        for ext in Self.syntaxExtensions {
            _ = cmark_parser_attach_syntax_extension(parser, ext)
        }

        let byteCount = source.utf8.count
        let fed = source.utf8.withContiguousStorageIfAvailable { ptr -> Bool in
            guard let base = ptr.baseAddress else { return false }
            cmark_parser_feed(parser, UnsafeRawPointer(base).assumingMemoryBound(to: CChar.self), ptr.count)
            return true
        } ?? false
        if !fed {
            source.withCString { bytes in
                cmark_parser_feed(parser, bytes, byteCount)
            }
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
        if !diagrams.renderers.isEmpty, FastScan.contains(html, token: #"<pre><code class="language-"#) {
            html = replaceDiagramBlocks(html)
        }
        if FastScan.contains(html, token: "MDVU-CALLOUT-") {
            html = replaceCalloutBlocks(html)
        }
        if FastScan.contains(html, ascii: UInt8(ascii: "&")) && (FastScan.contains(html, token: "&lt;style") || FastScan.contains(html, token: "&lt;STYLE") || FastScan.contains(html, token: "&lt;/style") || FastScan.contains(html, token: "&lt;/STYLE")) {
            html = RegexHelper.replace(html, regex: Self.styleTagPattern) { match in
                "<\(match[1])>"
            }
        }
        return html
    }

    private func replaceCalloutBlocks(_ input: String) -> String {
        let marker = "MDVU-CALLOUT-"
        var result = ""
        result.reserveCapacity(input.utf8.count)
        var cursor = input.startIndex
        var searchStart = cursor

        while let markerRange = input.range(of: marker, options: .literal, range: searchStart..<input.endIndex) {
            let searchBackStart = input.index(markerRange.lowerBound, offsetBy: -200, limitedBy: cursor) ?? cursor
            guard let bqStart = input[searchBackStart..<markerRange.lowerBound].range(of: "<blockquote>", options: [.backwards, .literal]) else {
                searchStart = markerRange.upperBound
                continue
            }

            var scan = markerRange.upperBound
            var depth = 0
            var matchingBqEnd: Range<String.Index>?
            while scan < input.endIndex {
                guard let nextTag = input[scan...].range(of: "<", options: .literal) else { break }
                let rem = input[nextTag.lowerBound...]
                if rem.starts(with: "<blockquote>") {
                    depth += 1
                    scan = input.index(nextTag.lowerBound, offsetBy: 12)
                } else if rem.starts(with: "</blockquote>") {
                    if depth == 0 {
                        matchingBqEnd = nextTag.lowerBound..<input.index(nextTag.lowerBound, offsetBy: 13)
                        break
                    }
                    depth -= 1
                    scan = input.index(nextTag.lowerBound, offsetBy: 13)
                } else {
                    scan = input.index(after: nextTag.lowerBound)
                }
            }

            guard let bqEnd = matchingBqEnd else {
                searchStart = markerRange.upperBound
                continue
            }

            guard let strongEnd = input[markerRange.upperBound..<bqEnd.lowerBound].range(of: "</strong>", options: .literal) else {
                searchStart = markerRange.upperBound
                continue
            }
            let type = String(input[markerRange.upperBound..<strongEnd.lowerBound]).lowercased()

            guard let pEnd = input[strongEnd.upperBound..<bqEnd.lowerBound].range(of: "</p>", options: .literal) else {
                searchStart = markerRange.upperBound
                continue
            }
            let rawTitle = input[strongEnd.upperBound..<pEnd.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let title = rawTitle.isEmpty ? type.capitalized : rawTitle

            var body = input[pEnd.upperBound..<bqEnd.lowerBound]
            while let first = body.first, first == "\n" || first == "\r" {
                body = body.dropFirst()
            }

            let processedBody = FastScan.contains(String(body), token: "MDVU-CALLOUT-") ? replaceCalloutBlocks(String(body)) : String(body)

            result.append(contentsOf: input[cursor..<bqStart.lowerBound])
            result.append("<aside class=\"callout callout-\(type)\"><div class=\"callout-title\">\(title)</div><div>\(processedBody)</div></aside>")
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
            let rawLang = input[opening.upperBound..<classEnd]
            guard let renderer = diagrams.renderer(for: rawLang) else {
                searchStart = closing.upperBound
                continue
            }
            result += input[cursor..<opening.lowerBound]
            var encodedSource = input[input.index(after: contentStart)..<closing.lowerBound]
            while let first = encodedSource.first, first == "\n" || first == "\r" {
                encodedSource = encodedSource.dropFirst()
            }
            while let last = encodedSource.last, last == "\n" || last == "\r" {
                encodedSource = encodedSource.dropLast()
            }
            let unescaped = HTML.unescape(encodedSource)
            result += renderer.placeholder(source: unescaped, theme: diagramTheme, cache: cache)
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
                var title = ""
                inlineText(cmark_node_first_child(node), into: &title)
                let value = cleanTitle(title)
                if !value.isEmpty { return value }
            } else if cmark_node_get_type(node) == CMARK_NODE_HTML_BLOCK {
                if let literal = cmark_node_get_literal(node) {
                    let html = String(cString: literal)
                    if let r = html.range(of: #"(?i)<h1\b[^>]*>(.*?)</h1>"#, options: .regularExpression) {
                        let match = html[r]
                        if let start = match.firstIndex(of: ">"), let end = match.range(of: "</h1>", options: .caseInsensitive)?.lowerBound {
                            let raw = String(match[match.index(after: start)..<end])
                            let value = cleanTitle(raw)
                            if !value.isEmpty { return value }
                        }
                    }
                }
            }
            child = cmark_node_next(node)
        }
        return nil
    }

    private func cleanTitle(_ raw: String) -> String {
        let stripped = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return HTML.unescape(stripped).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inlineText(_ first: UnsafeMutablePointer<cmark_node>?, into result: inout String) {
        var node = first
        while let current = node {
            if let literal = cmark_node_get_literal(current) { result.append(contentsOf: String(cString: literal)) }
            if let child = cmark_node_first_child(current) { inlineText(child, into: &result) }
            node = cmark_node_next(current)
        }
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
        result.reserveCapacity(value.utf8.count + 64)
        var cursor = value.startIndex
        var search = cursor
        while search < value.endIndex {
            let ch = value[search]
            if ch == "&" || ch == "<" || ch == ">" || ch == "\"" || (attribute && ch == "'") {
                result.append(contentsOf: value[cursor..<search])
                switch ch {
                case "&": result.append("&amp;")
                case "<": result.append("&lt;")
                case ">": result.append("&gt;")
                case "\"": result.append("&quot;")
                case "'": result.append("&#39;")
                default: break
                }
                search = value.index(after: search)
                cursor = search
            } else {
                search = value.index(after: search)
            }
        }
        if cursor < value.endIndex {
            result.append(contentsOf: value[cursor...])
        }
        return result
    }

    static func escapeAttribute(_ value: String) -> String {
        escape(value, attribute: true)
    }

    static func unescape(_ value: some StringProtocol) -> String {
        guard value.utf8.contains(UInt8(ascii: "&")) else { return String(value) }
        var result = ""
        result.reserveCapacity(value.utf8.count)
        var cursor = value.startIndex
        var search = cursor
        while search < value.endIndex {
            if value[search] == "&" {
                let rest = value[search...]
                if rest.starts(with: "&quot;") {
                    result.append(contentsOf: value[cursor..<search])
                    result.append("\"")
                    search = value.index(search, offsetBy: 6)
                    cursor = search
                } else if rest.starts(with: "&#39;") {
                    result.append(contentsOf: value[cursor..<search])
                    result.append("'")
                    search = value.index(search, offsetBy: 5)
                    cursor = search
                } else if rest.starts(with: "&gt;") {
                    result.append(contentsOf: value[cursor..<search])
                    result.append(">")
                    search = value.index(search, offsetBy: 4)
                    cursor = search
                } else if rest.starts(with: "&lt;") {
                    result.append(contentsOf: value[cursor..<search])
                    result.append("<")
                    search = value.index(search, offsetBy: 4)
                    cursor = search
                } else if rest.starts(with: "&amp;") {
                    result.append(contentsOf: value[cursor..<search])
                    result.append("&")
                    search = value.index(search, offsetBy: 5)
                    cursor = search
                } else {
                    search = value.index(after: search)
                }
            } else {
                search = value.index(after: search)
            }
        }
        if cursor < value.endIndex {
            result.append(contentsOf: value[cursor...])
        }
        return result
    }
}
