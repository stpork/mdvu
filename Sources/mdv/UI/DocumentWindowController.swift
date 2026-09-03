import AppKit
import UniformTypeIdentifiers
import WebKit

final class DocumentWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate, WKScriptMessageHandler, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate, NSMenuItemValidation {
    var onOpenURL: ((URL) -> Void)?
    var onClose: (() -> Void)?
    private let webView: WKWebView
    private let sidebar = NSTableView()
    private let split = NSSplitView()
    private let rootURL: URL
    private var currentURL: URL?
    private var files: [URL] = []
    private var watcher: FileWatcher?
    private let options: CLIOptions
    private let profiler: StartupProfiler
    private let cache: DiagramCache
    private let pipeline: MarkdownPipeline
    private var hasShown = false
    private var snapshotWritten = false
    private var isFullWidth: Bool
    private weak var fullWidthToolbarItem: NSToolbarItem?
    private let renderQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.mdv.render"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    private var renderOperation: Operation?
    private var renderGeneration = 0
    private var pendingScrollRatio: Double?
    private var systemAppearanceIsDark: Bool?

    private static let fullWidthItem = NSToolbarItem.Identifier("mdv.fullWidth")

    init(url: URL, directoryMode: Bool, options: CLIOptions, profiler: StartupProfiler) {
        self.rootURL = url; self.options = options; self.profiler = profiler
        let cache = DiagramCache()
        self.cache = cache
        self.pipeline = MarkdownPipeline(dialect: options.dialect, mermaid: options.mermaid, cache: cache)
        self.isFullWidth = options.fullWidth ?? UserDefaults.standard.bool(forKey: "layout.fullWidth")
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController = WKUserContentController()
        webView = WKWebView(frame: .zero, configuration: config)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.delegate = self; window.titlebarAppearsTransparent = false; window.titleVisibility = .visible; window.tabbingMode = .preferred
        systemAppearanceIsDark = effectiveAppearanceIsDark
        window.setFrameAutosaveName("mdv.mainWindow")
        configureToolbar()
        webView.navigationDelegate = self
        config.userContentController.add(self, name: "diagramCache")
        configureLayout(directoryMode: directoryMode)
        if directoryMode { loadDirectory(url) } else { openDocument(url) }
        profiler.mark("window.created")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { webView.configuration.userContentController.removeScriptMessageHandler(forName: "diagramCache") }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender); window?.center(); window?.makeKeyAndOrderFront(sender)
        if !hasShown { hasShown = true; profiler.mark("window.visible") }
    }
    func windowWillClose(_ notification: Notification) {
        renderQueue.cancelAllOperations()
        watcher = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "diagramCache")
        onClose?()
    }

    private func configureLayout(directoryMode: Bool) {
        split.isVertical = true; split.dividerStyle = .thin
        if directoryMode {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file")); column.title = "Markdown"
            sidebar.addTableColumn(column); sidebar.headerView = nil; sidebar.delegate = self; sidebar.dataSource = self
            let scroll = NSScrollView(); scroll.documentView = sidebar; scroll.hasVerticalScroller = true
            split.addArrangedSubview(scroll); scroll.widthAnchor.constraint(equalToConstant: 225).isActive = true
        }
        split.addArrangedSubview(webView)
        let dropView = DropView(frame: .zero, handler: { [weak self] in self?.handleDrop($0) })
        dropView.appearanceHandler = { [weak self] in self?.appearanceDidChange() }
        window?.contentView = dropView
        window?.contentView?.addSubview(split)
        split.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([split.leadingAnchor.constraint(equalTo: window!.contentView!.leadingAnchor), split.trailingAnchor.constraint(equalTo: window!.contentView!.trailingAnchor), split.topAnchor.constraint(equalTo: window!.contentView!.topAnchor), split.bottomAnchor.constraint(equalTo: window!.contentView!.bottomAnchor)])
    }

    private func configureToolbar() {
        let toolbar = NSToolbar(identifier: "mdv.toolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbarStyle = .unifiedCompact
        window?.toolbar = toolbar
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace, Self.fullWidthItem] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace, Self.fullWidthItem] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard identifier == Self.fullWidthItem else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.target = self; item.action = #selector(toggleFullWidth(_:)); item.isBordered = true
        fullWidthToolbarItem = item; updateFullWidthControl()
        return item
    }

    private func updateFullWidthControl() {
        fullWidthToolbarItem?.label = isFullWidth ? "Readable Width" : "Full Width"
        fullWidthToolbarItem?.toolTip = isFullWidth ? "Use readable document width" : "Use the full window width"
        fullWidthToolbarItem?.image = NSImage(systemSymbolName: isFullWidth ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Toggle full width")
    }

    private func loadDirectory(_ directory: URL) {
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            var discovered: [URL] = []
            if let iterator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let url as URL in iterator {
                    if operation.isCancelled { return }
                    if ["md", "markdown", "mdown", "mkd"].contains(url.pathExtension.lowercased()) {
                        discovered.append(url)
                        if discovered.count == 5000 { break }
                    }
                }
            }
            discovered.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.files = discovered
                self.sidebar.reloadData()
                if let first = discovered.first {
                    self.openDocument(first)
                    self.sidebar.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                } else {
                    self.showMessage("No Markdown files found", detail: directory.path)
                }
            }
        }
        renderQueue.addOperation(operation)
    }

    private func openDocument(_ url: URL, preserveScroll: Bool = false) {
        guard ["md", "markdown", "mdown", "mkd"].contains(url.pathExtension.lowercased()) else { return }
        currentURL = url; window?.representedURL = url; window?.title = url.lastPathComponent
        let scrollScript = preserveScroll ? "({y:scrollY,h:Math.max(1,document.documentElement.scrollHeight-innerHeight)})" : nil
        let render: (Any?) -> Void = { [weak self] position in self?.render(url, position: position) }
        if let scrollScript { webView.evaluateJavaScript(scrollScript) { position, _ in render(position) } } else { render(nil) }
        watcher = FileWatcher(url: url) { [weak self] in self?.openDocument(url, preserveScroll: true) }
    }

    private func render(_ url: URL, position: Any?) {
        renderGeneration += 1
        let generation = renderGeneration
        let theme = options.theme, fullWidth = isFullWidth
        let diagramTheme: String = {
            if theme != .system { return theme.rawValue }
            return window?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? "dark" : "light"
        }()
        let scrollRatio: Double? = {
            guard let dictionary = position as? [String: Any], let y = dictionary["y"] as? Double, let h = dictionary["h"] as? Double, h > 0 else { return nil }
            return y / h
        }()
        renderOperation?.cancel()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self, let operation, !operation.isCancelled else { return }
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard !operation.isCancelled else { return }
                let source = String(decoding: data, as: UTF8.self)
                let rendered = self.pipeline.render(source, diagramTheme: diagramTheme)
                guard !operation.isCancelled else { return }
                let html = HTMLDocument.make(body: rendered.body, title: rendered.title ?? url.lastPathComponent, theme: theme, fullWidth: fullWidth)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.renderGeneration == generation else { return }
                    self.pendingScrollRatio = scrollRatio
                    self.profiler.mark("markdown.ready")
                    self.webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
                    self.profiler.mark("html.loaded")
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.renderGeneration == generation else { return }
                    self.showMessage("Unable to open document", detail: error.localizedDescription)
                }
            }
        }
        renderOperation = operation
        renderQueue.addOperation(operation)
    }

    private func showMessage(_ title: String, detail: String) { webView.loadHTMLString(HTMLDocument.make(body: "<div class=\"empty\"><h1>\(HTML.escape(title))</h1><p>\(HTML.escape(detail))</p></div>", title: title, theme: options.theme, fullWidth: isFullWidth), baseURL: nil) }
    private func handleDrop(_ urls: [URL]) { urls.forEach { onOpenURL?($0) } }
    private var effectiveAppearanceIsDark: Bool { window?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
    private func appearanceDidChange() {
        guard options.theme == .system else { return }
        let isDark = effectiveAppearanceIsDark
        guard systemAppearanceIsDark != isDark else { return }
        systemAppearanceIsDark = isDark
        if let currentURL { openDocument(currentURL, preserveScroll: true) }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { files.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell"); let cell = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView ?? NSTableCellView()
        if cell.textField == nil { let field = NSTextField(labelWithString: ""); field.lineBreakMode = .byTruncatingMiddle; cell.addSubview(field); field.translatesAutoresizingMaskIntoConstraints = false; NSLayoutConstraint.activate([field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8), field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8), field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)]); cell.textField = field; cell.identifier = id }
        cell.textField?.stringValue = files[row].path.replacingOccurrences(of: rootURL.path + "/", with: ""); return cell
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard sidebar.selectedRow >= 0 else { return }
        let selected = files[sidebar.selectedRow]
        if selected.standardizedFileURL != currentURL?.standardizedFileURL { openDocument(selected) }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        profiler.mark("webview.firstContent")
        if let ratio = pendingScrollRatio { pendingScrollRatio = nil; webView.evaluateJavaScript("scrollTo(0, Math.max(1,document.documentElement.scrollHeight-innerHeight) * \(ratio))") }
        if options.snapshotPath != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.captureSnapshotIfRequested() }
        }
        guard options.mermaid else { captureSnapshotIfRequested(); return }
        webView.evaluateJavaScript("document.querySelector('.diagram-pending') !== null") { [weak self] value, _ in
            guard let self else { return }
            guard value as? Bool == true else { self.captureSnapshotIfRequested(); return }
            // Mermaid is parsed only when the page actually has an uncached diagram.
            let mermaid = ResourceLoader.mermaidJavaScript
            guard !mermaid.isEmpty else {
                self.webView.evaluateJavaScript("document.querySelectorAll('.diagram-status').forEach(e => e.textContent = 'Diagram renderer unavailable')")
                self.captureSnapshotIfRequested()
                return
            }
            self.webView.evaluateJavaScript(mermaid) { [weak self] _, error in
                guard let self else { return }
                if let error {
                    #if DEBUG
                    FileHandle.standardError.write(Data("mdv: Mermaid load failed: \(error.localizedDescription)\n".utf8))
                    #endif
                    self.webView.evaluateJavaScript("document.querySelectorAll('.diagram-status').forEach(e => e.textContent = 'Diagram renderer unavailable')")
                    self.captureSnapshotIfRequested()
                    return
                }
                self.webView.evaluateJavaScript("window.__mdvRenderDiagrams && window.__mdvRenderDiagrams()") { [weak self] _, _ in
                    self?.profiler.mark("mermaid.complete")
                    self?.captureSnapshotIfRequested()
                }
            }
        }
    }

    private func captureSnapshotIfRequested() {
        guard !snapshotWritten, let path = options.snapshotPath else { return }
        snapshotWritten = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in self?.writeSnapshot(to: path) }
    }

    private func writeSnapshot(to path: String) {
        guard let number = window?.windowNumber,
              let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(number), [.boundsIgnoreFraming, .bestResolution]) else { NSApp.terminate(nil); return }
        let bitmap = NSBitmapImageRep(cgImage: image)
        if let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        NSApp.terminate(nil)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else { decisionHandler(.allow); return }
        if ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url); decisionHandler(.cancel); return }
        if url.isFileURL, ["md", "markdown", "mdown", "mkd"].contains(url.pathExtension.lowercased()) {
            if url.standardizedFileURL.path == currentURL?.standardizedFileURL.path, url.fragment != nil { decisionHandler(.allow) }
            else { openDocument(url); decisionHandler(.cancel) }
            return
        }
        if url.scheme == "file" { NSWorkspace.shared.open(url); decisionHandler(.cancel); return }
        // Markdown is untrusted: unknown, data, and javascript schemes never load.
        decisionHandler(.cancel)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "diagramCache", let body = message.body as? [String: Any], let key = body["key"] as? String, let svg = body["svg"] as? String else { return }
        DispatchQueue.global(qos: .utility).async { [cache] in cache.write(key: key, svg: svg) }
    }

    @objc func reload(_ sender: Any?) { if let currentURL { openDocument(currentURL, preserveScroll: true) } }
    @objc func toggleFullWidth(_ sender: Any?) {
        isFullWidth.toggle()
        UserDefaults.standard.set(isFullWidth, forKey: "layout.fullWidth")
        updateFullWidthControl()
        webView.evaluateJavaScript("document.documentElement.classList.toggle('full-width', \(isFullWidth ? "true" : "false"))")
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleFullWidth(_:)) { menuItem.state = isFullWidth ? .on : .off }
        return true
    }
    @objc func zoomIn(_ sender: Any?) { webView.pageZoom = min(webView.pageZoom + 0.1, 3) }
    @objc func zoomOut(_ sender: Any?) { webView.pageZoom = max(webView.pageZoom - 0.1, 0.5) }
    @objc func resetZoom(_ sender: Any?) { webView.pageZoom = 1 }
    @objc func findText(_ sender: Any?) {
        let alert = NSAlert(); alert.messageText = "Find in Document"; let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24)); alert.accessoryView = field; alert.addButton(withTitle: "Find"); alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty { let config = WKFindConfiguration(); config.wraps = true; webView.find(field.stringValue, configuration: config) { _ in } }
    }
}

final class DropView: NSView {
    private let handler: ([URL]) -> Void
    var appearanceHandler: (() -> Void)?
    init(frame: NSRect, handler: @escaping ([URL]) -> Void) { self.handler = handler; super.init(frame: frame); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); appearanceHandler?() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let objects = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else { return false }; handler(objects); return true
    }
}
