<div align="center">
  <img src="packaging/AppIcon-256.png" alt="MDVu App Icon" width="128" height="128">
  <h1>MDVu - Superfast Markdown Viewer</h1>

  <p>
    The tiny, ultra-fast, ultra-compact and lightweight native Markdown viewer for <b>macOS &amp; Windows</b>.<br>
    Built with pure AppKit &amp; WebKit (macOS) and Win32 &amp; WebView2 (Windows). Zero Electron. Zero Node. Zero Telemetry. 100% Offline.
  </p>

  <p>
    <a href="https://github.com/stpork/mdvu/actions"><img src="https://github.com/stpork/mdvu/actions/workflows/ci.yml/badge.svg?branch=develop" alt="CI Status"></a>
    <a href="#installation"><img src="https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple" alt="macOS 13+"></a>
    <a href="#windows-installation--usage"><img src="https://img.shields.io/badge/Windows-10%20%2F%2011-0078D6?logo=windows" alt="Windows 10/11"></a>
    <a href="#installation"><img src="https://img.shields.io/badge/version-0.5.0-emerald" alt="Version 0.5.0"></a>
    <a href="#performance-and-size"><img src="https://img.shields.io/badge/bundle_size-3.4_MB_macOS_%7C_5.1_MB_Windows-brightgreen" alt="Bundle Size"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-purple" alt="License MIT"></a>
  </p>
</div>

<p align="center">
  <img src="packaging/MDVu.jpg" alt="mdvu screenshot" width="900" style="border-radius: 8px; box-shadow: 0 8px 30px rgba(0,0,0,0.12);">
</p>

---

## Why mdvu?

Modern Markdown tools often bundle 150+ MB of Chromium and Node.js runtimes just to display formatted text. **mdvu** takes the opposite approach:
* **Dual Native Engines**: Pure native **AppKit & WebKit** on macOS (~3.4 MB bundle) and native **Win32 & WebView2** on Windows (`mdvu.exe`, ~5.1 MB standalone). Both run on the shared, high-throughput `mdvu-core` Rust engine with zero Electron, Node, or JVM.
* **Instant Startup & Minimal Memory**: Launches in 30–50 ms and uses a fraction of Electron's memory footprint.
* **Unified Markdown Engine**: High-throughput `pulldown-cmark` parser with full CommonMark and GitHub Flavored Markdown (GFM) compliance and security tagfiltering.
* **Rich Markdown Dialects & Extensions**: Native support for **GitHub GFM**, **Obsidian** (callouts `[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!DANGER]`, wiki-links `[[target|label]]`, and embeds `![[image.png]]`), **MkDocs** (`!!!`, `???`, `???+`), **Docusaurus / VuePress** (`:::note` containers), **CriticMarkup** (`{++add++}`, `{--del--}`, `{~~old~>new~~}`, `{==mark==}`, `{>>comment<<}`), **Subscript & Superscript** (`~sub~`, `^sup^`, `^^underline^^`), and **GitLab TOC** (`[[_TOC_]]`).
* **Native Math Formulas (LaTeX / KaTeX)**: Full offline rendering for inline (`$...$`) and display (`$$...$$` or ````math```` blocks) mathematical formulas via an LZMA-compressed KaTeX engine (~64 KB) and native MathML Core rendering with dark/light mode integration and zero font downloads.
* **Offline Diagrams (Mermaid, ZenUML & PlantUML)**: Bundled **Mermaid 11.17.2**, **ZenUML 0.2.3**, and **PlantUML Core 1.2026.7** + **Viz.js 3.24.0** (Graphviz 14.1.1) with **LZMA Ultra** compression. Renders 100% offline with zero Java requirement, independent lazy loading, frame-budgeted execution, and SHA-256 disk caching.
* **Native Zoom & Window Management**:
  * macOS: Trackpad pinch-to-zoom (`.magnify`), smart magnify (`.smartMagnify`), compound toolbar control (`[-][ 100% ][+]`), magnetic $\pm 2.5\%$ snapping, titlebar quick-open, and 3-pane split view with Vault Navigator (`⌥⌘D`).
  * Windows: DWM Windows 11 immersive dark mode titlebars, native menus, status bar, and live atomic-save file watcher (`notify`).
* **Resource Hygiene**: Strict memory management, collision-resistant diagram caching, and zero background telemetry.

---

## Installation

### 1. Homebrew Cask (Recommended)

Install directly via the official `stpork` tap:

```sh
# Option A: One-line install
brew install --cask stpork/tap/mdvu

# Option B: Tap repository first, then install
brew tap stpork/tap
brew install --cask mdvu

# Option C: Direct URL install
brew install --cask https://raw.githubusercontent.com/stpork/homebrew-tap/main/Casks/mdvu.rb
```

To update in the future:
```sh
brew upgrade --cask mdvu
```

> [!NOTE]
> **Standard Installation:**
> `brew install --cask` installs directly into `/Applications` and links the `mdvu` CLI command without requiring `root` or `sudo`.
>
> **Restricted / Non-Admin Environments:**
> If your Mac is restricted by corporate MDM policies and your account does not have write access to `/Applications`, install into your home directory:
> ```sh
> brew install --cask --appdir=~/Applications stpork/tap/mdvu
> ```
> To make this default for all Homebrew casks, add `export HOMEBREW_CASK_OPTS="--appdir=~/Applications"` to your `~/.zshrc`.

---

### 2. Pre-Built Release Downloads (GitHub Releases)

Pre-compiled binaries, installers, and archives are available on the [GitHub Releases](https://github.com/stpork/mdvu/releases) page:

| Package | OS & Architecture | Description |
| :--- | :--- | :--- |
| **`mdvu-X.Y.Z-windows-x86_64.msi`** | Windows 10 & 11 (`x86_64`) | Native Windows MSI installer (Start Menu shortcut, `PATH` CLI registration, `.md` file associations) |
| **`mdvu-X.Y.Z-windows-x86_64.zip`** | Windows 10 & 11 (`x86_64`) | Portable standalone package containing single-file `mdvu.exe` (GUI & CLI) |
| **`mdvu-X.Y.Z-macos.dmg`** | macOS Universal (`arm64` + `x86_64`) | Graphical macOS installer with Drag-to-Applications |
| **`mdvu-X.Y.Z-macos-universal.zip`** | macOS Universal (`arm64` + `x86_64`) | Portable archive for both Apple Silicon and Intel |
| **`mdvu-X.Y.Z-macos-arm64.zip`** | macOS Apple Silicon (`arm64`) | Ultra-compact (2.9 MB) optimized for M1/M2/M3/M4 |
| **`mdvu-X.Y.Z-macos-x86_64.zip`** | macOS Intel (`x86_64`) | Ultra-compact (2.9 MB) optimized for Intel Macs |

---

### 3. Windows Installation & Usage

#### Option A: MSI Installer (Recommended)
1. Download **`mdvu-X.Y.Z-windows-x86_64.msi`** from [Releases](https://github.com/stpork/mdvu/releases).
2. **Interactive GUI install**:
   * Double-click the `.msi` package.
   * Check **Install for current user only (no administrator privileges needed)** to install without administrative privileges (installs to `%LOCALAPPDATA%\Programs\MDVu` without UAC elevation — the UAC shield icon dynamically disappears from the Install button).
   * Or leave it unchecked to install system-wide for all users (`C:\Program Files\MDVu`, requires UAC elevation).
   * Click **Install**.
3. **Silent / unattended install**:
   ```cmd
   :: Install just for current user (no admin rights required):
   msiexec /i mdvu-X.Y.Z-windows-x86_64.msi MSIINSTALLPERUSER=1 /qn

   :: Install for all users (system-wide, requires admin):
   msiexec /i mdvu-X.Y.Z-windows-x86_64.msi ALLUSERS=1 /qn
   ```
   * Automatically configures `mdvu` in `PATH` (user `PATH` for per-user, system `PATH` for all users).
   * Creates a Start Menu shortcut (`MDVu`) and registers `.md`, `.markdown`, `.mdown`, `.mkd` in Explorer's **Open with** menu.

#### Option B: Scoop / WinGet / Chocolatey
```powershell
# Scoop (direct manifest or bucket):
scoop install https://github.com/stpork/mdvu/releases/latest/download/mdvu.json

# WinGet:
winget install stpork.mdvu

# Chocolatey:
choco install mdvu
```

#### Option C: Portable ZIP Archive
1. Download **`mdvu-X.Y.Z-windows-x86_64.zip`** from [Releases](https://github.com/stpork/mdvu/releases).
2. Extract the archive into your preferred tools folder (e.g. `C:\Tools\MDVu` or `%LOCALAPPDATA%\Programs\MDVu`).
3. Launch `mdvu.exe` directly or run it from command line or PowerShell:
   ```cmd
   mdvu.exe document.md
   ```

**Building & packaging from source on Windows:**
```powershell
# Build release binary, portable .zip, .msi installer, and Scoop/WinGet/Chocolatey manifests:
.\scripts\build-windows.ps1

# Or using the root PowerShell / CMD drivers:
.\build.ps1
build.cmd

# Or using Cargo directly:
cargo build --release -p mdvu-windows --bin mdvu
```

---

### 4. macOS Manual Installation

1. Download the `.dmg` or `.zip` from [Releases](https://github.com/stpork/mdvu/releases).
2. Move `mdvu.app` into `/Applications` (or `~/Applications`).
3. *(If macOS Gatekeeper flags an ad-hoc release on first launch)*:
   ```sh
   xattr -d com.apple.quarantine /Applications/mdvu.app
   ```
4. *(Optional)* Link the CLI binary into your shell PATH:
   ```sh
   mkdir -p ~/.local/bin
   ln -sf /Applications/mdvu.app/Contents/MacOS/mdvu ~/.local/bin/mdvu
   # or system-wide (requires sudo):
   sudo ln -sf /Applications/mdvu.app/Contents/MacOS/mdvu /usr/local/bin/mdvu
   ```

---

### 3. Build & Install From Source

Requirements: macOS 13.0+, Swift 6 / Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/stpork/mdvu.git
cd mdvu

# Using the unified build.sh driver:
./build.sh app       # Build optimized native application
./build.sh install   # Installs to /Applications and links CLI binary

# Or using make:
make app             # Build release bundle
make install         # Install locally

# To compile a universal binary (Apple Silicon + Intel):
./build.sh universal # or 'make universal'
```

---

### 4. Direct Swift Package Manager (CLI Only)

If you only need the command-line rendering tool without the `.app` bundle:
```sh
git clone https://github.com/stpork/mdvu.git
cd mdvu
swift build -c release
cp .build/release/mdvu ~/.local/bin/
```

---

## Usage

### Command Line Interface

```sh
# --- Interactive GUI Mode ---
# Open a single file
mdvu README.md

# Open multiple files in separate tabs/windows
mdvu ARCHITECTURE.md CHANGELOG.md

# Open a directory (file navigator in List mode)
mdvu ~/Documents/Notes

# Force light, dark, or system theme
mdvu --theme dark document.md

# Select markdown dialect (generic, github, or obsidian)
mdvu --dialect obsidian note.md

# Open directly in edge-to-edge Full Width mode
mdvu --full-width document.md

# --- Headless CLI Mode (No GUI Window) ---
# Export Markdown to self-contained HTML file
mdvu README.md -o output.html

# Embed offline diagram & math engines (KaTeX, Mermaid, PlantUML) into the HTML
mdvu README.md -o output.html --standalone

# Stream rendered HTML directly to stdout (useful for piping)
mdvu README.md --stdout | grep -i "<article>"

# Read from stdin and render to file or stdout
cat document.md | mdvu - -o rendered.html

# Extract Table of Contents as JSON structure
mdvu README.md --toc

# Headless snapshot generation (render Markdown to PNG without opening a window, macOS)
mdvu --snapshot output.png README.md
```

### CLI Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| **`-o, --output <FILE>`** | **Headless**: Write rendered HTML to file instead of opening GUI | None |
| **`--stdout`** | **Headless**: Force render HTML to stdout instead of opening GUI | Disabled |
| **`--toc`** | **Headless**: Print Table of Contents (JSON) to stdout and exit | Disabled |
| **`-s, --standalone`** | **Headless**: Embed offline diagram & math engines into HTML | `false` |
| `--title <TITLE>` | Override document title | Filename |
| `-t, --theme <system\|light\|dark>` | Color theme for document and diagrams | `system` |
| `-d, --dialect <generic\|github\|obsidian>` | Parser dialect profile (auto-detects frontmatter) | `generic` |
| `--full-width` | Open in edge-to-edge full width mode | Saved preference |
| `--navigator` | Open with the File & Vault Navigator pane visible (`⌥⌘D`) | Saved preference |
| `--no-mermaid` | Disable Mermaid diagram rendering | Enabled |
| `--snapshot <file.png>` | Headless render to PNG image and exit (macOS) | None |
| `-v, --version` | Display version information and exit | None |
| `-h, --help` | Display command-line usage help | None |

---

## Features

### 🌐 Comprehensive Markdown Ecosystem & Dialect Support
`mdvu` brings unified compatibility across the most popular Markdown flavors in software engineering, technical documentation, and academic writing:

* **CommonMark & GitHub Flavored Markdown (GFM)**:
  * Reference C AST parsing via `cmark-gfm`.
  * Tables with column alignment, autolinks, task lists (`- [x]`), and double-tilde strikethrough (`~~deleted~~`).
  * Footnotes support (`[^1]`).
* **Obsidian Ecosystem**:
  * Native callouts: `[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!DANGER]`, `[!CAUTION]`, `[!INFO]`, `[!SUCCESS]`, `[!QUESTION]`, `[!FAILURE]`, `[!BUG]`, `[!EXAMPLE]`, `[!QUOTE]`.
  * Foldable callouts: expandable (`[!NOTE]+`) and collapsed by default (`[!NOTE]-`).
  * Wikilinks with aliases and header/block references: `[[document]]`, `[[document|Custom Label]]`, `[[#section]]`.
  * Media embeds: `![[diagram.png]]`, `![[audio.mp3]]`.
* **Admonitions & Colon Containers (MkDocs, Docusaurus, VuePress)**:
  * MkDocs syntax: `!!! note "Title"`, `??? tip "Collapsible"`, and `???+ warning "Open by default"`.
  * Fenced colon containers: `:::note`, `:::tip[Title]`, `:::warning`, `:::danger`, and closing `:::`.
  * Mapped transparently to native callout aside containers with SVG icons and theme colors.
* **CriticMarkup (Editorial & Review Syntax)**:
  * Additions: `{++new content++}` $\to$ `<ins class="critic-add">new content</ins>`.
  * Deletions: `{--removed content--}` $\to$ `<del class="critic-del">removed content</del>`.
  * Substitutions: `{~~old~>new~~}` $\to$ `<del class="critic-del">old</del><ins class="critic-add">new</ins>`.
  * Highlights: `{==highlighted phrase==}` $\to$ `<mark class="critic-mark">highlighted phrase</mark>`.
  * Reviewer Comments: `{>>inline comment<<}` $\to$ `<span class="critic-comment">💬 inline comment</span>`.
* **Subscript, Superscript & Underline**:
  * Subscript: `H~2~O` $\to$ `H<sub>2</sub>O` (with strict negative lookaround to prevent conflicts with GFM `~~strikethrough~~`).
  * Superscript: `E = mc^2^` $\to$ `E = mc<sup>2</sup>`.
  * Underline: `^^underlined text^^` $\to$ `<u>underlined text</u>`.
* **GitLab Flavored Markdown (GLFM)**:
  * Table of Contents tokens: automatic anchor-aware placeholders for `[[_TOC_]]` and `[TOC]`.
* **YAML FrontMatter**:
  * Frontmatter headers (`---`) are extracted and cleanly formatted as a readable document metadata table.
* **Dynamic Dialect Switching & Auto-Detection**:
  * **View → Dialect Menu**: Instantly switch the active document window between **Generic (CommonMark)**, **GitHub (GFM)**, and **Obsidian** with live re-rendering and scroll preservation.
  * **Frontmatter & Directive Auto-Detection**: Automatically detects dialect from YAML frontmatter (`dialect: obsidian`) or top-of-file HTML comment directives (`<!-- dialect: obsidian -->`), applying the optimal profile seamlessly.
* **Safe HTML & Styling**:
  * Uses `cmark-gfm` tag filtering while preserving presentation markup and raw `<style>` blocks. This is not a complete HTML sanitizer: use trusted documents, particularly when they contain raw HTML or remote resources.
* **Code Fence Protection**:
  * All inline transformations are shielded by `CodeFenceProtector` against modifying code blocks (including 3-backtick, 4-backtick ` ```` `, and tilde `~~~` fences).

---

### 📊 Offline Diagram Rendering (Mermaid, ZenUML & PlantUML)

`mdvu` bundles fully offline rendering engines compressed with **LZMA Ultra** for maximum storage efficiency:

* **Mermaid 11.17.2**:
  * **Core Grammars**: `flowchart`, `sequenceDiagram`, `classDiagram`, `stateDiagram-v2`, `erDiagram`, `gitGraph`, `gantt`, `pie`, `mindmap`, `quadrantChart`, `requirementDiagram`, `C4Context`, `C4Container`, `C4Component`, `C4Dynamic`, `C4Deployment`.
  * **Extended Types**: `ishikawa-beta` (fishbone diagrams), `swimlane-beta` (workflow swimlanes), `packet-beta` (binary packet protocols), `kanban`, `block-beta`, `architecture-beta`, `radar-beta`, `sankey-beta`, and `xychart-beta`.
  * **ZenUML 0.2.3 Plugin**: Full support for concise ZenUML sequence diagrams within ````mermaid`` code blocks.
  * **Auto-Quoting Resilience**: Grammar preprocessor automatically quotes unquoted labels containing hyphens in `requirementDiagram` and complex models.
* **PlantUML 1.2026.7 (`@plantuml/core`) + Graphviz (`Viz.js 3.24.0` / Graphviz 14.1.1)**:
  * **100% Offline & Pure WebAssembly/JS**: Executes client-side inside WebKit via TeaVM. **No Java runtime (JRE/JVM) or external binaries required.**
  * **Fenced Blocks**: Supports both ````plantuml`` and ````puml`` code fences.
  * **UML Models**: Sequence diagrams, Class models with inheritance and associations, State machines, Activity diagrams, Component architectures, Object diagrams, Deployment diagrams, and Use-case models.
  * **Non-UML Families**: JSON/YAML data tree visualizers, Salt UI wireframes, Archimate enterprise models, MindMaps, Work Breakdown Structures (WBS), Gantt schedules, and Network (`nwdiag`) diagrams.
  * **Dark Mode & Transparency**: Automatically adapts to document theme with transparent SVG backgrounds.
* **Frame-Budgeted Diagram Execution**:
  * Diagram rendering yields every 16 ms to the WebKit animation loop, preventing main-thread locks on documents with hundreds of diagrams (e.g. 300+ diagrams in stress fixtures).
* **On-Demand Lazy Decompression**:
  * Documents without diagrams incur **zero CPU/memory overhead**; the LZMA archives are never accessed.
  * Documents with only Mermaid diagrams decompress only `mermaid.lzma` (1.33 MB).
  * Documents with only PlantUML diagrams decompress only `plantuml.lzma` (1.20 MB).
* **SHA-256 SVG Disk Cache**:
  * SVGs are cached to `~/Library/Caches/com.mdvu.viewer/diagrams` keyed by `SHA256(renderer + version + source + theme)`.
  * Renders once; subsequent loads reuse cached SVG and bypass diagram generation.

---

### 🔍 Native Zoom Control `[-][ 100% ][+]`
* **Hardware-Accelerated Scaling**: WebKit handles continuous trackpad magnification. Frame rate depends on display refresh rate, document complexity, and system load; no fixed FPS guarantee is implied.
* **Magnetic Snapping ($\pm 2.5\%$)**: Micro-gestures within $\pm 2.5\%$ of clean 10% multiples (100%, 150%, 200%, 300%) snap cleanly to integers, eliminating jitter and phantom numbers (e.g. `201%` $\to$ `200%`).
* **Bounce-Back Settling Engine**: Rapid zoom-out bounce-back gestures settle at exact `1.0` (`100%`) via trailing spring timers.
* **Discrete 10% Stepping**: UI buttons and `⌘+` / `⌘-` step cleanly by 10% and snap to clean multiples.
* **Manual Entry & Boundaries**: Click the centered percentage field to type a custom value (e.g. `150`, `250%`), bounded between **10%** and **500%**.
* **Double-Click Reset**: Double-clicking the indicator resets the zoom level to 100% (`⌘0`).
* **Persistent Window Zoom**: Zoom level is preserved across Back/Forward navigation, link jumps, and file reloads.

---

### 📑 Document Titlebar Quick-Open
* Click the file name in the window titlebar to open the native `NSOpenPanel` sheet modal and switch files or folders in the current window.
* Full compatibility with macOS native window features: dragging the title moves the window, `⌘-click` reveals the Finder directory hierarchy, and the proxy icon can be dragged into Terminal or Mail.

---

### 📐 Readable Measure vs. Full Width
* **Readable Measure (Default)**: Constrains body text to 920px with optimal line length (~70–85 characters) for effortless reading.
* **Full Width (`⇧⌘W`)**: Expands text, code, tables, and diagrams edge-to-edge across wide monitors.

---

### 🧭 Navigation & Two-Finger Swipe
* **Two-Finger History Swipe**: Horizontal trackpad swipes navigate Back and Forward when history is available.
* **Zoom Pan-Priority**: When zoomed in (`> 105%`), two-finger gestures seamlessly pan overflowing tables, code blocks, and diagrams without triggering history jumps.
* **Dynamic Back/Forward Validation**: Segmented history buttons in the toolbar visually enable or disable based on actual navigation history availability.

---

### 🗂️ File & Vault Navigator (`⌥⌘D`)
* **Matching Pane Headers**: Both panels have a leading icon, title and × button to hide the panel.
* **One File Navigator**: The right pane switches between **Tree** (folders and files) and **List** (recursive relative file paths). The left pane shows only the current document’s table of contents.
* **Smart Root Detection**: Automatically walks up directory ancestors looking for `.obsidian` or `.git` boundaries, anchoring the root at your true vault or repository level.
* **Folder Opening**: Opening a folder shows List mode and opens its first sorted Markdown file. That folder stays the root while you browse its documents.
* **Bounded Scanning**: Tree mode loads folders on demand. List mode scans in the background, preserving the existing 5,000-file limit; ignored directories, packages and directory symlinks are skipped. Switching modes releases the previous model.
* **Active Selection**: Switching views preserves the current document without reloading it. Opening files and navigating Back/Forward highlights the active file in either view.
* **Native Keyboard & Click Flow**: Single-click opens files; double-click expands or collapses directories; Return/Enter opens the highlighted note.
* **Push-on/Push-off State**: Toolbar buttons for Table of Contents and File Navigator stay visually depressed when their respective panes are active.
* **CLI Flag**: Launch directly with navigator open using `mdvu --navigator <path>`.

---

## Performance & Sizing Benchmark

For a detailed side-by-side benchmark comparison against rivals (Obsidian, Typora, MarkText, Marked 2, VS Code), complete throughput curves, startup latency measurements, and compressed asset breakdowns, see **[COMPARISON.md](COMPARISON.md)**.

Measurements vary with architecture, OS, document, and cache state. `make benchmark` runs five parser iterations after a warmup; it does not measure DOM rendering, scrolling, or diagram execution. The 0.4.1 checks and exact artifact sizes are recorded in [CHANGELOG.md](CHANGELOG.md).

| Property | Configuration / measurement |
| :--- | :--- |
| Native / Universal app | Approximately 3.4 / 4.2 MiB, with shared compressed resources |
| Compiler | `-O`, cross-module optimization, linker dead stripping, stripped Mach-O |
| Resources | Lazy LZMA decompression off the UI queue; reused for later documents |
| Cache | Shared SVG `NSCache`, advisory 16 MiB cost limit; persistent disk cache |
| Zoom | Native WebKit magnification and page zoom; display/document dependent |

For the previous measured build, `-Osize` saved less than 1% of the entire app while reducing parser throughput in that run, so the speed-oriented flags are retained. No formatting or parser capabilities have been removed to reduce size.

### TOC navigation and installed copies

Click a heading in the Contents pane to scroll to it, including clicking the same selected row again after scrolling away. Local `file://` navigation tolerates WebKit history API restrictions and uses native Back/Forward history. If a fix appears absent, verify the version in **About mdvu**: `/Applications/mdvu.app` and `~/Applications/mdvu.app` can contain different builds. Launch the newly installed 0.4.1 copy explicitly.

---

## Keyboard Shortcuts

| Action | macOS | Windows |
| :--- | :--- | :--- |
| Open File or Folder | `⌘O` | `Ctrl+O` |
| Close Window | `⌘W` | `Alt+F4` |
| Reload Document | `⌘R` | `F5` / `Ctrl+R` |
| Zoom In (+10%) | `⌘+` / `⌘=` | `Ctrl++` / `Ctrl+=` |
| Zoom Out (-10%) | `⌘-` | `Ctrl+-` |
| Actual Size (100%) | `⌘0` | `Ctrl+0` |
| Toggle Fullscreen | `^⌘F` | `F11` |
| Toggle Table of Contents | `^⌘S` | `Ctrl+B` |
| Toggle File / Vault Navigator | `⌥⌘D` | — |
| Find in Document | `⌘F` | `Ctrl+F` |
| Find Next / Previous | `⌘G` / `⇧⌘G` | `F3` / `⇧F3` |
| Toggle Full Width Mode | `⇧⌘W` | — |
| Navigate Back / Forward | `⌘[` / `⌘]` | `Alt+←` / `Alt+→` |
| Quit Application | `⌘Q` | `Alt+F4` |

---

## Architecture

`mdvu` uses a unified cross-platform hybrid architecture:
* **Core (`crates/mdvu-core`)**: High-throughput Markdown parser (`pulldown-cmark`), dialect pipeline, embedded LZMA diagram engines (Mermaid, PlantUML, KaTeX), and C-ABI FFI layer.
* **Unified Binary Design**: Single executable on both platforms that functions seamlessly as an interactive GUI viewer and as a headless CLI renderer when options (`-o`, `--stdout`, `--toc`) or pipes are used.
* **macOS**: Hand-crafted native AppKit host with WebKit hardware-accelerated viewport, multi-pane split coordinator, trackpad gesture engine, and static FFI bridge.
* **Windows (`crates/mdvu-windows`)**: Lightweight standalone Win32 binary powered by Microsoft Edge WebView2, DWM dark mode, atomic-save file watching, and `AttachConsole` terminal integration.

For detailed diagrams and component design, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## License & Credits

* **Author**: Finn de Bear ([finndebear@gmail.com](mailto:finndebear@gmail.com))
* **License**: Released under the [MIT License](LICENSE).

### Third-Party Software & Licenses
* [pulldown-cmark](https://github.com/raphlinus/pulldown-cmark) — MIT / Apache-2.0 (c) Raph Levien and pulldown-cmark contributors.
* [wry](https://github.com/tauri-apps/wry) & [tao](https://github.com/tauri-apps/tao) — MIT / Apache-2.0 (c) The Tauri Programme within The Commons Conservancy.
* [lzma-rs](https://github.com/gendx/lzma-rs) — MIT / Apache-2.0 (c) Corentin Henry.
* [swift-cmark](https://github.com/swiftlang/swift-cmark) — BSD-2-Clause / MIT (c) John MacFarlane, GitHub, Apple.
* [Mermaid.js 11.17.2](https://github.com/mermaid-js/mermaid) — MIT (c) Knut Sveidqvist and Mermaid Contributors.
* [ZenUML Plugin 0.2.3](https://github.com/mermaid-js/mermaid-zenuml) — MIT (c) Mermaid Contributors.
* [PlantUML Core 1.2026.7](https://github.com/plantuml/plantuml-core) — GPL / LGPL / Apache-2.0 / MIT (c) PlantUML Team.
* [Viz.js 3.24.0 (Graphviz 14.1.1)](https://github.com/mdaines/viz.js) — MIT (c) Michael Daines, Graphviz Contributors.
* [KaTeX 0.16.21](https://github.com/KaTeX/KaTeX) — MIT (c) Emily Eisenberg, Sophie Alpert, and KaTeX Contributors.
