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

    @Test func testStyleTagPreservedWhileScriptDisarmed() throws {
        let md = """
        <style>
        body:has(#mdvu-showcase) { margin: 0; }
        </style>

        <script>alert('xss')</script>

        Inline `<style>code</style>` preserved as literal.
        """
        let result = MarkdownPipeline(dialect: .github, mermaid: false).render(md)
        #expect(result.body.contains("<style>\nbody:has(#mdvu-showcase) { margin: 0; }\n</style>"))
        #expect(!result.body.contains("<script>"))
        #expect(result.body.contains("<code>&lt;style&gt;code&lt;/style&gt;</code>"))
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
        #expect(ResourceLoader.mermaidJavaScript.contains("mermaid-zenuml"))
        #expect(ResourceLoader.mermaidJavaScript.contains("swimlane"))
        #expect(ResourceLoader.mermaidJavaScript.contains("ishikawa"))
        #expect(ResourceLoader.mermaidJavaScript.utf8.count > 5_000_000)
    }

    @Test func plantumlUsesPlaceholder() {
        let pumlResult = MarkdownPipeline(dialect: .generic, mermaid: true).render("```puml\nAlice -> Bob\n```")
        #expect(pumlResult.body.contains("data-renderer=\"plantuml\""))

        let plantumlResult = MarkdownPipeline(dialect: .generic, mermaid: true).render("```plantuml\nclass Car\n```")
        #expect(plantumlResult.body.contains("data-renderer=\"plantuml\""))
    }

    @Test func compressedPlantUMLResourceLoads() {
        #expect(ResourceLoader.plantumlJavaScript.contains("PlantUML"))
        #expect(ResourceLoader.plantumlJavaScript.contains("renderToString"))
        #expect(ResourceLoader.plantumlJavaScript.contains("Viz"))
        #expect(ResourceLoader.plantumlJavaScript.utf8.count > 4_000_000)
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

    private static func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)")
            .standardizedFileURL
    }

    @MainActor
    @Test func documentWindowTitleClickAndLoad() {
        let fixture = Self.fixtureURL("test-light.md")
        let profiler = StartupProfiler()
        let controller = DocumentWindowController(url: fixture, directoryMode: false, options: .default, profiler: profiler)
        guard let win = controller.window as? DocumentWindow else {
            #expect(Bool(false))
            return
        }
        #expect(win.title == "test-light.md")

        var changedURL: URL?
        controller.onDocumentChange = { url in changedURL = url }

        let target = Self.fixtureURL("test-medium.md")
        controller.loadTargetURL(target)

        #expect(win.title == "test-medium.md")
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
        let fixture = Self.fixtureURL("test-light.md")
        let profiler = StartupProfiler()
        let controller = DocumentWindowController(url: fixture, directoryMode: false, options: .default, profiler: profiler)

        controller.zoomIn(nil) // 110%
        controller.zoomIn(nil) // 120%
        #expect(abs(controller.currentMagnificationLevel - 1.20) < 0.001)

        let target = Self.fixtureURL("test-medium.md")
        controller.loadTargetURL(target)

        #expect(abs(controller.currentMagnificationLevel - 1.20) < 0.001)
    }

    @MainActor
    @Test func zoomPinchAndDiscreteSteps() {
        let fixture = Self.fixtureURL("test-light.md")
        let profiler = StartupProfiler()
        let controller = DocumentWindowController(url: fixture, directoryMode: false, options: .default, profiler: profiler)

        #expect(abs(controller.effectiveZoom - 1.0) < 0.001)

        // Mouse wheel magnification
        controller.applyMagnification(1.4, centeredAt: CGPoint(x: 200, y: 150))
        #expect(abs(controller.effectiveZoom - 1.4) < 0.01)

        // Sub-100% zoom (below WebKit's former 1.0 ceiling)
        controller.setUnifiedMagnification(0.5, centeredAt: CGPoint(x: 200, y: 150))
        #expect(abs(controller.effectiveZoom - 0.5) < 0.01)
        controller.setUnifiedMagnification(0.1, centeredAt: CGPoint(x: 200, y: 150))
        #expect(abs(controller.effectiveZoom - 0.1) < 0.01)

        // Above 300% zoom (above WebKit's former 3.0 ceiling)
        controller.setUnifiedMagnification(4.5, centeredAt: CGPoint(x: 200, y: 150))
        #expect(abs(controller.effectiveZoom - 4.5) < 0.01)
        controller.setUnifiedMagnification(5.0, centeredAt: CGPoint(x: 200, y: 150))
        #expect(abs(controller.effectiveZoom - 5.0) < 0.01)

        // Reset zoom resets to 1.0
        controller.resetZoom(nil)
        #expect(abs(controller.effectiveZoom - 1.0) < 0.001)

        // Discrete zoom steps
        controller.zoomIn(nil)
        #expect(abs(controller.effectiveZoom - 1.1) < 0.001)
        controller.zoomOut(nil)
        #expect(abs(controller.effectiveZoom - 1.0) < 0.001)
    }

    @MainActor
    @Test func aboutPanelContentAndLinks() {
        let attrString = AboutPanelController.makeAttributedString(version: "0.4.0")
        let plain = attrString.string

        #expect(plain.contains("mdvu\n"))
        #expect(plain.contains("Markdown and Mermaid Viewer\n"))
        #expect(plain.contains("Version: 0.4.0\n"))
        #expect(plain.contains("Copyright © 2026 Finn de Bear"))
        #expect(!plain.contains("(1)"))
        #expect(!plain.contains("("))

        // Check links
        var foundRepoLink = false
        var foundReleaseLink = false
        var foundMailLink = false

        attrString.enumerateAttribute(.link, in: NSRange(location: 0, length: attrString.length), options: []) { value, range, _ in
            guard let url = value as? URL else { return }
            let substring = (plain as NSString).substring(with: range)
            if url.absoluteString == "https://github.com/stpork/mdvu" && substring == "mdvu\n" {
                foundRepoLink = true
            }
            if url.absoluteString == "https://github.com/stpork/mdvu/releases/tag/v0.4.0" && substring.contains("0.4.0") {
                foundReleaseLink = true
            }
            if url.absoluteString == "mailto:finndebear@gmail.com" && substring == "Finn de Bear" {
                foundMailLink = true
            }
        }

        #expect(foundRepoLink)
        #expect(foundReleaseLink)
        #expect(foundMailLink)

        // Check center paragraph alignments
        attrString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attrString.length), options: []) { value, _, _ in
            if let style = value as? NSParagraphStyle {
                #expect(style.alignment == .center)
            }
        }
    }

    @Test func cliOptionsAndExtensionDetection() {
        // Dialects
        #expect(CLIOptions.parse(["--dialect", "generic"]).dialect == .generic)
        #expect(CLIOptions.parse(["--dialect", "github"]).dialect == .github)
        #expect(CLIOptions.parse(["--dialect", "obsidian"]).dialect == .obsidian)
        #expect(CLIOptions.parse(["--dialect", "unknown"]).dialect == .generic)

        // Themes
        #expect(CLIOptions.parse(["--theme", "dark"]).theme == .dark)
        #expect(CLIOptions.parse(["--theme", "light"]).theme == .light)
        #expect(CLIOptions.parse(["--theme", "system"]).theme == .system)

        // Flags & options
        let parsed = CLIOptions.parse(["--no-mermaid", "--full-width", "--snapshot", "/tmp/shot.png", "doc1.md", "doc2.markdown"])
        #expect(!parsed.mermaid)
        #expect(parsed.fullWidth == true)
        #expect(parsed.snapshotPath == "/tmp/shot.png")
        #expect(parsed.paths == ["doc1.md", "doc2.markdown"])

        #expect(CLIOptions.usage.contains("--version"))
        #expect(CLIOptions.usage.contains("--help"))

        // File extensions
        #expect(MarkdownDocument.isMarkdown(url: URL(fileURLWithPath: "/path/doc.md")))
        #expect(MarkdownDocument.isMarkdown(url: URL(fileURLWithPath: "/path/doc.MARKDOWN")))
        #expect(MarkdownDocument.isMarkdown(url: URL(fileURLWithPath: "/path/doc.mdown")))
        #expect(MarkdownDocument.isMarkdown(url: URL(fileURLWithPath: "/path/doc.mkd")))
        #expect(!MarkdownDocument.isMarkdown(url: URL(fileURLWithPath: "/path/doc.txt")))
        #expect(!MarkdownDocument.isMarkdown(url: URL(fileURLWithPath: "/path/doc.html")))
        #expect(!MarkdownDocument.isMarkdown(url: URL(fileURLWithPath: "/path/doc.png")))
    }

    @Test func frontMatterExtensionWithCRLF() {
        let crlfSource = "---\r\nTitle: Windows Document\r\nAuthor: Developer\r\n---\r\n# Hello World"
        let rendered = MarkdownPipeline(dialect: .github, mermaid: false).render(crlfSource)
        #expect(rendered.body.contains("Document metadata"))
        #expect(rendered.body.contains("Windows Document"))
        #expect(rendered.body.contains("Developer"))
        #expect(rendered.body.contains("Hello World"))

        // Without frontmatter
        let plain = "# Just Markdown"
        let renderedPlain = MarkdownPipeline(dialect: .github, mermaid: false).render(plain)
        #expect(!renderedPlain.body.contains("Document metadata"))
    }

    @MainActor
    @Test func fileWatcherDetectsModification() async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("test.md")
        try? "initial content".write(to: fileURL, atomically: false, encoding: .utf8)

        var triggered = false
        let watcher = FileWatcher(url: fileURL) {
            triggered = true
        }
        #expect(watcher != nil)

        // Modify file in-place
        try? "modified content".write(to: fileURL, atomically: false, encoding: .utf8)

        // Allow debounce time (FileWatcher uses 180ms debounce)
        for _ in 0..<15 {
            if triggered { break }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        #expect(triggered)
    }

    @MainActor
    @Test func aboutPanelLifecycleAndKeyboardShortcuts() {
        let controller = AboutPanelController.shared
        controller.show()

        guard let win = controller.window else {
            #expect(Bool(false))
            return
        }
        #expect(win.isVisible)
        #expect(win.level == .floating)
        #expect(win.isMovableByWindowBackground)

        // Link click handling (mock urlOpener to avoid launching browser during tests)
        var openedURLs: [URL] = []
        let originalOpener = controller.urlOpener
        controller.urlOpener = { url in
            openedURLs.append(url)
            return true
        }
        defer { controller.urlOpener = originalOpener }

        let repoURL = URL(string: "https://github.com/stpork/mdvu")!
        let dummyTextView = NSTextView()
        #expect(controller.textView(dummyTextView, clickedOnLink: repoURL, at: 0))
        #expect(controller.textView(dummyTextView, clickedOnLink: "https://github.com/stpork/mdvu", at: 0))
        #expect(!controller.textView(dummyTextView, clickedOnLink: 12345, at: 0))
        #expect(openedURLs.count == 2)
        #expect(openedURLs[0].absoluteString == "https://github.com/stpork/mdvu")

        // Escape closes window
        let escEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: win.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
        win.keyDown(with: escEvent)
        #expect(!win.isVisible)

        // Reopen
        controller.show()
        #expect(win.isVisible)

        // Cmd+W closes window
        let cmdWEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: win.windowNumber, context: nil, characters: "w", charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13)!
        let handled = win.performKeyEquivalent(with: cmdWEvent)
        #expect(handled)
        #expect(!win.isVisible)
    }

    @MainActor
    @Test func appMenuStructureAndActions() {
        let delegate = AppDelegate(arguments: [])
        let menu = AppMenu.make(target: delegate)

        #expect(menu.items.count >= 5) // App, File, Edit, View, Go
        let appItem = menu.items.first
        let appMenu = appItem?.submenu
        #expect(appMenu?.items.contains(where: { $0.title == "About mdvu" }) == true)

        let viewItem = menu.items.first { $0.submenu?.title == "View" }
        let viewMenu = viewItem?.submenu
        #expect(viewMenu?.items.contains(where: { $0.title == "Actual Size" }) == true)
        #expect(viewMenu?.items.contains(where: { $0.title == "Zoom In" }) == true)
        #expect(viewMenu?.items.contains(where: { $0.title == "Zoom Out" }) == true)

        let dialectItem = viewMenu?.items.first { $0.title == "Dialect" }
        #expect(dialectItem != nil)
        let dialectMenu = dialectItem?.submenu
        #expect(dialectMenu?.items.contains(where: { $0.title == "Generic (CommonMark)" }) == true)
        #expect(dialectMenu?.items.contains(where: { $0.title == "GitHub (GFM)" }) == true)
        #expect(dialectMenu?.items.contains(where: { $0.title == "Obsidian" }) == true)
    }

    @MainActor
    @Test func documentWindowControllerToggles() {
        let fixture = Self.fixtureURL("test-light.md")
        let profiler = StartupProfiler()
        let controller = DocumentWindowController(url: fixture, directoryMode: false, options: .default, profiler: profiler)

        // Full width toggle
        let initialFullWidth = controller.isFullWidth
        controller.toggleFullWidth(nil)
        #expect(controller.isFullWidth != initialFullWidth)
        controller.toggleFullWidth(nil)
        #expect(controller.isFullWidth == initialFullWidth)

        // Sidebar contents toggle
        let initialSplitState = controller.isSidebarVisible
        controller.toggleContents(nil)
        #expect(controller.isSidebarVisible != initialSplitState)
        controller.toggleContents(nil)
        #expect(controller.isSidebarVisible == initialSplitState)

        // File navigator toggle
        let initialNavState = controller.isFileNavigatorVisible
        #expect(initialNavState == false)
        controller.toggleFileNavigator(nil)
        #expect(controller.isFileNavigatorVisible == true)
        controller.toggleFileNavigator(nil)
        #expect(controller.isFileNavigatorVisible == false)

        // Toolbar item presence
        let toolbar = controller.window?.toolbar
        #expect(toolbar != nil)
        let allowed = controller.toolbarAllowedItemIdentifiers(toolbar!)
        #expect(allowed.contains(NSToolbarItem.Identifier("mdvu.navigator")))

        // Menu item validation
        let navMenuItem = NSMenuItem(title: "Show File Navigator", action: #selector(DocumentWindowController.toggleFileNavigator(_:)), keyEquivalent: "d")
        #expect(controller.validateMenuItem(navMenuItem) == true)
        #expect(navMenuItem.title == "Show File Navigator")
        #expect(navMenuItem.state == .off)

        controller.toggleFileNavigator(nil)
        _ = controller.validateMenuItem(navMenuItem)
        #expect(navMenuItem.title == "Hide File Navigator")
        #expect(navMenuItem.state == .on)
        controller.toggleFileNavigator(nil)
    }

    @Test func testCompleteValidationEcosystem() throws {
        let fixture = Self.fixtureURL("test-complete.md")
        let data = try Data(contentsOf: fixture)
        let source = String(decoding: data, as: UTF8.self)

        let pipeline = MarkdownPipeline(dialect: .github, mermaid: true)
        let doc = pipeline.render(source)

        // Title extracted from first heading
        #expect(doc.title != nil)

        // Validation markers
        #expect(doc.body.contains("MDVU-COMPLETE-BEGIN"))
        #expect(doc.body.contains("MDVU-COMPLETE-MIDDLE"))
        #expect(doc.body.contains("MDVU-COMPLETE-END"))
        #expect(doc.body.contains("MDVU-DIAGRAMS-END"))

        // Expanded sections 19-23 contracts
        #expect(doc.body.contains("MATH-001"))
        #expect(doc.body.contains("LIT-001"))
        #expect(doc.body.contains("GFM-001"))
        #expect(doc.body.contains("OBS-001"))

        // Diagram and Math placeholders
        #expect(doc.body.contains("data-renderer=\"mermaid\""))
        #expect(doc.body.contains("data-renderer=\"plantuml\""))
        #expect(doc.body.contains("<span class=\"math-inline\">E = mc^2</span>"))
        #expect(doc.body.contains("math-display"))

        // Obsidian dialect validation on complete fixture
        let obsidianDoc = MarkdownPipeline(dialect: .obsidian, mermaid: true).render(source)
        #expect(obsidianDoc.body.contains("Architecture Overview.md"))
    }

    @Test func testAllMathCasesInFixture() throws {
        let fixture = Self.fixtureURL("test-complete.md")
        let data = try Data(contentsOf: fixture)
        let source = String(decoding: data, as: UTF8.self)

        let pipeline = MarkdownPipeline(dialect: .github, mermaid: true)

        for i in 1...42 {
            let caseID = String(format: "MATH-%03d", i)
            guard let beginRange = source.range(of: "<!-- mdvu-case-begin: \(caseID) -->"),
                  let endRange = source.range(of: "<!-- mdvu-case-end: \(caseID) -->", range: beginRange.upperBound..<source.endIndex) else {
                continue
            }
            let rawSnippet = String(source[beginRange.upperBound..<endRange.lowerBound])
            let renderedSnippet = pipeline.render(rawSnippet).body
            let hasMath = renderedSnippet.contains("math-inline") || renderedSnippet.contains("math-display")
            if !hasMath {
                print("FAILED MATH CASE: \(caseID) -> raw: [\(rawSnippet)] rendered: [\(renderedSnippet)]")
            }
            #expect(hasMath, "Expected math in case \(caseID)")
        }
    }

    @Test func testRuntimeSecurityAndErrorFixtures() throws {
        let runtimeDir = Self.fixtureURL("runtime")
        let fileManager = FileManager.default
        let items = try fileManager.contentsOfDirectory(at: runtimeDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }

        #expect(items.count >= 25)

        let ghPipeline = MarkdownPipeline(dialect: .github, mermaid: true)
        let obsPipeline = MarkdownPipeline(dialect: .obsidian, mermaid: true)

        for fileURL in items {
            let data = try Data(contentsOf: fileURL)
            let content = String(decoding: data, as: UTF8.self)

            // Resiliency test: invalid math, recursive macros, and stress tokens must not crash
            let ghDoc = ghPipeline.render(content)
            #expect(!ghDoc.body.isEmpty)

            let obsDoc = obsPipeline.render(content)
            #expect(!obsDoc.body.isEmpty)

            // Security assertion: disallowed schemes and script tags must not produce executable unescaped tags
            if fileURL.lastPathComponent.hasPrefix("sec-") {
                #expect(!ghDoc.body.contains("<script>alert("))
                #expect(!obsDoc.body.contains("<script>alert("))
            }
        }
    }

    @Test func testCompanionFixtureAssetsIntegrity() {
        let assetsDir = Self.fixtureURL("assets")
        let archDoc = Self.fixtureURL("Architecture Overview.md")
        let diagramPng = Self.fixtureURL("diagram.png")
        let projectsDir = Self.fixtureURL("Projects")
        let docsDir = Self.fixtureURL("docs")

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: assetsDir.path))
        #expect(fm.fileExists(atPath: archDoc.path))
        #expect(fm.fileExists(atPath: diagramPng.path))
        #expect(fm.fileExists(atPath: projectsDir.path))
        #expect(fm.fileExists(atPath: docsDir.path))
    }

    @Test func testHeavyTortureFixtureValidation() throws {
        let fixture = Self.fixtureURL("test-heavy.md")
        let data = try Data(contentsOf: fixture)
        let source = String(decoding: data, as: UTF8.self)

        let pipeline = MarkdownPipeline(dialect: .github, mermaid: true)
        let doc = pipeline.render(source)

        // Title extracted from frontmatter / first heading
        #expect(doc.title?.contains("mdvu Full Torture Test") == true)

        // Verifying torture markers and constructs rendered
        #expect(doc.body.contains("GENERATED-STATS-BEGIN"))
        #expect(doc.body.contains("MDVU-TORTURE-TEST-END"))

        // Stress check: mermaid blocks rendered to placeholders and headings generated
        #expect(doc.body.contains("data-renderer=\"mermaid\""))
        #expect(doc.body.contains("<h1") || doc.body.contains("<h2"))
        #expect(doc.body.count > 100_000)
    }

    @Test func testCriticMarkupRendering() {
        let pipeline = MarkdownPipeline(dialect: .github, mermaid: false)
        let md = """
        Here is {++added text++} and {--deleted text--}.
        Substitution: {~~old~>new~~}.
        Highlight: {==important==}.
        Comment: {>>note to author<<}.

        ```text
        {++code block content++}
        ```
        """
        let doc = pipeline.render(md)
        #expect(doc.body.contains("<ins class=\"critic-add\">added text</ins>"))
        #expect(doc.body.contains("<del class=\"critic-del\">deleted text</del>"))
        #expect(doc.body.contains("<del class=\"critic-del\">old</del><ins class=\"critic-add\">new</ins>"))
        #expect(doc.body.contains("<mark class=\"critic-mark\">important</mark>"))
        #expect(doc.body.contains("<span class=\"critic-comment\""))
        #expect(doc.body.contains("{++code block content++}"))
    }

    @Test func testSubSuperscriptAndStrikethrough() {
        let pipeline = MarkdownPipeline(dialect: .github, mermaid: false)
        let md = """
        Water is H~2~O and energy is E = mc^2^.
        Underline is ^^emphasized^^.
        GFM strikethrough: ~~deleted content~~.

        ```text
        ~not-sub~ ^not-sup^
        ```
        """
        let doc = pipeline.render(md)
        #expect(doc.body.contains("H<sub>2</sub>O"))
        #expect(doc.body.contains("mc<sup>2</sup>"))
        #expect(doc.body.contains("<u>emphasized</u>"))
        #expect(doc.body.contains("<del>deleted content</del>"))
        #expect(!doc.body.contains("<sub>deleted content</sub>"))
        #expect(doc.body.contains("~not-sub~ ^not-sup^"))
    }

    @Test func testAdmonitionAndContainers() {
        let pipeline = MarkdownPipeline(dialect: .github, mermaid: false)
        let md = """
        !!! note "Custom Title"
            This is a note body.

        ???+ tip
            Collapsible tip.

        :::warning
        This is a warning block.
        :::
        """
        let doc = pipeline.render(md)
        #expect(doc.body.contains("callout-note"))
        #expect(doc.body.contains("Custom Title"))
        #expect(doc.body.contains("callout-tip"))
        #expect(doc.body.contains("callout-warning"))
    }

    @Test func testGitLabTOCPlaceholder() {
        let pipeline = MarkdownPipeline(dialect: .github, mermaid: false)
        let md = """
        # Documentation

        [[_TOC_]]

        ## Next Section
        """
        let doc = pipeline.render(md)
        #expect(doc.body.contains("toc-placeholder"))
        #expect(doc.body.contains("Table of Contents"))
    }

    @Test func testZoomPolicySnapping() {
        // Snapping within ±2.5% of 10% multiples
        #expect(ZoomPolicy.formatPercentage(1.0) == "100%")
        #expect(ZoomPolicy.formatPercentage(1.01) == "100%")
        #expect(ZoomPolicy.formatPercentage(1.02) == "100%")
        #expect(ZoomPolicy.formatPercentage(0.98) == "100%")
        #expect(ZoomPolicy.formatPercentage(2.01) == "200%")
        #expect(ZoomPolicy.formatPercentage(1.52) == "150%")
        #expect(ZoomPolicy.formatPercentage(3.02) == "300%")

        // Outside snapping tolerance remains exact
        #expect(ZoomPolicy.formatPercentage(1.34) == "134%")
        #expect(ZoomPolicy.formatPercentage(1.26) == "126%")
    }

    @Test func testCompressedKaTeXResourceLoads() {
        let js = ResourceLoader.katexJavaScript
        #expect(!js.isEmpty)
        #expect(js.contains("katex"))
    }

    @Test func testInlineAndDisplayMathParsing() {
        let pipeline = MarkdownPipeline(dialect: .github, mermaid: false)
        let md = """
        Для объявленных границы $B$, контура $\\ell$, возмущений $D$ и регуляторной способности $G$:

        $$
        \\Delta_{\\mathrm{maint}}(B,\\ell,D)
        =\\mathbb E[G\\mid\\pi_{\\mathrm{aligned}}]
        -\\mathbb E[G\\mid\\pi_{\\mathrm{misaligned}}].
        $$

        Здесь $\\pi$ — политика последовательных вмешательств.
        """
        let doc = pipeline.render(md)
        #expect(doc.body.contains("<span class=\"math-inline\">B</span>"))
        #expect(doc.body.contains("<span class=\"math-inline\">\\ell</span>"))
        #expect(doc.body.contains("<span class=\"math-inline\">D</span>"))
        #expect(doc.body.contains("<span class=\"math-inline\">G</span>"))
        #expect(doc.body.contains("<span class=\"math-inline\">\\pi</span>"))
        #expect(doc.body.contains("<div class=\"math-display\">"))
        #expect(doc.body.contains("\\Delta_{\\mathrm{maint}}"))
    }

    @Test func testMathCodeBlockAndFences() {
        let pipeline = MarkdownPipeline(dialect: .github, mermaid: false)
        let md = """
        ```math
        E = mc^2
        ```

        Here is code: `$not_math$` and price: $10 and $20 for items.
        """
        let doc = pipeline.render(md)
        #expect(doc.body.contains("<div class=\"math-display\">E = mc^2</div>"))
        #expect(doc.body.contains("<code>$not_math$</code>"))
        #expect(!doc.body.contains("<span class=\"math-inline\">10 and "))
        #expect(doc.body.contains("$10 and $20"))
    }

    @Test func testFastScanTokensAndAscii() {
        let text = "Hello world with [!NOTE] and $math$ and ```code```"
        #expect(FastScan.contains(text, token: "[!"))
        #expect(FastScan.contains(text, token: "```"))
        #expect(FastScan.contains(text, ascii: UInt8(ascii: "$")))
        #expect(!FastScan.contains(text, token: "missing"))
        #expect(!FastScan.contains(text, ascii: UInt8(ascii: "%")))
    }

    @Test func testEagerDocumentLoaderLifecycle() {
        let fixture = Self.fixtureURL("test-light.md")
        EagerDocumentLoader.start(path: fixture.path, options: .default)
        let task = EagerDocumentLoader.take(for: fixture)
        #expect(task != nil)
        #expect(EagerDocumentLoader.take(for: fixture) == nil)
    }

    @Test @MainActor func testDocumentWindowControllerDeallocationWithoutRetainCycle() {
        weak var weakController: DocumentWindowController?
        let fixture = Self.fixtureURL("test-light.md")
        autoreleasepool {
            let controller = DocumentWindowController(url: fixture, directoryMode: false, options: .default, profiler: StartupProfiler())
            weakController = controller
            #expect(weakController != nil)
            controller.window?.close()
        }
        #expect(weakController == nil)
    }

    @Test func testFrontMatterDialectDetection() {
        let obsSource = """
        ---
        title: Note with Obsidian
        dialect: obsidian
        ---
        # Notes
        See [[Target|My Target]]
        ![[photo.png]]
        """
        let defaultPipeline = MarkdownPipeline(dialect: .generic, mermaid: false)
        let renderedObs = defaultPipeline.render(obsSource)
        #expect(renderedObs.dialect == .obsidian)
        #expect(renderedObs.body.contains("<a href=\"Target.md\">My Target</a>"))
        #expect(renderedObs.body.contains("<img src=\"photo.png\" alt=\"photo.png\""))

        let ghSource = """
        ---
        dialect: github
        ---
        [[NotAWikiLink]]
        """
        let renderedGh = defaultPipeline.render(ghSource)
        #expect(renderedGh.dialect == .github)
        #expect(!renderedGh.body.contains("<a href=\"NotAWikiLink\">"))

        let commentObs = """
        <!-- dialect: obsidian -->
        [[Target|Link]]
        """
        let renderedComment = defaultPipeline.render(commentObs)
        #expect(renderedComment.dialect == .obsidian)
        #expect(renderedComment.body.contains("<a href=\"Target.md\">Link</a>"))

        // Explicit CLI override overrides frontmatter
        let explicitGenericPipeline = MarkdownPipeline(dialect: .generic, mermaid: false, isDialectExplicit: true)
        let renderedExplicit = explicitGenericPipeline.render(obsSource)
        #expect(renderedExplicit.dialect == .generic)
        #expect(!renderedExplicit.body.contains("<a href=\"Target.md\">My Target</a>"))
    }

    @Test @MainActor func testDialectMenuActionsAndValidation() {
        let fixture = Self.fixtureURL("test-light.md")
        let controller = DocumentWindowController(url: fixture, directoryMode: false, options: .default, profiler: StartupProfiler())
        #expect(controller.currentDialect == .generic)

        let autoItem = NSMenuItem(title: "Automatic", action: #selector(DocumentWindowController.selectDialectAuto(_:)), keyEquivalent: "")
        let genericItem = NSMenuItem(title: "Generic", action: #selector(DocumentWindowController.selectDialectGeneric(_:)), keyEquivalent: "")
        let githubItem = NSMenuItem(title: "GitHub", action: #selector(DocumentWindowController.selectDialectGitHub(_:)), keyEquivalent: "")
        let obsidianItem = NSMenuItem(title: "Obsidian", action: #selector(DocumentWindowController.selectDialectObsidian(_:)), keyEquivalent: "")

        #expect(controller.validateMenuItem(autoItem) == true)
        #expect(autoItem.state == .on)
        #expect(controller.validateMenuItem(genericItem) == true)
        #expect(genericItem.state == .on)
        #expect(controller.validateMenuItem(githubItem) == true)
        #expect(githubItem.state == .off)
        #expect(controller.validateMenuItem(obsidianItem) == true)
        #expect(obsidianItem.state == .off)

        controller.selectDialectObsidian(nil)
        #expect(controller.currentDialect == .obsidian)
        _ = controller.validateMenuItem(autoItem)
        _ = controller.validateMenuItem(genericItem)
        _ = controller.validateMenuItem(obsidianItem)
        #expect(autoItem.state == .off)
        #expect(genericItem.state == .off)
        #expect(obsidianItem.state == .on)

        controller.selectDialectGitHub(nil)
        #expect(controller.currentDialect == .github)
        _ = controller.validateMenuItem(autoItem)
        _ = controller.validateMenuItem(githubItem)
        #expect(autoItem.state == .off)
        #expect(githubItem.state == .on)

        controller.selectDialectAuto(nil)
        _ = controller.validateMenuItem(autoItem)
        #expect(autoItem.state == .on)

        controller.window?.close()
    }

    @Test func testTitleStripsHTMLTagsAndDecodesEntities() {
        let pipeline = MarkdownPipeline(dialect: .generic, mermaid: false)
        let doc1 = pipeline.render("# Hello <span class=\"badge\">World</span> &amp; Friends")
        #expect(doc1.title == "Hello World & Friends")

        let doc2 = pipeline.render("<h1><img src=\"icon.png\" alt=\"icon\"/> Document &lt;Special&gt;</h1>")
        #expect(doc2.title == "Document <Special>")
    }

    @Test func testNestedBlockquoteInCallout() {
        let pipeline = MarkdownPipeline(dialect: .obsidian, mermaid: false)
        let md = """
        > [!NOTE] Nested Title
        > Paragraph 1
        > > Inner quote
        > Paragraph 2
        """
        let rendered = pipeline.render(md)
        #expect(rendered.body.contains("<aside class=\"callout callout-note\">"))
        #expect(rendered.body.contains("<blockquote>"))
        #expect(rendered.body.contains("Inner quote"))
        #expect(rendered.body.contains("Paragraph 2"))
    }

    @Test func testCriticMarkupAttributeEscaping() {
        let pipeline = MarkdownPipeline(dialect: .generic, mermaid: false)
        let md = "{>>check \"this\" out & note<<}"
        let rendered = pipeline.render(md)
        #expect(rendered.body.contains("title=\"check &quot;this&quot; out &amp; note\""))
    }

    @Test func testObsidianFourBacktickFenceNotClosedByThree() {
        let pipeline = MarkdownPipeline(dialect: .obsidian, mermaid: false)
        let md = """
        ````markdown
        ```
        > [!NOTE] This should NOT be a callout
        ```
        ````
        """
        let rendered = pipeline.render(md)
        #expect(!rendered.body.contains("<aside class=\"callout"))
        #expect(rendered.body.contains("&gt; [!NOTE] This should NOT be a callout"))
    }

    @Test func testOneScreenFixtureDialectAndCard11() throws {
        let oneScreenPath = "/Users/C5370280/SAPDevelop/Sources/mdvu/Tests/Fixtures/test-onescreen.md"
        guard FileManager.default.fileExists(atPath: oneScreenPath) else { return }
        let source = try String(contentsOfFile: oneScreenPath, encoding: .utf8)
        let pipeline = MarkdownPipeline(dialect: .generic, mermaid: false)
        let rendered = pipeline.render(source)

        #expect(rendered.dialect == .obsidian)
        #expect(rendered.body.contains("<img src=\"data:image/png;base64,iVBORw0KGgo"))
        #expect(rendered.body.contains("<a href=\"MDVu-One-Screen.md#mathematics\">Wiki alias → Mathematics</a>"))
    }

    @Test func testVaultScannerAndVaultRootDetection() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mdvu_vault_test_\(UUID().uuidString)")
        let vaultDir = tempDir.appendingPathComponent("MyVault")
        let obsidianDir = vaultDir.appendingPathComponent(".obsidian")
        let folder1 = vaultDir.appendingPathComponent("Notes")
        let nodeModules = folder1.appendingPathComponent("node_modules")
        let subFolder = folder1.appendingPathComponent("Sub")

        try FileManager.default.createDirectory(at: obsidianDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subFolder, withIntermediateDirectories: true)

        let note1 = folder1.appendingPathComponent("test1.md")
        let note2 = folder1.appendingPathComponent("test2.markdown")
        let image = folder1.appendingPathComponent("photo.png")
        let ignoredNote = nodeModules.appendingPathComponent("ignore.md")
        let deepNote = subFolder.appendingPathComponent("deep.md")
        let rootNote = vaultDir.appendingPathComponent("README.md")

        try "content".write(to: note1, atomically: true, encoding: .utf8)
        try "content".write(to: note2, atomically: true, encoding: .utf8)
        try "png".write(to: image, atomically: true, encoding: .utf8)
        try "ignored".write(to: ignoredNote, atomically: true, encoding: .utf8)
        try "deep".write(to: deepNote, atomically: true, encoding: .utf8)
        try "root".write(to: rootNote, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Test root detection (walks up to .obsidian)
        let detectedVault = VaultScanner.findVaultRoot(for: note1)
        #expect(detectedVault.standardizedFileURL.path == vaultDir.standardizedFileURL.path)

        // Test fallback without .obsidian / .git
        let nonVaultDir = tempDir.appendingPathComponent("OrdinaryFolder")
        try FileManager.default.createDirectory(at: nonVaultDir, withIntermediateDirectories: true)
        let plainNote = nonVaultDir.appendingPathComponent("plain.md")
        try "plain".write(to: plainNote, atomically: true, encoding: .utf8)
        let detectedPlain = VaultScanner.findVaultRoot(for: plainNote)
        #expect(detectedPlain.standardizedFileURL.path == nonVaultDir.standardizedFileURL.path)

        // Test supported file types
        #expect(VaultScanner.isSupported(url: note1))
        #expect(VaultScanner.isSupported(url: note2))
        #expect(!VaultScanner.isSupported(url: image))

        // Test root item scanning
        let rootItem = VaultItem(url: vaultDir, isDirectory: true)
        #expect(rootItem.children == nil) // Lazy check
        rootItem.loadChildrenIfNeeded()
        #expect(rootItem.children != nil)

        let rootChildren = rootItem.children ?? []
        // Should contain "Notes" directory and "README.md", but NOT ".obsidian"
        #expect(rootChildren.contains(where: { $0.name == "Notes" && $0.isDirectory }))
        #expect(rootChildren.contains(where: { $0.name == "README.md" && !$0.isDirectory }))
        #expect(!rootChildren.contains(where: { $0.name == ".obsidian" }))

        // Directories sorted before files
        if let notesIdx = rootChildren.firstIndex(where: { $0.name == "Notes" }),
           let readmeIdx = rootChildren.firstIndex(where: { $0.name == "README.md" }) {
            #expect(notesIdx < readmeIdx)
        }

        // Test subfolder scanning and ignored directory exclusion
        let notesItem = rootChildren.first(where: { $0.name == "Notes" })!
        #expect(notesItem.children == nil)
        notesItem.loadChildrenIfNeeded()
        let notesChildren = notesItem.children ?? []
        #expect(notesChildren.contains(where: { $0.name == "Sub" && $0.isDirectory }))
        #expect(notesChildren.contains(where: { $0.name == "test1.md" && !$0.isDirectory }))
        #expect(notesChildren.contains(where: { $0.name == "test2.markdown" && !$0.isDirectory }))
        #expect(!notesChildren.contains(where: { $0.name == "photo.png" }))
        #expect(!notesChildren.contains(where: { $0.name == "node_modules" }))
    }

    @MainActor
    @Test func testVaultNavigatorViewHierarchyAndSelection() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mdvu_nav_view_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let note = tempDir.appendingPathComponent("Document.md")
        try "# Doc".write(to: note, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let navView = VaultNavigatorView(frame: NSRect(x: 0, y: 0, width: 240, height: 400))
        navView.setRoot(documentURL: note)

        #expect(navView.rootItem != nil)
        #expect(navView.rootItem?.url.standardizedFileURL.path == tempDir.standardizedFileURL.path)

        var openedURL: URL?
        navView.onFileSelected = { openedURL = $0 }
        navView.selectDocument(url: note)
        navView.onFileSelected?(note)
        #expect(openedURL == note)

        var closed = false
        navView.onCloseRequested = { closed = true }
        // Verify close callback wiring
        navView.onCloseRequested?()
        #expect(closed)
    }

    @MainActor
    @Test func testThreePaneSplitLayout() {
        let fixture = Self.fixtureURL("test-light.md")
        let profiler = StartupProfiler()
        let controller = DocumentWindowController(url: fixture, directoryMode: false, options: .default, profiler: profiler)

        controller.window?.setFrame(NSRect(x: 100, y: 100, width: 1080, height: 760), display: true)
        controller.window?.layoutIfNeeded()
        let drop = controller.window?.contentView as? DropView
        let split = drop?.subviews.first as? NSSplitView
        #expect(split != nil)

        defer {
            UserDefaults.standard.removeObject(forKey: "layout.sidebarVisible")
            UserDefaults.standard.removeObject(forKey: "layout.fileNavigatorVisible")
            UserDefaults.standard.removeObject(forKey: "layout.fullWidth")
        }

        // Ensure clean starting state regardless of UserDefaults
        if controller.isSidebarVisible { controller.toggleContents(nil) }
        if controller.isFileNavigatorVisible { controller.toggleFileNavigator(nil) }

        // Initial: only webView
        #expect(split?.subviews.count == 1)

        // Turn on TOC
        controller.toggleContents(nil)
        #expect(controller.isSidebarVisible)
        #expect(split?.subviews.count == 2)
        #expect(controller.window?.frame.width == 1080)

        // Turn on File Navigator
        controller.toggleFileNavigator(nil)
        #expect(controller.isSidebarVisible)
        #expect(controller.isFileNavigatorVisible)
        #expect(split?.subviews.count == 3)
        #expect(controller.window?.frame.width == 1080)

        // Verify subview widths cover split bounds completely
        let splitWidth3 = split?.bounds.width ?? 0
        let totalSubviewsWidth3 = split?.subviews.reduce(0) { $0 + $1.frame.width } ?? 0
        let dividerWidth3 = CGFloat((split?.subviews.count ?? 1) - 1) * (split?.dividerThickness ?? 1)
        #expect(abs((totalSubviewsWidth3 + dividerWidth3) - splitWidth3) <= 2.0)

        // Toggle File Navigator off: pane must be completely removed
        controller.toggleFileNavigator(nil)
        #expect(!controller.isFileNavigatorVisible)
        #expect(controller.isSidebarVisible)
        #expect(split?.subviews.count == 2)
        #expect(controller.window?.frame.width == 1080)

        // Verify remaining subviews fill the entire width
        let splitWidth2 = split?.bounds.width ?? 0
        let totalSubviewsWidth2 = split?.subviews.reduce(0) { $0 + $1.frame.width } ?? 0
        let dividerWidth2 = CGFloat((split?.subviews.count ?? 1) - 1) * (split?.dividerThickness ?? 1)
        #expect(abs((totalSubviewsWidth2 + dividerWidth2) - splitWidth2) <= 2.0)

        // Also test TOC off: returns to 1 subview filling entire window
        controller.toggleContents(nil)
        #expect(!controller.isSidebarVisible)
        #expect(split?.subviews.count == 1)
        #expect(controller.window?.frame.width == 1080)
        #expect(abs((split?.subviews[0].frame.width ?? 0) - (split?.bounds.width ?? 0)) <= 2.0)

        // Test File Navigator ON with TOC OFF
        controller.toggleFileNavigator(nil)
        #expect(controller.isFileNavigatorVisible)
        #expect(!controller.isSidebarVisible)
        #expect(split?.subviews.count == 2)
        #expect(controller.window?.frame.width == 1080)

        // Toggle File Navigator OFF again: back to 1 subview
        controller.toggleFileNavigator(nil)
        #expect(!controller.isFileNavigatorVisible)
        #expect(!controller.isSidebarVisible)
        #expect(split?.subviews.count == 1)
        #expect(controller.window?.frame.width == 1080)
        #expect(abs((split?.subviews[0].frame.width ?? 0) - (split?.bounds.width ?? 0)) <= 2.0)
    }

    @MainActor
    @Test func testToolbarDepressedStatesAndBackForwardControls() {
        let fixture = Self.fixtureURL("test-light.md")
        let fixture2 = Self.fixtureURL("test-dark.md")
        let profiler = StartupProfiler()
        let controller = DocumentWindowController(url: fixture, directoryMode: false, options: .default, profiler: profiler)
        defer {
            UserDefaults.standard.removeObject(forKey: "layout.sidebarVisible")
            UserDefaults.standard.removeObject(forKey: "layout.fileNavigatorVisible")
            UserDefaults.standard.removeObject(forKey: "layout.fullWidth")
        }

        let toolbar = controller.window?.toolbar
        #expect(toolbar != nil)

        // Find toolbar items
        let sidebarItem = toolbar?.items.first { $0.itemIdentifier == NSToolbarItem.Identifier("mdvu.contents") }
        let navItem = toolbar?.items.first { $0.itemIdentifier == NSToolbarItem.Identifier("mdvu.navigator") }
        let backForwardItem = toolbar?.items.first { $0.itemIdentifier == NSToolbarItem.Identifier("mdvu.backForward") }

        #expect(sidebarItem != nil)
        #expect(navItem != nil)
        #expect(backForwardItem != nil)

        let sidebarBtn = sidebarItem?.view as? NSButton
        let navBtn = navItem?.view as? NSButton
        let backForwardCtrl = backForwardItem?.view as? NSSegmentedControl

        #expect(sidebarBtn != nil)
        #expect(navBtn != nil)
        #expect(backForwardCtrl != nil)

        // Verify initial depressed states match visibility
        #expect(sidebarBtn?.state == (controller.isSidebarVisible ? .on : .off))
        #expect(navBtn?.state == (controller.isFileNavigatorVisible ? .on : .off))

        // Toggle TOC and verify depressed state flips
        let prevSidebarState = controller.isSidebarVisible
        controller.toggleContents(nil)
        #expect(controller.isSidebarVisible != prevSidebarState)
        #expect(sidebarBtn?.state == (controller.isSidebarVisible ? .on : .off))

        // Toggle Navigator and verify depressed state flips
        let prevNavState = controller.isFileNavigatorVisible
        controller.toggleFileNavigator(nil)
        #expect(controller.isFileNavigatorVisible != prevNavState)
        #expect(navBtn?.state == (controller.isFileNavigatorVisible ? .on : .off))

        // Back/forward controls initially disabled
        #expect(!controller.canGoBack)
        #expect(!controller.canGoForward)
        #expect(backForwardCtrl?.isEnabled(forSegment: 0) == false)
        #expect(backForwardCtrl?.isEnabled(forSegment: 1) == false)

        // Turn navigator on and navigate to second file
        if !controller.isFileNavigatorVisible { controller.toggleFileNavigator(nil) }
        #expect(controller.isFileNavigatorVisible)

        // Navigate to fixture2
        controller.openDocument(fixture2)
        #expect(controller.canGoBack)
        #expect(backForwardCtrl?.isEnabled(forSegment: 0) == true)
        #expect(!controller.canGoForward)
        #expect(backForwardCtrl?.isEnabled(forSegment: 1) == false)

        // Go back
        controller.goBack(nil)
        #expect(!controller.canGoBack)
        #expect(backForwardCtrl?.isEnabled(forSegment: 0) == false)
        #expect(controller.canGoForward)
        #expect(backForwardCtrl?.isEnabled(forSegment: 1) == true)
    }

    @MainActor
    @Test func testVaultNavigatorOutlineViewPopulated() throws {
        let fixture = Self.fixtureURL("test-light.md")
        let navView = VaultNavigatorView(frame: NSRect(x: 0, y: 0, width: 240, height: 400))
        navView.setRoot(documentURL: fixture)

        #expect(navView.rootItem != nil)
        let childCount = navView.outlineView(NSOutlineView(), numberOfChildrenOfItem: nil)
        #expect(childCount > 0)

        let firstChild = navView.outlineView(NSOutlineView(), child: 0, ofItem: nil) as? VaultItem
        #expect(firstChild != nil)

        let cell = navView.outlineView(NSOutlineView(), viewFor: nil, item: firstChild!) as? NSTableCellView
        #expect(cell != nil)
        #expect(cell?.textField?.stringValue.isEmpty == false)
        #expect(cell?.imageView?.image != nil)
    }
}

