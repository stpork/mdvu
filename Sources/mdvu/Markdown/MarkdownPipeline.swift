import Darwin
import Foundation

enum FastScan {
    @inline(__always)
    static func contains(_ string: String, ascii: UInt8) -> Bool {
        string.utf8.withContiguousStorageIfAvailable { buf in
            guard let base = buf.baseAddress else { return false }
            return memchr(base, Int32(ascii), buf.count) != nil
        } ?? string.utf8.contains(ascii)
    }

    @inline(__always)
    static func contains(_ string: String, token: StaticString) -> Bool {
        token.withUTF8Buffer { tokenBuf in
            guard !tokenBuf.isEmpty else { return true }
            if tokenBuf.count == 1 {
                return contains(string, ascii: tokenBuf[0])
            }
            return string.utf8.withContiguousStorageIfAvailable { hayBuf in
                guard hayBuf.count >= tokenBuf.count else { return false }
                guard let base = hayBuf.baseAddress, let tBase = tokenBuf.baseAddress else { return false }
                return memmem(base, hayBuf.count, tBase, tokenBuf.count) != nil
            } ?? (string.range(of: String(decoding: tokenBuf, as: UTF8.self), options: .literal) != nil)
        }
    }
}

protocol MarkdownExtension {
    func preprocess(_ source: String, dialect: MarkdownDialect) -> String
}

struct MarkdownPipeline {
    let dialect: MarkdownDialect
    let isDialectExplicit: Bool
    let extensions: [any MarkdownExtension]
    let diagrams: DiagramRegistry
    let cache: DiagramCache

    init(dialect: MarkdownDialect, mermaid: Bool, cache: DiagramCache = DiagramCache(), isDialectExplicit: Bool = false) {
        self.dialect = dialect
        self.isDialectExplicit = isDialectExplicit
        self.extensions = [
            FrontMatterExtension(),
            GitLabTOCExtension(),
            AdmonitionExtension(),
            ObsidianExtension(),
            MathExtension(),
            CriticMarkupExtension(),
            SubSuperscriptExtension()
        ]
        self.diagrams = DiagramRegistry(renderers: mermaid ? [MermaidRenderer(), PlantUMLRenderer()] : [])
        self.cache = cache
    }

    func render(_ source: String, diagramTheme: String = "light") -> RenderedDocument {
        let effectiveDialect = isDialectExplicit ? dialect : (MarkdownDocumentDirective.extractDialect(from: source) ?? dialect)
        let prepared = extensions.reduce(source) { $1.preprocess($0, dialect: effectiveDialect) }
        let rendered = MarkdownParser(diagrams: diagrams, cache: cache, diagramTheme: diagramTheme).render(prepared)
        return RenderedDocument(body: rendered.body, title: rendered.title, dialect: effectiveDialect)
    }
}

struct RenderedDocument {
    let body: String
    let title: String?
    let dialect: MarkdownDialect

    init(body: String, title: String?, dialect: MarkdownDialect = .generic) {
        self.body = body
        self.title = title
        self.dialect = dialect
    }
}

enum MarkdownDocumentDirective {
    private static let commentRegex = try! NSRegularExpression(pattern: #"<!--([\s\S]*?)-->"#)
    private static let directiveInCommentRegex = try! NSRegularExpression(
        pattern: #"(?:(?:dialect|markdown[-_]dialect)\s*[:=]\s*|--dialect\s+|(?i)\bin\s+)(["'`]?)([a-zA-Z_-]+)\1(?:\s+dialect)?"#,
        options: .caseInsensitive
    )

    static func extractDialect(from source: String) -> MarkdownDialect? {
        if let frontMatterDialect = extractFromFrontMatter(source) {
            return frontMatterDialect
        }

        let prefix = source.prefix(4096)
        let trimmedLeading = prefix.drop(while: { $0.isWhitespace || $0.isNewline })
        if trimmedLeading.hasPrefix("<!--") {
            let searchString = String(trimmedLeading)
            let nsString = searchString as NSString
            let fullRange = NSRange(location: 0, length: nsString.length)
            if let commentMatch = commentRegex.firstMatch(in: searchString, range: fullRange) {
                let commentContent = nsString.substring(with: commentMatch.range(at: 1))
                let commentNS = commentContent as NSString
                let commentRange = NSRange(location: 0, length: commentNS.length)
                if let directiveMatch = directiveInCommentRegex.firstMatch(in: commentContent, range: commentRange) {
                    let rawVal = commentNS.substring(with: directiveMatch.range(at: 2))
                    if let dialect = MarkdownDialect.from(string: rawVal) {
                        return dialect
                    }
                }
            }
        }
        return nil
    }

    private static func extractFromFrontMatter(_ source: String) -> MarkdownDialect? {
        let isLF = source.hasPrefix("---\n")
        let isCRLF = source.hasPrefix("---\r\n")
        guard isLF || isCRLF else { return nil }
        let headerLen = isCRLF ? 5 : 4
        let separator = isCRLF ? "\r\n---\r\n" : "\n---\n"
        guard let end = source.range(of: separator, range: source.index(source.startIndex, offsetBy: headerLen)..<source.endIndex) else { return nil }
        let yaml = source[source.index(source.startIndex, offsetBy: headerLen)..<end.lowerBound]
        for line in yaml.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            if key == "dialect" || key == "markdown-dialect" || key == "markdown_dialect" || key == "mode" {
                let val = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if let dialect = MarkdownDialect.from(string: String(val)) {
                    return dialect
                }
            }
        }
        return nil
    }
}

private struct FrontMatterExtension: MarkdownExtension {
    func preprocess(_ source: String, dialect: MarkdownDialect) -> String {
        let isLF = source.hasPrefix("---\n")
        let isCRLF = source.hasPrefix("---\r\n")
        guard isLF || isCRLF else { return source }
        let headerLen = isCRLF ? 5 : 4
        let separator = isCRLF ? "\r\n---\r\n" : "\n---\n"
        guard let end = source.range(of: separator, range: source.index(source.startIndex, offsetBy: headerLen)..<source.endIndex) else { return source }
        let yaml = source[source.index(source.startIndex, offsetBy: headerLen)..<end.lowerBound]
        let rows = yaml.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).compactMap { line -> String? in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            return "| \(line[..<colon]) | \(line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)) |"
        }.joined(separator: "\n")
        let rest = source[end.upperBound...]
        return rows.isEmpty ? String(rest) : "**Document metadata**\n\n| Field | Value |\n|---|---|\n\(rows)\n\n\(rest)"
    }
}

private struct ObsidianExtension: MarkdownExtension {
    private static let calloutPattern = try! NSRegularExpression(pattern: #"(?m)^([ \t]*>[ \t]*)\[!([A-Za-z]+)\][+-]?[ \t]*(.*)$"#)
    private static let embedPattern = try! NSRegularExpression(pattern: #"!\[\[([^\]]+)\]\]"#)
    private static let wikiLinkPattern = try! NSRegularExpression(pattern: #"\[\[([^\]|#]+)(#[^\]|]+)?(?:\|([^\]]+))?\]\]"#)

    func preprocess(_ source: String, dialect: MarkdownDialect) -> String {
        let hasCallout = FastScan.contains(source, token: "[!")
        let hasWikiSyntax = dialect == .obsidian && FastScan.contains(source, token: "[[")
        guard hasCallout || hasWikiSyntax else { return source }
        var result = ""
        var cursor = source.startIndex
        var chunkStart = cursor
        var fence: Character?

        while cursor < source.endIndex {
            let nextNewline = source[cursor...].firstIndex(of: "\n") ?? source.endIndex
            let line = source[cursor..<nextNewline]

            var firstNonSpace: Character?
            for ch in line {
                if ch != " " && ch != "\t" {
                    firstNonSpace = ch
                    break
                }
            }

            if let first = firstNonSpace, first == "`" || first == "~" {
                let candidate = line.drop(while: { $0 == " " || $0 == "\t" })
                let marker: Character? = candidate.hasPrefix("```") ? "`" : (candidate.hasPrefix("~~~") ? "~" : nil)
                if let marker {
                    if fence == nil { fence = marker }
                    else if fence == marker { fence = nil }
                }
            } else if fence == nil && line.utf8.contains(UInt8(ascii: "[")) {
                let needsCallout = line.contains("[!")
                let needsWiki = hasWikiSyntax && line.contains("[[")
                if needsCallout || needsWiki {
                    let transformed = transform(String(line), wikiLinks: hasWikiSyntax)
                    if transformed != line {
                        if result.isEmpty {
                            result.reserveCapacity(source.utf8.count + 256)
                        }
                        result.append(contentsOf: source[chunkStart..<cursor])
                        result.append(transformed)
                        if nextNewline < source.endIndex {
                            result.append("\n")
                            cursor = source.index(after: nextNewline)
                            chunkStart = cursor
                            continue
                        } else {
                            chunkStart = source.endIndex
                            break
                        }
                    }
                }
            }

            if nextNewline < source.endIndex {
                cursor = source.index(after: nextNewline)
            } else {
                break
            }
        }

        if result.isEmpty { return source }
        if chunkStart < source.endIndex {
            result.append(contentsOf: source[chunkStart...])
        }
        return result
    }

    private func transform(_ input: String, wikiLinks: Bool) -> String {
        var result = input
        if result.contains("[!") {
            result = RegexHelper.replace(result, regex: Self.calloutPattern) { match in
                "\(match[1])**MDVU-CALLOUT-\(match[2].uppercased())** \(match[3])\n\(match[1])"
            }
        }
        if wikiLinks, result.contains("![[") {
            result = RegexHelper.replace(result, regex: Self.embedPattern) { "![\($0[1])](\($0[1]))" }
        }
        if wikiLinks, result.contains("[[") {
            result = RegexHelper.replace(result, regex: Self.wikiLinkPattern) { match in
                let label = match[3].isEmpty ? match[1] : match[3]
                let target = match[1].lowercased().hasSuffix(".md") ? match[1] : match[1] + ".md"
                return "[\(label)](\(target)\(match[2]))"
            }
        }
        return result
    }
}

private struct CodeFenceScanner {
    static func process(_ source: String, transform: (String) -> String) -> String {
        guard FastScan.contains(source, token: "```") || FastScan.contains(source, token: "~~~") else {
            return transform(source)
        }
        var result = ""
        result.reserveCapacity(source.utf8.count)
        var cursor = source.startIndex
        var nonFenceChunkStart = cursor
        var activeFenceChar: Character?
        var activeFenceLength = 0
        var fenceStart = cursor

        while cursor < source.endIndex {
            let lineStart = cursor
            let lineEnd = source[cursor...].firstIndex(of: "\n") ?? source.endIndex

            // Scan leading indentation up to 3 spaces (CommonMark spec)
            var indent = 0
            var charIdx = lineStart
            while charIdx < lineEnd && (source[charIdx] == " " || source[charIdx] == "\t") {
                indent += 1
                charIdx = source.index(after: charIdx)
            }

            if let fenceChar = activeFenceChar {
                // Inside a fence: check if this line closes the fence
                if indent <= 3 && charIdx < lineEnd && source[charIdx] == fenceChar {
                    var count = 0
                    var scan = charIdx
                    while scan < lineEnd && source[scan] == fenceChar {
                        count += 1
                        scan = source.index(after: scan)
                    }
                    if count >= activeFenceLength {
                        let rest = source[scan..<lineEnd]
                        if rest.allSatisfy({ $0 == " " || $0 == "\t" || $0 == "\r" }) {
                            activeFenceChar = nil
                            activeFenceLength = 0
                            let nextCursor = lineEnd < source.endIndex ? source.index(after: lineEnd) : source.endIndex
                            result.append(contentsOf: source[fenceStart..<nextCursor])
                            cursor = nextCursor
                            nonFenceChunkStart = cursor
                            continue
                        }
                    }
                }
            } else {
                // Outside a fence: check if an opening fence starts here
                if indent <= 3 && charIdx < lineEnd {
                    let first = source[charIdx]
                    if first == "`" || first == "~" {
                        var count = 0
                        var scan = charIdx
                        while scan < lineEnd && source[scan] == first {
                            count += 1
                            scan = source.index(after: scan)
                        }
                        if count >= 3 {
                            if nonFenceChunkStart < lineStart {
                                let chunk = String(source[nonFenceChunkStart..<lineStart])
                                result.append(transform(chunk))
                            }
                            activeFenceChar = first
                            activeFenceLength = count
                            fenceStart = lineStart
                        }
                    }
                }
            }

            if lineEnd < source.endIndex {
                cursor = source.index(after: lineEnd)
            } else {
                cursor = source.endIndex
            }
        }

        if activeFenceChar != nil {
            result.append(contentsOf: source[fenceStart...])
        } else if nonFenceChunkStart < source.endIndex {
            let chunk = String(source[nonFenceChunkStart...])
            result.append(transform(chunk))
        }

        return result
    }
}

private struct GitLabTOCExtension: MarkdownExtension {
    private static let tocPattern = try! NSRegularExpression(pattern: #"(?m)^[ \t]*(?:\[\[_TOC_\]\]|\[TOC\])[ \t]*$"#)

    func preprocess(_ source: String, dialect: MarkdownDialect) -> String {
        guard FastScan.contains(source, token: "[[_TOC_]]") || FastScan.contains(source, token: "[TOC]") else { return source }
        return RegexHelper.replace(source, regex: Self.tocPattern) { _ in
            "<p class=\"toc-placeholder\"><a href=\"#table-of-contents\">Table of Contents</a></p>"
        }
    }
}

private struct AdmonitionExtension: MarkdownExtension {
    private static let mkdocsStart = try! NSRegularExpression(pattern: #"^([ \t]*)(\!{3}|\?{3}\+|\?{3})\s+([a-zA-Z]+)(?:\s+"([^"\n\r]*)")?[ \t]*$"#)
    private static let colonStart = try! NSRegularExpression(pattern: #"^([ \t]*):{3,4}([a-zA-Z]+)(?:\[([^\]\n\r]*)\])?[ \t]*$"#)
    private static let colonEnd = try! NSRegularExpression(pattern: #"^[ \t]*:{3,4}[ \t]*$"#)

    func preprocess(_ source: String, dialect: MarkdownDialect) -> String {
        guard FastScan.contains(source, token: "!!!") || FastScan.contains(source, token: "???") || FastScan.contains(source, token: ":::") else { return source }
        var output: [String] = []
        output.reserveCapacity(source.utf8.count / 40)
        var inMkDocs = false
        var mkdocsPendingBlankLines = 0
        var inColonAdmonition = false
        var activeFence: String?

        func endMkDocs() {
            if inMkDocs {
                inMkDocs = false
                mkdocsPendingBlankLines = 0
                output.append("")
                output.append("<!-- -->")
                output.append("")
            }
        }

        var cursor = source.startIndex
        while true {
            let nextNewline = source[cursor...].firstIndex(of: "\n") ?? source.endIndex
            let line = source[cursor..<nextNewline]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let currentFence = activeFence {
                if trimmed.hasPrefix(currentFence) {
                    activeFence = nil
                }
                output.append(String(line))
            } else if let fenceChar = trimmed.first, fenceChar == "`" || fenceChar == "~", trimmed.prefix(while: { $0 == fenceChar }).count >= 3 {
                let count = trimmed.prefix(while: { $0 == fenceChar }).count
                endMkDocs()
                activeFence = String(repeating: fenceChar, count: count)
                output.append(String(line))
            } else if inColonAdmonition {
                let lineStr = String(line)
                if Self.colonEnd.firstMatch(in: lineStr, range: NSRange(lineStr.startIndex..., in: lineStr)) != nil {
                    inColonAdmonition = false
                    output.append("")
                    output.append("<!-- -->")
                    output.append("")
                } else {
                    output.append("> " + lineStr)
                }
            } else if inMkDocs && (line.hasPrefix("    ") || line.hasPrefix("\t")) {
                while mkdocsPendingBlankLines > 0 {
                    output.append(">")
                    mkdocsPendingBlankLines -= 1
                }
                let stripped = line.hasPrefix("    ") ? String(line.dropFirst(4)) : String(line.dropFirst(1))
                output.append("> " + stripped)
            } else if inMkDocs && trimmed.isEmpty {
                mkdocsPendingBlankLines += 1
            } else {
                if inMkDocs { endMkDocs() }
                if let first = trimmed.first, first == "!" || first == "?" || first == ":" {
                    let lineStr = String(line)
                    let nsLine = lineStr as NSString
                    let fullRange = NSRange(location: 0, length: nsLine.length)

                    if let m = Self.mkdocsStart.firstMatch(in: lineStr, range: fullRange) {
                        endMkDocs()
                        inMkDocs = true
                        let marker = nsLine.substring(with: m.range(at: 2))
                        let type = nsLine.substring(with: m.range(at: 3)).uppercased()
                        let title = m.range(at: 4).location != NSNotFound ? nsLine.substring(with: m.range(at: 4)) : ""
                        let fold = marker.hasPrefix("???+") ? "+" : (marker.hasPrefix("???") ? "-" : "")
                        output.append("> [!\(type)]\(fold)\(title.isEmpty ? "" : " " + title)")
                    } else if let m = Self.colonStart.firstMatch(in: lineStr, range: fullRange) {
                        endMkDocs()
                        inColonAdmonition = true
                        let type = nsLine.substring(with: m.range(at: 2)).uppercased()
                        let title = m.range(at: 3).location != NSNotFound ? nsLine.substring(with: m.range(at: 3)) : ""
                        output.append("> [!\(type)]\(title.isEmpty ? "" : " " + title)")
                    } else {
                        output.append(String(line))
                    }
                } else {
                    output.append(String(line))
                }
            }

            if nextNewline < source.endIndex {
                cursor = source.index(after: nextNewline)
            } else {
                break
            }
        }
        return output.joined(separator: "\n")
    }
}

private struct CriticMarkupExtension: MarkdownExtension {
    private static let subRegex = try! NSRegularExpression(pattern: #"\{\~\~([\s\S]*?)\~>([\s\S]*?)\~\~\}"#)
    private static let addRegex = try! NSRegularExpression(pattern: #"\{\+\+([\s\S]*?)\+\+\}"#)
    private static let delRegex = try! NSRegularExpression(pattern: #"\{--([\s\S]*?)--\}"#)
    private static let markRegex = try! NSRegularExpression(pattern: #"\{==([\s\S]*?)==\}"#)
    private static let commentRegex = try! NSRegularExpression(pattern: #"\{>>([\s\S]*?)<<\}"#)

    func preprocess(_ source: String, dialect: MarkdownDialect) -> String {
        guard FastScan.contains(source, token: "{+") || FastScan.contains(source, token: "{-") || FastScan.contains(source, token: "{~") || FastScan.contains(source, token: "{=") || FastScan.contains(source, token: "{>") else {
            return source
        }
        return CodeFenceScanner.process(source) { chunk in
            guard FastScan.contains(chunk, token: "{+") || FastScan.contains(chunk, token: "{-") || FastScan.contains(chunk, token: "{~") || FastScan.contains(chunk, token: "{=") || FastScan.contains(chunk, token: "{>") else {
                return chunk
            }
            var text = chunk
            if FastScan.contains(text, token: "{~") {
                text = Self.subRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<del class=\"critic-del\">$1</del><ins class=\"critic-add\">$2</ins>")
            }
            if FastScan.contains(text, token: "{+") {
                text = Self.addRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<ins class=\"critic-add\">$1</ins>")
            }
            if FastScan.contains(text, token: "{-") {
                text = Self.delRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<del class=\"critic-del\">$1</del>")
            }
            if FastScan.contains(text, token: "{=") {
                text = Self.markRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<mark class=\"critic-mark\">$1</mark>")
            }
            if FastScan.contains(text, token: "{>") {
                text = Self.commentRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<span class=\"critic-comment\" title=\"$1\">💬 $1</span>")
            }
            return text
        }
    }
}

private struct SubSuperscriptExtension: MarkdownExtension {
    private static let underRegex = try! NSRegularExpression(pattern: #"\^\^([^\^\n\r]+)\^\^"#)
    private static let supRegex = try! NSRegularExpression(pattern: #"(?<!\^)\^([^\^\s\n\r]+)\^(?!\^)"#)
    private static let subRegex = try! NSRegularExpression(pattern: #"(?<!~)~([^~\s\n\r]+)~(?!~)"#)

    func preprocess(_ source: String, dialect: MarkdownDialect) -> String {
        guard FastScan.contains(source, ascii: UInt8(ascii: "~")) || FastScan.contains(source, ascii: UInt8(ascii: "^")) else {
            return source
        }
        return CodeFenceScanner.process(source) { chunk in
            guard FastScan.contains(chunk, ascii: UInt8(ascii: "~")) || FastScan.contains(chunk, ascii: UInt8(ascii: "^")) else { return chunk }
            var text = chunk
            if FastScan.contains(text, ascii: UInt8(ascii: "^")) {
                if FastScan.contains(text, token: "^^") {
                    text = Self.underRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<u>$1</u>")
                }
                text = Self.supRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<sup>$1</sup>")
            }
            if FastScan.contains(text, ascii: UInt8(ascii: "~")) {
                text = Self.subRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<sub>$1</sub>")
            }
            return text
        }
    }
}

private struct MathExtension: MarkdownExtension {
    private static let mathCodeBlockRegex = try! NSRegularExpression(pattern: #"(?m)^[ \t]{0,3}(`{3,}|~{3,})(?:math|latex|katex)[ \t]*\r?\n([\s\S]*?)\r?\n[ \t]{0,3}\1[ \t]*$"#)

    func preprocess(_ source: String, dialect: MarkdownDialect) -> String {
        let hasMathToken = FastScan.contains(source, token: "math") || FastScan.contains(source, token: "latex") || FastScan.contains(source, token: "katex")
        let hasDollar = FastScan.contains(source, ascii: UInt8(ascii: "$"))
        guard hasDollar || hasMathToken else {
            return source
        }

        var text = source
        if hasMathToken {
            text = RegexHelper.replace(text, regex: Self.mathCodeBlockRegex) { match in
                let tex = match[2].trimmingCharacters(in: .whitespacesAndNewlines)
                return "<div class=\"math-display\">\(HTML.escape(tex))</div>"
            }
        }

        guard FastScan.contains(text, ascii: UInt8(ascii: "$")) else { return text }

        return CodeFenceScanner.process(text) { chunk in
            guard FastScan.contains(chunk, ascii: UInt8(ascii: "$")) else { return chunk }
            return Self.scanMathInChunk(chunk)
        }
    }

    private static func scanMathInChunk(_ chunk: String) -> String {
        var result = ""
        result.reserveCapacity(chunk.utf8.count)
        var cursor = chunk.startIndex
        var chunkStart = cursor

        while cursor < chunk.endIndex {
            let ch = chunk[cursor]

            // 1. Skip inline code backticks: `...` or ``...``
            if ch == "`" {
                var scan = cursor
                while scan < chunk.endIndex && chunk[scan] == "`" {
                    scan = chunk.index(after: scan)
                }
                let ticks = chunk[cursor..<scan]
                if let closeRange = chunk[scan...].range(of: ticks, options: .literal) {
                    cursor = closeRange.upperBound
                    continue
                } else {
                    cursor = scan
                    continue
                }
            }

            // 2. Skip escaped backslash
            if ch == "\\" {
                let next = chunk.index(after: cursor)
                if next < chunk.endIndex {
                    cursor = chunk.index(after: next)
                    continue
                }
                cursor = next
                continue
            }

            // 3. Display math: $$
            if ch == "$" {
                let next = chunk.index(after: cursor)
                if next < chunk.endIndex && chunk[next] == "$" {
                    let mathStart = chunk.index(after: next)
                    var search = mathStart
                    var foundClosing: Range<String.Index>?
                    while let r = chunk[search...].range(of: "$$", options: .literal) {
                        let prev = chunk.index(before: r.lowerBound)
                        if prev >= mathStart && chunk[prev] == "\\" {
                            search = r.upperBound
                            continue
                        }
                        foundClosing = r
                        break
                    }

                    if let closeRange = foundClosing {
                        result.append(contentsOf: chunk[chunkStart..<cursor])
                        let tex = chunk[mathStart..<closeRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                        result.append("<div class=\"math-display\">\(HTML.escape(tex))</div>")
                        cursor = closeRange.upperBound
                        chunkStart = cursor
                        continue
                    }
                } else {
                    // 4. Inline math: $...$
                    // Opening $ cannot be followed by whitespace, newline, or $
                    if next < chunk.endIndex && chunk[next] != " " && chunk[next] != "\t" && chunk[next] != "\n" && chunk[next] != "\r" && chunk[next] != "$" {
                        let mathStart = next
                        var search = mathStart
                        var foundClosing: String.Index?
                        while search < chunk.endIndex {
                            let c = chunk[search]
                            if c == "\n" || c == "\r" {
                                break
                            }
                            if c == "\\" {
                                search = chunk.index(after: search)
                                if search < chunk.endIndex { search = chunk.index(after: search) }
                                continue
                            }
                            if c == "$" {
                                let prev = chunk.index(before: search)
                                if chunk[prev] != " " && chunk[prev] != "\t" {
                                    let after = chunk.index(after: search)
                                    if after == chunk.endIndex || chunk[after] != "$" {
                                        foundClosing = search
                                        break
                                    }
                                }
                            }
                            search = chunk.index(after: search)
                        }

                        if let closeIdx = foundClosing {
                            result.append(contentsOf: chunk[chunkStart..<cursor])
                            let tex = String(chunk[mathStart..<closeIdx])
                            result.append("<span class=\"math-inline\">\(HTML.escape(tex))</span>")
                            cursor = chunk.index(after: closeIdx)
                            chunkStart = cursor
                            continue
                        }
                    }
                }
            }

            cursor = chunk.index(after: cursor)
        }

        if chunkStart < chunk.endIndex {
            result.append(contentsOf: chunk[chunkStart...])
        }
        return result
    }
}

