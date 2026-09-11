import AppKit
import UniformTypeIdentifiers
import WebKit

private struct TOCHeading {
    let level: Int
    let title: String
    let id: String
}

private final class TOCNode: NSObject {
    let heading: TOCHeading
    var children: [TOCNode] = []
    init(_ heading: TOCHeading) { self.heading = heading }
}

enum MarkdownLinkRouting {
    static func internalFragment(in url: URL, currentDocument: URL) -> String? {
        guard let fragment = url.fragment?.removingPercentEncoding else { return nil }
        let destination = url.standardizedFileURL.path
        let document = currentDocument.standardizedFileURL.path
        let directory = currentDocument.deletingLastPathComponent().standardizedFileURL.path
        return destination == document || destination == directory ? fragment : nil
    }
}

enum SidebarSizing {
    static let minimumWidth: CGFloat = 220
    static let suggestedPercentile = 0.85

    static func widths(_ measuredWidths: [CGFloat], splitWidth: CGFloat) -> (suggested: CGFloat, maximum: CGFloat) {
        let sorted = measuredWidths.map { max(minimumWidth, $0) }.sorted()
        guard let longest = sorted.last else { return (minimumWidth, minimumWidth) }
        let midpoint = floor(splitWidth / 2)
        let maximum = max(minimumWidth, min(longest, midpoint))
        let percentileIndex = min(
            sorted.count - 1,
            max(0, Int(ceil(Double(sorted.count) * suggestedPercentile)) - 1)
        )
        return (min(sorted[percentileIndex], maximum), maximum)
    }
}

enum ToolbarVisibilityPolicy {
    static let zoomPriority = NSToolbarItem.VisibilityPriority(rawValue: -2_000)

    static func priorities(sidebarVisible: Bool) -> (sidebar: NSToolbarItem.VisibilityPriority, fullWidth: NSToolbarItem.VisibilityPriority, zoom: NSToolbarItem.VisibilityPriority) {
        if sidebarVisible {
            return (
                NSToolbarItem.VisibilityPriority(rawValue: 1_500),
                .high,
                zoomPriority
            )
        }
        return (
            .low,
            NSToolbarItem.VisibilityPriority(rawValue: -500),
            zoomPriority
        )
    }
}

enum ZoomPolicy {
    static let minimum: CGFloat = 0.10
    static let maximum: CGFloat = 5.00
    static let step: CGFloat = 0.10

    static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }

    static func nextStep(from current: CGFloat) -> CGFloat {
        let currentPercent = (current * 100.0).rounded()
        let nextPercent = floor(currentPercent / 10.0) * 10.0 + 10.0
        return clamp(CGFloat(nextPercent / 100.0))
    }

    static func previousStep(from current: CGFloat) -> CGFloat {
        let currentPercent = (current * 100.0).rounded()
        let prevPercent = ceil(currentPercent / 10.0) * 10.0 - 10.0
        return clamp(CGFloat(prevPercent / 100.0))
    }

    static func parseManualInput(_ input: String, fallback: CGFloat) -> CGFloat {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let percent = Double(cleaned), !percent.isNaN && !percent.isInfinite else {
            return fallback
        }
        return clamp(CGFloat(percent / 100.0))
    }

    static func formatPercentage(_ magnification: CGFloat) -> String {
        let rawPercent = magnification * 100.0
        let roundedTo10 = (rawPercent / 10.0).rounded() * 10.0
        let finalPercent: Int
        if abs(rawPercent - roundedTo10) <= 2.5 {
            finalPercent = Int(roundedTo10)
        } else {
            finalPercent = Int(rawPercent.rounded())
        }
        return "\(finalPercent)%"
    }
}

final class ZoomLevelTextField: NSTextField {
    var onDoubleClick: (() -> Void)?
    var onCommit: ((String) -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.makeFirstResponder(nil)
            onDoubleClick?()
            return
        }
        super.mouseDown(with: event)
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        onCommit?(stringValue)
    }
}

struct NavigationEntry: Equatable {
    let url: URL
    let fragment: String?
    var scrollRatio: Double?

    static func == (lhs: NavigationEntry, rhs: NavigationEntry) -> Bool {
        lhs.url.standardizedFileURL == rhs.url.standardizedFileURL && lhs.fragment == rhs.fragment
    }
}

final class NavigationHistory {
    private(set) var entries: [NavigationEntry] = []
    private(set) var currentIndex: Int = -1

    var currentEntry: NavigationEntry? {
        guard entries.indices.contains(currentIndex) else { return nil }
        return entries[currentIndex]
    }

    var canGoBack: Bool {
        currentIndex > 0
    }

    var canGoForward: Bool {
        currentIndex >= 0 && currentIndex < entries.count - 1
    }

    private func updateScrollRatio(_ ratio: Double?) {
        if let ratio, entries.indices.contains(currentIndex) {
            entries[currentIndex].scrollRatio = ratio
        }
    }

    func push(url: URL, fragment: String? = nil, currentScrollRatio: Double? = nil) {
        let entry = NavigationEntry(url: url.standardizedFileURL, fragment: fragment, scrollRatio: nil)
        if entries.indices.contains(currentIndex) {
            if entries[currentIndex] == entry { return }
            updateScrollRatio(currentScrollRatio)
        }
        if currentIndex >= 0 && currentIndex < entries.count - 1 {
            entries.removeSubrange((currentIndex + 1)...)
        }
        entries.append(entry)
        currentIndex = entries.count - 1
    }

    func goBack(currentScrollRatio: Double? = nil) -> NavigationEntry? {
        guard canGoBack else { return nil }
        updateScrollRatio(currentScrollRatio)
        currentIndex -= 1
        return entries[currentIndex]
    }

    func goForward(currentScrollRatio: Double? = nil) -> NavigationEntry? {
        guard canGoForward else { return nil }
        updateScrollRatio(currentScrollRatio)
        currentIndex += 1
        return entries[currentIndex]
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var handler: WKScriptMessageHandler?
    init(_ handler: WKScriptMessageHandler) { self.handler = handler }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        handler?.userContentController(userContentController, didReceive: message)
    }
}

final class DocumentWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate, WKScriptMessageHandler, NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSToolbarDelegate, NSMenuItemValidation, NSSearchFieldDelegate, NSSplitViewDelegate {
    var onOpenURL: ((URL) -> Void)?
    var onDocumentChange: ((URL) -> Void)?
    var onClose: (() -> Void)?
    private let webView: WKWebView
    private let fileTable = NSTableView()
    private let tocOutline = NSOutlineView()
    private let sidebarContainer = NSView()
    private let split = NSSplitView()
    private let rootURL: URL
    private var currentURL: URL?
    private var files: [URL] = []
    private var fileRelativePaths: [String] = []
    private var tocRoots: [TOCNode] = []
    private var fileScrollView: NSScrollView?
    private var tocScrollView: NSScrollView?
    private var sidebarModeControl: NSSegmentedControl?
    private var watcher: FileWatcher?
    private let options: CLIOptions
    private let profiler: StartupProfiler
    private let cache: DiagramCache
    private let pipeline: MarkdownPipeline
    private var userSelectedDialect: MarkdownDialect?
    private(set) var currentDialect: MarkdownDialect
    private var hasShown = false
    private var snapshotWritten = false
    private(set) var isFullWidth: Bool
    private(set) var isSidebarVisible: Bool = false
    private var lastSidebarWidth: CGFloat = 340
    private var suggestedSidebarWidth: CGFloat = 340
    private var longestSidebarWidth: CGFloat = 340
    private var hasUserResizedSidebar = false
    private var isApplyingSidebarPosition = false
    private weak var fullWidthToolbarItem: NSToolbarItem?
    private weak var sidebarToolbarItem: NSToolbarItem?
    private weak var backForwardToolbarItem: NSToolbarItemGroup?
    private weak var zoomToolbarItem: NSToolbarItem?
    private weak var zoomMinusButton: NSButton?
    private weak var zoomField: ZoomLevelTextField?
    private weak var zoomPlusButton: NSButton?
    private var targetPageZoom: CGFloat = 1.0
    private var isRestoringDocumentZoom: Bool = false

    var effectiveZoom: CGFloat {
        let rawMag = webView.magnification
        let currentMag: CGFloat
        if abs(rawMag - 1.0) <= 0.025 {
            currentMag = 1.0
        } else if abs(rawMag - 2.0) <= 0.025 {
            currentMag = 2.0
        } else {
            currentMag = rawMag
        }
        return targetPageZoom * currentMag
    }

    var currentMagnificationLevel: CGFloat { effectiveZoom }
    private weak var searchToolbarItem: NSSearchToolbarItem?
    private weak var searchField: NSSearchField?
    private let searchCountLabel = NSTextField(labelWithString: "")
    private var findWorkItem: DispatchWorkItem?
    private var pendingFragment: String?
    private let navigationHistory = NavigationHistory()
    private var isNavigatingHistory = false
    private let renderQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.mdvu.render"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    private var renderOperation: Operation?
    private var directoryOperation: Operation?
    private var renderGeneration = 0
    private var currentRenderFileURL: URL?
    private var pendingScrollRatio: Double?
    private var systemAppearanceIsDark: Bool?
    private var magnificationObservation: NSKeyValueObservation?

    private static let backForwardItem = NSToolbarItem.Identifier("mdvu.backForward")
    private static let sidebarItem = NSToolbarItem.Identifier("mdvu.contents")
    private static let searchItem = NSToolbarItem.Identifier("mdvu.search")
    private static let zoomItem = NSToolbarItem.Identifier("mdvu.zoom")
    private static let fullWidthItem = NSToolbarItem.Identifier("mdvu.fullWidth")
    private static let scriptHandlerNames = ["diagramCache", "tableOfContents", "navigationHistory"]
    private static let measureScrollJS = "({y:scrollY,h:Math.max(1,document.documentElement.scrollHeight-innerHeight)})"

    private static func restoreScrollJS(ratio: Double) -> String {
        "scrollTo(0, Math.max(1, document.documentElement.scrollHeight - innerHeight) * \(ratio))"
    }

    private func jsLiteral(for string: String) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: string, options: .fragmentsAllowed),
              let literal = String(data: data, encoding: .utf8) else { return nil }
        return literal
    }

    init(url: URL, directoryMode: Bool, options: CLIOptions, profiler: StartupProfiler) {
        self.rootURL = url; self.options = options; self.profiler = profiler
        let cache = DiagramCache()
        self.cache = cache
        self.pipeline = MarkdownPipeline(dialect: options.dialect, mermaid: options.mermaid, cache: cache, isDialectExplicit: options.isDialectExplicit)
        self.currentDialect = options.dialect
        self.isFullWidth = options.fullWidth ?? UserDefaults.standard.bool(forKey: "layout.fullWidth")
        self.isSidebarVisible = options.snapshotPath != nil ? true : (UserDefaults.standard.object(forKey: "layout.sidebarVisible") as? Bool ?? false)
        if let prewarmed = WebKitPrewarmer.takePrewarmedWebView() {
            webView = prewarmed
        } else {
            let config = WKWebViewConfiguration()
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            config.userContentController = WKUserContentController()
            webView = WKWebView(frame: .zero, configuration: config)
        }
        webView.allowsMagnification = true
        let window = DocumentWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.controller = self
        window.delegate = self; window.titlebarAppearsTransparent = false; window.titleVisibility = .visible; window.tabbingMode = .preferred
        systemAppearanceIsDark = effectiveAppearanceIsDark
        if options.snapshotPath == nil { window.setFrameAutosaveName("mdvu.mainWindow") }
        configureToolbar()
        magnificationObservation = webView.observe(\.magnification, options: [.new]) { [weak self] _, _ in
            guard let self else { return }
            if self.isRestoringDocumentZoom { return }
            self.updateZoomControls()
        }
        webView.navigationDelegate = self
        Self.scriptHandlerNames.forEach { webView.configuration.userContentController.add(WeakScriptMessageHandler(self), name: $0) }
        configureLayout(directoryMode: directoryMode)
        if directoryMode { loadDirectory(url) } else { openDocument(url) }
        profiler.mark("window.created")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        tearDown()
    }

    func tearDown() {
        magnificationObservation?.invalidate()
        magnificationObservation = nil
        directoryOperation?.cancel()
        directoryOperation = nil
        renderOperation?.cancel()
        renderOperation = nil
        renderQueue.cancelAllOperations()
        watcher?.invalidate()
        watcher = nil
        if let currentRenderFileURL {
            try? FileManager.default.removeItem(at: currentRenderFileURL)
            self.currentRenderFileURL = nil
        }
        unregisterScriptMessageHandlers()
    }

    override func close() {
        tearDown()
        super.close()
    }

    private func unregisterScriptMessageHandlers() {
        Self.scriptHandlerNames.forEach { webView.configuration.userContentController.removeScriptMessageHandler(forName: $0) }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender); window?.center(); window?.makeKeyAndOrderFront(sender)
        if !hasShown { hasShown = true; profiler.mark("window.visible") }
    }
    func windowWillClose(_ notification: Notification) {
        tearDown()
        onClose?()
    }

    private func configureLayout(directoryMode: Bool) {
        split.isVertical = true; split.dividerStyle = .thin; split.delegate = self
        let tocColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("toc")); tocColumn.title = "Table of Contents"
        tocOutline.addTableColumn(tocColumn); tocOutline.outlineTableColumn = tocColumn; tocOutline.headerView = nil
        tocOutline.delegate = self; tocOutline.dataSource = self; tocOutline.rowHeight = 25; tocOutline.indentationPerLevel = 16
        let tocScroll = NSScrollView(); tocScroll.documentView = tocOutline; tocScroll.hasVerticalScroller = true; tocScroll.drawsBackground = false
        tocScrollView = tocScroll

        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 36).isActive = true
        if directoryMode {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file")); column.title = "Markdown"
            fileTable.addTableColumn(column); fileTable.headerView = nil; fileTable.delegate = self; fileTable.dataSource = self; fileTable.rowSizeStyle = .small
            let scroll = NSScrollView(); scroll.documentView = fileTable; scroll.hasVerticalScroller = true; scroll.drawsBackground = false
            fileScrollView = scroll
            let control = NSSegmentedControl(labels: ["Files", "Contents"], trackingMode: .selectOne, target: self, action: #selector(changeSidebarMode(_:)))
            control.selectedSegment = 0; control.controlSize = .small; sidebarModeControl = control
            header.addSubview(control); control.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([control.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 10), control.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -10), control.centerYAnchor.constraint(equalTo: header.centerYAnchor)])
        } else {
            let label = NSTextField(labelWithString: "Table of Contents")
            label.font = .systemFont(ofSize: 13, weight: .semibold); label.textColor = .secondaryLabelColor
            header.addSubview(label); label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12), label.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -12), label.centerYAnchor.constraint(equalTo: header.centerYAnchor)])
        }

        let content = NSView(); content.translatesAutoresizingMaskIntoConstraints = false
        if let fileScrollView {
            content.addSubview(fileScrollView); fileScrollView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([fileScrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor), fileScrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor), fileScrollView.topAnchor.constraint(equalTo: content.topAnchor), fileScrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor)])
        }
        content.addSubview(tocScroll); tocScroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([tocScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor), tocScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor), tocScroll.topAnchor.constraint(equalTo: content.topAnchor), tocScroll.bottomAnchor.constraint(equalTo: content.bottomAnchor)])
        tocScroll.isHidden = directoryMode

        sidebarContainer.addSubview(header); sidebarContainer.addSubview(content)
        NSLayoutConstraint.activate([header.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor), header.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor), header.topAnchor.constraint(equalTo: sidebarContainer.topAnchor), content.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor), content.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor), content.topAnchor.constraint(equalTo: header.bottomAnchor), content.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor)])
        sidebarContainer.frame.size.width = lastSidebarWidth
        if isSidebarVisible { split.addArrangedSubview(sidebarContainer) }
        split.addArrangedSubview(webView)
        if isSidebarVisible { split.setHoldingPriority(.defaultHigh, forSubviewAt: 0) }
        let dropView = DropView(frame: .zero, handler: { [weak self] in self?.handleDrop($0) })
        dropView.appearanceHandler = { [weak self] in self?.appearanceDidChange() }
        window?.contentView = dropView
        window?.contentView?.addSubview(split)
        split.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([split.leadingAnchor.constraint(equalTo: window!.contentView!.leadingAnchor), split.trailingAnchor.constraint(equalTo: window!.contentView!.trailingAnchor), split.topAnchor.constraint(equalTo: window!.contentView!.topAnchor), split.bottomAnchor.constraint(equalTo: window!.contentView!.bottomAnchor)])
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isSidebarVisible else { return }
            self.applySidebarPosition(self.lastSidebarWidth)
        }
    }

    private func configureToolbar() {
        let toolbar = NSToolbar(identifier: "mdvu.toolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbarStyle = .unifiedCompact
        window?.toolbar = toolbar
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [Self.backForwardItem, Self.sidebarItem, .flexibleSpace, Self.searchItem, Self.zoomItem, Self.fullWidthItem] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [Self.backForwardItem, Self.sidebarItem, .flexibleSpace, Self.searchItem, Self.zoomItem, Self.fullWidthItem] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch identifier {
        case Self.backForwardItem:
            let item = NSToolbarItemGroup(
                itemIdentifier: identifier,
                images: [
                    NSImage(systemSymbolName: "chevron.backward", accessibilityDescription: "Back")!,
                    NSImage(systemSymbolName: "chevron.forward", accessibilityDescription: "Forward")!
                ],
                selectionMode: .momentary,
                labels: ["Back", "Forward"],
                target: self,
                action: #selector(backForwardAction(_:))
            )
            item.isNavigational = true
            item.subitems[0].toolTip = "Go back (⌘[)"
            item.subitems[1].toolTip = "Go forward (⌘])"
            backForwardToolbarItem = item
            updateBackForwardControls()
            return item
        case Self.sidebarItem:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.target = self; item.action = #selector(toggleContents(_:)); item.isBordered = true
            item.isNavigational = true
            sidebarToolbarItem = item; updateSidebarControl()
            return item
        case Self.zoomItem:
            let item = NSToolbarItem(itemIdentifier: identifier)
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = 2
            stack.distribution = .fill

            let minus = NSButton(image: NSImage(systemSymbolName: "minus", accessibilityDescription: "Zoom Out")!, target: self, action: #selector(zoomOut(_:)))
            minus.bezelStyle = .texturedRounded
            minus.controlSize = .small
            minus.isBordered = true
            minus.toolTip = "Zoom Out (⌘-)"
            minus.translatesAutoresizingMaskIntoConstraints = false

            let field = ZoomLevelTextField()
            field.isEditable = true
            field.isSelectable = true
            field.isBordered = true
            field.bezelStyle = .roundedBezel
            field.controlSize = .small
            field.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            field.alignment = .center
            field.toolTip = "Zoom level. Click to edit, double-click to reset (⌘0)"
            field.stringValue = ZoomPolicy.formatPercentage(effectiveZoom)
            field.target = self
            field.action = #selector(zoomFieldAction(_:))
            field.onCommit = { [weak self] raw in
                guard let self else { return }
                let newZoom = ZoomPolicy.parseManualInput(raw, fallback: self.effectiveZoom)
                self.applyPageZoom(newZoom, resetMagnification: true)
            }
            field.onDoubleClick = { [weak self] in
                self?.resetZoom(nil)
            }
            field.translatesAutoresizingMaskIntoConstraints = false

            let plus = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "Zoom In")!, target: self, action: #selector(zoomIn(_:)))
            plus.bezelStyle = .texturedRounded
            plus.controlSize = .small
            plus.isBordered = true
            plus.toolTip = "Zoom In (⌘+)"
            plus.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                minus.widthAnchor.constraint(equalToConstant: 24),
                minus.heightAnchor.constraint(equalToConstant: 22),
                field.widthAnchor.constraint(equalToConstant: 50),
                field.heightAnchor.constraint(equalToConstant: 22),
                plus.widthAnchor.constraint(equalToConstant: 24),
                plus.heightAnchor.constraint(equalToConstant: 22)
            ])

            stack.addArrangedSubview(minus)
            stack.addArrangedSubview(field)
            stack.addArrangedSubview(plus)

            item.view = stack
            item.label = "Zoom"
            item.paletteLabel = "Zoom"
            item.toolTip = "Zoom"
            zoomToolbarItem = item
            zoomMinusButton = minus
            zoomField = field
            zoomPlusButton = plus
            updateToolbarVisibilityPriorities()
            updateZoomControls()
            return item
        case Self.fullWidthItem:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.target = self; item.action = #selector(toggleFullWidth(_:)); item.isBordered = true
            fullWidthToolbarItem = item; updateFullWidthControl()
            return item
        case Self.searchItem:
            let item = NSSearchToolbarItem(itemIdentifier: identifier)
            let field = NSSearchField()
            field.placeholderString = "Find"; field.delegate = self
            field.target = self; field.action = #selector(findFromSearchField(_:))

            searchCountLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            searchCountLabel.textColor = .secondaryLabelColor
            searchCountLabel.alignment = .right
            searchCountLabel.isSelectable = false
            searchCountLabel.isEditable = false
            searchCountLabel.drawsBackground = false
            searchCountLabel.isBezeled = false
            searchCountLabel.wantsLayer = true
            searchCountLabel.layer?.zPosition = 100
            searchCountLabel.translatesAutoresizingMaskIntoConstraints = false
            field.addSubview(searchCountLabel)
            NSLayoutConstraint.activate([
                searchCountLabel.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -24),
                searchCountLabel.centerYAnchor.constraint(equalTo: field.centerYAnchor)
            ])

            item.searchField = field
            item.preferredWidthForSearchField = 300
            item.resignsFirstResponderWithCancel = true
            item.label = "Find"; item.paletteLabel = "Find"
            searchToolbarItem = item
            searchField = field
            updateToolbarVisibilityPriorities()
            return item
        default:
            return nil
        }
    }

    private func updateSidebarControl() {
        sidebarToolbarItem?.label = isSidebarVisible ? "Hide Contents" : "Show Contents"
        sidebarToolbarItem?.toolTip = isSidebarVisible ? "Hide table of contents" : "Show table of contents"
        sidebarToolbarItem?.image = NSImage(systemSymbolName: "sidebar.leading", accessibilityDescription: "Toggle table of contents")
        updateToolbarVisibilityPriorities()
    }

    private func updateFullWidthControl() {
        fullWidthToolbarItem?.label = isFullWidth ? "Readable Width" : "Full Width"
        fullWidthToolbarItem?.toolTip = isFullWidth ? "Use readable document width" : "Use the full window width"
        fullWidthToolbarItem?.image = NSImage(systemSymbolName: isFullWidth ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Toggle full width")
        updateToolbarVisibilityPriorities()
    }

    private func updateToolbarVisibilityPriorities() {
        searchToolbarItem?.visibilityPriority = .user
        backForwardToolbarItem?.visibilityPriority = .high
        let priorities = ToolbarVisibilityPolicy.priorities(sidebarVisible: isSidebarVisible)
        sidebarToolbarItem?.visibilityPriority = priorities.sidebar
        fullWidthToolbarItem?.visibilityPriority = priorities.fullWidth
        zoomToolbarItem?.visibilityPriority = priorities.zoom
    }

    private func loadDirectory(_ directory: URL) {
        directoryOperation?.cancel()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            var discovered: [URL] = []
            let ignoredNames: Set<String> = ["node_modules", ".build", ".git", "Pods", "vendor", "target", "dist", ".cache"]
            let prefix = directory.path + "/"
            if let iterator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for case let url as URL in iterator {
                    if operation.isCancelled { return }
                    if let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory, isDir {
                        if ignoredNames.contains(url.lastPathComponent) {
                            iterator.skipDescendants()
                            continue
                        }
                    }
                    if MarkdownDocument.isMarkdown(url: url) {
                        discovered.append(url)
                        if discovered.count == 5000 { break }
                    }
                }
            }
            discovered.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            let relativePaths = discovered.map {
                $0.path.hasPrefix(prefix) ? String($0.path.dropFirst(prefix.count)) : $0.lastPathComponent
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.files = discovered
                self.fileRelativePaths = relativePaths
                self.fileTable.reloadData()
                if let first = discovered.first {
                    self.openDocument(first)
                    self.fileTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                } else {
                    self.showMessage("No Markdown files found", detail: directory.path)
                }
            }
        }
        directoryOperation = operation
        renderQueue.addOperation(operation)
    }

    private func openDocument(_ url: URL, preserveScroll: Bool = false, isHistoryNavigation: Bool = false) {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let fragment = components?.fragment?.removingPercentEncoding
        components?.fragment = nil
        let documentURL = (components?.url ?? url).standardizedFileURL
        guard MarkdownDocument.isMarkdown(url: documentURL) else { return }
        let changedDocument = documentURL.path != currentURL?.path
        pendingFragment = fragment
        currentURL = documentURL; window?.representedURL = documentURL; window?.title = documentURL.lastPathComponent
        if changedDocument {
            tocRoots = []; tocOutline.reloadData()
            onDocumentChange?(documentURL)
            (window as? DocumentWindow)?.updateTitleToolTip()
            if !options.isDialectExplicit {
                userSelectedDialect = nil
            }
        }

        if !preserveScroll && !isHistoryNavigation && !isNavigatingHistory {
            captureCurrentScrollRatio { [weak self] ratio in
                guard let self else { return }
                self.navigationHistory.push(url: documentURL, fragment: fragment, currentScrollRatio: ratio)
                self.updateBackForwardControls()
            }
        }

        let scrollScript = preserveScroll ? Self.measureScrollJS : nil
        let render: (Any?) -> Void = { [weak self] position in self?.render(documentURL, position: position) }
        if let scrollScript { webView.evaluateJavaScript(scrollScript) { position, _ in render(position) } } else { render(nil) }
        watcher?.invalidate()
        watcher = FileWatcher(url: documentURL) { [weak self] in self?.openDocument(documentURL, preserveScroll: true) }
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

        if position == nil, let eagerTask = EagerDocumentLoader.take(for: url) {
            Task { @MainActor [weak self] in
                guard self?.renderGeneration == generation else { return }
                do {
                    let rendered = try await eagerTask.value
                    guard let self, self.renderGeneration == generation else { return }
                    self.currentDialect = rendered.dialect
                    let html = HTMLDocument.make(body: rendered.body, title: rendered.title ?? url.lastPathComponent, theme: theme, fullWidth: fullWidth, baseURL: url.deletingLastPathComponent())
                    self.isRestoringDocumentZoom = true
                    self.pendingScrollRatio = scrollRatio
                    self.profiler.mark("markdown.ready")
                    self.loadRenderedHTML(html, baseURL: url.deletingLastPathComponent())
                    self.profiler.mark("html.loaded")
                } catch {
                    guard let self, self.renderGeneration == generation else { return }
                    self.isRestoringDocumentZoom = false
                    self.showMessage("Unable to open document", detail: error.localizedDescription)
                }
            }
            return
        }

        let operation = BlockOperation()
        let userDialect = self.userSelectedDialect
        let basePipeline = self.pipeline
        let cache = self.cache
        let options = self.options
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard !operation.isCancelled else { return }
                let source = String(decoding: data, as: UTF8.self)
                let pipeline: MarkdownPipeline = {
                    if let userDialect {
                        return MarkdownPipeline(dialect: userDialect, mermaid: options.mermaid, cache: cache, isDialectExplicit: true)
                    }
                    return basePipeline
                }()
                let rendered = pipeline.render(source, diagramTheme: diagramTheme)
                guard !operation.isCancelled else { return }
                let html = HTMLDocument.make(body: rendered.body, title: rendered.title ?? url.lastPathComponent, theme: theme, fullWidth: fullWidth, baseURL: url.deletingLastPathComponent())
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.renderGeneration == generation else { return }
                    self.currentDialect = rendered.dialect
                    self.isRestoringDocumentZoom = true
                    self.pendingScrollRatio = scrollRatio
                    self.profiler.mark("markdown.ready")
                    self.loadRenderedHTML(html, baseURL: url.deletingLastPathComponent())
                    self.profiler.mark("html.loaded")
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.renderGeneration == generation else { return }
                    self.isRestoringDocumentZoom = false
                    self.showMessage("Unable to open document", detail: error.localizedDescription)
                }
            }
        }
        renderOperation = operation
        renderQueue.addOperation(operation)
    }

    private func loadRenderedHTML(_ html: String, baseURL: URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("mdvu-renders-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempFile = tempDir.appendingPathComponent("render-\(UUID().uuidString).html")
        do {
            try html.write(to: tempFile, atomically: true, encoding: .utf8)
            if let old = currentRenderFileURL {
                try? FileManager.default.removeItem(at: old)
            }
            currentRenderFileURL = tempFile
            webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        } catch {
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    private func showMessage(_ title: String, detail: String) {
        isRestoringDocumentZoom = false
        webView.loadHTMLString(HTMLDocument.make(body: "<div class=\"empty\"><h1>\(HTML.escape(title))</h1><p>\(HTML.escape(detail))</p></div>", title: title, theme: options.theme, fullWidth: isFullWidth), baseURL: nil)
    }
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
        cell.textField?.stringValue = row < fileRelativePaths.count ? fileRelativePaths[row] : files[row].lastPathComponent; return cell
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard fileTable.selectedRow >= 0 else { return }
        let selected = files[fileTable.selectedRow]
        if selected.standardizedFileURL != currentURL?.standardizedFileURL { openDocument(selected) }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? TOCNode)?.children.count ?? tocRoots.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? TOCNode)?.children[index] ?? tocRoots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as? TOCNode)?.children.isEmpty ?? true)
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? TOCNode else { return nil }
        let id = NSUserInterfaceItemIdentifier("tocCell")
        let cell = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView ?? NSTableCellView()
        if cell.textField == nil {
            let field = NSTextField(labelWithString: "")
            field.font = .systemFont(ofSize: 13); field.lineBreakMode = .byTruncatingTail
            cell.addSubview(field); field.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2), field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4), field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
            cell.textField = field; cell.identifier = id
        }
        cell.textField?.stringValue = node.heading.title
        cell.toolTip = node.heading.title
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = tocOutline.selectedRow
        guard row >= 0, let node = tocOutline.item(atRow: row) as? TOCNode else { return }
        scrollToFragment(node.heading.id, updateHistory: true)
    }

    private func updateTableOfContents(_ headings: [TOCHeading]) {
        var roots: [TOCNode] = []
        var stack: [TOCNode] = []
        for heading in headings {
            let node = TOCNode(heading)
            while let parent = stack.last, parent.heading.level >= heading.level { stack.removeLast() }
            if let parent = stack.last { parent.children.append(node) } else { roots.append(node) }
            stack.append(node)
        }
        tocRoots = roots
        tocOutline.reloadData()
        tocOutline.expandItem(nil, expandChildren: true)
        fitSidebarToContents(headings)
        if let pendingFragment {
            self.pendingFragment = nil
            scrollToFragment(pendingFragment, updateHistory: false)
        }
    }

    private func scrollToFragment(_ fragment: String, updateHistory: Bool) {
        guard let literal = jsLiteral(for: fragment) else { return }
        webView.evaluateJavaScript("window.__mdvuScrollToFragment?.(\(literal), \(updateHistory ? "true" : "false"))")
    }

    @objc private func changeSidebarMode(_ sender: NSSegmentedControl) {
        let showingContents = sender.selectedSegment == 1
        fileScrollView?.isHidden = showingContents
        tocScrollView?.isHidden = !showingContents
    }

    @objc func toggleContents(_ sender: Any?) {
        if isSidebarVisible {
            lastSidebarWidth = max(SidebarSizing.minimumWidth, sidebarContainer.frame.width)
            split.removeArrangedSubview(sidebarContainer)
            sidebarContainer.removeFromSuperview()
            isSidebarVisible = false
        } else {
            isSidebarVisible = true
            split.insertArrangedSubview(sidebarContainer, at: 0)
            split.setHoldingPriority(.defaultHigh, forSubviewAt: 0)
            let target = hasUserResizedSidebar ? min(lastSidebarWidth, maximumSidebarWidth(in: split)) : suggestedSidebarWidth
            applySidebarPosition(target)
        }
        UserDefaults.standard.set(isSidebarVisible, forKey: "layout.sidebarVisible")
        updateSidebarControl()
    }

    private func flattenedHeadings() -> [TOCHeading] {
        func flatten(_ nodes: [TOCNode]) -> [TOCHeading] {
            nodes.flatMap { [$0.heading] + flatten($0.children) }
        }
        return flatten(tocRoots)
    }

    private func fitSidebarToContents(_ headings: [TOCHeading]) {
        guard !headings.isEmpty else { return }
        let font = NSFont.systemFont(ofSize: 13)
        let baseLevel = headings.map(\.level).min() ?? 1
        let measuredWidths = headings.map { heading in
            let textWidth = ceil((heading.title as NSString).size(withAttributes: [.font: font]).width)
            let indentation = CGFloat(max(0, heading.level - baseLevel)) * tocOutline.indentationPerLevel
            return textWidth + indentation + 52
        }
        let sizing = SidebarSizing.widths(measuredWidths, splitWidth: split.bounds.width)
        suggestedSidebarWidth = sizing.suggested
        longestSidebarWidth = measuredWidths.max() ?? SidebarSizing.minimumWidth
        guard isSidebarVisible, sidebarContainer.superview === split else { return }
        let target = hasUserResizedSidebar ? min(lastSidebarWidth, sizing.maximum) : sizing.suggested
        applySidebarPosition(target)
    }

    private func maximumSidebarWidth(in splitView: NSSplitView) -> CGFloat {
        max(SidebarSizing.minimumWidth, min(longestSidebarWidth, floor(splitView.bounds.width / 2)))
    }

    private func applySidebarPosition(_ width: CGFloat) {
        let constrained = max(SidebarSizing.minimumWidth, min(width, maximumSidebarWidth(in: split)))
        isApplyingSidebarPosition = true
        split.setPosition(constrained, ofDividerAt: 0)
        isApplyingSidebarPosition = false
        lastSidebarWidth = constrained
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        dividerIndex == 0 ? max(SidebarSizing.minimumWidth, proposedMinimumPosition) : proposedMinimumPosition
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        dividerIndex == 0 ? min(maximumSidebarWidth(in: splitView), proposedMaximumPosition) : proposedMaximumPosition
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard isSidebarVisible, sidebarContainer.superview === split, sidebarContainer.frame.width >= SidebarSizing.minimumWidth else { return }
        let maximum = maximumSidebarWidth(in: split)
        if !isApplyingSidebarPosition, sidebarContainer.frame.width > maximum + 0.5 {
            applySidebarPosition(maximum)
            return
        }
        lastSidebarWidth = sidebarContainer.frame.width
        if !isApplyingSidebarPosition, NSApp.currentEvent?.type == .leftMouseDragged {
            hasUserResizedSidebar = true
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        profiler.mark("webview.firstContent")
        if abs(webView.pageZoom - targetPageZoom) > 0.001 {
            webView.pageZoom = targetPageZoom
        }
        if abs(webView.magnification - 1.0) > 0.001 {
            webView.setMagnification(1.0, centeredAt: CGPoint.zero)
        }
        isRestoringDocumentZoom = false
        updateZoomControls()
        if let ratio = pendingScrollRatio { pendingScrollRatio = nil; webView.evaluateJavaScript(Self.restoreScrollJS(ratio: ratio)) }
        if let query = searchField?.stringValue, !query.isEmpty { performFind(query) }
        if options.snapshotPath != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.captureSnapshotIfRequested() }
        }
        webView.evaluateJavaScript("[(document.querySelector('.diagram-pending[data-renderer=\"mermaid\"]') !== null), (document.querySelector('.diagram-pending[data-renderer=\"plantuml\"]') !== null), (document.querySelector('.math-inline, .math-display') !== null)]") { [weak self] value, _ in
            guard let self else { return }
            guard let flags = value as? [Bool], flags.count == 3 else { self.captureSnapshotIfRequested(); return }
            let needsMermaid = options.mermaid && flags[0]
            let needsPlantUML = options.mermaid && flags[1]
            let needsMath = flags[2]
            guard needsMermaid || needsPlantUML || needsMath else { self.captureSnapshotIfRequested(); return }

            let group = DispatchGroup()

            if needsMermaid {
                let mermaid = ResourceLoader.mermaidJavaScript
                if !mermaid.isEmpty {
                    group.enter()
                    self.webView.evaluateJavaScript(mermaid) { _, error in
                        #if DEBUG
                        if let error {
                            FileHandle.standardError.write(Data("mdvu: Mermaid load failed: \(error.localizedDescription)\n".utf8))
                        }
                        #endif
                        group.leave()
                    }
                }
            }

            if needsPlantUML {
                let plantuml = ResourceLoader.plantumlJavaScript
                if !plantuml.isEmpty {
                    group.enter()
                    self.webView.evaluateJavaScript(plantuml) { _, error in
                        #if DEBUG
                        if let error {
                            FileHandle.standardError.write(Data("mdvu: PlantUML load failed: \(error.localizedDescription)\n".utf8))
                        }
                        #endif
                        group.leave()
                    }
                }
            }

            if needsMath {
                let katex = ResourceLoader.katexJavaScript
                if !katex.isEmpty {
                    group.enter()
                    self.webView.evaluateJavaScript(katex) { _, error in
                        #if DEBUG
                        if let error {
                            FileHandle.standardError.write(Data("mdvu: KaTeX load failed: \(error.localizedDescription)\n".utf8))
                        }
                        #endif
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) { [weak self] in
                guard let self else { return }
                self.webView.evaluateJavaScript("(window.__mdvuRenderMath && window.__mdvuRenderMath()), (window.__mdvuRenderDiagrams && window.__mdvuRenderDiagrams())") { [weak self] _, _ in
                    self?.profiler.mark("render.complete")
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
              let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(number), [.boundsIgnoreFraming, .nominalResolution]) else { NSApp.terminate(nil); return }
        let bitmap = NSBitmapImageRep(cgImage: image)
        if let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        NSApp.terminate(nil)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else { decisionHandler(.allow); return }
        if ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url); decisionHandler(.cancel); return }
        if let currentURL, let fragment = MarkdownLinkRouting.internalFragment(in: url, currentDocument: currentURL) {
            scrollToFragment(fragment, updateHistory: true); decisionHandler(.cancel); return
        }
        if url.isFileURL, MarkdownDocument.isMarkdown(url: url) {
            openDocument(url); decisionHandler(.cancel)
            return
        }
        if url.scheme == "file" { NSWorkspace.shared.open(url); decisionHandler(.cancel); return }
        // Markdown is untrusted: unknown, data, and javascript schemes never load.
        decisionHandler(.cancel)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "diagramCache", let body = message.body as? [String: Any], let key = body["key"] as? String, let svg = body["svg"] as? String {
            DispatchQueue.global(qos: .utility).async { [cache] in cache.write(key: key, svg: svg) }
            return
        }
        if message.name == "tableOfContents", let body = message.body as? [[String: Any]] {
            let headings = body.compactMap { item -> TOCHeading? in
                guard let level = (item["level"] as? NSNumber)?.intValue, let title = item["title"] as? String, let id = item["id"] as? String else { return nil }
                return TOCHeading(level: level, title: title, id: id)
            }
            updateTableOfContents(headings)
            return
        }
        if message.name == "navigationHistory", let body = message.body as? [String: Any], let fragment = body["fragment"] as? String {
            guard !isNavigatingHistory, let url = currentURL else { return }
            captureCurrentScrollRatio { [weak self] ratio in
                guard let self else { return }
                self.navigationHistory.push(url: url, fragment: fragment, currentScrollRatio: ratio)
                self.updateBackForwardControls()
            }
            return
        }
    }

    @objc func reload(_ sender: Any?) { if let currentURL { openDocument(currentURL, preserveScroll: true) } }
    @objc func toggleFullWidth(_ sender: Any?) {
        preserveReadingAnchor()
        isFullWidth.toggle()
        UserDefaults.standard.set(isFullWidth, forKey: "layout.fullWidth")
        updateFullWidthControl()
        webView.evaluateJavaScript("document.documentElement.classList.toggle('full-width', \(isFullWidth ? "true" : "false"))")
    }

    @objc private func backForwardAction(_ sender: NSToolbarItemGroup) {
        if sender.selectedIndex == 0 {
            goBack(sender)
        } else if sender.selectedIndex == 1 {
            goForward(sender)
        }
    }

    var canGoBack: Bool { navigationHistory.canGoBack }
    var canGoForward: Bool { navigationHistory.canGoForward }

    private func navigateHistory(step: @escaping (Double?) -> NavigationEntry?) {
        captureCurrentScrollRatio { [weak self] ratio in
            guard let self, let target = step(ratio) else { return }
            self.restoreNavigationEntry(target)
            self.updateBackForwardControls()
        }
    }

    @objc func goBack(_ sender: Any? = nil) {
        guard navigationHistory.canGoBack else { return }
        navigateHistory { [navigationHistory] in navigationHistory.goBack(currentScrollRatio: $0) }
    }

    @objc func goForward(_ sender: Any? = nil) {
        guard navigationHistory.canGoForward else { return }
        navigateHistory { [navigationHistory] in navigationHistory.goForward(currentScrollRatio: $0) }
    }

    private func restoreNavigationEntry(_ entry: NavigationEntry) {
        isNavigatingHistory = true
        defer { isNavigatingHistory = false }

        if entry.url.standardizedFileURL == currentURL?.standardizedFileURL {
            if let fragment = entry.fragment {
                scrollToFragment(fragment, updateHistory: false)
            } else if let ratio = entry.scrollRatio {
                webView.evaluateJavaScript(Self.restoreScrollJS(ratio: ratio))
            } else {
                webView.evaluateJavaScript("scrollTo(0, 0)")
            }
        } else {
            if let fragment = entry.fragment {
                self.pendingFragment = fragment
                self.pendingScrollRatio = nil
            } else {
                self.pendingFragment = nil
                self.pendingScrollRatio = entry.scrollRatio ?? 0
            }
            openDocument(entry.url, isHistoryNavigation: true)
            selectFileInList(entry.url)
        }
    }

    private func selectFileInList(_ url: URL) {
        guard let idx = files.firstIndex(where: { $0.standardizedFileURL == url.standardizedFileURL }), fileTable.selectedRow != idx else { return }
        fileTable.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        fileTable.scrollRowToVisible(idx)
    }

    private func captureCurrentScrollRatio(completion: @escaping (Double?) -> Void) {
        webView.evaluateJavaScript(Self.measureScrollJS) { result, _ in
            guard let dict = result as? [String: Any],
                  let y = dict["y"] as? Double,
                  let h = dict["h"] as? Double, h > 0 else {
                completion(nil)
                return
            }
            completion(y / h)
        }
    }

    private func updateBackForwardControls() {
        backForwardToolbarItem?.subitems[0].isEnabled = navigationHistory.canGoBack
        backForwardToolbarItem?.subitems[1].isEnabled = navigationHistory.canGoForward
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(goBack(_:)) { return navigationHistory.canGoBack }
        if menuItem.action == #selector(goForward(_:)) { return navigationHistory.canGoForward }
        if menuItem.action == #selector(toggleFullWidth(_:)) { menuItem.state = isFullWidth ? .on : .off }
        if menuItem.action == #selector(toggleContents(_:)) {
            menuItem.state = isSidebarVisible ? .on : .off
            menuItem.title = isSidebarVisible ? "Hide Table of Contents" : "Show Table of Contents"
        }
        if menuItem.action == #selector(selectDialectAuto(_:)) {
            menuItem.state = userSelectedDialect == nil ? .on : .off
            return true
        }
        if menuItem.action == #selector(selectDialectGeneric(_:)) {
            menuItem.state = currentDialect == .generic ? .on : .off
            return true
        }
        if menuItem.action == #selector(selectDialectGitHub(_:)) {
            menuItem.state = currentDialect == .github ? .on : .off
            return true
        }
        if menuItem.action == #selector(selectDialectObsidian(_:)) {
            menuItem.state = currentDialect == .obsidian ? .on : .off
            return true
        }
        if menuItem.action == #selector(zoomIn(_:)) { return effectiveZoom < (ZoomPolicy.maximum - 0.005) }
        if menuItem.action == #selector(zoomOut(_:)) { return effectiveZoom > (ZoomPolicy.minimum + 0.005) }
        if menuItem.action == #selector(resetZoom(_:)) {
            return abs(effectiveZoom - 1.0) > 0.005
        }
        return true
    }

    @objc func selectDialectAuto(_ sender: Any?) {
        guard userSelectedDialect != nil else { return }
        userSelectedDialect = nil
        if let currentURL {
            openDocument(currentURL, preserveScroll: true)
        }
    }

    @objc func selectDialectGeneric(_ sender: Any?) {
        setDialect(.generic)
    }

    @objc func selectDialectGitHub(_ sender: Any?) {
        setDialect(.github)
    }

    @objc func selectDialectObsidian(_ sender: Any?) {
        setDialect(.obsidian)
    }

    func setDialect(_ newDialect: MarkdownDialect) {
        guard userSelectedDialect != newDialect else { return }
        userSelectedDialect = newDialect
        currentDialect = newDialect
        if let currentURL {
            openDocument(currentURL, preserveScroll: true)
        }
    }

    @objc func zoomIn(_ sender: Any?) {
        let current = effectiveZoom
        let next = ZoomPolicy.nextStep(from: current)
        applyPageZoom(next)
    }

    @objc func zoomOut(_ sender: Any?) {
        let current = effectiveZoom
        let prev = ZoomPolicy.previousStep(from: current)
        applyPageZoom(prev)
    }

    @objc func resetZoom(_ sender: Any?) {
        applyPageZoom(1.0, resetMagnification: true)
    }

    @objc private func zoomFieldAction(_ sender: Any?) {
        window?.makeFirstResponder(nil)
    }

    private func preserveReadingAnchor() {
        let captureAnchorJS = """
        (() => {
            const x = window.innerWidth / 2;
            const y = window.innerHeight / 2;
            let el = document.elementFromPoint(x, y);
            while (el && el !== document.body && el !== document.documentElement) {
                if (['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'LI', 'PRE', 'TR', 'BLOCKQUOTE', 'TABLE', 'IMG'].includes(el.tagName)) {
                    break;
                }
                el = el.parentElement;
            }
            if (!el || el === document.body || el === document.documentElement) {
                el = document.elementFromPoint(x, 100) || document.body;
            }
            const prev = document.querySelector('[data-mdvu-anchor]');
            if (prev) prev.removeAttribute('data-mdvu-anchor');
            if (el && el !== document.body && el !== document.documentElement) {
                el.setAttribute('data-mdvu-anchor', 'true');
                return { top: el.getBoundingClientRect().top, ratio: window.scrollY / (document.documentElement.scrollHeight || 1) };
            }
            return { top: 0, ratio: window.scrollY / (document.documentElement.scrollHeight || 1) };
        })()
        """
        webView.evaluateJavaScript(captureAnchorJS) { [weak self] result, _ in
            guard let self else { return }
            let dict = (result as? [String: Any]) ?? [:]
            let oldTop = (dict["top"] as? Double) ?? 0
            let oldRatio = (dict["ratio"] as? Double) ?? 0

            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(40)) { [weak self] in
                guard let self else { return }
                let restoreAnchorJS = """
                (() => {
                    const el = document.querySelector('[data-mdvu-anchor]');
                    if (el) {
                        const newRect = el.getBoundingClientRect();
                        const delta = newRect.top - (\(oldTop));
                        window.scrollBy(0, delta);
                        el.removeAttribute('data-mdvu-anchor');
                    } else {
                        window.scrollTo(0, (\(oldRatio)) * document.documentElement.scrollHeight);
                    }
                })()
                """
                self.webView.evaluateJavaScript(restoreAnchorJS)
            }
        }
    }

    func applyPageZoom(_ zoom: CGFloat, resetMagnification: Bool = false) {
        let clamped = ZoomPolicy.clamp(zoom)
        targetPageZoom = clamped
        preserveReadingAnchor()
        if resetMagnification || abs(webView.magnification - 1.0) > 0.005 {
            webView.setMagnification(1.0, centeredAt: CGPoint.zero)
        }
        webView.pageZoom = clamped
        updateZoomControls()
    }

    func setUnifiedMagnification(_ magnification: CGFloat, centeredAt centerPoint: CGPoint? = nil) {
        applyPageZoom(magnification, resetMagnification: true)
    }

    func updateZoomControls() {
        let current = effectiveZoom
        zoomMinusButton?.isEnabled = current > (ZoomPolicy.minimum + 0.005)
        zoomPlusButton?.isEnabled = current < (ZoomPolicy.maximum - 0.005)

        let formatted = ZoomPolicy.formatPercentage(current)
        if zoomField?.stringValue != formatted {
            zoomField?.stringValue = formatted
            if let editor = zoomField?.currentEditor() as? NSTextView, window?.firstResponder === editor {
                editor.string = formatted
                editor.selectAll(nil)
            }
        }
    }

    func syncLiveMagnification(ended: Bool = false) {
        updateZoomControls()
        if ended {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.settleMagnification()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.settleMagnification()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
                self?.settleMagnification(final: true)
            }
        }
    }

    private func settleMagnification(final: Bool = false) {
        if abs(webView.magnification - 1.0) <= 0.03 {
            if final && webView.magnification != 1.0 {
                webView.setMagnification(1.0, centeredAt: CGPoint.zero)
            }
        } else if abs(webView.magnification - 2.0) <= 0.03 {
            if final && webView.magnification != 2.0 {
                webView.setMagnification(2.0, centeredAt: CGPoint.zero)
            }
        }
        updateZoomControls()
    }

    func handleSmartMagnifyAnimation() {
        let start = CACurrentMediaTime()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            self.updateZoomControls()
            if CACurrentMediaTime() - start > 0.35 {
                t.invalidate()
                self.settleMagnification(final: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func isPointInWebView(_ pointInWindow: NSPoint) -> Bool {
        let pointInWebView = webView.convert(pointInWindow, from: nil)
        return webView.bounds.contains(pointInWebView)
    }

    func handleZoomScroll(with event: NSEvent) {
        guard event.momentumPhase.isEmpty else { return }
        let rawDelta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
        guard rawDelta != 0 else { return }
        let delta = event.isDirectionInvertedFromDevice ? -rawDelta : rawDelta
        let factor: CGFloat = event.hasPreciseScrollingDeltas ? 0.005 : 0.08
        let scale = max(0.2, 1.0 + delta * factor)
        let curMag = webView.magnification
        let newMagnification = ZoomPolicy.clamp(curMag * scale)
        guard abs(newMagnification - curMag) > 0.0005 else { return }

        let mouseInWindow = event.locationInWindow
        let mouseInWebView = webView.convert(mouseInWindow, from: nil)
        let centerPoint = webView.bounds.contains(mouseInWebView) ? mouseInWebView : CGPoint(x: webView.bounds.midX, y: webView.bounds.midY)
        applyMagnification(newMagnification, centeredAt: centerPoint)
    }

    func applyMagnification(_ newMag: CGFloat, centeredAt mousePoint: CGPoint) {
        let curMag = webView.magnification
        let clamped = ZoomPolicy.clamp(newMag)
        guard abs(clamped - curMag) > 0.0005 else { return }

        let mx = Double(mousePoint.x)
        let my = Double(mousePoint.y)
        let deltaX = mx * (1.0 / Double(curMag) - 1.0 / Double(clamped))
        let deltaY = my * (1.0 / Double(curMag) - 1.0 / Double(clamped))

        webView.setMagnification(clamped, centeredAt: CGPoint.zero)
        webView.evaluateJavaScript("window.scrollBy(\(deltaX), \(deltaY))")
        updateZoomControls()
    }

    @objc func openFileDialog(_ sender: Any? = nil) {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown File or Folder"
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder] + MarkdownDocument.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        if let currentURL {
            panel.directoryURL = currentURL.deletingLastPathComponent()
        }
        guard let window, window.attachedSheet == nil else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let selectedURL = panel.url else { return }
            self.loadTargetURL(selectedURL)
        }
    }

    func loadTargetURL(_ url: URL) {
        let standardized = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory) else { return }
        if isDirectory.boolValue {
            if fileScrollView != nil {
                loadDirectory(standardized)
            } else {
                onOpenURL?(standardized)
            }
        } else if MarkdownDocument.isMarkdown(url: standardized) {
            openDocument(standardized)
            selectFileInList(standardized)
        }
    }

    @objc func findText(_ sender: Any?) {
        if let searchToolbarItem { searchToolbarItem.beginSearchInteraction() }
        else if let searchField { window?.makeFirstResponder(searchField) }
    }

    @objc func findNextText(_ sender: Any?) { findNext() }
    @objc func findPreviousText(_ sender: Any?) { findPrevious() }

    @objc private func findFromSearchField(_ sender: NSSearchField) {
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
            findPrevious()
        } else {
            findNext()
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField, field === searchField else { return }
        findWorkItem?.cancel()
        let query = field.stringValue
        if query.isEmpty {
            clearFind()
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.performFind(query) }
        findWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func performFind(_ query: String) {
        guard !query.isEmpty else {
            clearFind()
            return
        }
        guard let literal = jsLiteral(for: query) else { return }
        webView.evaluateJavaScript("window.__mdvuFind?.search(\(literal))") { [weak self] result, _ in
            self?.updateFindCounter(result, query: query)
        }
    }

    private func stepFind(_ method: String) {
        webView.evaluateJavaScript("window.__mdvuFind?.\(method)()") { [weak self] result, _ in
            if let query = self?.searchField?.stringValue, !query.isEmpty {
                self?.updateFindCounter(result, query: query)
            }
        }
    }

    private func findNext() { stepFind("next") }
    private func findPrevious() { stepFind("previous") }

    private func clearFind() {
        searchCountLabel.stringValue = ""
        webView.evaluateJavaScript("window.__mdvuFind?.clear()")
    }

    private func updateFindCounter(_ result: Any?, query: String) {
        guard let dict = result as? [String: Any],
              let count = dict["count"] as? Int,
              let current = dict["current"] as? Int else {
            searchCountLabel.stringValue = ""
            return
        }
        if query.isEmpty {
            searchCountLabel.stringValue = ""
        } else if count == 0 {
            searchCountLabel.stringValue = "0/0"
            searchCountLabel.textColor = .systemRed
        } else {
            searchCountLabel.stringValue = "\(current)/\(count)"
            searchCountLabel.textColor = .secondaryLabelColor
        }
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

final class DocumentWindow: NSWindow {
    weak var controller: DocumentWindowController?
    private var isZoomingWithScroll = false
    private var titleClickStartPoint: NSPoint?
    private weak var cachedTitleField: NSTextField?

    override func close() {
        if !isVisible {
            controller?.tearDown()
        }
        super.close()
    }

    private enum SwipeState {
        case idle
        case tracking(isBack: Bool)
        case cancelled
    }

    private var swipeState: SwipeState = .idle
    private var swipeAccumulatorX: CGFloat = 0
    private var swipeTotalAbsY: CGFloat = 0
    private var swipeStartTime: TimeInterval = 0

    private static let commitThreshold: CGFloat = 100.0
    private static let flickVelocityThreshold: CGFloat = 500.0
    private static let activationThreshold: CGFloat = 15.0

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            if isKeyWindow && isPointInTitle(event.locationInWindow) {
                titleClickStartPoint = event.locationInWindow
            } else {
                titleClickStartPoint = nil
            }
        } else if event.type == .leftMouseDragged {
            if let start = titleClickStartPoint {
                let dx = event.locationInWindow.x - start.x
                let dy = event.locationInWindow.y - start.y
                if hypot(dx, dy) > 4.0 {
                    titleClickStartPoint = nil
                }
            }
        } else if event.type == .leftMouseUp {
            if let start = titleClickStartPoint {
                titleClickStartPoint = nil
                let dx = event.locationInWindow.x - start.x
                let dy = event.locationInWindow.y - start.y
                let isNormalClick = !event.modifierFlags.contains(.command) &&
                                    !event.modifierFlags.contains(.control) &&
                                    !event.modifierFlags.contains(.option)
                if hypot(dx, dy) <= 4.0 && event.clickCount == 1 && isNormalClick && isPointInTitle(event.locationInWindow) {
                    controller?.openFileDialog()
                    return
                }
            }
        }
        if event.type == .otherMouseDown || event.type == .otherMouseUp {
            if event.buttonNumber == 3 {
                if event.type == .otherMouseUp { controller?.goBack() }
                return
            } else if event.buttonNumber == 4 {
                if event.type == .otherMouseUp { controller?.goForward() }
                return
            }
        }
        if event.type == .keyDown && event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) && !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
            let isEditingText = firstResponder is NSTextView || firstResponder is NSTextField
            if !isEditingText {
                if event.keyCode == 123 { // Left Arrow
                    controller?.goBack()
                    return
                } else if event.keyCode == 124 { // Right Arrow
                    controller?.goForward()
                    return
                }
            }
        }
        if event.type == .scrollWheel {
            let isCmd = event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control)
            let mouseInWindow = event.locationInWindow

            if isCmd && (isZoomingWithScroll || (controller?.isPointInWebView(mouseInWindow) == true)) {
                if event.hasPreciseScrollingDeltas {
                    if event.phase == .began {
                        isZoomingWithScroll = true
                    }
                    if event.momentumPhase.isEmpty {
                        controller?.handleZoomScroll(with: event)
                    }
                    if event.phase == .ended || event.phase == .cancelled {
                        if event.momentumPhase.isEmpty {
                            isZoomingWithScroll = false
                        }
                    }
                    if event.momentumPhase == .ended || event.momentumPhase == .cancelled {
                        isZoomingWithScroll = false
                    }
                } else {
                    controller?.handleZoomScroll(with: event)
                }
                return
            } else if isZoomingWithScroll {
                if event.momentumPhase == .ended || event.momentumPhase == .cancelled || event.phase == .ended || event.phase == .cancelled {
                    isZoomingWithScroll = false
                }
                return
            }

            if event.hasPreciseScrollingDeltas {
                handleScrollWheelSwipe(event)
            }
        }
        if event.type == .magnify {
            super.sendEvent(event)
            controller?.syncLiveMagnification(ended: event.phase == .ended || event.phase == .cancelled)
            return
        }
        if event.type == .smartMagnify {
            super.sendEvent(event)
            controller?.handleSmartMagnifyAnimation()
            return
        }
        super.sendEvent(event)
    }

    func updateTitleToolTip() {
        if let tf = findTitleField() {
            tf.toolTip = "Click to open another file (⌘O)"
            tf.superview?.toolTip = "Click to open another file (⌘O)"
        }
    }

    func isPointInTitle(_ point: NSPoint) -> Bool {
        guard !title.isEmpty, let titleField = findTitleField() else { return false }
        let rectInWindow = titleField.convert(titleField.bounds, to: nil).insetBy(dx: -4, dy: -4)
        return rectInWindow.contains(point)
    }

    private func findTitleField() -> NSTextField? {
        if let cached = cachedTitleField, cached.window === self, cached.stringValue == title {
            return cached
        }
        guard let themeFrame = contentView?.superview else { return nil }
        let found = findTitleField(in: themeFrame, title: title)
        cachedTitleField = found
        if let found {
            found.toolTip = "Click to open another file (⌘O)"
            found.superview?.toolTip = "Click to open another file (⌘O)"
        }
        return found
    }

    private func findTitleField(in view: NSView, title: String) -> NSTextField? {
        if view === contentView { return nil }
        if let tf = view as? NSTextField, !tf.stringValue.isEmpty, tf.stringValue == title {
            return tf
        }
        for sub in view.subviews {
            if let found = findTitleField(in: sub, title: title) {
                return found
            }
        }
        return nil
    }

    private func handleScrollWheelSwipe(_ event: NSEvent) {
        guard event.momentumPhase.isEmpty else { return }

        let canBack = controller?.canGoBack ?? false
        let canForward = controller?.canGoForward ?? false
        if !canBack && !canForward {
            swipeState = .idle
            swipeAccumulatorX = 0
            swipeTotalAbsY = 0
            return
        }

        if (controller?.currentMagnificationLevel ?? 1.0) > 1.05 {
            swipeState = .idle
            swipeAccumulatorX = 0
            swipeTotalAbsY = 0
            return
        }

        let physicalDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        let physicalDeltaY = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY

        switch event.phase {
        case .began:
            swipeAccumulatorX = 0
            swipeTotalAbsY = 0
            swipeStartTime = event.timestamp
            swipeState = .idle

        case .changed:
            if case .cancelled = swipeState { return }

            swipeAccumulatorX += physicalDeltaX
            swipeTotalAbsY += abs(physicalDeltaY)

            if swipeTotalAbsY > 2.0 * abs(swipeAccumulatorX) && swipeTotalAbsY > 20.0 {
                swipeState = .cancelled
                return
            }
            if swipeTotalAbsY > 40.0 && abs(swipeAccumulatorX) < Self.activationThreshold {
                swipeState = .cancelled
                return
            }

            if case .idle = swipeState {
                if abs(swipeAccumulatorX) >= Self.activationThreshold {
                    let isBack = swipeAccumulatorX > 0
                    let canNavigate = isBack ? (controller?.canGoBack ?? false) : (controller?.canGoForward ?? false)
                    if canNavigate {
                        swipeState = .tracking(isBack: isBack)
                    } else {
                        swipeState = .cancelled
                    }
                }
            } else if case .tracking(let isBack) = swipeState {
                if isBack && swipeAccumulatorX < -Self.activationThreshold {
                    swipeState = .cancelled
                } else if !isBack && swipeAccumulatorX > Self.activationThreshold {
                    swipeState = .cancelled
                }
            }

        case .ended:
            if case .tracking(let isBack) = swipeState {
                let duration = max(0.01, event.timestamp - swipeStartTime)
                let distance = abs(swipeAccumulatorX)
                let velocity = distance / duration

                let reachedThreshold = distance >= Self.commitThreshold || (distance >= 70.0 && velocity >= Self.flickVelocityThreshold)
                let correctDirection = isBack ? (swipeAccumulatorX > 0) : (swipeAccumulatorX < 0)

                if reachedThreshold && correctDirection {
                    if isBack {
                        controller?.goBack()
                    } else {
                        controller?.goForward()
                    }
                }
            }
            swipeState = .idle
            swipeAccumulatorX = 0
            swipeTotalAbsY = 0

        case .cancelled:
            swipeState = .idle
            swipeAccumulatorX = 0
            swipeTotalAbsY = 0

        default:
            break
        }
    }

    override func swipe(with event: NSEvent) {
        if (controller?.currentMagnificationLevel ?? 1.0) > 1.05 {
            super.swipe(with: event)
            return
        }
        if event.deltaX > 0 {
            if controller?.canGoBack == true { controller?.goBack() }
        } else if event.deltaX < 0 {
            if controller?.canGoForward == true { controller?.goForward() }
        } else {
            super.swipe(with: event)
        }
    }
}

enum WebKitPrewarmer {
    private static var prewarmedView: WKWebView?

    static func prewarm() {
        guard prewarmedView == nil else { return }
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController = WKUserContentController()
        let prewarmed = WKWebView(frame: .zero, configuration: config)
        prewarmed.allowsMagnification = true
        prewarmed.loadHTMLString("", baseURL: nil)
        prewarmedView = prewarmed
    }

    static func takePrewarmedWebView() -> WKWebView? {
        defer {
            prewarmedView = nil
            DispatchQueue.main.async { prewarm() }
        }
        return prewarmedView
    }
}
