import AppKit

final class VaultItem: NSObject {
    let url: URL
    let name: String
    let isDirectory: Bool
    weak var parent: VaultItem?
    private(set) var children: [VaultItem]?

    init(url: URL, isDirectory: Bool, parent: VaultItem? = nil) {
        self.url = url
        self.name = url.lastPathComponent
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
        return url.standardizedFileURL == other.url.standardizedFileURL
    }

    override var hash: Int {
        url.standardizedFileURL.hashValue
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

    static func scanChildren(of parent: VaultItem) -> [VaultItem] {
        let dirURL = parent.url
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dirURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var dirs: [VaultItem] = []
        var files: [VaultItem] = []

        for url in entries {
            let name = url.lastPathComponent
            if ignoredDirectoryNames.contains(name) { continue }

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
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
    private let outline = VaultOutlineView()
    private let scrollView = NSScrollView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let iconImageView = NSImageView()

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

        // Header view
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 36).isActive = true

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        if let folderImg = NSImage(systemSymbolName: "folder", accessibilityDescription: nil) {
            iconImageView.image = folderImg
            iconImageView.contentTintColor = .secondaryLabelColor
        }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Navigator")
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeAction(_:))
        closeButton.toolTip = "Hide File Navigator (⌥⌘D)"

        header.addSubview(iconImageView)
        header.addSubview(titleLabel)
        header.addSubview(closeButton)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 10),
            iconImageView.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -6),

            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16)
        ])

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
        outline.action = #selector(outlineClicked(_:))
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

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func closeAction(_ sender: Any?) {
        onCloseRequested?()
    }

    func setRoot(documentURL: URL) {
        let vaultRoot = VaultScanner.findVaultRoot(for: documentURL)
        if let existing = rootItem, existing.url.standardizedFileURL == vaultRoot.standardizedFileURL {
            selectDocument(url: documentURL)
            return
        }

        let root = VaultItem(url: vaultRoot, isDirectory: true)
        self.rootItem = root
        titleLabel.stringValue = vaultRoot.lastPathComponent
        titleLabel.toolTip = vaultRoot.path

        outline.reloadData()
        selectDocument(url: documentURL)
    }

    func selectDocument(url: URL) {
        guard let root = rootItem else { return }
        guard let node = findOrCreateItem(for: url, in: root) else { return }

        isProgrammaticSelection = true
        defer { isProgrammaticSelection = false }

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
        let targetStandardized = targetURL.standardizedFileURL.path
        let currentStandardized = current.url.standardizedFileURL.path

        if currentStandardized == targetStandardized {
            return current
        }

        if current.isDirectory {
            current.loadChildrenIfNeeded()
            guard let children = current.children else { return nil }

            for child in children {
                let childPath = child.url.standardizedFileURL.path
                if child.isDirectory {
                    if targetStandardized.hasPrefix(childPath + "/") || targetStandardized == childPath {
                        if let found = findOrCreateItem(for: targetURL, in: child) {
                            return found
                        }
                    }
                } else if childPath == targetStandardized {
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
        return vaultItem.isDirectory
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
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

        cell.textField?.stringValue = vaultItem.name
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

    @objc private func outlineClicked(_ sender: Any?) {
        let row = outline.clickedRow
        guard row >= 0, let item = outline.item(atRow: row) as? VaultItem else { return }
        if !item.isDirectory {
            onFileSelected?(item.url)
        }
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
