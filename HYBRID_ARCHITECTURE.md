# MDVu Hybrid Architecture: Cross-Platform Rust Core + Native UIs (macOS & Windows)

This document describes the hybrid architecture implemented in the `feature/mdvu-rust` branch.

---

## 1. Architectural Philosophy

The primary objective of `mdvu` is to provide the **fastest, smallest, and highest-fidelity offline Markdown viewer possible**.

Most modern cross-platform markdown tools bundle 150+ MB of Chromium and Node.js runtimes (Electron), consuming 300+ MB of RAM just to view text. MDVu takes the polar opposite approach:

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
        │ • Bundle Size: ~3.4 MB      │ │ • Standalone Exe: ~5.1 MB   │
        │ • Startup: ~30-50 ms        │ │ • Startup: ~40-60 ms        │
        └─────────────────────────────┘ └─────────────────────────────┘
```

---

## 2. Component Breakdown

### A. `crates/mdvu-core` (Cross-Platform Rust Core)
* **High-Throughput Markdown Parsing**: Powered by `pulldown-cmark` (an event-driven pull-parser with zero heap allocations during tokenization).
* **Dialect Preprocessing Engine**:
  * **Obsidian**: `[!NOTE]` callouts, `[[target|label]]` wikilinks, and `![[image.png]]` embeds.
  * **MkDocs**: `!!!`, `???`, `???+` admonitions mapped directly to native callouts.
  * **Docusaurus / VuePress**: `:::note[title]` containers.
  * **CriticMarkup**: `{++add++}`, `{--del--}`, `{~~old~>new~~}`, `{==mark==}`, `{>>comment<<}`.
  * **Sub & Superscript**: `~sub~`, `^sup^`, `^^underline^^` without colliding with GFM `~~strikethrough~~`.
  * **Math / LaTeX**: Linear O(N) scanner for `$inline$` and `$$display$$` math expressions.
  * **GitLab TOC**: `[[_TOC_]]` and `[TOC]` placeholder generation.
  * **FrontMatter**: YAML frontmatter conversion to a structured document metadata table.
* **Embedded Offline Diagram & Math Assets**:
  * `mermaid.lzma` (~1.3 MB, decompressing 7 MB of Mermaid 11.17.2 + ZenUML).
  * `plantuml.lzma` (~1.2 MB, PlantUML Core 1.2026.7 + Viz.js Graphviz Wasm).
  * `katex.lzma` (~62 KB, KaTeX MathML engine).
  * Decompressed on-demand with pure Rust `lzma-rs` (zero external C dependencies).
* **C-ABI FFI Layer (`include/mdvu_core.h`)**:
  * Provides clean C functions (`mdvu_render_to_html`, `mdvu_document_get_html`, `mdvu_document_get_title`, `mdvu_document_get_toc_json`, `mdvu_document_free`) allowing Swift, C, or any foreign language to call the core with zero overhead.

---

### B. macOS Native UI (Swift + AppKit)
* Preserves 100% of the hand-crafted macOS experience:
  * Native `NSOutlineView` hierarchical table of contents and file vault navigator.
  * Native trackpad pinch-to-zoom (`.magnify`), smart magnify (`.smartMagnify`), horizontal pan vs. swipe navigation conflict resolution, and magnetic $\pm 2.5\%$ snapping.
  * Window title proxy icon dragging and `NSOpenPanel` titlebar quick-open.
  * Zero Electron runtime overhead, sharing macOS system dyld cache for Swift runtime.
* Connects to `mdvu-core` via `MdvuCoreBridge.swift` for unified parsing behavior across platforms.

---

### C. Windows Native UI (`crates/mdvu-windows`)
* **Zero-Runtime Overhead**: Utilizes the pre-installed **Microsoft Edge WebView2** runtime (present out-of-the-box on all modern Windows 10 & 11 installations).
* **Lightweight Standalone Binary**: Produces a single `mdvu.exe` (~5.1 MB including all diagram engines, compared to 150+ MB for Electron).
* **Native Windows Features**:
  * **DWM Dark Mode**: Activates Windows 11 immersive dark mode titlebars via `DwmSetWindowAttribute(hwnd, 20)`.
  * **Live File Watcher**: Powered by `notify`, detects file writes from VS Code, Vim, Notepad, or Obsidian and reloads preview instantly while preserving scroll ratio.
  * **Hotkeys**:
    * `Ctrl + O`: Native Windows open file dialog (`rfd`).
    * `Ctrl + R` / `F5`: Force reload.
    * `Ctrl + Plus` / `Ctrl + Minus` / `Ctrl + 0`: Zoom in, zoom out, reset zoom (100%).
    * `F11`: Fullscreen toggle.
  * **CLI & Shell Association**: Double-clicking any `.md` file or running `mdvu.exe document.md` opens immediately.

---

### D. Headless CLI (`crates/mdvu-cli`)
* High-speed command-line renderer for CI/CD and script automation:
  ```sh
  # Render markdown to standalone HTML with embedded offline diagrams
  mdvu-cli document.md -o output.html --standalone

  # Extract Table of Contents as JSON
  mdvu-cli document.md --toc
  ```

---

## 3. Build & Release Instructions

### Build on macOS:
```sh
# Build Swift native app
make release
make package

# Build Rust core, CLI, and desktop viewer
make rust-release

# Run all test suites (Swift + Rust)
make test
make rust-test
```

### Build on Windows (PowerShell):
```powershell
# Using the automated build script
pwsh ./scripts/build-windows.ps1

# Or manually via Cargo
cargo build --release --workspace
```
The resulting `mdvu.exe` and `mdvu-cli.exe` are placed in `dist/windows/` and packaged into `dist/mdvu-0.4.1-windows-x86_64.zip`.
