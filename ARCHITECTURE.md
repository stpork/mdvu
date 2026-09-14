# Architecture of mdvu

`mdvu` is an ultra-lightweight, single-process macOS desktop application engineered for instantaneous startup, minimal memory footprint, and reference-grade Markdown rendering. It combines native **AppKit** window management with a hardware-accelerated **WKWebView** viewport and C-based **cmark-gfm** parsing.

---

## 1. System Pipeline Overview

```
 Markdown File (.md)
        │
        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ MarkdownPipeline (Background Queue / Eager Loader)          │
 │  1. FastScan: Hardware-vectorized byte scanning (memchr,    │
 │     memmem) pre-checks extensions at gigabytes/sec          │
 │  2. CodeFenceScanner: Streaming zero-allocation cursor      │
 │     isolates code fences (```, ~~~) from transformations    │
 │  3. Dialect Preprocessing Pipeline:                         │
 │     • FrontMatterExtension: YAML metadata table conversion  │
 │     • GitLabTOCExtension: [[_TOC_]] & [TOC] placeholders    │
 │     • AdmonitionExtension: MkDocs (!!!, ???) & Docusaurus/  │
 │       VuePress (:::note) mapped cleanly to native callouts  │
 │     • ObsidianExtension: Callouts ([!NOTE]), [[wikilinks]], │
 │       and media embeds (![[image.png]])                     │
 │     • CriticMarkupExtension: {++add++}, {--del--},          │
 │       {~~old~>new~~}, {==mark==}, and {>>comment<<}         │
 │     • SubSuperscriptExtension: ~sub~, ^sup^, ^^underline^^  │
 │       (strictly preserving GFM ~~strikethrough~~)           │
 │     • MathExtension: Linear O(N) scanner for $inline$ and   │
 │       $$display$$ math skipping backticks and escapes       │
 │  4. Parsing: cmark-gfm AST parsing with extensions:         │
 │     tables, task lists, autolinks, footnotes, strikethrough │
 │     and tagfilter XSS prevention                            │
 │  5. AST Extraction: Extracts H1-H6 metadata for native TOC  │
 │  6. HTML Assembly: HTMLDocument embeds inline CSS, prism    │
 │     tokens, and async diagram placeholders                  │
 └─────────────────────────────────────────────────────────────┘
        │
        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ AppKit & WebKit Integration (Main Thread)                   │
 │  • 3-Pane Split View: TOC (left), WKWebView, Vault (right)  │
 │  • WKWebView renders HTML via loadHTMLString                │
 │  • 120 FPS CoreAnimation GPU-layer zoom scaling             │
 │  • Preserves user-defined targetMagnification across loads  │
 │  • Restores scroll position ratio asynchronously            │
 └─────────────────────────────────────────────────────────────┘
        │
        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ Asynchronous Post-Render Phase (Decoupled & Lazy)           │
 │  • Evaluates pending diagrams & math on page:               │
 │    - Mermaid 11.17.2 + ZenUML 0.2.3 (mermaid.lzma)          │
 │    - PlantUML 1.2026.7 + Viz.js 3.24.0 (plantuml.lzma)      │
 │    - KaTeX MathML Engine (katex.lzma, 64 KB)                │
 │  • Frame-Budgeted Rendering: Yields every 16 ms to prevent  │
 │    main-thread stalls on 300+ diagram documents             │
 │  • Auto-Quoting Resilience for requirementDiagram           │
 │  • On-Demand Decompression: 0 ms overhead if no assets used │
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
  * Restores magnification in `webView(_:didFinish:)` so Back, Forward, link clicks, and file edits never discard user zoom.
* **Titlebar File Open & Proxy Icon**:
  * Intercepts title text clicks to trigger `NSOpenPanel` as a sheet modal.
  * Preserves window dragging (4 pt drag threshold), macOS directory hierarchy popup (`⌘-click`), and file dragging via the document proxy icon.
  * Excludes `contentView` during title field lookup to prevent false matches against sidebar items.

### B. Event Interception & Gesture Routing (`DocumentWindow`)
* **Pinch-to-Zoom (`.magnify`)**: Delivered directly via `super.sendEvent` to WebKit for zero-latency 60–120 FPS GPU CoreAnimation layer magnification, with toolbar percentage synced live on every gesture event.
* **Smart Magnify (`.smartMagnify`)**: Double-tap with two fingers toggles smoothly between 100% and 150% zoom.
* **Momentum Leak Protection**: Absorbs remaining momentum scroll events when `⌘` is released during zoom gestures, preventing unwanted document jumps.
* **Two-Finger Navigation vs. Zoom Conflict**:
  * When `!canGoBack && !canGoForward`, horizontal swipes are discarded without accumulating deltas or touching zoom.
  * When content is magnified (`> 105%`), horizontal trackpad swipes prioritize **content panning** over history navigation, enabling smooth reading of wide tables and diagrams.

### C. Standardized Zoom Controls (`ZoomPolicy` & `ZoomLevelTextField`)
* **Compound Toolbar Item**: `[-][ 100% ][+]` built as an `NSStackView` with `minus` button, editable text field, and `plus` button.
* **Magnetic Snapping ($\pm 2.5\%$)**: Micro-gestures within $\pm 2.5\%$ of clean 10% multiples (100%, 150%, 200%, 300%) snap cleanly to round numbers, eliminating jitter and phantom presentation artifacts like `201%` or `101%`.
* **Bounce-Back Settling Engine**: Rapid pinch-out gestures that bounce back against WebKit's viewport boundaries settle at exact `1.0` (`100%`) via trailing spring timers (50 ms, 150 ms, 300 ms).
* **Stepping & Snapping**: Buttons and `⌘+` / `⌘-` step by 10% and snap to clean 10% multiples.
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
    * **Standard Grammars**: `flowchart`, `sequenceDiagram`, `classDiagram`, `stateDiagram-v2`, `erDiagram`, `gitGraph`, `gantt`, `pie`, `mindmap`, `quadrantChart`, `requirementDiagram`, `C4Context`, `C4Container`, `C4Component`, `C4Dynamic`, `C4Deployment`.
    * **Extended Grammars**: `ishikawa-beta` (fishbone), `swimlane-beta` (swimlanes), `packet-beta`, `kanban`, `block-beta`, `architecture-beta`, `radar-beta`, `xychart-beta`.
  * **ZenUML Plugin 0.2.3** (`@mermaid-js/mermaid-zenuml`): Sequence diagrams embedded inside ````mermaid`` code blocks registered via `mermaid.registerExternalDiagrams`.
  * **PlantUML Core 1.2026.7** (`@plantuml/core`) + **Viz.js 3.24.0** (Graphviz 14.1.1):
    * 100% client-side WebAssembly / TeaVM execution. **Zero Java runtime (JVM/JRE) requirement.**
    * Supports code fences ````plantuml`` and ````puml``.
    * Renders sequence, class, state, activity, component, object, deployment, and use-case models, plus JSON/YAML trees, Salt wireframes, and network diagrams.
    * Automatic dark mode adaptation (`skinparam backgroundColor transparent`).
* **Frame-Budgeted Batch Rendering**:
  * JavaScript diagram dispatcher tracks frame execution time (`performance.now()`) and yields via `requestAnimationFrame` whenever a 16 ms budget is exceeded. This allows micro-diagrams to batch render at 30+ diagrams per frame while preventing main-thread lockups on heavy documents.
* **Grammar Preprocessing Resilience**:
  * Custom grammar cleaner automatically fixes common parser traps (e.g. auto-quoting unquoted identifiers with hyphens in Mermaid `requirementDiagram`).
* **LZMA Ultra Compression**:
  * Bundled assets are compressed using **LZMA Ultra** (`preset 9 | PRESET_EXTREME`, `nice=273`, `mf=bt4`, `dict=64MB`):
    * `mermaid.lzma`: **1.33 MB** (compresses 7.02 MB of raw minified JS).
    * `plantuml.lzma`: **1.20 MB** (compresses 5.02 MB of raw minified JS + WebAssembly Graphviz).
    * `katex.lzma`: **64 KB** (compresses 276 KB of raw minified KaTeX engine).
* **Decoupled Lazy Loading**:
  * Plain Markdown documents without diagrams or formulas incur **0% memory or startup overhead** (no archives are read from disk).
  * Documents with only Mermaid diagrams decompress only `mermaid.lzma`.
  * Documents with only PlantUML diagrams decompress only `plantuml.lzma`.
  * Documents with only Math formulas decompress only `katex.lzma`.
* **Native WebKit MathML Rendering**:
  * Formulas are translated via KaTeX to standard MathML Core, allowing macOS WebKit to render them natively with system math typography, crisp Retina scaling, dark/light theme adaptation, and screen-reader accessibility.
* **SHA-256 SVG Disk Cache**:
  * All diagram SVGs are persisted to `~/Library/Caches/com.mdvu.viewer/diagrams/` keyed by `SHA256(renderer + version + source + theme)`.
  * Renders once asynchronously; subsequent views or window reloads display the cached SVG instantaneously without JavaScript engine evaluation.

### F. File & Vault Navigator Subsystem (`VaultScanner`, `VaultItem`, `VaultOutlineView`)
* **Heuristic Vault Root Discovery (`VaultScanner.findVaultRoot`)**:
  * Traverses directory ancestors up to 20 levels deep searching for knowledge vault or project root markers (`.obsidian` or `.git`).
  * Seamlessly anchors root to the workspace or knowledge repository while falling back to the document's immediate directory if no marker exists.
* **On-Demand Lazy Tree Enumeration (`VaultItem`)**:
  * `loadChildrenIfNeeded()` avoids upfront recursive directory walks. Files and subfolders are scanned only when the user expands a folder row.
  * Uses bulk directory resource enumeration (`includingPropertiesForKeys: [.isDirectoryKey]`) eliminating redundant `stat()` system calls.
  * Automatically filters hidden/system directories (`.git`, `.obsidian`, `node_modules`, `.build`, `Pods`, `vendor`, `target`, `dist`, `.cache`, `.DS_Store`).
  * Sorts folders first alphabetically followed by Markdown files using `localizedStandardCompare`.
* **Adaptive 3-Pane `NSSplitView` Coordinator**:
  * Coordinates three subviews: TOC Sidebar (leading), Document `WKWebView` (center), and Vault Navigator (trailing).
  * Employs frame-based layout with `.autoresizingMask = [.width, .height]` inside `dropView`, eliminating Auto Layout fitting-size calculation traps that cause window enlargement.
  * Dynamically enforces minimum and maximum divider positions with `splitView(_:constrainMinCoordinate:ofSubviewAt:)` and `splitView(_:constrainMaxCoordinate:ofSubviewAt:)`, ensuring the web reading area never dips below 200px.
  * On pane toggle or removal, calls `split.adjustSubviews()` ensuring zero dead space and immediate full-width recovery.
* **Active Note Selection & Auto-Reveal**:
  * `selectDocument(url:)` automatically expands all ancestor folders and selects/scrolls the active note into view when opening files or navigating history.

---

## 3. Memory & Performance Optimizations

1. **Startup Pipelining (`EagerDocumentLoader`)**: Asynchronously begins document mapping (`.mappedIfSafe`) and markdown parsing on a detached background task at CLI invocation, executing concurrently with AppKit runloop and window initialization.
2. **Prewarmed WebKit**: `WebKitPrewarmer` initializes a lightweight background `WKWebView` during `applicationWillFinishLaunching` and automatically preheats the next view upon usage, shaving ~150 ms off initial document paint time.
3. **Hardware-Vectorized FastScan**: Replaced standard library string searches with POSIX `memchr` and `memmem` byte matching, eliminating grapheme cluster normalization overhead and accelerating extension filtering by **30x–800x**.
4. **Cancellable Background Pipelines**: Parsing runs on a dedicated user-initiated `OperationQueue`. Operations decouple `self` and retain only immutable pipeline state, allowing immediate window controller deallocation on close.
5. **Zero Reflection & Metadata**: Compiled with `-O -cross-module-optimization -Xfrontend -disable-reflection-metadata -Xfrontend -disable-reflection-names -dead_strip -dead_strip_dylibs`, enabling whole-module dead-code stripping.
6. **Stripped Binary**: Single-architecture Mach-O executable is **~670 KB** (`strip -u -r`). The complete `.app` bundle is only **3.4 MB** (Universal bundle **4.2 MB**, compressed release archive **~2.9 MB**) including all offline diagram engines, fonts, and assets.
7. **High-Throughput Markdown Pipeline**: Reference C parsing via `cmark-gfm` coupled with vectorized linear extension scanning processes content at **16.5 – 52 MB/s** (~52 MB/s on standard documentation, ~16.5 MB/s on complex multi-extension documents with callouts, math, and diagrams).
8. **Bulk Directory Attribute Enumeration**: `VaultScanner` consumes cached kernel directory attributes directly from `contentsOfDirectory(includingPropertiesForKeys:)`, bypassing individual `stat` / `lstat` syscalls during vault tree expansion.
9. **Lifecycle & Memory Hygiene**: `WeakScriptMessageHandler` trampoline permanently breaks WebKit script handler retain cycles; `FileWatcher.invalidate()` immediately closes file descriptors and cancels dispatch sources on window close; and `DiagramCache` memory cache is strictly capped at 16 MB.
10. **Multi-Process Memory Isolation**: The host AppKit UI process maintains a lean ~35–45 MB footprint; the WebKit auxiliary web process (`com.apple.WebKit.WebContent`) isolates DOM state and garbage collection from the desktop application chrome.

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
* **Isolated `main` Branch**: The `main` branch contains only clean, tagged release commits. All active development occurs on `develop`. Following a release, `publish-release.sh` switches back to `develop`, automatically increments the `Y` counter (`0.3.0` $\to$ `0.4.0`), and pushes the bump commit.
* **Native About Panel**: Integrated via `AppDelegate.showAboutPanel(_:)` providing dynamic version reporting from bundle metadata, author credits (Finn de Bear), and direct link routing to the source repository.
