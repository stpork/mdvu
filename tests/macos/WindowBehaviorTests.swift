import AppKit
import Testing
@testable import mdvu

@MainActor
struct WindowBehaviorTests {
    @Test func filenameOpenWaitsForTheDoubleClickInterval() async throws {
        let pending = DelayedTitlebarOpen(interval: 0.03)
        var opened = false
        pending.schedule { opened = true }
        #expect(!opened)
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(opened)
    }

    @Test func secondClickCancelsThePendingFileDialog() async throws {
        let pending = DelayedTitlebarOpen(interval: 0.03)
        var openCount = 0
        pending.schedule { openCount += 1 }
        pending.cancel()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(openCount == 0)
    }

    private func makeWindow() -> DocumentWindow {
        _ = NSApplication.shared
        let window = DocumentWindow(contentRect: NSRect(x: 100, y: 100, width: 820, height: 560),
                                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                    backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unifiedCompact
        window.toolbar = NSToolbar(identifier: UUID().uuidString)
        return window
    }

    @Test func restoredExpandedWindowKeepsItsNormalFrame() {
        let name = "mdvu.test.window." + UUID().uuidString
        defer {
            NSWindow.removeFrame(usingName: name)
            NSWindow.removeFrame(usingName: name + ".unzoomed")
        }
        let original = makeWindow()
        let normal = original.frame
        WindowFramePersistence.saveUserFrameBeforeZoom(original, usingName: name)
        original.zoom(nil)
        #expect(original.frame != normal)
        original.saveFrame(usingName: name)
        original.close()

        let restored = makeWindow()
        defer { restored.close() }
        #expect(WindowFramePersistence.restore(restored, usingName: name))
        let expanded = restored.frame
        for _ in 0..<3 {
            restored.zoom(nil)
            #expect(restored.frame == normal)
            restored.zoom(nil)
            #expect(restored.frame == expanded)
        }
    }

    @Test func legacyExpandedFrameGetsANativeRestoreState() {
        let name = "mdvu.test.window." + UUID().uuidString
        defer {
            NSWindow.removeFrame(usingName: name)
            NSWindow.removeFrame(usingName: name + ".unzoomed")
        }
        let original = makeWindow()
        original.zoom(nil)
        original.saveFrame(usingName: name)
        original.close()

        let restored = makeWindow()
        defer { restored.close() }
        #expect(WindowFramePersistence.restore(restored, usingName: name))
        let expanded = restored.frame
        restored.zoom(nil)
        let normal = restored.frame
        #expect(normal != expanded)
        #expect(!restored.isZoomed)
        restored.zoom(nil)
        #expect(restored.frame == expanded)
        restored.zoom(nil)
        #expect(restored.frame == normal)
    }

    @Test func firstPresentationPreservesTheRestoredZoomUserState() throws {
        let name = "mdvu.test.window." + UUID().uuidString
        defer {
            NSWindow.removeFrame(usingName: name)
            NSWindow.removeFrame(usingName: name + ".unzoomed")
        }
        let original = makeWindow()
        let normal = original.frame
        WindowFramePersistence.saveUserFrameBeforeZoom(original, usingName: name)
        original.zoom(nil)
        original.saveFrame(usingName: name)
        original.close()

        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("fixtures/test-onescreen.md")
        let controller = DocumentWindowController(url: file, directoryMode: false, options: .default, profiler: StartupProfiler(), frameAutosaveName: name)
        defer { controller.window?.setFrameAutosaveName(""); controller.close() }
        controller.showWindow(nil)
        let window = try #require(controller.window)
        let expanded = window.frame
        for _ in 0..<3 {
            window.zoom(nil)
            #expect(window.frame == normal)
            window.zoom(nil)
            #expect(window.frame == expanded)
        }
    }

    @Test func standardWindowCommandsUseAppKitActions() throws {
        _ = NSApplication.shared
        let previousWindowsMenu = NSApp.windowsMenu
        let previousServicesMenu = NSApp.servicesMenu
        defer { NSApp.windowsMenu = previousWindowsMenu; NSApp.servicesMenu = previousServicesMenu }
        let menu = AppMenu.make(target: AppDelegate(arguments: []))
        let windowMenu = try #require(menu.items.compactMap(\.submenu).first { $0.title == "Window" })
        #expect(NSApp.windowsMenu === windowMenu)
        let minimize = try #require(windowMenu.items.first { $0.action == #selector(NSWindow.performMiniaturize(_:)) })
        #expect(minimize.keyEquivalent == "m")
        #expect(minimize.keyEquivalentModifierMask == .command)
        #expect(windowMenu.items.contains { $0.action == #selector(NSWindow.performZoom(_:)) && $0.target == nil })
        let view = try #require(menu.items.compactMap(\.submenu).first { $0.title == "View" })
        let fullscreen = try #require(view.items.first { $0.action == #selector(NSWindow.toggleFullScreen(_:)) })
        #expect(fullscreen.keyEquivalent == "f")
        #expect(fullscreen.keyEquivalentModifierMask == [.command, .control])
        let app = try #require(menu.items.first?.submenu)
        #expect(app.items.contains { $0.action == #selector(NSApplication.hide(_:)) && $0.keyEquivalent == "h" })
    }

    @Test func showingAnExistingWindowPreservesItsPosition() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("fixtures/test-onescreen.md")
        let controller = DocumentWindowController(url: file, directoryMode: false, options: .default, profiler: StartupProfiler(), frameAutosaveName: "mdvu.test.window." + UUID().uuidString)
        defer { controller.close() }
        let window = try #require(controller.window)
        // Keep this test's frame out of the user's saved placement.
        window.setFrameAutosaveName("")
        controller.showWindow(nil)
        window.setFrameOrigin(NSPoint(x: window.frame.minX + 25, y: window.frame.minY + 25))
        let movedFrame = window.frame
        controller.showWindow(nil)
        #expect(window.frame == movedFrame)
        #expect(window.styleMask.contains([.titled, .closable, .miniaturizable, .resizable]))
        #expect(window.contentMinSize == NSSize(width: 460, height: 360))
    }

}
