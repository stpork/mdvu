<div align="center">
  <a href="https://stpork.github.io/mdvu/"><img src="packaging/assets/AppIcon-256.png" alt="MDVu Markdown viewer" width="128" height="128"></a>
  <h1>MDVu — Markdown Viewer for Mac &amp; Windows</h1>

  <p><a href="https://stpork.github.io/mdvu/"><strong>stpork.github.io/mdvu</strong></a><br>
    <a href="https://stpork.github.io/mdvu/#download">Downloads</a> · <a href="https://stpork.github.io/mdvu/diagrams/">Diagram examples</a> · <a href="https://stpork.github.io/mdvu/#comparison">Comparison</a>
  </p>

  <p>
    Superfast Markdown viewing in an ultracompact native app for <b>macOS &amp; Windows</b>.<br>
    Read MD files, LaTeX math and diagrams offline. No Electron, account or telemetry.
  </p>

  <p>
    <a href="https://github.com/stpork/mdvu/releases/latest"><img src="https://img.shields.io/github/v/release/stpork/mdvu" alt="Latest stable release"></a>
    <a href="https://github.com/stpork/mdvu/actions/workflows/ci.yml?query=branch%3Amain"><img src="https://github.com/stpork/mdvu/actions/workflows/ci.yml/badge.svg?branch=main" alt="macOS, Windows and Linux build and tests"></a>
    <a href="#installation"><img src="https://img.shields.io/badge/macOS-13%2B-58677c?logo=apple" alt="macOS 13+"></a>
    <a href="#3-windows-installation--usage"><img src="https://img.shields.io/badge/Windows-10%20%2F%2011-58677c" alt="Windows 10 and 11"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-58677c" alt="MIT license"></a>
  </p>
</div>

<p align="center">
  <img src="packaging/assets/MDVu.jpg" alt="mdvu screenshot" width="900" style="border-radius: 8px; box-shadow: 0 8px 30px rgba(0,0,0,0.12);">
</p>

---

## Why mdvu?

Read Markdown, diagrams and math in a compact native app for Mac and Windows. The rendering engines are included; a separate browser runtime is not bundled. See measured sizes and UI performance on the [website](https://stpork.github.io/mdvu/#comparison).
* **Dual Native Engines**: Pure native **AppKit & WebKit** on macOS and native **Win32 & WebView2** on Windows. Both run on the shared `mdvu-core` Rust engine with zero Electron, Node, or JVM.
* **Responsive Reading**: Diagram execution uses a separate renderer so scrolling and zoom can continue while a diagram is being generated. Native fixture tests measure cold interaction latency and process memory.
* **Unified Markdown Engine**: High-throughput `pulldown-cmark` parser with CommonMark parsing, GFM extensions and security tagfiltering.
* **Rich Markdown Dialects & Extensions**: Native support for **GitHub GFM**, **Obsidian** (callouts `[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!DANGER]`, wiki-links `[[target|label]]`, and embeds `![[image.png]]`), **MkDocs** (`!!!`, `???`, `???+`), **Docusaurus / VuePress** (`:::note` containers), **CriticMarkup** (`{++add++}`, `{--del--}`, `{~~old~>new~~}`, `{==mark==}`, `{>>comment<<}`), **Subscript & Superscript** (`~sub~`, `^sup^`, `^^underline^^`), and **GitLab TOC** (`[[_TOC_]]`).
* **Native Math Formulas (LaTeX / KaTeX)**: Full offline rendering for inline (`$...$`) and display (`$$...$$` or ````math```` blocks) mathematical formulas via an LZMA-compressed KaTeX engine (~64 KB) and native MathML Core rendering with dark/light mode integration and zero font downloads.
* **Offline Diagrams (Mermaid, ZenUML & PlantUML)**: Bundled **Mermaid 12.2.0**, **ZenUML Core 4.7.2** (plugin 1.0.1), **ELK 0.12.0**, and **PlantUML Core 1.2026.9** + **Viz.js 3.31.0** (Graphviz 16.1.0) with **LZMA Ultra** compression. Renders 100% offline with zero Java requirement, independent lazy loading, isolated native diagram execution, and runtime-aware disk caching.
* **Native Zoom & Window Management**:
  * macOS: Trackpad pinch-to-zoom (`.magnify`), smart magnify (`.smartMagnify`), compound toolbar control (`[-][ 100% ][+]`), magnetic $\pm 2.5\%$ snapping, native titlebar behavior, and 3-pane split view with Vault Navigator (`⌥⌘D`).
  * Windows: DWM Windows 11 immersive dark mode titlebars, native menus, a WebView2 reader toolbar and sidebars, and a live atomic-save file watcher (`notify`).
* **Resource Hygiene**: Strict memory management, collision-resistant diagram caching, and zero background telemetry.

---

## Installation

### 1. Homebrew Cask (macOS)

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

Download the **latest stable release** for native macOS and Windows: [macOS DMG](https://github.com/stpork/mdvu/releases/latest/download/mdvu-macos.dmg), [Windows MSI](https://github.com/stpork/mdvu/releases/latest/download/mdvu-windows-x86_64.msi), or a portable ZIP from [GitHub Releases](https://github.com/stpork/mdvu/releases/latest). These permanent links follow each new stable release. Every package has a published SHA-256 checksum; historical releases and versioned download URLs remain available.

Start with **DMG on macOS** or **MSI on Windows**. Portable ZIP variants are under **Other versions · portable ZIPs** on the [website](https://stpork.github.io/mdvu/#download), linking to [GitHub Releases](https://github.com/stpork/mdvu/releases). Starting with 0.5.0, a release is published only after all six packages below and their SHA-256 sidecars are present. Earlier releases are macOS-only; consult the published asset list for availability.

| Package | OS & Architecture | Description |
| :--- | :--- | :--- |
| **`mdvu-X.Y.Z-windows-x86_64.msi`** | Windows 10 & 11 (`x86_64`) | Native Windows MSI installer (Start Menu shortcut, `PATH` CLI registration, `.md` file associations) |
| **`mdvu-X.Y.Z-windows-x86_64.zip`** | Windows 10 & 11 (`x86_64`) | Portable package containing `mdvu.exe` (GUI & CLI) and the WebView2 loader |
| **`mdvu-X.Y.Z-macos.dmg`** | macOS Universal (`arm64` + `x86_64`) | Graphical macOS installer with Drag-to-Applications |
| **`mdvu-X.Y.Z-macos-universal.zip`** | macOS Universal (`arm64` + `x86_64`) | Portable archive for both Apple Silicon and Intel |
| **`mdvu-X.Y.Z-macos-arm64.zip`** | macOS Apple Silicon (`arm64`) | Application containing only the Apple Silicon binaries |
| **`mdvu-X.Y.Z-macos-x86_64.zip`** | macOS Intel (`x86_64`) | Application containing only the Intel binaries |

---

### 3. Windows Installation & Usage

#### Option A: MSI Installer (Recommended)
1. Install Microsoft Edge WebView2 Runtime if it is absent (it is shared with the OS, not bundled in MDVu). Download **`mdvu-X.Y.Z-windows-x86_64.msi`** from [Releases](https://github.com/stpork/mdvu/releases).
2. **Interactive GUI install**:
   * Double-click the `.msi` package.
   * Check **Install for current user only (no administrator privileges needed)** to install without administrative privileges (installs to `%LOCALAPPDATA%\Programs\MDVu` without UAC elevation — the UAC shield icon dynamically disappears from the Install button).
   * Or leave it unchecked to install system-wide for all users (`C:\Program Files\MDVu`, requires UAC elevation).
   * Click **Install**, then **Finish**. The Start Menu shortcut launches the installed executable in the selected location.
3. **Silent / unattended install**:
   ```cmd
   :: Install just for current user (no admin rights required):
   msiexec /i mdvu-X.Y.Z-windows-x86_64.msi ALLUSERS=2 MSIINSTALLPERUSER=1 /qn

   :: Install for all users (system-wide, requires admin):
   msiexec /i mdvu-X.Y.Z-windows-x86_64.msi ALLUSERS=1 /qn
   ```
   * Automatically configures `mdvu` in `PATH` (user `PATH` for per-user, system `PATH` for all users).
   * Creates a Start Menu shortcut (`MDVu`) and registers `.md`, `.markdown`, `.mdown`, `.mkd` in Explorer's **Open with** menu.

#### Option B: Package manager manifests

When the release includes `mdvu.json`, Scoop can install the portable package:

```powershell
scoop install https://github.com/stpork/mdvu/releases/latest/download/mdvu.json
```

The build also generates WinGet and Chocolatey submission templates. Generation does **not** publish them to the public registries; use MSI or ZIP unless a registry listing has been verified.

#### Option C: Portable ZIP Archive
1. Download **`mdvu-X.Y.Z-windows-x86_64.zip`** from [Releases](https://github.com/stpork/mdvu/releases).
2. Extract the archive into your preferred tools folder (e.g. `C:\Tools\MDVu` or `%LOCALAPPDATA%\Programs\MDVu`).
3. Launch `mdvu.exe` directly or run it from command line or PowerShell:
   ```cmd
   mdvu.exe document.md
   ```

**Building & packaging from source on Windows:** (PowerShell produces MSI and ZIP; `./build.sh windows` on macOS/Linux cross-compiles the portable ZIP only.)
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

### 5. Build & Install From Source

Requirements: macOS 13.0+, Swift 6 / Xcode Command Line Tools (`xcode-select --install`), and the stable Rust toolchain with Cargo. Universal builds also require the `aarch64-apple-darwin` and `x86_64-apple-darwin` Rust targets. Windows builds require Rust, the MSVC C++ build tools and the Windows SDK; packaging additionally uses WiX as configured by `scripts/build-windows.ps1`.

The examples below build `develop`. For a published version, check out its corresponding `vX.Y.Z` tag before building.

```sh
git clone --branch develop https://github.com/stpork/mdvu.git
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

### 6. Command-line use from the macOS bundle

The CLI uses the same executable, Rust library and resources as the native app. Build the complete bundle and link its executable; copying the Swift binary alone omits required files.
```sh
git clone --branch develop https://github.com/stpork/mdvu.git
cd mdvu
make app
mkdir -p ~/.local/bin
ln -s "$PWD/dist/mdvu.app/Contents/MacOS/mdvu" ~/.local/bin/mdvu
```

---

## Usage

### Command Line Interface

```sh
# --- Interactive GUI Mode ---
# Open a single file
mdvu README.md

# macOS: open multiple files in separate windows (Windows accepts one path per invocation)
mdvu ARCHITECTURE.md CHANGELOG.md

# Open a directory (file navigator in List mode)
mdvu ~/Documents/Notes

# Force light, dark, or system theme
mdvu --theme dark document.md

# Select a Markdown dialect profile (also mkdocs, docusaurus, commonmark, hugo)
mdvu --dialect obsidian note.md

# Open directly in edge-to-edge Full Width mode
mdvu --full-width document.md

# --- Headless CLI Mode (No GUI Window) ---
# Export Markdown to an HTML file
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
| **`-s, --standalone`** | Export modifier: embed the required offline diagram & math engines | `false` |
| `--title <TITLE>` | Override document title | Automatic |
| `-t, --theme <system\|light\|dark>` | Color theme for document and diagrams | `system` |
| `-d, --dialect <PROFILE>` | Dialect profile: `generic`, `github`/`gfm`, `obsidian`, `mkdocs`, `docusaurus`, `commonmark`, `hugo`; automatic selection also accepts `auto` | Automatic, falling back to `generic` |
| `--full-width` | Open in edge-to-edge full width mode | macOS: saved preference; Windows: off |
| `--navigator` | Open with the File & Vault Navigator pane visible (`⌥⌘D`) | macOS: saved preference; Windows: off |
| `--no-mermaid` | Disable Mermaid/ZenUML and PlantUML-family diagrams | Diagram rendering enabled |
| `--snapshot <file.png>` | Headless render to PNG image and exit (macOS) | None |
| `--benchmark <FILE>` | Measure Markdown processing without opening the GUI | Disabled |
| `--version` | Display version information and exit (`-v` on macOS; `-V` on Windows) | None |
| `-h, --help` | Display command-line usage help | None |

---

## Features

### 🌐 Comprehensive Markdown Ecosystem & Dialect Support
`mdvu` brings unified compatibility across the most popular Markdown flavors in software engineering, technical documentation, and academic writing:

* **CommonMark & GitHub Flavored Markdown (GFM)**:
  * Shared Rust parsing via `pulldown-cmark` on both operating systems.
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
  * **View → Dialect Menu** on macOS: switch between Automatic, Generic, GitHub (GFM), Obsidian, MkDocs, Docusaurus, CommonMark and Hugo. Windows selects the dialect through `--dialect` or document directives.
  * **Frontmatter & Directive Auto-Detection**: Automatically detects dialect from YAML frontmatter (`dialect: obsidian`) or top-of-file HTML comment directives (`<!-- dialect: obsidian -->`), applying the optimal profile seamlessly.
* **Safe HTML & Styling**:
  * Preserves presentation markup and raw `<style>` blocks. A per-document nonce policy authorizes bundled scripts and blocks scripts and event handlers embedded in Markdown.
* **Code Fence Protection**:
  * The shared Rust dialect pipeline protects code blocks from inline transformations (including 3-backtick, 4-backtick ` ```` `, and tilde `~~~` fences).

---

### 📊 Offline Diagram Rendering (Mermaid, ZenUML & PlantUML)

`mdvu` bundles fully offline rendering engines compressed with **LZMA Ultra** for maximum storage efficiency:

* **Mermaid 12.2.0**:
  * **Core Grammars**: `flowchart`, `sequenceDiagram`, `classDiagram`, `stateDiagram-v2`, `erDiagram`, `gitGraph`, `gantt`, `pie`, `mindmap`, `quadrantChart`, `requirementDiagram`, `C4Context`, `C4Container`, `C4Component`, `C4Dynamic`, `C4Deployment`.
  * **Extended Types**: `ishikawa-beta` (fishbone diagrams), `swimlane-beta` (workflow swimlanes), `packet-beta` (binary packet protocols), `kanban`, `block-beta`, `architecture-beta`, `radar-beta`, `sankey-beta`, and `xychart-beta`.
  * **ZenUML Core 4.7.2 / Mermaid Plugin 1.0.1**: Support for concise ZenUML sequence diagrams within ````mermaid`` and standalone ````zenuml`` code blocks, sharing the same renderer and SVG cache.
  * **Auto-Quoting Resilience**: Grammar preprocessor automatically quotes unquoted labels containing hyphens in `requirementDiagram` and complex models.
* **PlantUML 1.2026.9 (`@plantuml/core`) + Graphviz (`Viz.js 3.31.0` / Graphviz 16.1.0)**:
  * **Offline JavaScript/WebAssembly**: Executes locally through TeaVM and Viz.js in WebKit on macOS or WebView2 on Windows. **No Java runtime (JRE/JVM) or external binaries required.**
  * **Fenced Blocks**: Supports both ````plantuml`` and ````puml`` code fences.
  * **UML Models**: Sequence diagrams, Class models with inheritance and associations, State machines, Activity diagrams, Component architectures, Object diagrams, Deployment diagrams, and Use-case models.
  * **Non-UML Families**: JSON/YAML data tree visualizers, Salt UI wireframes, Archimate enterprise models, MindMaps, Work Breakdown Structures (WBS), Gantt schedules, and Network (`nwdiag`) diagrams.
  * **Dark Mode & Transparency**: Automatically adapts to document theme with transparent SVG backgrounds.
  * **Included libraries**: C4-PlantUML 2.14.0 and ArchiMate 3.2.2 render offline through `!include <C4/C4_Context>`, `<C4/C4_Container>`, `<archimate/Archimate>` and their library files.
  * **DOT**: `@startdot` blocks use the same bundled Graphviz/Viz.js instance as PlantUML, with no additional engine or Java requirement.
  * **Runtime limits**: The JavaScript port supports fewer diagram types than the Java engine; Ditaa, standalone AsciiMath/LaTeX, chronology, Chen ER, files, board, wire, flow, HCL, BPM and git are not available. Other optional standard libraries are not bundled. Unsupported and error SVGs are reported as rendering errors.
* **Isolated Diagram Execution**:
  * Native builds generate diagrams in a separate renderer and attach SVGs near the reading viewport. The renderer is released after inactivity; a bounded queue and cache limit retained work.
* **On-Demand Lazy Decompression**:
  * Documents without diagrams do not load the diagram engines; their LZMA archives remain compressed.
  * macOS release bundles store compressed runtimes once in `Contents/Resources`, shared by both CPU architectures. Windows embeds them in the executable.
  * Documents with only Mermaid diagrams decompress only `mermaid.lzma` (1.64 MiB).
  * Documents with only PlantUML diagrams decompress only `plantuml.lzma` (1.22 MiB, including C4 and ArchiMate).
* **Runtime-aware SVG Disk Cache**:
  * SVGs are cached to `~/Library/Caches/mdvu/diagrams` on macOS and `%LOCALAPPDATA%\mdvu\Caches\diagrams` on Windows; `MDVU_CACHE_DIR` overrides the directory. Keys cover renderer, source, theme, app version and the locked runtime manifest.
  * Renders once; subsequent loads reuse cached SVG and bypass diagram generation.

---

### 🔍 Zoom Control `[-][ 100% ][+]`
* **Hardware-Accelerated Scaling**: WebKit handles continuous trackpad magnification. Frame rate depends on display refresh rate, document complexity, and system load; no fixed FPS guarantee is implied.
* **Magnetic Snapping ($\pm 2.5\%$)**: Micro-gestures within $\pm 2.5\%$ of clean 10% multiples (100%, 150%, 200%, 300%) snap cleanly to integers, eliminating jitter and phantom numbers (e.g. `201%` $\to$ `200%`).
* **Bounce-Back Settling Engine**: Rapid zoom-out bounce-back gestures settle at exact `1.0` (`100%`) via trailing spring timers.
* **Discrete 10% Stepping**: UI buttons and `⌘+` / `⌘-` step cleanly by 10% and snap to clean multiples.
* **Manual Entry & Boundaries**: Click the centered percentage field to type a custom value (e.g. `150`, `250%`), bounded between **10%** and **500%**.
* **Double-Click Reset**: Double-clicking the indicator resets the zoom level to 100% (`⌘0`).
* **Persistent Window Zoom**: Zoom level is preserved across Back/Forward navigation, link jumps, and file reloads.

---

### 📑 Native Window Controls
* **macOS**: Single-click the file name to open a file or folder; the dialog waits for the system double-click interval. Double-click the name to toggle the window's native Zoom size. Outside the name, double-click follows Desktop & Dock settings; dragging moves the window, and `⌘-click` reveals the document path. **File → Open…** (`⌘O`), **Window → Minimize / Zoom** and **View → Enter Full Screen** remain available.
* **Windows**: The native caption supports double-click to maximize/restore, drag to move, and right-click or `Alt+Space` for the system window menu. Caption buttons, Snap, `Alt+F4` and `F11` retain Windows behavior.

---

### 📐 Readable Measure vs. Full Width
* **Readable Measure (Default)**: Constrains body text to 920px with optimal line length (~70–85 characters) for effortless reading.
* **Full Width (`⇧⌘W`)**: Expands text, code, tables, and diagrams edge-to-edge across wide monitors.

---

### 🧭 macOS Trackpad Navigation & Two-Finger Swipe
* **Two-Finger History Swipe**: Horizontal trackpad swipes navigate Back and Forward when history is available.
* **Zoom Pan-Priority**: When zoomed in (`> 105%`), two-finger gestures seamlessly pan overflowing tables, code blocks, and diagrams without triggering history jumps.
* **Dynamic Back/Forward Validation**: Segmented history buttons in the toolbar visually enable or disable based on actual navigation history availability.

---

### 🗂️ File & Vault Navigator (`⌥⌘D`)
* **Matching Pane Headers**: Both panels have a leading icon, title and × button to hide the panel.
* **One File Navigator**: The right pane switches between **Tree** (folders and files) and **List** (recursive relative file paths). The left pane shows only the current document’s table of contents.
* **Smart Root Detection**: Automatically walks up directory ancestors looking for `.obsidian` or `.git` boundaries, anchoring the root at your true vault or repository level.
* **Folder Opening**: An explicitly opened folder stays the root while you browse its documents. macOS selects the first file in its sorted recursive list; Windows prefers a top-level README/index, then the first top-level Markdown file.
* **Background Scanning**: macOS loads Tree folders on demand and limits its recursive List to 5,000 files. Windows scans a tree up to six levels deep in the background and derives List mode from that tree. Both skip ignored directories, application packages and directory symlinks. Windows also accepts `.txt` files in its navigator and open dialog.
* **Active Selection**: Switching views preserves the current document without reloading it. Opening files and navigating Back/Forward highlights the active file in either view.
* **Native Keyboard & Click Flow**: Single-click opens files; double-click expands or collapses directories; Return/Enter opens the highlighted note.
* **Push-on/Push-off State**: Toolbar buttons for Table of Contents and File Navigator stay visually depressed when their respective panes are active.
* **CLI Flag**: Launch directly with navigator open using `mdvu --navigator <path>`.

---

## Keyboard Shortcuts

| Action | macOS | Windows |
| :--- | :--- | :--- |
| Open File | `⌘O` | `Ctrl+O` |
| Open Folder / Vault | `⌘O` (select a folder) | `Ctrl+Shift+O` |
| Close Window | `⌘W` | `Ctrl+W` / `Alt+F4` |
| Reload Document | `⌘R` | `F5` / `Ctrl+R` |
| Zoom In (+10%) | `⌘+` / `⌘=` | `Ctrl++` / `Ctrl+=` |
| Zoom Out (-10%) | `⌘-` | `Ctrl+-` |
| Actual Size (100%) | `⌘0` | `Ctrl+0` |
| Toggle Fullscreen | `^⌘F` | `F11` |
| Toggle Table of Contents | `^⌘S` | `Ctrl+B` |
| Toggle File / Vault Navigator | `⌥⌘D` | `Ctrl+Shift+D` |
| Find in Document | `⌘F` | `Ctrl+F` |
| Find Next / Previous | `⌘G` / `⇧⌘G` | `F3` / `⇧F3` |
| Toggle Full Width Mode | `⇧⌘W` | `Ctrl+Shift+W` |
| Navigate Back / Forward | `⌘[` / `⌘]` | `Alt+←` / `Alt+→` |
| Quit Application | `⌘Q` | `Alt+F4` |

---

## License & Credits

* **Author**: Finn de Bear ([finndebear@gmail.com](mailto:finndebear@gmail.com))
* **License**: Released under the [MIT License](LICENSE).

### Third-Party Software & Licenses
* [pulldown-cmark](https://github.com/raphlinus/pulldown-cmark) — MIT / Apache-2.0 (c) Raph Levien and pulldown-cmark contributors.
* [wry](https://github.com/tauri-apps/wry) & [tao](https://github.com/tauri-apps/tao) — MIT / Apache-2.0 (c) The Tauri Programme within The Commons Conservancy.
* [lzma-rust2](https://github.com/hasenbanck/lzma-rust2) — Apache-2.0.
* [Mermaid.js 12.2.0](https://github.com/mermaid-js/mermaid) — MIT (c) Knut Sveidqvist and Mermaid Contributors.
* [ZenUML Plugin 1.0.1](https://github.com/mermaid-js/mermaid-zenuml) — MIT (c) Mermaid Contributors.
* [PlantUML Core 1.2026.9](https://github.com/plantuml/plantuml) — MIT (c) PlantUML Team.
* [Viz.js 3.31.0 (Graphviz 16.1.0)](https://github.com/mdaines/viz.js) — MIT (c) Michael Daines, Graphviz Contributors.
* [KaTeX 0.19.0](https://github.com/KaTeX/KaTeX) — MIT (c) Emily Eisenberg, Sophie Alpert, and KaTeX Contributors.
