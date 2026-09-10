import Foundation

final class EagerDocumentLoader: @unchecked Sendable {
    static let shared = EagerDocumentLoader()
    private let lock = NSLock()
    private var pendingURL: URL?
    private var pendingTask: Task<RenderedDocument, Error>?

    static func start(path: String, options: CLIOptions) {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { return }
        guard MarkdownDocument.isMarkdown(url: url) else { return }
        shared.begin(url: url, options: options)
    }

    private func begin(url: URL, options: CLIOptions) {
        lock.lock()
        defer { lock.unlock() }
        pendingURL = url
        pendingTask = Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let source = String(decoding: data, as: UTF8.self)
            let pipeline = MarkdownPipeline(dialect: options.dialect, mermaid: options.mermaid)
            let diagramTheme: String = {
                if options.theme != .system { return options.theme.rawValue }
                return "light"
            }()
            return pipeline.render(source, diagramTheme: diagramTheme)
        }
    }

    static func take(for url: URL) -> Task<RenderedDocument, Error>? {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        guard let pendingURL = shared.pendingURL, pendingURL.standardizedFileURL.path == url.standardizedFileURL.path else {
            return nil
        }
        defer {
            shared.pendingURL = nil
            shared.pendingTask = nil
        }
        return shared.pendingTask
    }
}
