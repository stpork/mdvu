# Architecture of mdvu

`mdvu` is a high-performance, ultra-compact native Markdown viewer for **macOS** and **Windows**, powered by a unified cross-platform **Rust Core** (`mdvu-core`) and 100% native platform user interfaces.

---

## 1. Architectural Philosophy

Most modern cross-platform Markdown tools bundle 150+ MB of Chromium and Node.js runtimes (Electron), consuming 300+ MB of RAM just to display formatted text. MDVu takes the polar opposite approach:

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
* Powered by `pulldown-cmark`, an event-driven pull-parser with zero heap allocations during tokenization.
* Full GitHub Flavored Markdown (GFM) compliance: tables, strikethrough, autolinks, task lists, and footnotes.
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
All engine assets are compressed with **LZMA Ultra** and compiled into the core binary:
* **Mermaid 11.17.2 + ZenUML 0.2.3** (`mermaid.lzma`, ~1.33 MB): Sequence, flowchart, class, state, ER, Gantt, mindmap, C4, architecture, and ZenUML sequence diagrams.
* **PlantUML Core 1.2026.7 + Viz.js 3.24.0** (`plantuml.lzma`, ~1.20 MB): Complete client-side WebAssembly execution with Graphviz 14.1.1. **Zero Java runtime (JVM/JRE) requirement.**
* **KaTeX MathML Engine** (`katex.lzma`, ~64 KB): Translates LaTeX equations to standard MathML Core for hardware-accelerated rendering.
* **Deterministic Diagram Caching**: SHA-256 / 64-bit SipHash cache keys (`compute_diagram_cache_key`) prevent diagram collisions across themes and documents.
* **Native diagram isolation**: macOS shares one lazy, nonpersistent renderer WebView between document windows. Windows uses an isolated renderer origin within the same WebView2 environment, sharing its browser and GPU. Jobs run serially, obsolete work is cancelled, each job has a 30-second deadline, and the renderer is released after five idle seconds. Diagram engines never enter the reading document. Standalone HTML retains its browser fallback.
* **Bounded reading DOM and cache writes**: offscreen diagrams retain SVG text and a size placeholder; SVG nodes are restored near the viewport or for matching search results. Cache writes run away from the UI thread through a bounded queue; slow storage can skip an optional cache write instead of delaying input.
* **Regression checks**: both native CI jobs render every Markdown fixture. Their explicit timer mode checks correctness and renderer cleanup without claiming display-frame performance. The system runners' default mode measures actual animation frames while scrolling and zooming during cold rendering.

### D. C-ABI Foreign Function Interface (`include/mdvu_core.h`)
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
  * Fallback to pure Swift pipeline when Rust core is not loaded.

---

## 4. Windows Native Application (`src/windows`)

The Windows frontend is a lightweight standalone binary leveraging native Win32 controls and the Evergreen WebView2 runtime:

* **WebView2**: Uses the installed Microsoft Edge WebView2 runtime and reports a missing runtime with a download link.
* **Single Executable**: Produces `mdvu.exe` with embedded offline diagram engines; packaging records the built executable's size and checksum.
* **Native Win32 Chrome**:
  * **DWM Dark Mode**: Activates Windows 11 immersive dark mode window frames via `DwmSetWindowAttribute(hwnd, 20)`.
  * **Win32 Menus & Status Bar**: Native top menu bar (`File`, `View`) and bottom status bar (`CommonControlsEx`).
* **Live File Watcher**:
  * Powered by `notify`, monitors the document's parent directory with atomic save tracking (surviving file replacements and renames by editors like VS Code, Notepad++, and Vim).
  * Trailing debounce (150 ms) reloads the view while seamlessly preserving the user's vertical scroll ratio.
* **Shortcuts & Shell Integration**:
  * `Ctrl+O`: Native open file dialog (`rfd`).
  * `Ctrl+R` / `F5`: Reload preview.
  * `Ctrl++` / `Ctrl+-` / `Ctrl+0`: Zoom in, zoom out, reset zoom.
  * `Ctrl+B`: Toggle Table of Contents sidebar.
  * `F11`: Borderless fullscreen mode.

---

## 5. Unified Single-Binary Mode (GUI & Headless CLI)

MDVu follows a unified single-binary philosophy across all platforms:
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
  * `make test`: Runs 64 native Swift regression and performance tests.
* **Unified Script**:
  * `./build.sh app` / `./build.sh universal` / `./build.sh archive` / `./build.sh test`
  * `./build.sh windows`: Cross-compiles or packages the Windows release.

### B. Windows
* **PowerShell**: `.\build.ps1` (or `.\scripts\build-windows.ps1`):
  * `.\build.ps1`: Builds release and packages `dist/mdvu-<version>-windows-x86_64.zip`.
  * `.\build.ps1 test`: Runs Rust workspace test suite.
  * `.\build.ps1 release`: Compiles optimized release binaries.
* **Command Prompt**: `build.cmd` (`build`, `build release`, `build test`).

### C. Continuous Integration (`.github/workflows/`)
* **macOS Pipeline (`ci.yml`)**: Automates Xcode build, 64-test validation suite, and universal binary verification on macOS runners.
* **Windows Pipeline (`windows.yml`)**: Automates MSVC compilation, Rust test suite, standalone packaging, and release artifact generation on Windows runners.
