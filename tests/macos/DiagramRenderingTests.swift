import Foundation
import Testing
import WebKit
@testable import mdvu

@MainActor struct DiagramRenderingTests {
    @Test func largeCodePreservesTextSelectionAndSearchAcrossLineGroups() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(source: "window.requestAnimationFrame=callback=>setTimeout(callback,16)", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        let source = (0..<2000).map { "line \($0): Åä 中文 العربية 😀 const text = 'needle';\n" }.joined()
        view.loadHTMLString(HTMLDocument.make(body: "<pre><code class='language-text'>\(HTML.escape(source))</code></pre>", title: "Large code", theme: .light), baseURL: nil)
        defer { view.stopLoading() }
        for _ in 0..<100 {
            if try await view.evaluateJavaScriptValue("!!document.querySelector('.mdvu-chunked')") as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(try await view.evaluateJavaScriptValue("document.querySelector('code').textContent") as? String == source)
        #expect(try await view.evaluateJavaScriptValue("document.querySelectorAll('.mdvu-code-chunk').length") as? Int == 63)
        #expect(try await view.evaluateJavaScriptValue("(() => {const range=document.createRange();range.selectNodeContents(document.querySelector('code'));return range.toString()})()") as? String == source)
        #expect(try await view.evaluateJavaScriptValue("window.__mdvuFind.search('needle').count") as? Int == 2000)
        _ = try await view.evaluateJavaScriptValue("window.__mdvuFind.clear();window.__mdvuInitArticle();true")
        #expect(try await view.evaluateJavaScriptValue("document.querySelector('code').textContent") as? String == source)
        #expect(try await view.evaluateJavaScriptValue("document.querySelectorAll('.mdvu-code-chunk').length") as? Int == 63)
    }

    @Test func nativeTransportCanArriveAfterTheReaderScript() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(source: "window.requestAnimationFrame=callback=>setTimeout(callback,16)", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        view.loadHTMLString(HTMLDocument.make(body: "<figure id='late' class='diagram diagram-pending' data-renderer='mermaid'><pre>graph TD; A-->B</pre></figure>", title: "Late bridge", theme: .light), baseURL: nil)
        defer { view.stopLoading() }
        for _ in 0..<100 {
            if try await view.evaluateJavaScriptValue("typeof window.__mdvuRenderDiagrams==='function'") as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        _ = try await view.evaluateJavaScriptValue("""
            window.__mdvuNativeDiagramTransport={post:job=>setTimeout(()=>window.__mdvuDiagramResult({id:job.id,svg:'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 10"><text>A</text></svg>'}),0),cancel:()=>{}};
            window.__mdvuRenderDiagrams({all:true});true
            """)
        for _ in 0..<100 {
            if try await view.evaluateJavaScriptValue("document.getElementById('late').classList.contains('diagram-rendered')") as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(try await view.evaluateJavaScriptValue("!!window.__mdvuHasDiagramSVG(document.getElementById('late')) && !window.mermaid") as? Bool == true)
    }

    @Test func invalidRequestsNeverStartAWebProcess() {
        let service = DiagramRenderingService()
        var reply: [String: Any]?
        service.submit(owner: UUID(), request: ["id": "invalid", "renderer": "unknown", "source": "A"]) { reply = $0 }
        #expect(reply?["error"] != nil)
        #expect(!service.hasRenderer)
    }

    @Test func cancellationDiscardsObsoleteJobsButPreservesOtherOwners() async throws {
        let service = DiagramRenderingService(idleDelay: 0.05), obsolete = UUID(), current = UUID()
        var obsoleteCompleted = false
        var reply: [String: Any]?
        service.submit(owner: obsolete, request: ["id": "obsolete", "renderer": "mermaid", "source": "graph TD; A-->B"]) { _ in obsoleteCompleted = true }
        service.submit(owner: current, request: ["id": "current", "renderer": "mermaid", "source": "graph TD; C-->D"]) { reply = $0 }
        service.cancel(owner: obsolete)
        defer { service.cancel(owner: current) }
        for _ in 0..<600 where reply == nil { try await Task.sleep(for: .milliseconds(25)) }
        #expect(!obsoleteCompleted)
        #expect(reply?["id"] as? String == "current")
        #expect((reply?["svg"] as? String)?.contains("<svg") == true)
        for _ in 0..<100 where service.hasRenderer { try await Task.sleep(for: .milliseconds(25)) }
        #expect(!service.hasRenderer)
    }

    @Test func zenumlRendersInAnOfflineOriginWithoutEnteringTheReader() async throws {
        let service = DiagramRenderingService(idleDelay: 0.05), owner = UUID()
        var reply: [String: Any]?
        service.submit(owner: owner, request: ["id": "zenuml", "renderer": "mermaid", "source": "zenuml\n  A->B: Hello"]) { reply = $0 }
        defer { service.cancel(owner: owner) }
        for _ in 0..<600 where reply == nil { try await Task.sleep(for: .milliseconds(25)) }
        #expect(reply?["error"] == nil)
        #expect((reply?["svg"] as? String)?.contains("<svg") == true)
    }

    @Test func offscreenDiagramsReleaseTheirDOMAndRemainSearchable() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(source: "window.requestAnimationFrame=callback=>setTimeout(callback,0)", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        view.loadHTMLString(HTMLDocument.make(body: """
            <h1>Document</h1><div style="height:10000px"></div>
            <figure id="far" class="diagram diagram-rendered"><svg xmlns="http://www.w3.org/2000/svg" width="200" viewBox="0 0 200 100"><text>ς &amp; needle</text></svg></figure>
            """, title: "Offscreen", theme: .light), baseURL: nil)
        defer { view.stopLoading() }
        for _ in 0..<100 {
            if try await view.evaluateJavaScriptValue("!!window.__mdvuHasDiagramSVG?.(document.getElementById('far'))") as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(try await view.evaluateJavaScriptValue("!!window.__mdvuHasDiagramSVG?.(document.getElementById('far'))") as? Bool == true)
        #expect(try await view.evaluateJavaScriptValue("document.getElementById('far').querySelector('.diagram-content').shadowRoot.childElementCount") as? Int == 0)
        for query in ["needle", "&", "σ"] {
            let literal = String(data: try JSONSerialization.data(withJSONObject: query, options: .fragmentsAllowed), encoding: .utf8)!
            #expect(try await view.evaluateJavaScriptValue("window.__mdvuFind.search(\(literal)).count") as? Int == 1)
            _ = try await view.evaluateJavaScriptValue("window.__mdvuFind.clear();true")
            #expect(try await view.evaluateJavaScriptValue("document.getElementById('far').querySelector('.diagram-content').shadowRoot.childElementCount") as? Int == 0)
        }
    }
}
