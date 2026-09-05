import Foundation

protocol MarkdownExtension {
    func preprocess(_ source: String, dialect: MarkdownDialect) -> String
}

struct MarkdownPipeline {
    let dialect: MarkdownDialect
    let extensions: [any MarkdownExtension]
    let diagrams: DiagramRegistry
    let cache: DiagramCache

    init(dialect: MarkdownDialect, mermaid: Bool, cache: DiagramCache = DiagramCache()) {
        self.dialect = dialect
        self.extensions = [
            FrontMatterExtension(),
            GitLabTOCExtension(),
            AdmonitionExtension(),
            ObsidianExtension(),
            CriticMarkupExtension(),
            SubSuperscriptExtension()
        ]
        self.diagrams = DiagramRegistry(renderers: mermaid ? [MermaidRenderer(), PlantUMLRenderer()] : [])
        self.cache = cache
    }

    func render(_ source: String, diagramTheme: String = "light") -> RenderedDocument {
        let prepared = extensions.reduce(source) { $1.preprocess($0, dialect: dialect) }
        return MarkdownParser(diagrams: diagrams, cache: cache, diagramTheme: diagramTheme).render(prepared)
    }
}

struct RenderedDocument { let body: String; let title: String? }

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
        let hasCallout = source.contains("[!")
        let hasWikiSyntax = dialect == .obsidian && source.contains("[[")
        guard hasCallout || hasWikiSyntax else { return source }
        var result = ""
        var cursor = source.startIndex
        var chunkStart = cursor
        var fence: Character?

        while cursor < source.endIndex {
            let nextNewline = source[cursor...].firstIndex(of: "\n") ?? source.endIndex
            let line = source[cursor..<nextNewline]

            let candidate = line.drop(while: { $0 == " " || $0 == "\t" })
            let marker: Character? = candidate.hasPrefix("```") ? "`" : (candidate.hasPrefix("~~~") ? "~" : nil)
            if let marker {
                if fence == nil { fence = marker }
                else if fence == marker { fence = nil }
            } else if fence == nil {
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

private struct CodeFenceProtector {
    static func process(_ source: String, transform: (String) -> String) -> String {
        guard source.contains("```") || source.contains("~~~") else {
            return transform(source)
        }
        let lines = source.components(separatedBy: "\n")
        var output: [String] = []
        var activeFence: String?
        var textChunk: [String] = []

        func flushChunk() {
            if !textChunk.isEmpty {
                let joined = textChunk.joined(separator: "\n")
                output.append(transform(joined))
                textChunk.removeAll()
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let currentFence = activeFence {
                if trimmed.hasPrefix(currentFence) {
                    activeFence = nil
                }
                output.append(line)
                continue
            }

            if let fenceChar = trimmed.first, fenceChar == "`" || fenceChar == "~" {
                let count = trimmed.prefix(while: { $0 == fenceChar }).count
                if count >= 3 {
                    flushChunk()
                    activeFence = String(repeating: fenceChar, count: count)
                    output.append(line)
                    continue
                }
            }

            textChunk.append(line)
        }
        flushChunk()
        return output.joined(separator: "\n")
    }
}

private struct GitLabTOCExtension: MarkdownExtension {
    private static let tocPattern = try! NSRegularExpression(pattern: #"(?m)^[ \t]*(?:\[\[_TOC_\]\]|\[TOC\])[ \t]*$"#)

    func preprocess(_ source: String, dialect: MarkdownDialect) -> String {
        guard source.contains("[[_TOC_]]") || source.contains("[TOC]") else { return source }
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
        guard source.contains("!!!") || source.contains("???") || source.contains(":::") else { return source }
        let lines = source.components(separatedBy: "\n")
        var output: [String] = []
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

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let currentFence = activeFence {
                if trimmed.hasPrefix(currentFence) {
                    activeFence = nil
                }
                output.append(line)
                continue
            }

            if let fenceChar = trimmed.first, fenceChar == "`" || fenceChar == "~" {
                let count = trimmed.prefix(while: { $0 == fenceChar }).count
                if count >= 3 {
                    endMkDocs()
                    activeFence = String(repeating: fenceChar, count: count)
                    output.append(line)
                    continue
                }
            }

            if inColonAdmonition {
                if Self.colonEnd.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                    inColonAdmonition = false
                    output.append("")
                    output.append("<!-- -->")
                    output.append("")
                    continue
                }
                output.append("> " + line)
                continue
            }

            if inMkDocs {
                if line.hasPrefix("    ") || line.hasPrefix("\t") {
                    while mkdocsPendingBlankLines > 0 {
                        output.append(">")
                        mkdocsPendingBlankLines -= 1
                    }
                    let stripped = line.hasPrefix("    ") ? String(line.dropFirst(4)) : String(line.dropFirst(1))
                    output.append("> " + stripped)
                    continue
                } else if trimmed.isEmpty {
                    mkdocsPendingBlankLines += 1
                    continue
                } else {
                    endMkDocs()
                }
            }

            if let first = trimmed.first, first == "!" || first == "?" || first == ":" {
                let nsLine = line as NSString
                let fullRange = NSRange(location: 0, length: nsLine.length)

                if let m = Self.mkdocsStart.firstMatch(in: line, range: fullRange) {
                    endMkDocs()
                    inMkDocs = true
                    let marker = nsLine.substring(with: m.range(at: 2))
                    let type = nsLine.substring(with: m.range(at: 3)).uppercased()
                    let title = m.range(at: 4).location != NSNotFound ? nsLine.substring(with: m.range(at: 4)) : ""
                    let fold = marker.hasPrefix("???+") ? "+" : (marker.hasPrefix("???") ? "-" : "")
                    output.append("> [!\(type)]\(fold)\(title.isEmpty ? "" : " " + title)")
                    continue
                }

                if let m = Self.colonStart.firstMatch(in: line, range: fullRange) {
                    endMkDocs()
                    inColonAdmonition = true
                    let type = nsLine.substring(with: m.range(at: 2)).uppercased()
                    let title = m.range(at: 3).location != NSNotFound ? nsLine.substring(with: m.range(at: 3)) : ""
                    output.append("> [!\(type)]\(title.isEmpty ? "" : " " + title)")
                    continue
                }
            }

            output.append(line)
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
        guard source.contains("{+") || source.contains("{-") || source.contains("{~") || source.contains("{=") || source.contains("{>") else {
            return source
        }
        return CodeFenceProtector.process(source) { chunk in
            guard chunk.contains("{+") || chunk.contains("{-") || chunk.contains("{~") || chunk.contains("{=") || chunk.contains("{>") else {
                return chunk
            }
            var text = chunk
            if text.contains("{~") {
                text = Self.subRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<del class=\"critic-del\">$1</del><ins class=\"critic-add\">$2</ins>")
            }
            if text.contains("{+") {
                text = Self.addRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<ins class=\"critic-add\">$1</ins>")
            }
            if text.contains("{-") {
                text = Self.delRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<del class=\"critic-del\">$1</del>")
            }
            if text.contains("{=") {
                text = Self.markRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<mark class=\"critic-mark\">$1</mark>")
            }
            if text.contains("{>") {
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
        guard source.contains("~") || source.contains("^") else {
            return source
        }
        return CodeFenceProtector.process(source) { chunk in
            guard chunk.contains("~") || chunk.contains("^") else { return chunk }
            var text = chunk
            if text.contains("^") {
                text = Self.underRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<u>$1</u>")
                text = Self.supRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<sup>$1</sup>")
            }
            if text.contains("~") {
                text = Self.subRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "<sub>$1</sub>")
            }
            return text
        }
    }
}

