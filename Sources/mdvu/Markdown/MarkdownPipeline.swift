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
        self.extensions = [FrontMatterExtension(), ObsidianExtension()]
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
        result.reserveCapacity(source.utf8.count + 256)
        var cursor = source.startIndex
        var fence: Character?

        while cursor < source.endIndex {
            let nextNewline = source[cursor...].firstIndex(of: "\n") ?? source.endIndex
            let line = source[cursor..<nextNewline]

            let candidate = line.drop(while: { $0 == " " || $0 == "\t" })
            let marker: Character? = candidate.hasPrefix("```") ? "`" : (candidate.hasPrefix("~~~") ? "~" : nil)
            if let marker {
                if fence == nil { fence = marker }
                else if fence == marker { fence = nil }
                result.append(contentsOf: line)
            } else if fence != nil {
                result.append(contentsOf: line)
            } else {
                let needsCallout = line.contains("[!")
                let needsWiki = hasWikiSyntax && line.contains("[[")
                if needsCallout || needsWiki {
                    result.append(transform(String(line), wikiLinks: hasWikiSyntax))
                } else {
                    result.append(contentsOf: line)
                }
            }

            if nextNewline < source.endIndex {
                result.append("\n")
                cursor = source.index(after: nextNewline)
            } else {
                break
            }
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
