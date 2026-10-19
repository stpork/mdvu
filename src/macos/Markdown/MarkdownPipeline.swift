import Foundation

struct MarkdownPipeline {
    let dialect: MarkdownDialect
    let mermaid: Bool
    let isDialectExplicit: Bool

    init(dialect: MarkdownDialect, mermaid: Bool, isDialectExplicit: Bool = false) {
        self.dialect = dialect
        self.mermaid = mermaid
        self.isDialectExplicit = isDialectExplicit
    }

    func render(_ source: String, diagramTheme: String = "light") -> RenderedDocument {
        guard let result = MdvuCoreBridge.shared.renderBody(
            source: source, dialect: dialect.rawValue, isDialectExplicit: isDialectExplicit,
            theme: diagramTheme, enableDiagrams: mermaid
        ) else {
            return RenderedDocument(body: "<p class=\"diagram-error\">Unable to render the document: mdvu-core is unavailable or incompatible.</p>", title: nil, dialect: dialect)
        }
        return RenderedDocument(body: result.body, title: result.title,
                                dialect: MarkdownDialect.from(string: result.dialect) ?? dialect)
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
