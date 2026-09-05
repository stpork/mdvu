import AppKit
import Foundation
import Testing
@testable import mdvu

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
        #expect(ResourceLoader.markdownCSS.contains(".diagram{margin:1.7em 0;padding:1.2em;overflow:auto;text-align:center;border:0;background:transparent}"))
        #expect(ResourceLoader.markdownCSS.contains(".diagram svg{max-width:100%;height:auto;background:transparent!important}"))
        #expect(ResourceLoader.appJavaScript.contains("themeVariables:{background:'transparent'}"))
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
        #expect(ResourceLoader.appJavaScript.contains("tableOfContents"))
        #expect(ResourceLoader.appJavaScript.contains("href?.startsWith('#')"))
        #expect(ResourceLoader.appJavaScript.contains("__mdvuScrollToFragment"))
        #expect(ResourceLoader.appJavaScript.contains("h1,h2,h3,h4,h5,h6"))
    }

    @Test func fragmentLinksStayInsideTheDocument() {
        let current = URL(fileURLWithPath: "/tmp/docs/readme.md")
        let direct = URL(string: "file:///tmp/docs/readme.md#overview")!
        let directoryBased = URL(string: "file:///tmp/docs/#overview")!
        let other = URL(string: "file:///tmp/docs/other.md#overview")!
        #expect(MarkdownLinkRouting.internalFragment(in: direct, currentDocument: current) == "overview")
        #expect(MarkdownLinkRouting.internalFragment(in: directoryBased, currentDocument: current) == "overview")
        #expect(MarkdownLinkRouting.internalFragment(in: other, currentDocument: current) == nil)
    }

    @Test func sidebarUsesPercentileForInitialWidthAndMidpointForMaximum() {
        let widths: [CGFloat] = [230, 240, 250, 260, 270, 280, 290, 300, 310, 900]
        let sizing = SidebarSizing.widths(widths, splitWidth: 1_000)
        #expect(sizing.suggested == 310)
        #expect(sizing.maximum == 500)

        let short = SidebarSizing.widths([180, 240, 280], splitWidth: 1_000)
        #expect(short.suggested == 280)
        #expect(short.maximum == 280)

        let minimum = SidebarSizing.widths([100], splitWidth: 1_000)
        #expect(minimum.suggested == 220)
        #expect(minimum.maximum == 220)
    }

    @Test func toolbarPrioritiesFollowSidebarState() {
        let closed = ToolbarVisibilityPolicy.priorities(sidebarVisible: false)
        #expect(closed.zoom.rawValue < closed.sidebar.rawValue)
        #expect(closed.sidebar.rawValue < closed.fullWidth.rawValue)
        #expect(closed.fullWidth.rawValue < NSToolbarItem.VisibilityPriority.standard.rawValue)

        let open = ToolbarVisibilityPolicy.priorities(sidebarVisible: true)
        #expect(open.zoom.rawValue < NSToolbarItem.VisibilityPriority.standard.rawValue)
        #expect(open.zoom.rawValue < open.fullWidth.rawValue)
        #expect(NSToolbarItem.VisibilityPriority.standard.rawValue < open.fullWidth.rawValue)
        #expect(open.fullWidth.rawValue < open.sidebar.rawValue)
        #expect(open.sidebar.rawValue < NSToolbarItem.VisibilityPriority.user.rawValue)
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

    @Test func inPageFindResourcesArePresent() {
        #expect(ResourceLoader.appJavaScript.contains("__mdvuFind"))
        #expect(ResourceLoader.markdownCSS.contains("mark.find-match"))
        #expect(ResourceLoader.markdownCSS.contains("mark.find-match.find-current"))
        #expect(ResourceLoader.appJavaScript.contains("navigationHistory"))
    }

    @Test func navigationHistoryStackOperations() {
        let history = NavigationHistory()
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)

        let doc1 = URL(fileURLWithPath: "/tmp/doc1.md")
        let doc2 = URL(fileURLWithPath: "/tmp/doc2.md")

        history.push(url: doc1, fragment: nil, currentScrollRatio: nil)
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)
        #expect(history.currentEntry?.url.path == doc1.path)
        #expect(history.currentEntry?.fragment == nil)

        history.push(url: doc1, fragment: "section-1", currentScrollRatio: 0.1)
        #expect(history.canGoBack)
        #expect(!history.canGoForward)
        #expect(history.entries[0].scrollRatio == 0.1)
        #expect(history.currentEntry?.fragment == "section-1")

        history.push(url: doc2, fragment: nil, currentScrollRatio: 0.5)
        #expect(history.canGoBack)
        #expect(!history.canGoForward)
        #expect(history.entries[1].scrollRatio == 0.5)
        #expect(history.currentEntry?.url.path == doc2.path)

        let back1 = history.goBack(currentScrollRatio: 0.0)
        #expect(back1?.url.path == doc1.path)
        #expect(back1?.fragment == "section-1")
        #expect(history.canGoBack)
        #expect(history.canGoForward)

        let back2 = history.goBack(currentScrollRatio: 0.3)
        #expect(back2?.url.path == doc1.path)
        #expect(back2?.fragment == nil)
        #expect(!history.canGoBack)
        #expect(history.canGoForward)

        let fwd1 = history.goForward(currentScrollRatio: 0.0)
        #expect(fwd1?.url.path == doc1.path)
        #expect(fwd1?.fragment == "section-1")
        #expect(history.canGoBack)
        #expect(history.canGoForward)

        let doc3 = URL(fileURLWithPath: "/tmp/doc3.md")
        history.push(url: doc3, fragment: nil, currentScrollRatio: 0.2)
        #expect(history.currentEntry?.url.path == doc3.path)
        #expect(history.canGoBack)
        #expect(!history.canGoForward)
        #expect(history.entries.count == 3)
    }

    @MainActor
    @Test func documentWindowTitleClickAndLoad() {
        let fixture = URL(fileURLWithPath: "Tests/Fixtures/kitchen-sink-small.md").standardizedFileURL
        let profiler = StartupProfiler()
        let controller = DocumentWindowController(url: fixture, directoryMode: false, options: .default, profiler: profiler)
        guard let win = controller.window as? DocumentWindow else {
            #expect(Bool(false))
            return
        }
        #expect(win.title == "kitchen-sink-small.md")

        var changedURL: URL?
        controller.onDocumentChange = { url in changedURL = url }

        let target = URL(fileURLWithPath: "Tests/Fixtures/kitchen-sink.md").standardizedFileURL
        controller.loadTargetURL(target)

        #expect(win.title == "kitchen-sink.md")
        #expect(changedURL?.path == target.path)
    }

    @Test func zoomPolicySteppingAndBoundaries() {
        // Clamp boundaries: 10% min, 500% max
        #expect(ZoomPolicy.clamp(0.05) == 0.10)
        #expect(ZoomPolicy.clamp(0.10) == 0.10)
        #expect(ZoomPolicy.clamp(5.00) == 5.00)
        #expect(ZoomPolicy.clamp(6.00) == 5.00)
        #expect(ZoomPolicy.clamp(1.25) == 1.25)

        // 10% steps
        #expect(abs(ZoomPolicy.nextStep(from: 1.00) - 1.10) < 0.001)
        #expect(abs(ZoomPolicy.nextStep(from: 1.10) - 1.20) < 0.001)
        #expect(abs(ZoomPolicy.previousStep(from: 1.00) - 0.90) < 0.001)
        #expect(abs(ZoomPolicy.previousStep(from: 0.90) - 0.80) < 0.001)

        // Snapping from fractional/continuous zoom
        #expect(abs(ZoomPolicy.nextStep(from: 1.14) - 1.20) < 0.001)
        #expect(abs(ZoomPolicy.previousStep(from: 1.14) - 1.10) < 0.001)

        // Limits
        #expect(abs(ZoomPolicy.previousStep(from: 0.10) - 0.10) < 0.001)
        #expect(abs(ZoomPolicy.nextStep(from: 5.00) - 5.00) < 0.001)

        // Manual text input
        #expect(abs(ZoomPolicy.parseManualInput("150%", fallback: 1.0) - 1.50) < 0.001)
        #expect(abs(ZoomPolicy.parseManualInput("  250  ", fallback: 1.0) - 2.50) < 0.001)
        #expect(abs(ZoomPolicy.parseManualInput("5%", fallback: 1.0) - 0.10) < 0.001)
        #expect(abs(ZoomPolicy.parseManualInput("1000", fallback: 1.0) - 5.00) < 0.001)
        #expect(abs(ZoomPolicy.parseManualInput("invalid", fallback: 1.35) - 1.35) < 0.001)

        // Formatting
        #expect(ZoomPolicy.formatPercentage(1.00) == "100%")
        #expect(ZoomPolicy.formatPercentage(1.14) == "114%")
        #expect(ZoomPolicy.formatPercentage(0.10) == "10%")
        #expect(ZoomPolicy.formatPercentage(5.00) == "500%")
    }

    @MainActor
    @Test func zoomPersistsAcrossDocumentLoad() {
        let fixture = URL(fileURLWithPath: "Tests/Fixtures/kitchen-sink-small.md").standardizedFileURL
        let profiler = StartupProfiler()
        let controller = DocumentWindowController(url: fixture, directoryMode: false, options: .default, profiler: profiler)

        controller.zoomIn(nil) // 110%
        controller.zoomIn(nil) // 120%
        #expect(abs(controller.currentMagnificationLevel - 1.20) < 0.001)

        let target = URL(fileURLWithPath: "Tests/Fixtures/kitchen-sink.md").standardizedFileURL
        controller.loadTargetURL(target)

        #expect(abs(controller.currentMagnificationLevel - 1.20) < 0.001)
    }
}
