import Foundation
import WebKit

/// One lazy, serial renderer for the application. Diagram engines never enter a
/// reading WebView's process; idle/obsolete work releases this WebView entirely.
@MainActor final class DiagramRenderingService: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    static let shared = DiagramRenderingService()
    private struct Job {
        let owner: UUID
        let request: [String: Any]
        let complete: ([String: Any]) -> Void
        var id: String { request["id"] as? String ?? "" }
    }
    private var view: WKWebView?
    private var queue: [Job] = []
    private var active: Job?
    private var ready = false
    private var loaded: Set<String> = []
    private var runtimeSource: String?
    private var deadline: DispatchWorkItem?
    private let idleDelay: TimeInterval
    private let profiler = StartupProfiler()

    init(idleDelay: TimeInterval = 5) { self.idleDelay = idleDelay; super.init() }
    var hasRenderer: Bool { view != nil }

    func submit(owner: UUID, request: [String: Any], complete: @escaping ([String: Any]) -> Void) {
        guard let id = request["id"] as? String, !id.isEmpty,
              let renderer = request["renderer"] as? String, ["mermaid", "plantuml"].contains(renderer),
              let source = request["source"] as? String, source.utf8.count <= 1_000_000,
              queue.count < 16 else {
            complete(["id": request["id"] as? String ?? "", "error": "Invalid or excessive diagram request"]); return
        }
        queue.append(Job(owner: owner, request: request, complete: complete))
        profiler.mark("diagram.request")
        advance()
    }

    func cancel(owner: UUID) {
        queue.removeAll { $0.owner == owner }
        if active?.owner == owner { active = nil; releaseRenderer(); advance() }
    }

    private func releaseRenderer() {
        deadline?.cancel(); deadline = nil
        view?.stopLoading()
        view?.configuration.userContentController.removeScriptMessageHandler(forName: "diagramResult")
        view?.navigationDelegate = nil
        view = nil; ready = false; loaded.removeAll(); runtimeSource = nil
    }

    private func advance() {
        guard active == nil else { return }
        deadline?.cancel()
        guard !queue.isEmpty else {
            let idle = DispatchWorkItem { [weak self] in self?.releaseRenderer() }
            deadline = idle; DispatchQueue.main.asyncAfter(deadline: .now() + idleDelay, execute: idle)
            return
        }
        active = queue.removeFirst()
        let timeout = DispatchWorkItem { [weak self] in self?.finish(["error": "Diagram rendering timed out"], discardRenderer: true) }
        deadline = timeout; DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
        if view == nil { createRenderer() }
        guard let job = active, let web = view, let renderer = job.request["renderer"] as? String else { return }
        if loaded.contains(renderer) { renderActive(); return }
        // Decode while WebKit starts, never on the reading/UI thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let source = renderer == "mermaid" ? ResourceLoader.mermaidRuntime : ResourceLoader.plantumlJavaScript
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active?.id == job.id, self.view === web else { return }
                self.profiler.mark("diagram.decompressed")
                self.runtimeSource = source
                self.renderActive()
            }
        }
    }

    private func createRenderer() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(self, name: "diagramResult")
        if #available(macOS 14.0, *) { config.preferences.inactiveSchedulingPolicy = .none }
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 920, height: 800), configuration: config)
        web.navigationDelegate = self
        view = web
        profiler.mark("diagram.webview")
        let nonce = UUID().uuidString
        web.loadHTMLString("""
        <!doctype html><html><head><meta charset="utf-8"><meta name="mdvu-script-nonce" content="\(nonce)">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-\(nonce)' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'unsafe-inline'; img-src data: blob:; font-src data:; worker-src blob:; connect-src 'none'; object-src 'none'; form-action 'none'">
        <style>body{margin:0;font:16px Arial,sans-serif}</style></head><body><script nonce="\(nonce)">\(ResourceLoader.diagramRendererJavaScript)</script></body></html>
        """, baseURL: URL(string: "https://mdvu-diagram.invalid/"))
    }

    private func renderActive() {
        guard ready, let job = active, let web = view, let renderer = job.request["renderer"] as? String else { return }
        guard loaded.contains(renderer) || runtimeSource != nil else { return }
        let source = runtimeSource ?? ""
        runtimeSource = nil
        loaded.insert(renderer)
        guard let data = try? JSONSerialization.data(withJSONObject: job.request),
              let json = String(data: data, encoding: .utf8) else { finish(["error": "Invalid diagram request"]); return }
        web.evaluateJavaScript("\(source);window.__mdvuRunDiagramJob(\(json)); void 0") { [weak self] _, error in
            guard let self, self.active?.id == job.id, self.view === web, let error else { return }
            self.finish(["error": error.localizedDescription], discardRenderer: true)
        }
    }

    private func finish(_ result: [String: Any], discardRenderer: Bool = false) {
        guard let job = active else { return }
        deadline?.cancel(); deadline = nil; active = nil
        var reply = result; reply["id"] = job.id
        job.complete(reply)
        profiler.mark("diagram.result")
        if discardRenderer { releaseRenderer() }
        advance()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.webView === view, message.frameInfo.isMainFrame, let result = message.body as? [String: Any] else { return }
        if result["ready"] as? Bool == true { profiler.mark("diagram.ready"); ready = true; renderActive() }
        else if result["id"] as? String == active?.id { finish(result) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === view else { return }
        finish(["error": "Diagram renderer exited"], discardRenderer: true)
    }
}
