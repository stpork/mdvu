import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let arguments: [String]
    private var windows: [DocumentWindowController] = []
    private var documents: [String: DocumentWindowController] = [:]
    private let profiler = StartupProfiler()

    init(arguments: [String]) { self.arguments = arguments }

    func applicationWillFinishLaunching(_ notification: Notification) {
        profiler.mark("application.initialized")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("mdvu-renders-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDir)
        NSApp.mainMenu = AppMenu.make(target: self)
        WebKitPrewarmer.prewarm()
    }

    func applicationWillTerminate(_ notification: Notification) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("mdvu-renders-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDir)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let options = CLIOptions.parse(arguments)
        if options.paths.isEmpty {
            if windows.isEmpty { openPanel(nil) }
        } else {
            options.paths.forEach { open(URL(fileURLWithPath: $0).standardizedFileURL, options: options) }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let options = CLIOptions.parse(arguments)
        filenames.forEach { open(URL(fileURLWithPath: $0).standardizedFileURL, options: options) }
        sender.reply(toOpenOrPrint: .success)
    }

    @objc func openPanel(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown File or Folder"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.folder] + MarkdownDocument.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK { panel.urls.forEach { open($0, options: .default) } }
        else if windows.isEmpty { NSApp.terminate(nil) }
    }

    private func open(_ url: URL, options: CLIOptions) {
        let key = url.standardizedFileURL.path
        if let existing = documents[key] {
            existing.showWindow(nil); existing.window?.makeKeyAndOrderFront(nil); return
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            showError("File not found: \(url.path)"); return
        }
        let controller = DocumentWindowController(url: url, directoryMode: isDirectory.boolValue, options: options, profiler: profiler)
        controller.onOpenURL = { [weak self] target in self?.open(target, options: options) }
        controller.onDocumentChange = { [weak self, weak controller] newURL in
            guard let self, let controller else { return }
            self.documents = self.documents.filter { $0.value !== controller }
            self.documents[newURL.standardizedFileURL.path] = controller
        }
        controller.onClose = { [weak self, weak controller] in
            guard let self, let controller else { return }
            self.windows.removeAll { $0 === controller }
            self.documents = self.documents.filter { $0.value !== controller }
        }
        windows.append(controller)
        documents[key] = controller
        controller.showWindow(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert(); alert.messageText = "mdvu"; alert.informativeText = message; alert.runModal()
    }

    @MainActor @objc func showAboutPanel(_ sender: Any?) {
        AboutPanelController.shared.show()
    }
}

enum AppMenu {
    static func make(target: AppDelegate) -> NSMenu {
        let main = NSMenu()
        let app = NSMenuItem(); main.addItem(app)
        let appMenu = NSMenu(); app.submenu = appMenu
        let about = appMenu.addItem(withTitle: "About mdvu", action: #selector(AppDelegate.showAboutPanel(_:)), keyEquivalent: "")
        about.target = target
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit mdvu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let file = NSMenuItem(); main.addItem(file)
        let fileMenu = NSMenu(title: "File"); file.submenu = fileMenu
        let open = fileMenu.addItem(withTitle: "Open…", action: #selector(AppDelegate.openPanel(_:)), keyEquivalent: "o"); open.target = target
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let edit = NSMenuItem(); main.addItem(edit)
        let editMenu = NSMenu(title: "Edit"); edit.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Find…", action: #selector(DocumentWindowController.findText(_:)), keyEquivalent: "f")
        editMenu.addItem(withTitle: "Find Next", action: #selector(DocumentWindowController.findNextText(_:)), keyEquivalent: "g")
        let findPrev = editMenu.addItem(withTitle: "Find Previous", action: #selector(DocumentWindowController.findPreviousText(_:)), keyEquivalent: "g")
        findPrev.keyEquivalentModifierMask = [.command, .shift]

        let view = NSMenuItem(); main.addItem(view)
        let viewMenu = NSMenu(title: "View"); view.submenu = viewMenu
        viewMenu.addItem(withTitle: "Reload", action: #selector(DocumentWindowController.reload(_:)), keyEquivalent: "r")
        viewMenu.addItem(.separator())
        let contents = viewMenu.addItem(withTitle: "Hide Table of Contents", action: #selector(DocumentWindowController.toggleContents(_:)), keyEquivalent: "s")
        contents.keyEquivalentModifierMask = [.command, .control]
        let fullWidth = viewMenu.addItem(withTitle: "Full Width", action: #selector(DocumentWindowController.toggleFullWidth(_:)), keyEquivalent: "w")
        fullWidth.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(.separator())
        let dialectItem = NSMenuItem(title: "Dialect", action: nil, keyEquivalent: "")
        let dialectMenu = NSMenu(title: "Dialect")
        dialectItem.submenu = dialectMenu
        dialectMenu.addItem(withTitle: "Generic (CommonMark)", action: #selector(DocumentWindowController.selectDialectGeneric(_:)), keyEquivalent: "")
        dialectMenu.addItem(withTitle: "GitHub (GFM)", action: #selector(DocumentWindowController.selectDialectGitHub(_:)), keyEquivalent: "")
        dialectMenu.addItem(withTitle: "Obsidian", action: #selector(DocumentWindowController.selectDialectObsidian(_:)), keyEquivalent: "")
        viewMenu.addItem(dialectItem)
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(DocumentWindowController.zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(DocumentWindowController.zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(DocumentWindowController.resetZoom(_:)), keyEquivalent: "0")

        let go = NSMenuItem(); main.addItem(go)
        let goMenu = NSMenu(title: "Go"); go.submenu = goMenu
        goMenu.addItem(withTitle: "Back", action: #selector(DocumentWindowController.goBack(_:)), keyEquivalent: "[")
        goMenu.addItem(withTitle: "Forward", action: #selector(DocumentWindowController.goForward(_:)), keyEquivalent: "]")
        return main
    }
}
