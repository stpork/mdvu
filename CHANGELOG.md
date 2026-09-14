# Changelog

All notable changes to **mdvu** are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-09-14

### Added
- **Obsidian-Style File & Vault Navigator Pane (`⌥⌘D`)**:
  - Integrated collapsible right-hand file navigation pane with hierarchical tree view (`VaultNavigatorView`, `VaultOutlineView`).
  - Automatic vault root detection (`VaultScanner.findVaultRoot`): intelligently scans up the folder hierarchy for `.obsidian` or `.git` boundaries (up to 20 levels), anchoring the vault tree at the true repository or knowledge base root.
  - On-demand lazy scanning (`loadChildrenIfNeeded`): child directories are scanned only when expanded, keeping memory and CPU footprint near zero even in vaults with thousands of Markdown notes.
  - Auto-reveal and selection: opening or switching documents automatically expands parent folders and highlights the active file.
  - Native keyboard navigation: Return/Enter key opens files or expands/collapses folders; double-click toggles directories; single-click opens notes.
  - CLI flag `--navigator`: launch directly with the navigator pane open (`mdvu --navigator <path>`).
- **Push-On / Push-Off Toolbar Button States**:
  - Table of Contents (`Contents`) and File Navigator (`Navigator`) toolbar buttons use textured `.pushOnPushOff` styles that stay visually depressed when their corresponding panes are active.
  - Synchronized across keyboard shortcuts (`^⌘S`, `⌥⌘D`), menu items (`View → Show/Hide Table of Contents`, `View → Show/Hide File Navigator`), and toolbar clicks.
- **Dynamic Back / Forward Toolbar Button Validation**:
  - Segmented history navigation control in the toolbar dynamically enables or disables individual segments based on `navigationHistory.canGoBack` and `navigationHistory.canGoForward`, providing clear visual state and eliminating dead clicks.

### Changed
- **Adaptive 3-Pane Split View Coordinator**:
  - Unified `rebuildSplitSubviews()` managing 1, 2, or 3 panes (`[sidebarContainer, webView, vaultNavigatorView]`) inside an autoresizing `NSSplitView`.
  - Configured split view holding priorities (`.defaultLow` for document web view, `.defaultHigh` for sidebars) so window resizing gracefully stretches the document reading area.
  - Available width clamping: prevents navigator or sidebar from squeezing the Markdown document web view below 200px.
- **CLI Flag Filtering in Application Delegate**:
  - `AppDelegate.application(_:openFiles:)` filters out CLI flags (e.g. `--navigator`, `--snapshot`) so external launch events or drag-and-drop operations do not treat command options as document paths.
  - Suppressed modal `NSAlert` dialogs during `--snapshot` runs, piping error messages to `stderr` to prevent headless execution hangs.

### Fixed
- **Window Expansion on Navigator Toggle**:
  - Replaced Auto Layout constraints on `split` with frame-based bounds and autoresizing masks (`split.frame = dropView.bounds`, `autoresizingMask = [.width, .height]`), eliminating AppKit fitting-size accumulation that previously caused the window to expand horizontally beyond the screen boundaries.
- **Clean Pane Removal & Subview Stretching**:
  - Added `split.adjustSubviews()` upon closing the navigator or sidebar pane, ensuring the remaining views immediately and smoothly reclaim 100% of the window width without leaving empty residual view space.

## [0.3.2] - 2026-09-11

### Added
- **Automatic Dialect Option & Document State Reset**:
  - Added `Automatic` option to `View → Dialect` menu, allowing dynamic frontmatter and comment directive detection while retaining menu fallback.
  - Switching or opening documents now automatically resets manual dialect overrides to the document's detected default, unless `--dialect` was explicitly passed via CLI.

### Changed
- **Linear Callout Scanner & Pipeline Throughput**:
  - Replaced regular expressions in callout block processing with linear bounded scans and literal string matching, reducing callout postprocessing time by ~8.5x.
  - Pipeline throughput boosted to **16.5 – 52 MB/s** (~52 MB/s on standard documentation, ~16.5 MB/s on rich multi-extension fixtures).
  - Optimized extension pre-checks with hardware-accelerated `FastScan.count(..., atLeast:)` using SIMD `memchr`, skipping heavy sub/superscript and math passes when fewer than 2 delimiter tokens exist.
  - Admonition line parser handles CRLF (`\r\n`) line breaks cleanly without premature block termination.
- **Documentation & Benchmark Comparison**:
  - Replaced compiler flags and N/A entries in `README.md` with a realistic 3-column benchmark comparing `mdvu` against real-world native viewers ([MacDown](https://macdown.uranusjr.com/), [mdv](https://www.mowglii.com/mdv/)) and Electron applications ([Typora](https://typora.io/), Obsidian).

### Fixed
- **CriticMarkup Tooltip Attribute Escaping**:
  - Escaped user comment text in `CriticMarkupExtension` tooltip attribute (`HTML.escapeAttribute`) to prevent HTML attribute breakouts.
- **Obsidian 4-Backtick Fence Handling**:
  - Added fence length and character tracking to prevent 4-backtick code blocks (` ```` `) from being prematurely terminated by inner 3-backtick sequences (` ``` `).
- **Window Title Markup Leaks**:
  - Document title extraction from `<h1>` elements now strips nested HTML tags and decodes entities, preventing raw markup from leaking into the macOS window title.
- **Entity Unescaping with Standalone Ampersands**:
  - Fixed pointer-advancing logic in `HTML.unescape` when standalone ampersands are present without valid entity codes.

## [0.3.1] - 2026-09-11

### Added
- **Application Menu Dialect Switcher (`View → Dialect`)**:
  - Integrated `Dialect` submenu in macOS View menu offering:
    - `Generic (CommonMark)`
    - `GitHub (GFM)`
    - `Obsidian`
  - Active dialect displays checkmark state (`NSControl.StateValue.on`).
  - Selecting a dialect immediately re-renders the document and preserves scroll ratio.
- **Automated Dialect Detection (YAML Frontmatter & Directives)**:
  - Added `MarkdownDocumentDirective` parser that scans:
    - YAML frontmatter keys: `dialect`, `markdown-dialect`, `markdown_dialect`, `mode` (supporting `obsidian`, `github`, `gfm`, `generic`, `commonmark`).
    - Top-of-file HTML comment directives (e.g. `<!-- dialect: obsidian -->`, `Run: mdvu --dialect obsidian`, `Open in Obsidian dialect`).
  - Dynamic hierarchy: explicit CLI `--dialect` and explicit user menu selection override document directives; default `.generic` allows document directives to activate automatically.
- **Preservation of Raw `<style>` Elements**:
  - `<style>...</style>` blocks in Markdown are preserved during sanitization instead of being escaped as literal text, allowing custom single-page layouts, showcase templates, and responsive stylesheets to render as intended.
  - `<script>` elements and event handler attributes remain strictly disarmed.
- **Showcase Fixture & High-Resolution Snapshot**:
  - Added `test-onescreen.md` fixture validating multi-column card presentations, native MathML, embedded base64 wiki-embeds, and diagram pipelines.
  - Added `Tests/Snapshots/MDVu.jpg` high-resolution showcase screenshot linked in `README.md`.

### Changed
- **Compiler Intermediate Hygiene**:
  - Thin LTO `.bc` bitcode files generated during release and benchmark compilation are isolated inside `Tests/` and ignored by git, eliminating root-level workspace clutter.
- **Temporary Render Lifecycle**:
  - Unique PID-scoped temporary directory for rendered HTML documents with automatic cleanup on document close and application shutdown.

## [0.3.0] - 2026-09-10

### Added
- **Native LaTeX Formula Support (KaTeX + WebKit MathML)**:
  - Full offline rendering for inline (`$...$`) and display (`$$...$$` and ````math````, ````latex````, ````katex```` blocks) mathematical formulas.
  - Translated client-side via embedded LZMA-compressed KaTeX engine (~64 KB) into native WebKit MathML Core markup.
  - 100% offline with zero font download delays, dark/light theme integration, and crisp Retina scaling.
- **Hardware-Vectorized FastScan**:
  - Replaced Swift `String.contains("...")` pre-checks with POSIX `memchr` and `memmem` byte-matching routines.
  - Bypasses grapheme cluster normalization on multi-megabyte documents, delivering a **30x–800x** speedup in extension pre-checks.
- **Linear $O(N)$ Streaming Math & Code Fence Scanner**:
  - Single-pass cursor scanning that natively skips inline code spans (`` `...` ``) and escaped backslashes (`\$`) without token replacement arrays.
  - Streaming `CodeFenceScanner` replaces memory-heavy string splitting for fenced code blocks.
- **Startup Pipelining (`EagerDocumentLoader`)**:
  - Detached background reading and parsing launched immediately upon CLI invocation, running concurrently with AppKit runloop and window initialization.
  - Continuous WebKit prewarming keeps subsequent document windows instant.
- **Zero-Leak Memory & Lifecycle Hygiene**:
  - `WeakScriptMessageHandler` trampoline breaks the hidden `WKUserContentController` retain cycle.
  - Decoupled background rendering in `DocumentWindowController` captures only immutable `MarkdownPipeline` state, eliminating controller retain across background parse tasks.
  - Deterministic `tearDown()` and `FileWatcher.invalidate()` cancel GCD dispatch sources, debounce timers, and close file descriptors immediately upon window close.
  - `DiagramCache` memory cache bounded strictly to 16 MB.
- **Corporate & Non-Admin Installation**:
  - `make install` and Homebrew cask automatically detect write permissions on `/Applications`, installing without `root` or falling back seamlessly to `~/Applications`.
- **GitHub Actions CI Pipeline**:
  - Automated continuous integration on native Apple Silicon `macos-14` (M1) runners with Xcode 16.
  - Validates full test suites, release builds, binary stripping and sizes, streaming throughput benchmarks, universal lipo binaries, and artifact generation.
- **Full Fixture Coverage & Torture Testing**:
  - Audited and activated 100% of test fixtures in `Tests/Fixtures/`: `test-light.md` (109 KB), `test-medium.md` (174 KB), `test-complete.md` (228 KB), and `test-heavy.md` (1.65 MB).
  - Added torture test verifying `test-heavy.md` (13,916 lines, 324 Mermaid diagrams, 1,100 headings, multi-script Unicode) parses end-to-end in **0.35 seconds**.
  - Expanded `test-complete.md` with sections 19–23 covering 120 content-cases: formulas inside tables, blockquotes, callouts, CriticMarkup, false-positive currency protection, and isolated security fixtures (`Tests/Fixtures/runtime/`).
  - Programmatic verification suite (`testAllMathCasesInFixture`) asserting all 42 LaTeX formula cases.
  - Extended math code fence scanner to support CommonMark tildes (`~~~math`) and multi-backtick (````math````) fences with variable indentation.
  - Unit and integration suite expanded to **43 tests** executing in **< 0.8 seconds** with **> 92% line coverage** on core rendering modules.

### Changed
- **Compiler Optimization**:
  - Updated release build configuration to `-O -cross-module-optimization -disable-reflection-metadata -disable-reflection-names -dead_strip -dead_strip_dylibs`.
  - Stripped single-arch binary is **638 KB**; entire `.app` bundle is **3.3 MB** (including KaTeX, Mermaid, PlantUML).
- **Throughput & Latency Gains**:
  - Parsing throughput boosted from 3.0 MB/s to **14.3+ MB/s** (~4.8x faster on large documents; 1 MB in 70 ms, 25 MB in 1.77 s, 44 KB real-world documents in 4.97 ms).

## [0.2.0] - 2026-09-05

### Added
- **Ultra-Fast Native Architecture**: Built with pure AppKit and WebKit. Zero Electron, zero Node runtime, zero telemetry, and 100% offline. Cold start in ~150 ms, first paint in ~300 ms, with an ultra-compact **3.2 MB** app bundle (**4.2 MB** Universal, **~2.2 MB** compressed release archive). Stripped Mach-O binary is **572 KB**.
- **High-Throughput Markdown Engine**: Powered by Apple/GitHub's reference `cmark-gfm` with full CommonMark and GitHub Flavored Markdown support (tables, task lists, autolinks, and strikethrough). High throughput of **4.5+ MB/s** (~35 ms for 4,600+ line documents).
- **Comprehensive Markdown Ecosystem Support**:
  - **Obsidian**: Callouts (`[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!DANGER]`, `[!CAUTION]`, `[!INFO]`, `[!SUCCESS]`, etc.), expandable/foldable callouts (`[!...]+` / `[!...]-`), `[[wikilinks]]` with aliases and block references, and media embeds (`![[embed]]`).
  - **Admonitions & Containers**: MkDocs syntax (`!!!`, `???`, `???+`) and Docusaurus/VuePress colon containers (`:::note`, `:::tip`, `:::warning`, `:::danger`, `:::`) mapped cleanly to native callouts.
  - **CriticMarkup**: Full editorial review syntax for additions (`{++add++}`), deletions (`{--del--}`), substitutions (`{~~old~>new~~}`), highlights (`{==mark==}`), and reviewer comments (`{>>comment<<}`).
  - **Subscript, Superscript & Underline**: `~sub~` (strictly guarded against GFM `~~strikethrough~~`), `^sup^`, and `^^underline^^`.
  - **GitLab Markdown**: Table of Contents tokens (`[[_TOC_]]` and `[TOC]`).
  - **YAML FrontMatter**: Extracted into clean, readable document metadata tables.
  - **Safe HTML & XSS Prevention**: Built-in `tagfilter` disarming malicious elements while preserving presentation tags (`<details>`, `<summary>`, `<b>`, `<u>`, `<sub>`, `<sup>`).
  - **Code Fence Protection**: `CodeFenceProtector` shields all 3-backtick, 4-backtick, and tilde blocks from transformation.
- **Offline Diagrams (Mermaid 11.17.2, ZenUML 0.2.3 & PlantUML 1.2026.7)**:
  - Bundled Mermaid 11.17.2 supporting all standard and beta grammars (including all five C4 models, fishbone, swimlanes, and ZenUML sequence diagrams).
  - Bundled PlantUML Core 1.2026.7 with WebAssembly Graphviz (Viz.js 3.24.0) via TeaVM—100% offline with zero Java requirement, supporting both ````plantuml`` and ````puml`` code fences.
  - Frame-budgeted diagram batching (16 ms time slices) preventing UI lockup on documents with hundreds of diagrams.
  - Automatic error recovery and syntax resilience (including unquoted hyphen handling in `requirementDiagram`).
  - On-demand lazy decompression and SHA-256 SVG disk caching.
- **Standardized 120 FPS Zoom Subsystem**: Compound `[-][ 100% ][+]` toolbar control featuring:
  - Smooth, real-time continuous trackpad pinch (`.magnify`) via hardware-accelerated CoreAnimation layer scaling.
  - Magnetic snapping ($\pm 2.5\%$) eliminating jitter and presentation rounding errors (e.g. `201%` $\to$ `200%`).
  - Bounce-back settling engine via trailing spring timers (50 ms, 150 ms, 300 ms) ensuring clean return to exact 1.0 (100%).
  - Discrete 10% stepping with automatic snapping from fractional gesture levels.
  - Manual percentage input field bounded strictly between **10%** and **500%**.
  - Double-click to instantly reset zoom to 100% (`⌘0`).
  - Persistent window zoom across document reloads, navigation history, and link jumps.
- **Document Titlebar Quick-Open**: Click directly on the filename in the window title to summon an `NSOpenPanel` modal sheet to switch files or folders within the current window, while preserving macOS proxy icon dragging and `⌘-click` folder hierarchy popups.
- **Two-Finger Navigation & Content Panning**: Intelligent trackpad gesture routing—two-finger horizontal swipes navigate Back and Forward when history is available, and automatically transition to smooth horizontal panning when zoomed in (`> 105%`) over wide tables and code blocks.
- **In-Page Search (`⌘F`)**: Instant keyword search with live match counters, highlighting, and smooth cycling (`⌘G` / `⇧⌘G`).
- **Full Width Mode (`⇧⌘W`)**: One-key toggle between readable typographic measure (920px max-width) and fluid edge-to-edge layout.
- **Atomic File Watching**: Live automatic reload on document save, supporting atomic file replacements in Vim, Xcode, and VS Code while preserving scroll position.
- **Headless PNG Snapshot (`--snapshot`)**: Fast command-line renderer for automation and visual regression testing.
- **Homebrew Cask Distribution**: Prepared automated tap packaging for `stpork/homebrew-tap` (`Casks/mdvu.rb`).
