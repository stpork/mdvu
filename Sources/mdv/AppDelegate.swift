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
        NSApp.mainMenu = AppMenu.make(target: self)
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
        panel.allowedContentTypes = [.folder] + ["md", "markdown", "mdown", "mkd"].compactMap { UTType(filenameExtension: $0) }
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
        controller.onClose = { [weak self, weak controller] in
            guard let self, let controller else { return }
            self.windows.removeAll { $0 === controller }
            self.documents.removeValue(forKey: key)
        }
        windows.append(controller)
        documents[key] = controller
        controller.showWindow(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert(); alert.messageText = "mdv"; alert.informativeText = message; alert.runModal()
    }
}

enum AppMenu {
    static func make(target: AppDelegate) -> NSMenu {
        let main = NSMenu()
        let app = NSMenuItem(); main.addItem(app)
        let appMenu = NSMenu(); app.submenu = appMenu
        appMenu.addItem(withTitle: "About mdv", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit mdv", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let file = NSMenuItem(); main.addItem(file)
        let fileMenu = NSMenu(title: "File"); file.submenu = fileMenu
        let open = fileMenu.addItem(withTitle: "Open…", action: #selector(AppDelegate.openPanel(_:)), keyEquivalent: "o"); open.target = target
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let edit = NSMenuItem(); main.addItem(edit)
        let editMenu = NSMenu(title: "Edit"); edit.submenu = editMenu
        editMenu.addItem(withTitle: "Find…", action: #selector(DocumentWindowController.findText(_:)), keyEquivalent: "f")

        let view = NSMenuItem(); main.addItem(view)
        let viewMenu = NSMenu(title: "View"); view.submenu = viewMenu
        viewMenu.addItem(withTitle: "Reload", action: #selector(DocumentWindowController.reload(_:)), keyEquivalent: "r")
        viewMenu.addItem(.separator())
        let fullWidth = viewMenu.addItem(withTitle: "Full Width", action: #selector(DocumentWindowController.toggleFullWidth(_:)), keyEquivalent: "w")
        fullWidth.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(DocumentWindowController.zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(DocumentWindowController.zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(DocumentWindowController.resetZoom(_:)), keyEquivalent: "0")
        return main
    }
}
