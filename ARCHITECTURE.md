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
 │  1. Dialect Preprocessing:                                  │
 │     • github: YAML front-matter conversion                  │
 │     • obsidian: Callouts ([!NOTE]), [[wikilinks]], ![[embed]]│
 │     • generic: Strict CommonMark compliance                 │
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
 │ Asynchronous Post-Render Phase (Decoupled & Lazy)           │
 │  • Evaluates pending diagrams on page:                      │
 │    - Mermaid 11.17.2 + ZenUML 0.2.3 (mermaid.lzma)          │
 │    - PlantUML 1.2026.7 + Viz.js 3.24.0 (plantuml.lzma)      │
 │  • On-Demand Decompression: 0 ms overhead if no diagrams    │
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
`mdvu` integrates a decoupled multi-engine diagram architecture supporting both Mermaid and PlantUML with complete offline isolation and zero external dependencies:

* **Engine Specifications & Versions**:
  * **Mermaid 11.17.2**:
    * **Standard Grammars**: `flowchart`, `sequenceDiagram`, `classDiagram`, `stateDiagram-v2`, `erDiagram`, `gitGraph`, `gantt`, `pie`, `mindmap`, `quadrantChart`, `requirementDiagram`, `C4Context`, `C4Component`.
    * **Extended Grammars**: `ishikawa-beta` (fishbone), `swimlane-beta` (swimlanes), `packet-beta`, `kanban`, `block-beta`, `architecture-beta`, `radar-beta`, `xychart-beta`.
  * **ZenUML Plugin 0.2.3** (`@mermaid-js/mermaid-zenuml`): Sequence diagrams embedded inside ````mermaid`` code blocks registered via `mermaid.registerExternalDiagrams`.
  * **PlantUML Core 1.2026.7** (`@plantuml/core`) + **Viz.js 3.24.0** (Graphviz 14.1.1):
    * 100% client-side WebAssembly / TeaVM execution. **Zero Java runtime (JVM/JRE) requirement.**
    * Supports code fences ````plantuml`` and ````puml``.
    * Renders sequence, class, state, activity, component, and use-case models.
    * Automatic dark mode adaptation (`skinparam backgroundColor transparent`).
* **LZMA Ultra Compression**:
  * Bundled assets are compressed using **LZMA Ultra** (`preset 9 | PRESET_EXTREME`, `nice=273`, `mf=bt4`, `dict=64MB`):
    * `mermaid.lzma`: **1.33 MB** (compresses 7.02 MB of raw minified JS).
    * `plantuml.lzma`: **1.20 MB** (compresses 5.02 MB of raw minified JS + WebAssembly Graphviz).
* **Decoupled Lazy Loading**:
  * Plain Markdown documents without diagrams incur **0% memory or startup overhead** (neither archive is read from disk).
  * Documents with only Mermaid diagrams decompress only `mermaid.lzma`.
  * Documents with only PlantUML diagrams decompress only `plantuml.lzma`.
* **SHA-256 SVG Disk Cache**:
  * All diagram SVGs are persisted to `~/Library/Caches/com.mdvu.viewer/diagrams/` keyed by `SHA256(renderer + version + source + theme)`.
  * Renders once asynchronously; subsequent views or window reloads display the cached SVG instantaneously without JavaScript engine evaluation.

---

## 3. Memory & Performance Optimizations

1. **Prewarmed WebKit**: `WebKitPrewarmer` initializes a lightweight background `WKWebView` during `applicationWillFinishLaunching`, shaving ~150 ms off initial document paint time.
2. **Cancellable Background Pipelines**: Parsing runs on a dedicated user-initiated `OperationQueue`. Quickly switching files in directory mode cancels in-flight operations immediately.
3. **Zero Reflection & Metadata**: Compiled with `-Osize -Xfrontend -disable-reflection-metadata -Xfrontend -disable-reflection-names`, stripping Swift metadata overhead.
4. **Stripped Binary**: Single-architecture Mach-O executable is **572 KB** (`strip -u -r`). The complete `.app` bundle is only **3.2 MB** (Universal bundle **4.2 MB**, compressed release archive **2.2 MB**).
5. **Lazy Client-Side Processing**: In-page syntax highlighting uses `IntersectionObserver` (800px margin) to stream code tokenization lazily without blocking initial display. Preprocessor directives (`#include`, `#define`) and C-style block comments are recognized cleanly without allocating intermediate token arrays. Heading anchors and TOC serialization are deduplicated to eliminate redundant WebKit IPC messages.
6. **Multi-Process Memory Isolation**: The host AppKit UI process maintains a lean ~35–45 MB footprint; the WebKit auxiliary web process (`com.apple.WebKit.WebContent`) isolates DOM state and garbage collection from the desktop application chrome.

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
