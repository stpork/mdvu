import Foundation
import Testing
import WebKit
@testable import mdvu

@MainActor struct DiagramRenderingTests {
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
