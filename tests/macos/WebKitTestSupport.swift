import Testing
import WebKit

// Both producer and consumer run on MainActor; the continuation never exposes
// WebKit's Objective-C result to a different actor.
private struct WebKitValue: @unchecked Sendable { let value: Any? }

extension WKWebView {
    // The SDK's async overload returns nonoptional Any. On older WebKit it traps
    // while bridging JavaScript undefined/null, even inside try?. The completion
    // API correctly represents these values as nil.
    @MainActor func evaluateJavaScriptValue(_ script: String) async throws -> Any? {
        let result: WebKitValue = try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: WebKitValue(value: value)) }
            }
        }
        return result.value
    }
}

struct WebKitBridgeTests {
    @MainActor @Test func undefinedJavaScriptResultDoesNotTrapTheTestProcess() async throws {
        let view = WKWebView(frame: .zero)
        view.loadHTMLString("<html><body>Ready</body></html>", baseURL: nil)
        defer { view.stopLoading() }
        for _ in 0..<100 where view.isLoading { try await Task.sleep(for: .milliseconds(20)) }
        #expect(try await view.evaluateJavaScriptValue("void 0") == nil)
        #expect(try await view.evaluateJavaScriptValue("42") as? Int == 42)
    }
}
