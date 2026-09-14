import AppKit
import Foundation
import Testing
@testable import mdvu

struct AuditRegressionTests {
    @Test func tocMarkersInsideFencesStayLiteral() {
        let body = MarkdownPipeline(dialect: .github, mermaid: false)
            .render("```text\n[TOC]\n[[_TOC_]]\n```\n\n[TOC]").body
        #expect(body.contains("[TOC]\n[[_TOC_]]"))
        #expect(body.components(separatedBy: "toc-placeholder").count == 2)
    }

    @Test func lateScrollCaptureDoesNotPushAnOldDocument() {
        let history = NavigationHistory()
        let a = URL(fileURLWithPath: "/a.md")
        let b = URL(fileURLWithPath: "/b.md")
        let c = URL(fileURLWithPath: "/c.md")
        history.push(url: a)
        let previousIndex = history.currentIndex
        history.push(url: b)
        history.push(url: c)
        history.recordScrollRatio(0.7, at: previousIndex)
        #expect(history.entries.count == 3)
        #expect(history.currentEntry?.url == c)
        #expect(history.goBack()?.url == b)
        #expect(history.goBack()?.scrollRatio == 0.7)
    }

    @MainActor @Test func watcherSurvivesDelayedReplacementAndStopsAfterInvalidation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("note.md")
        try "first".write(to: file, atomically: false, encoding: .utf8)
        var count = 0
        let watcher = try #require(FileWatcher(url: file) { count += 1 })
        defer { watcher.invalidate() }
        try FileManager.default.removeItem(at: file)
        try await Task.sleep(nanoseconds: 800_000_000)
        #expect(count == 0)
        try "replacement".write(to: file, atomically: false, encoding: .utf8)
        for _ in 0..<30 {
            if count > 0 { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(count > 0)
        let afterReplacement = count
        try "changed".write(to: file, atomically: false, encoding: .utf8)
        for _ in 0..<20 {
            if count > afterReplacement { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(count > afterReplacement)
        watcher.invalidate()
        let stopped = count
        try "ignored".write(to: file, atomically: false, encoding: .utf8)
        try await Task.sleep(nanoseconds: 350_000_000)
        #expect(count == stopped)
    }
}

// Exercise the actual DOM runtime, rather than testing for JavaScript substrings.
import WebKit

extension AuditRegressionTests {
    @MainActor @Test func webRuntimePreservesTextAndUniqueHeadingTargets() async throws {
        let configuration = WKWebViewConfiguration()
        // Offscreen WebViews throttle animation frames. This test verifies DOM
        // correctness, not frame timing; make scheduling deterministic.
        configuration.userContentController.addUserScript(WKUserScript(
            source: "window.requestAnimationFrame = callback => setTimeout(callback, 0)",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.loadHTMLString(HTMLDocument.make(
            body: "<h1>A</h1><h2>A</h2><h2>A-1</h2><p id='text'>İstanbul target a.b a+b [x]</p>",
            title: "Audit", theme: .light), baseURL: nil)
        defer { view.stopLoading() }
        var ready = false
        for _ in 0..<100 {
            if let value = try? await view.evaluateJavaScript("typeof window.__mdvuFind === 'object' && document.querySelectorAll('.heading-anchor').length === 3"), value as? Bool == true {
                ready = true
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(ready)
        guard ready else { return }
        let unique = try await view.evaluateJavaScript("new Set([...document.querySelectorAll('h1,h2')].map(h=>h.id)).size")
        #expect(unique as? Int == 3)
        for query in ["target", "a.b", "a+b", "[x]"] {
            let literal = String(data: try JSONSerialization.data(withJSONObject: query, options: .fragmentsAllowed), encoding: .utf8)!
            let matched = try await view.evaluateJavaScript("window.__mdvuFind.search(\(literal)); (document.querySelector('#text mark')?.textContent ?? '')")
            #expect(matched as? String == query)
            _ = try await view.evaluateJavaScript("window.__mdvuFind.clear(); true")
            let text = try await view.evaluateJavaScript("document.getElementById('text').textContent")
            #expect(text as? String == "İstanbul target a.b a+b [x]")
        }
    }

    @MainActor @Test func scrollToFragmentWorksOnFileURL() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(
            source: "window.requestAnimationFrame = callback => setTimeout(callback, 0)",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let html = HTMLDocument.make(
            body: "<h1>Top</h1>" + String(repeating: "<p>filler</p>", count: 80) + "<h2>Target</h2>" + String(repeating: "<p>tail</p>", count: 30),
            title: "Scroll", theme: .light)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("scroll-\(UUID().uuidString).html")
        try html.write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        view.loadFileURL(temp, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        defer { view.stopLoading() }
        var ready = false
        for _ in 0..<100 {
            if let ok = try? await view.evaluateJavaScript("typeof window.__mdvuScrollToFragment === 'function' && document.getElementById('target') !== null"), ok as? Bool == true {
                ready = true; break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(ready)
        guard ready else { return }
        // A boolean alone does not prove the requested heading was reached.
        _ = try await view.evaluateJavaScript("document.documentElement.style.scrollBehavior='auto'; true")
        for push in [true, false] {
            _ = try await view.evaluateJavaScript("scrollTo(0,0); true")
            let result = try await view.evaluateJavaScript("window.__mdvuScrollToFragment('target', \(push))")
            #expect(result as? Bool == true)
            let reached = try await view.evaluateJavaScript("scrollY > 0 && Math.abs(document.getElementById('target').getBoundingClientRect().top) < 2")
            #expect(reached as? Bool == true)
        }
        let missing = try await view.evaluateJavaScript("window.__mdvuScrollToFragment('missing')")
        #expect(missing as? Bool == false)
    }
}
