# Architecture of mdvu

`mdvu` is a Markdown viewer for **macOS** and **Windows** with a shared **Rust core** (`mdvu-core`). AppKit provides the macOS controls; Windows uses a native Win32 frame and menus with document controls inside WebView2. Both render the document through the system browser runtime.

---

## 1. Architectural Philosophy

The application shares parsing, dialect handling, reader JavaScript/CSS and offline engines across platforms. Platform hosts implement window management, menus, shortcuts, file access and browser integration. No Electron or Node.js runtime is bundled; browser processes still contribute to GUI memory use.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       mdvu-core (Rust Workspace)                            │
│  • Dialect Pipeline: Obsidian, MkDocs, Docusaurus, CriticMarkup, Math, TOC  │
│  • High-Throughput Parser: pulldown-cmark + GFM (tables, tasks, footnotes)  │
│  • Embedded Offline Engines: Mermaid, PlantUML (TeaVM/Wasm), KaTeX (LZMA)   │
│  • Zero-Copy SIMD byte scanning (memchr, memmem)                            │
│  • C-ABI FFI Layer: mdvu_render_to_html, mdvu_document_get_toc_json, etc.   │
└──────────────────────┬───────────────────────────────┬──────────────────────┘
                       │                               │
                       ▼                               ▼
        ┌─────────────────────────────┐ ┌─────────────────────────────┐
        │   macOS Native UI (Swift)   │ │  Windows Native UI (Rust)   │
        │ • Pure AppKit & WebKit      │ │ • Native Win32 & WebView2   │
        │ • 3-Pane Split & OutlineView│ │ • Evergreen Edge Runtime    │
        │ • macOS Trackpad Gestures   │ │ • DWM Dark Window Frames    │
        │ • Proxy Icon & Titlebar Open│ │ • Live File Watcher (Notify)│
        │ • App bundle + shared core  │ │ • Standalone executable    │
        │ • Lazy diagram renderer     │ │ • Lazy diagram renderer    │
        └─────────────────────────────┘ └─────────────────────────────┘
```

The shared core parses Markdown locally. The system runners measure native window creation, first content, cold diagram rendering, responsiveness, and process memory separately.

---

## 2. Cross-Platform Core Subsystem (`src/core`)

The core repository logic lives in `src/core` and is shared across all frontends:

### A. High-Throughput Markdown Parsing & GFM
* Powered by `pulldown-cmark`, an event-driven pull-parser. HTML output and dialect transforms allocate storage as needed.
* GFM extensions: tables, strikethrough, autolinks, task lists, and footnotes.
* Strict GFM Security Tagfilter: disarms malicious `<script>`, `<iframe>`, `<textarea>`, `<title>`, `<xmp>`, `<noembed>`, `<noframes>`, and `<plaintext>` tags across block and inline HTML, while explicitly preserving user-defined `<style>` blocks per the MDVu specification.

### B. Dialect Preprocessing Pipeline
* **Obsidian**: Callouts (`[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!DANGER]`, etc.), `[[target|label]]` wikilinks, and `![[image.png]]` media embeds.
* **MkDocs**: `!!!`, `???`, and `???+` admonitions mapped directly to native callouts.
* **Docusaurus / VuePress**: `:::note[title]` containers.
* **CriticMarkup**: Inline revision syntax: `{++add++}`, `{--del--}`, `{~~old~>new~~}`, `{==mark==}`, `{>>comment<<}`.
* **Subscript & Superscript**: `~sub~`, `^sup^`, and `^^underline^^` without colliding with GFM `~~strikethrough~~`.
* **Math / LaTeX**: Linear O(N) scanner for `$inline$` and `$$display$$` math expressions.
* **GitLab TOC**: `[[_TOC_]]` and `[TOC]` placeholder generation.
* **YAML FrontMatter**: Structured conversion into a clean document metadata table.

### C. Embedded Offline Diagram & Math Engines
All engine assets use **LZMA Ultra**. Windows and default Cargo builds embed them in the core. Packaged macOS release builds use `bundle-assets` and keep one copy in `Contents/Resources`, shared by the ARM and Intel code slices:
* **Mermaid 12.2.0 + ZenUML 1.0.1** (`mermaid.lzma`, ~1.64 MiB): Sequence, flowchart, class, state, ER, Gantt, mindmap, C4, architecture, and ZenUML sequence diagrams.
* **PlantUML Core 1.2026.9 + Viz.js 3.31.0** (`plantuml.lzma`, ~1.22 MiB): Offline TeaVM/Viz.js execution with Graphviz 16.1.0, C4-PlantUML 2.14.0 and ArchiMate 3.2.2. **Zero Java runtime (JVM/JRE) requirement.**
* **KaTeX 0.19.0 MathML Engine** (`katex.lzma`, ~64 KB): Translates LaTeX equations to standard MathML Core for hardware-accelerated rendering.
* **Deterministic Diagram Caching**: Four domain-separated 64-bit hashes (`compute_diagram_cache_key`) distinguish source, theme, application version and the locked runtime manifest, including asset hashes. Updating an engine invalidates old SVG cache entries.
* **Runtime startup**: decode concurrently with native worker creation, then inject the direct runtime source and first job in one call. The decoder-only `lzma-rust2` build bounds its dictionary to the known output size in the locked manifest. Standalone HTML keeps a separate escaped loader so script text cannot break out of its container.
* **Native diagram isolation**: macOS shares one lazy, nonpersistent renderer WebView between document windows. Windows uses an isolated renderer origin within the same WebView2 environment, sharing its browser and GPU. Jobs run serially, obsolete work is cancelled, each job has a 30-second deadline, and the renderer is released after five idle seconds. Diagram engines never enter the reading document. Standalone HTML retains its browser fallback.
* **Bounded reading DOM and cache writes**: offscreen diagrams retain SVG text and a size placeholder; SVG nodes are restored near the viewport or for matching search results. Cache writes run away from the UI thread through a bounded queue; slow storage can skip an optional cache write instead of delaying input.
* **Regression checks**: both native CI jobs render every Markdown fixture. Heavy and the 73-case catalogue also receive forward/backward visibility checks before any zoom: a cached SVG string alone cannot pass. Their explicit timer mode checks correctness and renderer cleanup without claiming display-frame performance. The system runners' default mode measures actual animation frames while scrolling and zooming during cold rendering. macOS fullscreen tests wait for AppKit's transition completion, rather than the earlier style-mask change.
* **Large code blocks**: line groups keep their original text and fixed-height placeholders. The same visibility observer bounds font shaping to the viewport plus 400 px on both platforms, including WebKit versions without `content-visibility`. This avoids the browser overscan growing into a large Unicode corpus at small zoom factors. Hidden groups reference their original text for accessibility; selection/copy and print expose the complete code. This prevents a Unicode corpus from monopolizing the reading process on the first zoom. Regression checks preserve text, selection, search, and repeated initialization.
* **Deferred geometry and headings**: initial diagram discovery registers the existing intersection observer without reading every diagram rectangle. This lets the browser establish offscreen layout containment before geometry is requested. Heading text has its own containment span so zoom/reflow can skip offscreen glyph shaping while the heading ID, original markup and outer anchor remain usable. The outer anchor is positioned outside text flow so its float cannot pull offscreen headings back into text layout. Headings and strong text use the standard 700 weight to avoid the fallback-font cost observed with the intermediate 680 weight. Diagram, code and highlighting observers use the reader scrollport as their root, created after the shell exists. Enter callbacks trust the post-layout intersection snapshot: a second geometry read can refine deferred layout and discard the only notification. Retention callbacks batch current bounds before removing SVGs; mounting re-arms retention so a delayed enter cannot retain offscreen DOM indefinitely. Reading-position corrections run after layout through the existing resize observer. Re-observing the scroller tracks deferred position changes even without a resize; input cancels the bounded task.
* **Shared application UI**: `assets/sidebar-policy.json` defines TOC widths, row height, indentation, text size, initial expansion threshold, and the navigator's initial width for both frontends. Both TOCs expose a hierarchy with disclosure controls, truncated labels with full titles, and keyboard navigation. The Windows outline uses ARIA tree semantics; macOS uses `NSOutlineView`.
* **Release optimization**: the shared Rust core retains O3, LTO and one codegen unit. Only the Windows OS/UI host uses size optimization; native fixture/control checks and paired parsing measurements verify the resulting build. AppKit's split-view delegate assigns window-size changes to the document, preserving panel widths without a resize polling loop.
* **Platform conventions**: AppKit owns the macOS title bar, toolbar, menus, search control, and window management. Windows retains its standard Win32 title bar and menu, with equivalent document controls below them. Shortcuts use Cmd on macOS and Ctrl/Alt/F-keys on Windows. Icons share meanings and placement while retaining platform rendering; window controls and system menus are not imitated.

### D. C-ABI Foreign Function Interface (`src/core/include/mdvu_core.h`)
* Stable C-ABI interface for language interop:
  * `mdvu_version()`: Returns engine version string.
  * `mdvu_render_to_html(...)`: Renders markdown to HTML, returning an opaque `MdvuDocument*`.
  * `mdvu_document_get_html()`, `mdvu_document_get_body()`, `mdvu_document_get_title()`, `mdvu_document_get_toc_json()`.
  * `mdvu_document_free()`: Safely deallocates the document.
* Backed by NUL-terminated `CString` storage in `assets.rs` for memory-safe C and Swift interop.

---

## 3. macOS Native Application (Swift + AppKit)

The macOS frontend preserves 100% of the hand-crafted AppKit user experience:

* **3-Pane Split View Coordinator**:
  * Left: Table of Contents (`TOCOutlineView`).
  * Center: Hardware-accelerated `WKWebView` viewport.
  * Right: Unified File & Vault Navigator (`VaultNavigatorView`) with Tree / List modes and automatic `.obsidian` / `.git` root detection.
* **Native Trackpad & Zoom Engine**:
  * Fluid pinch-to-zoom (`.magnify`), smart magnify (`.smartMagnify`), horizontal pan vs. swipe navigation conflict resolution, and magnetic $\pm 2.5\%$ snapping.
  * Compound toolbar control `[-][ 100% ][+]` with persistent `targetPageZoom` surviving document navigation.
* **Titlebar Quick-Open & Proxy Icon**:
  * Click window title to open documents or folders via sheet modal.
  * Native window dragging, document proxy icon dragging, and `⌘-click` path hierarchy menu.
* **Swift FFI Bridge (`MdvuCoreBridge.swift`)**:
  * Dynamically loads `libmdvu_core.dylib` using safe scoped C-string closures (`withOptionalCString`), completely eliminating dangling pointers.
  * Successful documents and error pages share the in-place reader loader. Reusing the reader retains its math runtime; a full WebView navigation clears runtime state before loading a replacement.
  * Markdown processing, dialect rules and diagram cache storage use the same Rust core as Windows. The native host reports a missing or incompatible core instead of maintaining a second parser.

---

## 4. Windows Native Application (`src/windows`)

The Windows frontend is a lightweight standalone binary leveraging native Win32 controls and the Evergreen WebView2 runtime:

* **WebView2**: Uses the installed Microsoft Edge WebView2 runtime and reports a missing runtime with a download link. Its profile lives in `%LOCALAPPDATA%\MDVu\WebView2` (or the explicit `WEBVIEW2_USER_DATA_FOLDER` override), outside the release directory. Packaging removes obsolete adjacent profiles and archives only the four release files.
* **Single Executable**: Produces `mdvu.exe` with embedded offline diagram engines; packaging records the built executable's size and checksum.
* **Native Win32 Chrome**:
  * **Window themes**: Tao owns native caption theming from window creation through theme changes. `system` follows Windows; explicit light/dark preferences use the same window API. No competing DWM override is applied.
  * **Win32 menus**: Native `File`, `Edit`, `View`, `Go` and `Help` menus; the reader toolbar and sidebars are WebView2 content.
* **Live File Watcher**:
  * Powered by `notify`, monitors the document's parent directory with atomic save tracking (surviving file replacements and renames by editors like VS Code, Notepad++, and Vim).
  * Trailing debounce (150 ms) reloads the view while seamlessly preserving the user's vertical scroll ratio.
* **Local links**: The reader decodes the file path and fragment separately and sends structured JSON to the native host. A decoded `#` or `%` in a filename is never reparsed as a URL delimiter.
* **Shortcuts & Shell Integration**:
  * `Ctrl+O`: Native open file dialog (`rfd`).
  * `Ctrl+R` / `F5`: Reload preview.
  * `Ctrl++` / `Ctrl+-` / `Ctrl+0`: Zoom in, zoom out, reset zoom.
  * `Ctrl+B`: Toggle Table of Contents sidebar.
  * `Ctrl+Shift+O`: Open a folder or vault.
  * `Ctrl+Shift+D`: Toggle File Navigator; `Ctrl+Shift+W`: toggle Full Width.
  * `F11`: Borderless fullscreen mode.

---

## 5. GUI and Headless CLI Entry Points

Each platform uses the same frontend executable for GUI and CLI. The macOS bundle also contains the Rust shared library and resources; Windows links the core into its executable:
* **Interactive Mode (GUI)**: When invoked without CLI export flags (`mdvu document.md` or via Desktop/Finder/Explorer), MDVu launches its full hardware-accelerated GUI viewport.
* **Headless Mode (CLI)**: When invoked with export or batch flags (`-o`, `--stdout`, `--toc`, `-s`, stdin `-`), MDVu skips window creation, directly invokes the `mdvu-core` rendering pipeline, streams the result to the target file or stdout, and exits with code 0.
* **Windows Console Integration (`AttachConsole`)**: On Windows, the binary is compiled with `windows_subsystem = "windows"` to ensure clean launches from File Explorer without terminal flashing. When CLI flags are detected, it dynamically calls Win32 `AttachConsole(ATTACH_PARENT_PROCESS)` to pipe standard I/O directly to the caller's console (Windows Terminal, PowerShell, Git Bash, cmd).

```sh
# Render markdown to standalone HTML with embedded offline diagrams
mdvu document.md -o output.html --standalone

# Stream from stdin to stdout
cat notes.md | mdvu - --stdout > output.html

# Extract Table of Contents as JSON
mdvu document.md --toc
```

---

## 6. Build & Packaging Architecture

### A. macOS
* **Makefile Targets**:
  * `make app`: Builds native macOS `.app` bundle.
  * `make universal`: Builds dual-architecture `arm64` + `x86_64` bundle.
  * `make archive`: Creates signed ZIP archives and DMG installer with SHA-256 sidecars.
  * `make test`: Runs the native Swift regression suite against the shared Rust library.
* **Unified Script**:
  * `./build.sh app` / `./build.sh universal` / `./build.sh archive` / `./build.sh test`
  * `./build.sh check`: Runs shared Rust, Swift and visual reference checks.
  * `./build.sh windows`: Cross-compiles the Windows x64 portable ZIP from macOS/Linux; native PowerShell packaging builds MSI as well.

### B. Windows
* **PowerShell**: `.\build.ps1` (or `.\scripts\build-windows.ps1`):
  * `.\build.ps1`: Builds release and packages the Windows x64 MSI, portable ZIP, SHA-256 sidecars and package-manager submission templates. Only the release executable returned by Cargo and its matching WebView2 loader are packaged.
  * `.\build.ps1 test`: Runs Rust workspace test suite.
  * `.\build.ps1 release`: Compiles optimized release binaries.
* **Command Prompt**: `build.cmd` (`build.cmd`, `build.cmd release`, `build.cmd test`).
* **MSI scope**: One dual-purpose MSI supports Program Files for all users and `%LOCALAPPDATA%\Programs\MDVu` for the current user without elevation. Directory assignments run before MSI costing; an interactive scope change updates the target directory. Shortcut and registry commands reference `[#MdvuExe]`, the installed file identity, rather than concatenating directory strings. Finish has an explicit `EndDialog` event.

### C. Continuous Integration (`.github/workflows/`)
* **Shared workflow (`ci.yml`)**: Linux tests the Rust core. macOS runs Swift/core tests and coverage, native fixture correctness checks, release and universal builds. Windows parses all PowerShell scripts, runs workspace tests and coverage, native fixture correctness checks, CLI checks, release packaging and full MSI install/Finish/launch/uninstall tests for elevated and non-elevated scopes. The latter loads a temporary standard account's profile through secondary logon and resolves its profile environment by token SID, without relying on inherited administrator paths, Task Scheduler's batch-logon policy or an administrator's filtered token. An explicitly configured private WebView2 runtime is staged as a test dependency for that account; it is not included in the application packages. Linux additionally checks repository hygiene, documentation links, release metadata, installer authoring and renderer integrity. Hosted fixture tests use timer mode; physical desktop measurements use the default system runners described in [COMPARISON.md](COMPARISON.md).

  The disposable Windows CI VM temporarily permits unmanaged MSI installations for the standard-user test and restores its original `DisableMSI` policy afterward. This is test-host setup; the application and installer do not change machine policy. Failed installer reports are saved even when cleanup also fails.

* **Release publication**: A version tag must match `version.txt`. After all three CI jobs pass, a dedicated job downloads that run's macOS and Windows artifacts. `scripts/release-assets.py` requires six packages and valid SHA-256 sidecars, uploads them to a draft, verifies the remote asset set and only then publishes it. Public releases are immutable; the manifest identifies the tested source commit. `scripts/publish-release.sh` orchestrates tagging from clean, green `develop`, Homebrew and the website refresh.

### Updating embedded renderers

Run `python3 scripts/update-renderer-assets.py` with Node 22+ and Python 3. Exact dependencies and transitive integrity hashes are locked in `scripts/runtime-assets/package-lock.json`. The script bundles browser-only IIFEs, preserves upstream license comments, and writes LZMA1 preset 9 extreme archives shared by both native platforms. `manifest.json` records versions, sizes and SHA-256 hashes; normal application builds need no npm installation or network. Run native rendering tests and all fixture/control benchmarks after an update.

The JavaScript PlantUML build registers fewer diagram factories than the Java engine. Unsupported-type and syntax-error SVG panels are rejected before display/caching. C4 and ArchiMate library data are embedded in the PlantUML bundle, with their script-loader states pre-registered, so includes require no network or separate files. Other optional libraries are not included. `scripts/runtime-assets/stdlib-lock.json` pins the library URLs, versions and source hashes; the renderer asset generator verifies them before bundling. Updating the runtime manifest invalidates old SVG cache entries on both platforms. `assets/plantuml-adapter.mjs` routes `@startdot` directly to the same memoized Viz.js instance used by the PlantUML layout engine. The shared Rust parser normalizes standalone `zenuml` fences to Mermaid ZenUML input before computing their SVG cache key.

### Source checkout and generated data

Only application/build sources, locked runtimes, regression tests, fixtures, approved snapshots and human-readable documentation belong in Git. Build output is ignored under `.build/`, `target/` and `dist/`. Competitor apps, ad hoc comparison tools, raw JSON/video/screenshots and browser profiles remain local under `test-results/`. Native correctness runners derive catalogue cases directly from `tests/fixtures/test-diagrams.md`; a fresh checkout never needs local benchmark registries or results. Repository tests reject tracked downloads and generated diagnostics.
