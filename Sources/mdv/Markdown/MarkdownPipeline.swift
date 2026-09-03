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
        self.diagrams = DiagramRegistry(renderers: mermaid ? [MermaidRenderer()] : [])
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
        guard source.hasPrefix("---\n"), let end = source.range(of: "\n---\n", range: source.index(source.startIndex, offsetBy: 4)..<source.endIndex) else { return source }
        let yaml = source[source.index(source.startIndex, offsetBy: 4)..<end.lowerBound]
        let rows = yaml.split(separator: "\n").compactMap { line -> String? in
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
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        var result = ""
        result.reserveCapacity(source.utf8.count)
        var fence: Character?
        for (index, substring) in lines.enumerated() {
            var line = String(substring)
            let candidate = line.drop(while: { $0 == " " || $0 == "\t" })
            let marker: Character? = candidate.hasPrefix("```") ? "`" : (candidate.hasPrefix("~~~") ? "~" : nil)
            if let marker {
                if fence == nil { fence = marker }
                else if fence == marker { fence = nil }
            } else if fence == nil {
                line = transform(line, wikiLinks: hasWikiSyntax)
            }
            result += line
            if index != lines.index(before: lines.endIndex) { result += "\n" }
        }
        return result
    }

    private func transform(_ input: String, wikiLinks: Bool) -> String {
        var result = input
        if result.contains("[!") {
            result = replace(result, regex: Self.calloutPattern) { match in
                "\(match[1])**MDV-CALLOUT-\(match[2].uppercased())** \(match[3])\n\(match[1])"
            }
        }
        if wikiLinks, result.contains("![[") {
            result = replace(result, regex: Self.embedPattern) { "![\($0[1])](\($0[1]))" }
        }
        if wikiLinks, result.contains("[[") {
            result = replace(result, regex: Self.wikiLinkPattern) { match in
                let label = match[3].isEmpty ? match[1] : match[3]
                let target = match[1].lowercased().hasSuffix(".md") ? match[1] : match[1] + ".md"
                return "[\(label)](\(target)\(match[2]))"
            }
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
