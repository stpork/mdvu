import AppKit

enum SidebarHeader {
    @MainActor static func make(title: NSTextField, symbol: String, target: AnyObject,
                                action: Selector, help: String) -> NSView {
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabelColor
        title.lineBreakMode = .byTruncatingTail
        let close = NSButton()
        close.translatesAutoresizingMaskIntoConstraints = false
        close.bezelStyle = .inline
        close.isBordered = false
        close.focusRingType = .none
        close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: help)
        close.contentTintColor = .secondaryLabelColor
        close.target = target
        close.action = action
        close.toolTip = help
        for view in [icon, title, close] { header.addSubview(view) }
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 36),
            icon.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            title.trailingAnchor.constraint(lessThanOrEqualTo: close.leadingAnchor, constant: -6),
            close.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -8),
            close.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 16),
            close.heightAnchor.constraint(equalToConstant: 16)
        ])
        return header
    }
}

final class VaultItem: NSObject {
    let url: URL
    let name: String
    let isDirectory: Bool
    weak var parent: VaultItem?
    private(set) var children: [VaultItem]?

    init(url: URL, isDirectory: Bool, parent: VaultItem? = nil) {
        let std = url.standardizedFileURL
        self.url = std
        self.name = std.lastPathComponent
        self.isDirectory = isDirectory
        self.parent = parent
        super.init()
    }

    func loadChildrenIfNeeded() {
        guard isDirectory, children == nil else { return }
        children = VaultScanner.scanChildren(of: self)
    }

    func invalidate() {
        children = nil
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? VaultItem else { return false }
        return url == other.url
    }

    override var hash: Int {
        url.hashValue
    }
}

enum VaultScanner {
    static let ignoredDirectoryNames: Set<String> = [
        ".git", ".obsidian", ".trash", "node_modules", ".build",
        "Pods", "vendor", "target", "dist", ".cache", ".DS_Store"
    ]

    static func findVaultRoot(for url: URL) -> URL {
        let initialDir: URL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            initialDir = url
        } else {
            initialDir = url.deletingLastPathComponent()
        }

        var current = initialDir
        var depth = 0
        while depth < 20 {
            let obsidianMarker = current.appendingPathComponent(".obsidian")
            let gitMarker = current.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: obsidianMarker.path) ||
               FileManager.default.fileExists(atPath: gitMarker.path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path || current.path == "/" {
                break
            }
            current = parent
            depth += 1
        }
        return initialDir
    }

    static func isSupported(url: URL) -> Bool {
        MarkdownDocument.isMarkdown(url: url)
    }

    static func scanFiles(in directory: URL, isCancelled: () -> Bool = { false }) -> [URL] {
        var files: [URL] = []
        if let iterator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let url as URL in iterator {
                if isCancelled() { return [] }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if values?.isDirectory == true {
                    if ignoredDirectoryNames.contains(url.lastPathComponent) || values?.isSymbolicLink == true {
                        iterator.skipDescendants()
                    }
                } else if isSupported(url: url) {
                    files.append(url.standardizedFileURL)
                    if files.count == 5000 { break }
                }
            }
        }
        files.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        return files
    }

    static func scanChildren(of parent: VaultItem) -> [VaultItem] {
        let dirURL = parent.url
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dirURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var dirs: [VaultItem] = []
        var files: [VaultItem] = []

        for url in entries {
            let name = url.lastPathComponent
            if ignoredDirectoryNames.contains(name) { continue }

            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey])
            if resourceValues?.isPackage == true { continue }
            let isDir: Bool
            if let isDirectory = resourceValues?.isDirectory {
                isDir = isDirectory
            } else {
                var isDirObjC: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirObjC) else { continue }
                isDir = isDirObjC.boolValue
            }

            if isDir {
                if resourceValues?.isSymbolicLink == true { continue }
                dirs.append(VaultItem(url: url, isDirectory: true, parent: parent))
            } else if isSupported(url: url) {
                files.append(VaultItem(url: url, isDirectory: false, parent: parent))
            }
        }

        dirs.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return dirs + files
    }
}

final class VaultOutlineView: NSOutlineView {
    var onReturnOrEnter: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { // Return or Enter
            onReturnOrEnter?()
            return
        }
        super.keyDown(with: event)
    }
}

final class VaultNavigatorView: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate {
    enum Mode: Int { case tree, list }
    private(set) var mode: Mode = .tree
    private static let scanQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 2
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private var scanOperation: Operation?
    private var flatItems: [VaultItem] = []
    private var selectedURL: URL?
    private var explicitRoot: URL?
    private var openingDirectory = false
    private let modeControl = NSSegmentedControl(labels: ["Tree", "List"], trackingMode: .selectOne, target: nil, action: nil)
    private let outline = VaultOutlineView()
    private let scrollView = NSScrollView()
    private let titleLabel = NSTextField(labelWithString: "")

    private(set) var rootItem: VaultItem?
    private var isProgrammaticSelection = false

    var onFileSelected: ((URL) -> Void)?
    var onCloseRequested: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        autoresizingMask = [.width, .height]

        let header = SidebarHeader.make(title: titleLabel, symbol: "folder", target: self,
                                        action: #selector(closeAction(_:)), help: "Hide File Navigator (⌥⌘D)")

        // Outline view
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("vaultColumn"))
        column.title = "Files"
        column.resizingMask = .autoresizingMask
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.delegate = self
        outline.dataSource = self
        outline.rowHeight = 24
        outline.indentationPerLevel = 14
        outline.allowsMultipleSelection = false
        outline.focusRingType = .none
        outline.autoresizesOutlineColumn = true
        outline.autoresizingMask = [.width, .height]
        outline.target = self
        outline.doubleAction = #selector(outlineDoubleClicked(_:))

        outline.onReturnOrEnter = { [weak self] in
            self?.openCurrentSelection()
        }

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = outline
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        addSubview(header)
        addSubview(scrollView)
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.controlSize = .small
        modeControl.selectedSegment = mode.rawValue
        modeControl.target = self
        modeControl.action = #selector(changeMode(_:))
        modeControl.setAccessibilityLabel("File navigator view")
        addSubview(modeControl)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),

            modeControl.topAnchor.constraint(equalTo: header.bottomAnchor),
            modeControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            modeControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func closeAction(_ sender: Any?) {
        onCloseRequested?()
    }

    deinit { scanOperation?.cancel() }

    @objc private func changeMode(_ sender: NSSegmentedControl) {
        setMode(Mode(rawValue: sender.selectedSegment) ?? .tree)
    }

    func setMode(_ newMode: Mode) {
        guard mode != newMode else { return }
        mode = newMode
        modeControl.selectedSegment = mode.rawValue
        flatItems = []
        rootItem?.invalidate()
        reloadOutline()
        if mode == .list { startScan() }
        else {
            if !openingDirectory { scanOperation?.cancel(); scanOperation = nil }
            if let selectedURL { selectDocument(url: selectedURL) }
        }
    }

    private func reloadOutline() {
        isProgrammaticSelection = true
        outline.reloadData()
        isProgrammaticSelection = false
    }

    private func replaceRoot(_ url: URL) {
        scanOperation?.cancel()
        scanOperation = nil
        openingDirectory = false
        flatItems = []
        rootItem = VaultItem(url: url, isDirectory: true)
        titleLabel.stringValue = url.lastPathComponent
        titleLabel.toolTip = url.path
        reloadOutline()
    }

    func openDirectory(_ url: URL, completion: @escaping (URL?) -> Void) {
        explicitRoot = url.standardizedFileURL
        selectedURL = nil
        mode = .list
        modeControl.selectedSegment = mode.rawValue
        replaceRoot(url)
        startScan(firstFile: completion)
    }

    private func startScan(firstFile: ((URL?) -> Void)? = nil) {
        guard scanOperation == nil, let directory = rootItem?.url else { return }
        let operation = BlockOperation()
        openingDirectory = firstFile != nil
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            let files = autoreleasepool { VaultScanner.scanFiles(in: directory, isCancelled: { operation.isCancelled }) }
            guard !operation.isCancelled else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, !operation.isCancelled else { return }
                self.scanOperation = nil
                self.openingDirectory = false
                if self.mode == .list {
                    self.flatItems = files.map { VaultItem(url: $0, isDirectory: false) }
                    self.reloadOutline()
                    if let selectedURL = self.selectedURL { self.selectDocument(url: selectedURL) }
                }
                firstFile?(files.first)
            }
        }
        scanOperation = operation
        Self.scanQueue.addOperation(operation)
    }

    func setRoot(documentURL: URL) {
        if openingDirectory {
            scanOperation?.cancel()
            scanOperation = nil
            openingDirectory = false
            if mode == .list { startScan() }
        }
        let documentURL = documentURL.standardizedFileURL
        let vaultRoot: URL
        if let explicitRoot, documentURL.path.hasPrefix(explicitRoot.path + "/") {
            vaultRoot = explicitRoot
        } else {
            explicitRoot = nil
            vaultRoot = VaultScanner.findVaultRoot(for: documentURL)
        }
        if rootItem?.url != vaultRoot.standardizedFileURL {
            replaceRoot(vaultRoot)
            if mode == .list { startScan() }
        }
        selectDocument(url: documentURL)
    }

    func selectDocument(url: URL) {
        selectedURL = url.standardizedFileURL
        guard let root = rootItem else { return }
        isProgrammaticSelection = true
        defer { isProgrammaticSelection = false }
        let node = mode == .list
            ? flatItems.first(where: { $0.url == selectedURL })
            : findOrCreateItem(for: url, in: root)
        guard let node else {
            outline.deselectAll(nil)
            return
        }

        // Expand all ancestors
        var ancestors: [VaultItem] = []
        var curr = node.parent
        while let a = curr, a !== root {
            ancestors.append(a)
            curr = a.parent
        }
        for a in ancestors.reversed() {
            outline.expandItem(a)
        }

        let row = outline.row(forItem: node)
        if row >= 0 {
            outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outline.scrollRowToVisible(row)
        }
    }

    private func findOrCreateItem(for targetURL: URL, in current: VaultItem) -> VaultItem? {
        let targetPath = targetURL.standardizedFileURL.path
        let currentPath = current.url.path

        if currentPath == targetPath {
            return current
        }

        if current.isDirectory {
            current.loadChildrenIfNeeded()
            guard let children = current.children else { return nil }

            for child in children {
                let childPath = child.url.path
                if child.isDirectory {
                    if targetPath.hasPrefix(childPath + "/") || targetPath == childPath {
                        if let found = findOrCreateItem(for: targetURL, in: child) {
                            return found
                        }
                    }
                } else if childPath == targetPath {
                    return child
                }
            }
        }
        return nil
    }

    private func openCurrentSelection() {
        let row = outline.selectedRow
        guard row >= 0, let item = outline.item(atRow: row) as? VaultItem else { return }
        if item.isDirectory {
            if outline.isItemExpanded(item) {
                outline.collapseItem(item)
            } else {
                outline.expandItem(item)
            }
        } else {
            onFileSelected?(item.url)
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if mode == .list { return item == nil ? flatItems.count : 0 }
        if item == nil {
            guard let root = rootItem else { return 0 }
            root.loadChildrenIfNeeded()
            return root.children?.count ?? 0
        }
        guard let vaultItem = item as? VaultItem, vaultItem.isDirectory else { return 0 }
        vaultItem.loadChildrenIfNeeded()
        return vaultItem.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let vaultItem = item as? VaultItem else { return false }
        return mode == .tree && vaultItem.isDirectory
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if mode == .list { return flatItems[index] }
        let parent = (item as? VaultItem) ?? rootItem
        parent?.loadChildrenIfNeeded()
        guard let children = parent?.children, index < children.count else {
            fatalError("Index \(index) out of bounds")
        }
        return children[index]
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let vaultItem = item as? VaultItem else { return nil }
        let id = NSUserInterfaceItemIdentifier("vaultCell")
        let cell = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView ?? NSTableCellView()

        if cell.textField == nil {
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown
            cell.addSubview(imageView)
            cell.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = .systemFont(ofSize: 12)
            textField.lineBreakMode = .byTruncatingTail
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            cell.identifier = id
        }

        cell.textField?.lineBreakMode = mode == .list ? .byTruncatingMiddle : .byTruncatingTail
        cell.textField?.stringValue = mode == .list
            ? String(vaultItem.url.path.dropFirst((rootItem?.url.path.count ?? 0) + 1))
            : vaultItem.name
        cell.toolTip = vaultItem.url.path

        if vaultItem.isDirectory {
            if let folderImg = NSImage(systemSymbolName: "folder", accessibilityDescription: "Folder") {
                cell.imageView?.image = folderImg
                cell.imageView?.contentTintColor = .secondaryLabelColor
            } else {
                cell.imageView?.image = NSWorkspace.shared.icon(forFile: vaultItem.url.path)
            }
        } else {
            if let docImg = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Markdown") {
                cell.imageView?.image = docImg
                cell.imageView?.contentTintColor = .secondaryLabelColor
            } else {
                cell.imageView?.image = NSWorkspace.shared.icon(forFile: vaultItem.url.path)
            }
        }

        return cell
    }

    @objc private func outlineDoubleClicked(_ sender: Any?) {
        let row = outline.clickedRow
        guard row >= 0, let item = outline.item(atRow: row) as? VaultItem else { return }
        if item.isDirectory {
            if outline.isItemExpanded(item) {
                outline.collapseItem(item)
            } else {
                outline.expandItem(item)
            }
        }
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isProgrammaticSelection else { return }
        let row = outline.selectedRow
        guard row >= 0, let item = outline.item(atRow: row) as? VaultItem else { return }

        if !item.isDirectory {
            onFileSelected?(item.url)
        }
    }
}
