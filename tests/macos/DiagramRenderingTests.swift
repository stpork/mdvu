import Foundation
import Testing
import WebKit
@testable import mdvu

@MainActor struct DiagramRenderingTests {
    @Test func windowsTOCTreeMatchesNativeOutlineKeyboardAndExpansion() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(source: ResourceLoader.tocTreeJavaScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        view.loadHTMLString("<html><body><nav id='tree'></nav></body></html>", baseURL: nil)
        defer { view.stopLoading() }
        for _ in 0..<100 where view.isLoading { try await Task.sleep(for: .milliseconds(25)) }
        _ = try await view.evaluateJavaScriptValue("""
            window.selected=[];
            window.__mdvuBuildTOCTree(document.getElementById('tree'),[
              {id:'root',title:'Root',level:1},{id:'child',title:'Child',level:2},
              {id:'grandchild',title:'<img src=x onerror=alert(1)>',level:3},{id:'sibling',title:'Sibling',level:1}
            ],{indentation:16,expandAllLimit:2},id=>selected.push(id));
            window.key=(id,key)=>document.querySelector('[data-id="'+id+'"]').dispatchEvent(new KeyboardEvent('keydown',{key,bubbles:true,cancelable:true}));true
            """)
        #expect(try await view.evaluateJavaScriptValue("document.querySelector('[data-id=child]').getAttribute('aria-expanded')") as? String == "false")
        #expect(try await view.evaluateJavaScriptValue("!!document.querySelector('img')") as? Bool == false)
        _ = try await view.evaluateJavaScriptValue("key('root','ArrowLeft');true")
        #expect(try await view.evaluateJavaScriptValue("document.querySelector('[data-id=root]').getAttribute('aria-expanded')") as? String == "false")
        _ = try await view.evaluateJavaScriptValue("key('root','ArrowRight');key('root','ArrowDown');key('child','ArrowRight');key('child','ArrowRight');true")
        #expect(try await view.evaluateJavaScriptValue("selected.at(-1)") as? String == "grandchild")
        _ = try await view.evaluateJavaScriptValue("key('grandchild','ArrowLeft');key('child','Home');key('root','End');true")
        #expect(try await view.evaluateJavaScriptValue("selected.at(-1)") as? String == "sibling")
        #expect(try await view.evaluateJavaScriptValue("document.querySelectorAll('[tabindex=\"0\"]').length") as? Int == 1)
    }

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
        let matches = try await view.evaluateJavaScriptValue("window.__mdvuFind.search('needle').count") as? Int
        let findDiagnostic = try await view.evaluateJavaScriptValue("JSON.stringify({reader:window.__mdvuFind.search.toString().slice(0,1400),codes:[...document.querySelectorAll('code')].map(code=>({plain:code.textContent.match(/needle/g)?.length,unicode:code.textContent.match(/needle/giu)?.length,classes:code.textContent.match(/[Nn][Ee][Ee][Dd][Ll][Ee]/gu)?.length,copied:code.textContent.split('').join('').match(/needle/giu)?.length,marks:code.querySelectorAll('.find-match').length}))})") as? String
        #expect(matches == 2000, "\(findDiagnostic ?? "Missing find diagnostics")")
        _ = try await view.evaluateJavaScriptValue("window.__mdvuFind.clear();window.__mdvuInitArticle();true")
        #expect(try await view.evaluateJavaScriptValue("document.querySelector('code').textContent") as? String == source)
        #expect(try await view.evaluateJavaScriptValue("document.querySelectorAll('.mdvu-code-chunk').length") as? Int == 63)
    }

    @Test func legacyCodeVisibilityPreservesFindAndNativeSelectionText() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(source: "const supports=CSS.supports.bind(CSS);CSS.supports=(...args)=>args[0]==='content-visibility'?false:supports(...args);window.requestAnimationFrame=callback=>setTimeout(callback,16)", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        let source = (0..<2000).map { "line \($0): Åä 中文 العربية 😀 const text = 'needle';\n" }.joined()
        let html = HTMLDocument.make(body: "<div style='height:5000px'></div><pre contenteditable='false'><code class='language-text'>\(HTML.escape(source))</code></pre><pre id='wrapped' style='white-space:pre-wrap'><code class='language-text'>\(HTML.escape(source))</code></pre>", title: "Legacy code", theme: .light)
        let nonce = html.components(separatedBy: "name=\"mdvu-script-nonce\" content=\"")[1].components(separatedBy: "\"")[0]
        // Run while the parser is still in the article, before DOMContentLoaded.
        let probe = "<script nonce=\"\(nonce)\">window.codeBeforeReadyHidden=getComputedStyle(document.querySelector('code')).display==='none'</script>"
        view.loadHTMLString(html.replacingOccurrences(of: "</article>", with: probe + "</article>"), baseURL: nil)
        defer { view.stopLoading() }
        for _ in 0..<200 {
            if try await view.evaluateJavaScriptValue("document.querySelectorAll('.mdvu-code-content[hidden]').length>50") as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(try await view.evaluateJavaScriptValue("document.querySelectorAll('.mdvu-code-content[hidden]').length>50") as? Bool == true)
        #expect(try await view.evaluateJavaScriptValue("window.codeBeforeReadyHidden") as? Bool == true)
        #expect(try await view.evaluateJavaScriptValue("document.querySelector('code').textContent") as? String == source)
        _ = try await view.evaluateJavaScriptValue("const field=document.createElement('input');document.body.append(field);field.dispatchEvent(new Event('selectstart',{bubbles:true}));field.dispatchEvent(new Event('copy',{bubbles:true}));true")
        #expect(try await view.evaluateJavaScriptValue("document.querySelectorAll('.mdvu-code-content[hidden]').length>50") as? Bool == true)
        let matches = try await view.evaluateJavaScriptValue("window.__mdvuFind.search('needle').count") as? Int
        let findDiagnostic = try await view.evaluateJavaScriptValue("JSON.stringify({reader:window.__mdvuFind.search.toString().slice(0,1400),codes:[...document.querySelectorAll('code')].map(code=>({plain:code.textContent.match(/needle/g)?.length,unicode:code.textContent.match(/needle/giu)?.length,classes:code.textContent.match(/[Nn][Ee][Ee][Dd][Ll][Ee]/gu)?.length,copied:code.textContent.split('').join('').match(/needle/giu)?.length,marks:code.querySelectorAll('.find-match').length}))})") as? String
        #expect(matches == 4000, "\(findDiagnostic ?? "Missing find diagnostics")")
        #expect(try await view.evaluateJavaScriptValue("!document.querySelector('#wrapped .mdvu-code-virtual')") as? Bool == true)
        #expect(try await view.evaluateJavaScriptValue("!document.querySelector('.find-current').closest('.mdvu-code-content').hidden") as? Bool == true)
        _ = try await view.evaluateJavaScriptValue("window.__mdvuFind.clear();document.querySelector('code').dispatchEvent(new Event('selectstart',{bubbles:true}));const range=document.createRange();range.selectNodeContents(document.querySelector('code'));getSelection().removeAllRanges();getSelection().addRange(range);true")
        #expect(try await view.evaluateJavaScriptValue("document.querySelectorAll('.mdvu-code-content[hidden]').length") as? Int == 0)
        let selected = try await view.evaluateJavaScriptValue("getSelection().toString()") as? String
        #expect(selected?.count == source.count)
        #expect(selected == source)
        _ = try await view.evaluateJavaScriptValue("getSelection().removeAllRanges();window.scrollTo(0,0);true")
        for _ in 0..<100 {
            if try await view.evaluateJavaScriptValue("document.querySelectorAll('.mdvu-code-content[hidden]').length>50") as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(try await view.evaluateJavaScriptValue("document.querySelectorAll('.mdvu-code-content[hidden]').length>50") as? Bool == true)
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
            _ = try await view.evaluateJavaScriptValue("window.dispatchEvent(new KeyboardEvent('keydown',{key:'Home',bubbles:true,cancelable:true}));window.__mdvuFind.clear();true")
            #expect(try await view.evaluateJavaScriptValue("document.getElementById('far').querySelector('.diagram-content').shadowRoot.childElementCount") as? Int == 0)
        }
    }
}
