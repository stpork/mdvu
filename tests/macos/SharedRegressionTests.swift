import AppKit
import Foundation
import Testing
import WebKit
@testable import mdvu

struct SharedRegressionTests {
    @Test func crlfFrontmatterAndTruncatedHeader() {
        for nl in ["\n", "\r\n"] {
            let source = "---\(nl)dialect: obsidian\(nl)---\(nl)[[Target]]"
            #expect(MarkdownDocumentDirective.extractDialect(from: source) == .obsidian)
            #expect(MarkdownPipeline(dialect: .generic, mermaid: false).render(source).body.contains("Target.md"))
            #expect(!MarkdownPipeline(dialect: .generic, mermaid: false).render("---\(nl)").body.isEmpty)
        }
    }
    @Test func protectedRegionsAndWikiDestinations() {
        let pipeline = MarkdownPipeline(dialect: .obsidian, mermaid: false)
        let code = pipeline.render("`[[Target]]` and `{++literal++}`\n\n    $x$\n\n> ```text\n> [[Target]] $x$\n> ```").body
        #expect(code.contains("<code>[[Target]]</code>"))
        #expect(code.contains("{++literal++}"))
        #expect(!code.contains("math-inline"))
        let links = pipeline.render("[[Architecture Overview|Design]]\n\n![[assets/diagram light.png]]").body
        #expect(links.contains("href=\"Architecture%20Overview.md\""))
        #expect(links.contains("src=\"assets/diagram%20light.png\""))
        let math = pipeline.render("$a^b+c^d$ and $H~2~O$").body
        #expect(math.contains("a^b+c^d"))
        #expect(math.contains("H~2~O"))
        let html = pipeline.render("<a href=\"https://example.org/$a$\">link</a>").body
        #expect(html.contains("https://example.org/$a$"))
    }
    @Test func unmatchedMathIsBounded() {
        let source = String(repeating: "$a ", count: 32_000)
        let start = ContinuousClock.now
        let doc = MarkdownPipeline(dialect: .generic, mermaid: false).render(source)
        #expect(!doc.body.contains("math-inline"))
        #expect(start.duration(to: .now) < .seconds(5))
    }
    @Test func bridgePreservesNulAndOptions() throws {
        let bridge = MdvuCoreBridge.shared
        guard bridge.isAvailable else { return } // Fallback run has no FFI requirement.
        let source = "---\ndialect: obsidian\n---\n[[Target]]\n\0\n# After\n```mermaid\ngraph TD\nA-->B\n```"
        let result = try #require(bridge.render(source: source, dialect: "generic", isDialectExplicit: false, enableDiagrams: false))
        #expect(result.body.contains("Target.md"))
        #expect(result.body.contains("After"))
        #expect(!result.body.contains("diagram-pending"))
    }
    @MainActor private func ready(_ view: WKWebView) async throws {
        for _ in 0..<100 {
            if let ok = try? await view.evaluateJavaScriptValue("typeof window.__mdvuInitArticle === 'function'"), ok as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(30))
        }
        Issue.record("Document runtime failed to load")
    }
    @MainActor @Test func cspBlocksActiveMarkdownAndKeepsRuntime() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(source: "window.requestAnimationFrame=cb=>setTimeout(cb,0)", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: configuration)
        let html = HTMLDocument.make(body: "<link rel='stylesheet' href='data:text/css,%23audit-style%7Bcolor%3Argb(1%2C2%2C3)%7D'><p id='audit-style'>Styled</p><img src='data:,bad' onerror='window.auditExecuted=true'><svg onload='window.auditExecuted=true'></svg><iframe srcdoc=\"&lt;script&gt;parent.auditExecuted=true&lt;/script&gt;\"></iframe><script>window.auditExecuted=true</script><h1>Safe</h1>", title: "CSP", theme: .light)
        view.loadHTMLString(html, baseURL: nil)
        defer { view.stopLoading() }
        try await ready(view)
        try await Task.sleep(for: .milliseconds(100))
        let safe = try await view.evaluateJavaScriptValue("window.auditExecuted !== true && typeof window.__mdvuFind === 'object'")
        #expect(safe as? Bool == true)
        #expect(try await view.evaluateJavaScriptValue("getComputedStyle(document.getElementById('audit-style')).color") as? String == "rgb(1, 2, 3)")
    }
    @MainActor @Test func articleReplacementReleasesObserversAndPreservesIDs() async throws {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(source: """
            window.requestAnimationFrame=cb=>setTimeout(cb,0);
            window.auditObservers=[];
            const NativeIO=window.IntersectionObserver;
            window.IntersectionObserver=class extends NativeIO {
                constructor(cb,o){super(cb,o);this.targets=new Set;window.auditObservers.push(this)}
                observe(t){this.targets.add(t);super.observe(t)}
                unobserve(t){this.targets.delete(t);super.unobserve(t)}
                disconnect(){this.targets.clear();super.disconnect()}
            };
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: config)
        view.loadHTMLString(HTMLDocument.make(body: "<h1>Start</h1>", title: "Replace", theme: .light), baseURL: nil)
        defer { view.stopLoading() }
        try await ready(view)
        let result = try await view.evaluateJavaScriptValue("""
            (()=>{
                for(let i=0;i<20;i++){
                    window.__mdvuDisposeArticle();
                    document.querySelector('article').innerHTML='<h1 id="custom">A</h1><h2>foo -</h2><h2><img alt="alt"></h2><div style="height:100000px"></div><pre><code>text</code></pre>';
                    window.__mdvuInitArticle();
                }
                window.__mdvuInitArticle();
                return {custom:document.getElementById('custom')!==null,foo:document.getElementById('foo--')!==null,alt:document.getElementById('alt')!==null,leaks:window.auditObservers.flatMap(o=>[...o.targets]).filter(t=>!t.isConnected).length,ids:[...document.querySelectorAll('article h1,article h2')].map(h=>h.id)};
            })()
            """)
        let facts = try #require(result as? [String: Any])
        #expect(facts["custom"] as? Bool == true)
        #expect(facts["foo"] as? Bool == true)
        #expect(facts["alt"] as? Bool == true)
        #expect(facts["leaks"] as? Int == 0)
    }
    @MainActor @Test func standaloneIncludesWorkingMathRuntime() async throws {
        let pipeline = MarkdownPipeline(dialect: .github, mermaid: false)
        let html = HTMLDocument.make(body: pipeline.render("$x^2$").body, title: "Math", theme: .light, embedEngines: true)
        #expect(html.utf8.count > 200_000)
        let view = WKWebView(frame: .zero)
        view.loadHTMLString(html, baseURL: nil)
        defer { view.stopLoading() }
        try await ready(view)
        _ = try await view.evaluateJavaScriptValue("window.__mdvuRenderMath(); true")
        let rendered = try await view.evaluateJavaScriptValue("document.querySelector('.math-rendered math') !== null")
        #expect(rendered as? Bool == true)
    }
}

extension SharedRegressionTests {
    @MainActor @Test func documentNavigationReusesRuntimeAndBlocksScriptNavigation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("first.md"), second = directory.appendingPathComponent("second.md")
        try "# First".write(to: first, atomically: true, encoding: .utf8)
        try "# Second".write(to: second, atomically: true, encoding: .utf8)
        let controller = DocumentWindowController(url: first, directoryMode: false, options: .default, profiler: StartupProfiler())
        defer { controller.close() }
        func findWebView(_ view: NSView) -> WKWebView? {
            if let web = view as? WKWebView { return web }
            return view.subviews.lazy.compactMap(findWebView).first
        }
        let web = try #require(controller.window?.contentView.flatMap(findWebView))
        for _ in 0..<150 {
            if !web.isLoading, let text = try? await web.evaluateJavaScriptValue("document.querySelector('article h1')?.textContent"), (text as? String)?.contains("First") == true { break }
            try await Task.sleep(for: .milliseconds(30))
        }
        _ = try await web.evaluateJavaScriptValue("window.auditRetained = 42; true")
        controller.openDocument(second)
        var changed = false
        for _ in 0..<150 {
            if let text = try? await web.evaluateJavaScriptValue("document.querySelector('article h1')?.textContent"), (text as? String)?.contains("Second") == true { changed = true; break }
            try await Task.sleep(for: .milliseconds(30))
        }
        #expect(changed)
        #expect(try await web.evaluateJavaScriptValue("window.auditRetained") as? Int == 42)
        let original = web.url
        _ = try? await web.evaluateJavaScriptValue("location.href='data:text/html,<h1>Untrusted navigation</h1>'; true")
        try await Task.sleep(for: .milliseconds(100))
        #expect(web.url == original)
    }
}

extension SharedRegressionTests {
    @MainActor @Test func offlineDiagramEnginesWorkUnderDocumentPolicy() async throws {
        let markdown = "```mermaid\ngraph TD\nA-->B\n```\n\n```plantuml\nAlice -> Bob: Hello\n```"
        let body = MarkdownPipeline(dialect: .github, mermaid: true).render(markdown).body
        let html = HTMLDocument.make(body: body, title: "Offline engines", theme: .light, embedEngines: true)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(source: "window.requestAnimationFrame=cb=>setTimeout(cb,0)", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: CGRect(x: 0,y: 0,width: 900,height: 700), configuration: configuration)
        view.loadHTMLString(html, baseURL: nil)
        defer { view.stopLoading() }
        try await ready(view)
        _ = try await view.callAsyncJavaScript("await Promise.all([window.__mdvuRenderDiagrams({all:true}),window.__mdvuRenderDiagrams({all:true}),window.__mdvuRenderDiagrams({all:true})]); return true", arguments: [:], in: nil, contentWorld: .page)
        var count = 0
        for _ in 0..<200 {
            count = (try? await view.evaluateJavaScriptValue("[...document.querySelectorAll('figure.diagram')].filter(n=>n.querySelector('.diagram-content')?.shadowRoot?.querySelector('svg')).length")) as? Int ?? 0
            if count == 2 { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let diagnostics = try? await view.evaluateJavaScriptValue("JSON.stringify({runtime:!!window.mermaid,error:window.__mdvuMermaidError,frames:[...document.querySelectorAll('iframe')].map(f=>({src:f.srcdoc.length,url:f.contentDocument?.URL}))})")
        #expect(count == 2, "\(String(describing: diagnostics))")
        let errors = try await view.evaluateJavaScriptValue("[...document.querySelectorAll('.diagram-error')].map(n=>n.textContent).join(' | ')")
        #expect(errors as? String == "")
        let found = try await view.evaluateJavaScriptValue("window.__mdvuFind.search('Hello').count")
        #expect(found as? Int == 1)
        _ = try await view.evaluateJavaScriptValue("window.__mdvuFind.clear(); true")
    }
}

extension SharedRegressionTests {
    @MainActor @Test func readingShortcutsAndLayoutAnchorUseTheActiveScroller() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(source: "window.requestAnimationFrame=cb=>setTimeout(cb,0)", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 700), configuration: configuration)
        view.loadHTMLString(HTMLDocument.make(body: "<h1>Start</h1><p style='height:4000px'>Long content</p><h2>End</h2><input id='editor'>", title: "Reading controls", theme: .light), baseURL: nil)
        defer { view.stopLoading() }
        try await ready(view)
        let facts = try await view.callAsyncJavaScript("""
            const pause=()=>new Promise(r=>setTimeout(r,50));
            const key=(target,name)=>target.dispatchEvent(new KeyboardEvent('keydown',{key:name,bubbles:true,cancelable:true}));
            const result={};
            key(window,'End');await pause();
            result.documentEnd=document.scrollingElement.scrollHeight-innerHeight-scrollY<3;
            key(window,'Home');await pause();result.documentHome=scrollY<2;
            key(window,'End');requestAnimationFrame(()=>document.querySelector('article>p').style.height='5500px');await pause();
            result.endFollowsLayout=document.scrollingElement.scrollHeight-innerHeight-scrollY<3;
            key(window,'Home');await pause();
            const scroller=document.createElement('div');scroller.id='mdvu-main-content';scroller.style.cssText='height:500px;overflow:auto';
            const article=document.querySelector('article');article.replaceWith(scroller);scroller.append(article);
            key(window,'End');await pause();result.nestedEnd=scroller.scrollHeight-scroller.clientHeight-scroller.scrollTop<3;
            key(document.getElementById('editor'),'Home');await pause();result.editorUnaffected=scroller.scrollTop>3000;
            key(window,'Home');await pause();result.nestedHome=scroller.scrollTop<2;
            scroller.scrollTop=250;
            const token=window.__mdvuCaptureReadingAnchor();
            const paragraph=article.querySelector('p'),before=paragraph.getBoundingClientRect().top;
            article.style.paddingTop='200px';window.__mdvuRestoreReadingAnchor(token);await pause();
            result.anchorStable=Math.abs(paragraph.getBoundingClientRect().top-before)<2;
            const interrupted=window.__mdvuCaptureReadingAnchor();
            article.style.paddingTop='400px';
            window.dispatchEvent(new WheelEvent('wheel'));scroller.scrollTop=800;
            window.__mdvuRestoreReadingAnchor(interrupted);await pause();
            result.userScrollCancelsAnchor=Math.abs(scroller.scrollTop-800)<2;
            return result;
            """, arguments: [:], in: nil, contentWorld: .page)
        let checks = try #require(facts as? [String: Bool])
        #expect(checks.count == 8)
        #expect(checks.values.allSatisfy { $0 }, "\(checks)")
    }
}

extension SharedRegressionTests {
    @MainActor @Test func nativeZoomAppliesTheLatestValueAndKeepsTheReadingPosition() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        try (0..<100).map { "## Section \($0)\n\nA paragraph to keep in view.\n\n" }.joined().write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        let controller = DocumentWindowController(url: file, directoryMode: false, options: .default, profiler: StartupProfiler())
        defer { controller.close() }
        func webView(in view: NSView) -> WKWebView? {
            if let web = view as? WKWebView { return web }
            return view.subviews.lazy.compactMap { webView(in: $0) }.first
        }
        controller.showWindow(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        let web = try #require(controller.window?.contentView.flatMap { webView(in: $0) })
        for _ in 0..<150 {
            if !web.isLoading, let ready = try? await web.evaluateJavaScriptValue("!!window.__mdvuCaptureReadingAnchor"), ready as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(30))
        }
        _ = try await web.evaluateJavaScriptValue("window.requestAnimationFrame=cb=>setTimeout(()=>cb(performance.now()),16);document.documentElement.style.scrollBehavior='auto';const target=document.querySelectorAll('h2')[20];target.id='reading-target';target.scrollIntoView({block:'center',behavior:'instant'});window.auditRuntime=42;true")
        // content-visibility refines offscreen heights after the first jump.
        // Wait for a text block at the centre instead of sampling a margin.
        var anchorReady = false
        for _ in 0..<100 {
            if try await web.evaluateJavaScriptValue("!!document.elementFromPoint(innerWidth/2,innerHeight/2)?.closest('p,h2')") as? Bool == true { anchorReady = true; break }
            _ = try await web.evaluateJavaScriptValue("document.getElementById('reading-target').scrollIntoView({block:'center',behavior:'instant'});true")
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(anchorReady)
        let before = try await web.evaluateJavaScriptValue("(()=>{const anchor=document.elementFromPoint(innerWidth/2,innerHeight/2).closest('p,h2');document.getElementById('reading-target').removeAttribute('id');anchor.id='reading-target';return anchor.getBoundingClientRect().top/innerHeight})()")
        _ = try await web.evaluateJavaScriptValue("window.auditCaptureNative=window.__mdvuCaptureReadingAnchor;window.__mdvuCaptureReadingAnchor=()=>{window.auditCapture={picked:document.elementFromPoint(innerWidth/2,innerHeight/2)?.outerHTML.slice(0,180),width:innerWidth,height:innerHeight,y:scrollY,target:document.getElementById('reading-target').getBoundingClientRect().top/innerHeight};return window.auditCaptureNative()};true")
        controller.applyPageZoom(1.1)
        controller.applyPageZoom(1.2)
        controller.applyPageZoom(1.5)
        for _ in 0..<100 where abs(web.pageZoom - 1.5) > 0.001 { try await Task.sleep(for: .milliseconds(20)) }
        for _ in 0..<100 {
            if let settled = try? await web.evaluateJavaScriptValue("window.__mdvuReadingAnchorSettled > 0"), settled as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(abs(web.pageZoom - 1.5) < 0.001)
        #expect(abs(controller.effectiveZoom - 1.5) < 0.001)
        let after = try await web.evaluateJavaScriptValue("document.getElementById('reading-target').getBoundingClientRect().top/innerHeight")
        let diagnostic = try? await web.evaluateJavaScriptValue("JSON.stringify({capture:window.auditCapture,width:innerWidth,height:innerHeight,y:scrollY,settled:window.__mdvuReadingAnchorSettled,target:document.getElementById('reading-target').getBoundingClientRect().top/innerHeight})")
        #expect(abs((after as? Double ?? -10) - (before as? Double ?? 10)) < 0.02, "\(String(describing: diagnostic))")
        #expect(try await web.evaluateJavaScriptValue("window.auditRuntime") as? Int == 42)
    }
}

extension SharedRegressionTests {
    @MainActor @Test func consumingTheStartupWebViewDoesNotKeepAnotherHiddenRenderer() async throws {
        WebKitPrewarmer.prewarm()
        let view = try #require(WebKitPrewarmer.takePrewarmedWebView())
        defer { view.stopLoading() }
        await Task.yield()
        #expect(WebKitPrewarmer.takePrewarmedWebView() == nil)
    }
}
