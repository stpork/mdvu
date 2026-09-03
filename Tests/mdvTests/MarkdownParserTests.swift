import Testing
@testable import mdv

struct MarkdownParserTests {
    @Test func gfmBlocksAndSafeHTML() {
        let source = """
        # Title

        | A | B |
        |---|:---:|
        | one | **two** |

        - [x] done
        - [ ] later

        <script>alert(1)</script>
        """
        let result = MarkdownPipeline(dialect: .github, mermaid: true).render(source)
        #expect(result.title == "Title")
        #expect(result.body.contains("<h1>Title</h1>"))
        #expect(result.body.contains("<table>"))
        #expect(result.body.contains("type=\"checkbox\" checked="))
        #expect(!result.body.contains("<script>"))
    }

    @Test func mermaidUsesGenericPlaceholder() {
        let result = MarkdownPipeline(dialect: .generic, mermaid: true).render("```mermaid\ngraph TD\nA-->B\n```")
        #expect(result.body.contains("data-renderer=\"mermaid\""))
    }

    @Test func obsidianCalloutAndWikiLink() {
        let result = MarkdownPipeline(dialect: .obsidian, mermaid: false).render("> [!NOTE] Useful\n> See [[Other|the page]]")
        #expect(result.body.contains("callout-note"))
        #expect(result.body.contains("Other.md"))
    }

    @Test func commonMarkNestingAndFootnotes() {
        let source = """
        1. outer
           - nested *value*

        A statement.[^note]

        [^note]: Footnote text.
        """
        let result = MarkdownPipeline(dialect: .github, mermaid: false).render(source)
        #expect(result.body.contains("<ol>"))
        #expect(result.body.contains("<ul>"))
        #expect(result.body.contains("<em>value</em>"))
        #expect(result.body.contains("Footnote text"))
    }

    @Test func fullWidthDocumentClass() {
        let html = HTMLDocument.make(body: "<p>wide</p>", title: "Wide", theme: .system, fullWidth: true)
        #expect(html.contains("class=\"full-width\""))
    }

    @Test func headingTitlesAndIDsAreStable() {
        let result = MarkdownPipeline(dialect: .github, mermaid: false).render("Title\n=====\n\n## Repeat\n\n## Repeat")
        #expect(result.title == "Title")
        #expect(ResourceLoader.appJavaScript.contains("counts.set(base,count+1)"))
    }

    @Test func dialectProfilesDoNotRewriteWikiSyntax() {
        let generic = MarkdownPipeline(dialect: .generic, mermaid: false).render("Open [[Page]]")
        let obsidian = MarkdownPipeline(dialect: .obsidian, mermaid: false).render("Open [[Page.md]]\n\n```text\n[[Literal]]\n```")
        #expect(generic.body.contains("[[Page]]"))
        #expect(obsidian.body.contains("href=\"Page.md\""))
        #expect(!obsidian.body.contains("Page.md.md"))
        #expect(obsidian.body.contains("[[Literal]]"))
    }

    @Test func diagramCacheSeparatesThemes() {
        let pipeline = MarkdownPipeline(dialect: .github, mermaid: true)
        let source = "```mermaid\ngraph TD\nA-->B\n```"
        let light = pipeline.render(source, diagramTheme: "light").body
        let dark = pipeline.render(source, diagramTheme: "dark").body
        #expect(light != dark)
    }

    @Test func compressedMermaidResourceLoads() {
        #expect(ResourceLoader.mermaidJavaScript.contains("mermaid"))
        #expect(ResourceLoader.mermaidJavaScript.utf8.count > 2_000_000)
    }
}
