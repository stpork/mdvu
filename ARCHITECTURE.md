# Architecture of mdvu

`mdvu` is an ultra-lightweight, single-process macOS desktop application engineered for instantaneous startup, minimal memory footprint, and reference-grade Markdown rendering. It combines native **AppKit** window management with a hardware-accelerated **WKWebView** viewport and C-based **cmark-gfm** parsing.

---

## 1. System Pipeline Overview

```
 Markdown File (.md)
        │
        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ MarkdownPipeline (Background Queue)                         │
 │  1. Preprocessing: Fast regex-free scan for Obsidian        │
 │     callouts ([!NOTE], [!TIP]) and wikilinks ([[target]])   │
 │  2. Parsing: cmark-gfm in safe mode with pinned extensions  │
 │     (tables, task lists, autolinks, strikethrough)          │
 │  3. AST Extraction: Extracts H1-H6 metadata for native TOC  │
 │  4. HTML Assembly: HTMLDocument embeds inline CSS, prism    │
 │     tokens, and async diagram placeholders                  │
 └─────────────────────────────────────────────────────────────┘
        │
        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ AppKit & WebKit Integration (Main Thread)                   │
 │  • WKWebView renders HTML via loadHTMLString                │
 │  • Preserves user-defined targetMagnification across loads  │
 │  • Restores scroll position ratio asynchronously            │
 └─────────────────────────────────────────────────────────────┘
        │
        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ Asynchronous Post-Render Phase                              │
 │  • Mermaid.js (LZMA-compressed) initializes on demand       │
 │  • Renders SVG diagrams to SHA-256 disk cache               │
 │  • In-page find highlights matches & reports live counts    │
 └─────────────────────────────────────────────────────────────┘
```

---

## 2. Core Subsystems

### A. Document Window Controller (`DocumentWindowController`)
* **Window Lifecycle**: Manages `DocumentWindow`, toolbar items, TOC sidebar, file list table, and navigation history.
* **Persistent Window Zoom**:
  * Tracks user scale preference via `targetMagnification` (bounded between `0.10` [10%] and `5.00` [500%]).
  * Guards against WebKit's automatic internal viewport resets to `1.0` during `loadHTMLString`.
  * Restores `setMagnification` in `webView(_:didFinish:)` so Back, Forward, link clicks, and file edits never discard user zoom.
* **Titlebar File Open & Proxy Icon**:
  * Intercepts title text clicks to trigger `NSOpenPanel` as a sheet modal.
  * Preserves window dragging (4 pt drag threshold), macOS directory hierarchy popup (`⌘-click`), and file dragging via the document proxy icon.
  * Excludes `contentView` during title field lookup to prevent false matches against sidebar items.

### B. Event Interception & Gesture Routing (`DocumentWindow`)
* **Pinch-to-Zoom (`.magnify`)**: Intercepted in `sendEvent`, smoothly adjusting `targetMagnification` around the gesture center point and updating toolbar indicators on every frame.
* **Smart Magnify (`.smartMagnify`)**: Double-tap with two fingers toggles between 100% and 150% zoom.
* **Momentum Leak Protection**: Absorbs remaining momentum scroll events when `⌘` is released during zoom gestures, preventing unwanted document jumps.
* **Two-Finger Navigation vs. Zoom Conflict**:
  * When `!canGoBack && !canGoForward`, horizontal swipes are discarded without accumulating deltas or touching zoom.
  * When content is magnified (`> 105%`), horizontal trackpad swipes prioritize **content panning** over history navigation, enabling smooth reading of wide tables and diagrams.

### C. Standardized Zoom Controls (`ZoomPolicy` & `ZoomLevelTextField`)
* **Compound Toolbar Item**: `[-][ 100% ][+]` built as an `NSStackView` with `minus` button, editable text field, and `plus` button.
* **Stepping & Snapping**: Steps by 10% and snaps fractional pinch values to clean 10% multiples (e.g. `114%` $\to$ `120%` or `110%`).
* **Active Field Editor Sync**: Even if the cursor is focused inside `ZoomLevelTextField`, changing zoom level immediately updates the active `NSTextView` string and selection.
* **Double-Click Reset**: Double-clicking the field immediately resets zoom to `100%` (`⌘0`).

### D. File Watching (`FileWatcher`)
* Powered by `DispatchSourceFileSystemObject` watching the file descriptor for `.write`, `.delete`, `.rename`, and `.extend` events.
* Supports atomic saves (e.g. from Vim, Xcode, or VS Code where files are unlinked and replaced) by detecting inode transitions and re-registering the watch descriptor without interrupting user workflow.
* Reloads markdown asynchronously while preserving the user's relative vertical scroll ratio.

### E. Diagram Subsystem & Asset Compression
* **LZMA Compression**: The bundled `mermaid.min.js` (2.7 MB uncompressed) is compressed to 609 KB using LZMA (`mermaid.lzma`).
* **On-Demand Decompression**: Decompressed in memory only when a document containing an uncached diagram is viewed.
* **SHA-256 SVG Cache**: Diagram SVGs are stored under `~/Library/Caches/com.mdvu.viewer/diagrams` keyed by SHA-256 hash of `(source + theme)`.

---

## 3. Memory & Performance Optimizations

1. **Prewarmed WebKit**: `WebKitPrewarmer` initializes a lightweight background `WKWebView` during `applicationWillFinishLaunching`, shaving ~150 ms off initial document paint time.
2. **Cancellable Background Pipelines**: Parsing runs on a dedicated user-initiated `OperationQueue`. Quickly switching files in directory mode cancels in-flight operations immediately.
3. **Zero Reflection & Metadata**: Compiled with `-Osize -Xfrontend -disable-reflection-metadata -Xfrontend -disable-reflection-names`, stripping Swift metadata overhead.
4. **Stripped Binary**: Universal binary is stripped using `strip -u -r`, keeping the final `.app` under **1.8 MB** (single-architecture slice under **1.2 MB**, compressed zip **1.1 MB**).

---

## 4. Release Automation & Distribution Architecture

```
develop branch                                              main branch
     │                                                           │
     ▼                                                           ▼
[make test] ───────────────────────────────────────────► [Merge --no-ff]
     │                                                           │
     ▼                                                           ▼
[make archive]                                              [Git Tag vX.Y.Z]
  ├─ arm64 zip + sha256                                          │
  ├─ x86_64 zip + sha256                                         ▼
  ├─ universal zip + sha256                                [Push to Remote]
  ├─ universal dmg + sha256                                https://github.com/stpork/mdvu
  └─ Casks/mdvu.rb                                               │
                                                                 ▼
                                                           [GitHub Release]
                                                           Upload 4 bundles + checksums
                                                                 │
                                                                 ▼
                                                           [Homebrew Tap Sync]
                                                           Update stpork/homebrew-tap
                                                                 │
                                                                 ▼
[Bump Y-Counter: X.(Y+1).0] ◄────────────────────────────────────┘
Commit & Push to develop
```

* **Single Source of Truth (`version.txt`)**: Strict semantic versioning (`X.Y.Z`). `package-release.sh` synchronizes `version.txt` with `packaging/Info.plist`.
* **Two-Stage Publication (`./build.sh publish [-y|--yes]`)**:
  * Default invocation runs a non-destructive **Dry Run**: compiles and validates all 4 slices/bundles and checks release notes from `CHANGELOG.md` without pushing remote commits or uploading assets.
  * `-y` / `--yes` flag initiates the complete live release lifecycle, pushing to `stpork/mdvu`, creating the GitHub Release, and publishing to `stpork/homebrew-tap`.
* **Isolated `main` Branch**: The `main` branch contains only clean, tagged release commits. All active development occurs on `develop`. Following a release, `publish-release.sh` switches back to `develop`, automatically increments the `Y` counter (`0.2.0` $\to$ `0.3.0`), and pushes the bump commit.
* **Native About Panel**: Integrated via `AppDelegate.showAboutPanel(_:)` providing dynamic version reporting from bundle metadata, author credits (Finn de Bear), and direct link routing to the source repository.
