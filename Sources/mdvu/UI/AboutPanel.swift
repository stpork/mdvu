import AppKit

final class AboutWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            close()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class AboutTextView: NSTextView {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
        guard let textStorage, let layoutManager, let textContainer else { return }
        textStorage.enumerateAttribute(.link, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, _ in
            if value != nil {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                layoutManager.enumerateEnclosingRects(
                    forGlyphRange: glyphRange,
                    withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                    in: textContainer
                ) { rect, _ in
                    self.addCursorRect(rect, cursor: .pointingHand)
                }
            }
        }
    }
}

@MainActor
final class AboutPanelController: NSObject, NSTextViewDelegate {
    static let shared = AboutPanelController()
    private(set) var window: AboutWindow?

    static func makeAttributedString(version: String) -> NSAttributedString {
        let mas = NSMutableAttributedString()

        // 1. mdvu (clickable -> repo)
        let repoURL = URL(string: "https://github.com/stpork/mdvu")!
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        titleStyle.paragraphSpacing = 4
        mas.append(NSAttributedString(string: "mdvu\n", attributes: [
            .font: NSFont.systemFont(ofSize: 26, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .link: repoURL,
            .paragraphStyle: titleStyle,
            .toolTip: "https://github.com/stpork/mdvu"
        ]))

        // 2. Markdown and Mermaid Viewer
        let subtitleStyle = NSMutableParagraphStyle()
        subtitleStyle.alignment = .center
        subtitleStyle.paragraphSpacing = 12
        mas.append(NSAttributedString(string: "Markdown and Mermaid Viewer\n", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: subtitleStyle
        ]))

        // 3. Version: 0.2.0 (clickable -> releases)
        let releaseURL = URL(string: "https://github.com/stpork/mdvu/releases/tag/v\(version)")!
        let versionStyle = NSMutableParagraphStyle()
        versionStyle.alignment = .center
        versionStyle.paragraphSpacing = 12
        mas.append(NSAttributedString(string: "Version: ", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .link: releaseURL,
            .paragraphStyle: versionStyle,
            .toolTip: "https://github.com/stpork/mdvu/releases/tag/v\(version)"
        ]))
        mas.append(NSAttributedString(string: "\(version)\n", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .link: releaseURL,
            .paragraphStyle: versionStyle,
            .toolTip: "https://github.com/stpork/mdvu/releases/tag/v\(version)"
        ]))

        // 4. Copyright © 2026 Finn de Bear (Finn de Bear clickable -> mailto)
        let emailURL = URL(string: "mailto:finndebear@gmail.com")!
        let copyStyle = NSMutableParagraphStyle()
        copyStyle.alignment = .center
        mas.append(NSAttributedString(string: "Copyright © 2026 ", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: copyStyle
        ]))
        mas.append(NSAttributedString(string: "Finn de Bear", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .link: emailURL,
            .paragraphStyle: copyStyle,
            .toolTip: "mailto:finndebear@gmail.com"
        ]))

        return mas
    }

    func show() {
        if let window {
            if !window.isVisible {
                window.center()
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = AboutWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.center()

        let content = NSView()
        win.contentView = content

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
        ])

        let iconImageView = NSImageView()
        let icon: NSImage = {
            if let path = Bundle.main.path(forResource: "mdvu", ofType: "icns"),
               let img = NSImage(contentsOfFile: path) {
                return img
            }
            let devPath = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // UI
                .deletingLastPathComponent() // mdvu
                .deletingLastPathComponent() // Sources
                .appendingPathComponent("packaging/mdvu.icns").path
            if let img = NSImage(contentsOfFile: devPath) {
                return img
            }
            if let img = NSImage(named: NSImage.applicationIconName) {
                return img
            }
            return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        }()
        iconImageView.image = icon
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 128),
            iconImageView.heightAnchor.constraint(equalToConstant: 128)
        ])
        stack.addArrangedSubview(iconImageView)
        stack.setCustomSpacing(16, after: iconImageView)

        let version: String = {
            if let str = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, !str.isEmpty {
                return str
            }
            let plistPath = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("packaging/Info.plist").path
            if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let str = plist["CFBundleShortVersionString"] as? String {
                return str
            }
            return "0.2.0"
        }()

        let mas = Self.makeAttributedString(version: version)

        let textContainer = NSTextContainer(containerSize: NSSize(width: 312, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage(attributedString: mas)
        textStorage.addLayoutManager(layoutManager)

        let textView = AboutTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.focusRingType = .none
        textView.delegate = self
        textView.linkTextAttributes = [
            .cursor: NSCursor.pointingHand
        ]
        textView.translatesAutoresizingMaskIntoConstraints = false

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        NSLayoutConstraint.activate([
            textView.widthAnchor.constraint(equalToConstant: 312),
            textView.heightAnchor.constraint(equalToConstant: ceil(usedRect.height) + 4)
        ])
        stack.addArrangedSubview(textView)

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = link as? URL {
            NSWorkspace.shared.open(url)
            return true
        } else if let str = link as? String, let url = URL(string: str) {
            NSWorkspace.shared.open(url)
            return true
        }
        return false
    }
}
