<div align="center">
  <img src="packaging/assets/AppIcon-256.png" alt="MDVu App Icon" width="128" height="128">
  <h1>MDVu - Superfast Markdown Viewer</h1>

  <p>
    The tiny, ultra-fast, ultra-compact and lightweight native Markdown viewer for <b>macOS &amp; Windows</b>.<br>
    Built with pure AppKit &amp; WebKit (macOS) and Win32 &amp; WebView2 (Windows). Zero Electron. Zero Node. Zero Telemetry. Markdown, math and diagrams render offline.
  </p>

  <p>
    <a href="https://github.com/stpork/mdvu/actions"><img src="https://github.com/stpork/mdvu/actions/workflows/ci.yml/badge.svg?branch=develop" alt="CI Status"></a>
    <a href="#installation"><img src="https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple" alt="macOS 13+"></a>
    <a href="#3-windows-installation--usage"><img src="https://img.shields.io/badge/Windows-10%20%2F%2011-0078D6?logo=windows" alt="Windows 10/11"></a>
    <a href="#installation"><img src="https://img.shields.io/badge/version-0.5.0-emerald" alt="Version 0.5.0"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-purple" alt="License MIT"></a>
  </p>
</div>

<p align="center">
  <img src="packaging/assets/MDVu.jpg" alt="mdvu screenshot" width="900" style="border-radius: 8px; box-shadow: 0 8px 30px rgba(0,0,0,0.12);">
</p>

---

## Why mdvu?

Read Markdown, diagrams and math in a compact native app for Mac and Windows. The rendering engines are included; a separate browser runtime is not bundled. See [measured sizes and UI performance](COMPARISON.md) and the [website](https://stpork.github.io/mdvu/#comparison).
* **Dual Native Engines**: Pure native **AppKit & WebKit** on macOS and native **Win32 & WebView2** on Windows. Both run on the shared `mdvu-core` Rust engine with zero Electron, Node, or JVM.
* **Responsive Reading**: Diagram execution uses a separate renderer so scrolling and zoom can continue while a diagram is being generated. Native fixture tests measure cold interaction latency and process memory.
* **Unified Markdown Engine**: High-throughput `pulldown-cmark` parser with CommonMark parsing, GFM extensions and security tagfiltering.
* **Rich Markdown Dialects & Extensions**: Native support for **GitHub GFM**, **Obsidian** (callouts `[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!DANGER]`, wiki-links `[[target|label]]`, and embeds `![[image.png]]`), **MkDocs** (`!!!`, `???`, `???+`), **Docusaurus / VuePress** (`:::note` containers), **CriticMarkup** (`{++add++}`, `{--del--}`, `{~~old~>new~~}`, `{==mark==}`, `{>>comment<<}`), **Subscript & Superscript** (`~sub~`, `^sup^`, `^^underline^^`), and **GitLab TOC** (`[[_TOC_]]`).
* **Native Math Formulas (LaTeX / KaTeX)**: Full offline rendering for inline (`$...$`) and display (`$$...$$` or ````math```` blocks) mathematical formulas via an LZMA-compressed KaTeX engine (~64 KB) and native MathML Core rendering with dark/light mode integration and zero font downloads.
* **Offline Diagrams (Mermaid, ZenUML & PlantUML)**: Bundled **Mermaid 12.2.0**, **ZenUML 1.0.1**, and **PlantUML Core 1.2026.9** + **Viz.js 3.31.0** (Graphviz 16.1.0) with **LZMA Ultra** compression. Renders 100% offline with zero Java requirement, independent lazy loading, isolated native diagram execution, and runtime-aware disk caching.
* **Native Zoom & Window Management**:
  * macOS: Trackpad pinch-to-zoom (`.magnify`), smart magnify (`.smartMagnify`), compound toolbar control (`[-][ 100% ][+]`), magnetic $\pm 2.5\%$ snapping, titlebar quick-open, and 3-pane split view with Vault Navigator (`⌥⌘D`).
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

This checkout documents **0.5.0 in development**. The current public release is **0.4.1 for macOS**; Windows installers and the updated engine/catalogue features described here are planned for 0.5.0. Check the release asset list before downloading.

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

### 6. Command-line use from the macOS bundle

The CLI uses the same executable, Rust library and resources as the native app. Build the complete bundle and link its executable; copying the Swift binary alone omits required files.
```sh
git clone https://github.com/stpork/mdvu.git
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
| `-d, --dialect <PROFILE>` | Dialect profile: `generic`, `github`/`gfm`, `obsidian`, `mkdocs`, `docusaurus`, `commonmark`, `hugo`; automatic selection also accepts `auto` | Automatic, falling back to `generic` |
| `--full-width` | Open in edge-to-edge full width mode | Saved preference |
| `--navigator` | Open with the File & Vault Navigator pane visible (`⌥⌘D`) | Saved preference |
| `--no-mermaid` | Disable Mermaid/ZenUML and PlantUML-family diagrams | Diagram rendering enabled |
| `--snapshot <file.png>` | Headless render to PNG image and exit (macOS) | None |
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
  * **ZenUML 1.0.1 Plugin**: Support for concise ZenUML sequence diagrams within ````mermaid`` and standalone ````zenuml`` code blocks, sharing the same renderer and SVG cache.
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

### 📑 macOS Document Titlebar Quick-Open
* Click the file name in the window titlebar to open the native `NSOpenPanel` sheet modal and switch files or folders in the current window.
* Full compatibility with macOS native window features: dragging the title moves the window, `⌘-click` reveals the Finder directory hierarchy, and the proxy icon can be dragged into Terminal or Mail.

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
* **Folder Opening**: Opening a folder shows List mode and opens its first sorted Markdown file. That folder stays the root while you browse its documents.
* **Bounded Scanning**: Tree mode loads folders on demand. List mode scans in the background, preserving the existing 5,000-file limit; ignored directories, packages and directory symlinks are skipped. Switching modes releases the previous model.
* **Active Selection**: Switching views preserves the current document without reloading it. Opening files and navigating Back/Forward highlights the active file in either view.
* **Native Keyboard & Click Flow**: Single-click opens files; double-click expands or collapses directories; Return/Enter opens the highlighted note.
* **Push-on/Push-off State**: Toolbar buttons for Table of Contents and File Navigator stay visually depressed when their respective panes are active.
* **CLI Flag**: Launch directly with navigator open using `mdvu --navigator <path>`.

---

## Performance & Sizing Benchmark

See **[COMPARISON.md](COMPARISON.md)** for measurement definitions, native UI checks, distribution sizing and reproducible commands. The current local macOS comparison includes eight applications, separate application-cache-cold and warm starts, process memory and a 73-example diagram catalogue. It remains incomplete: 136/192 startup observations and 135/192 verified full-document passes. Windows native checks are reported separately; there is no Windows competitor ranking.

Measurements vary with architecture, OS, document, and cache state. `make benchmark` runs five parser iterations after a warmup; it does not measure DOM rendering, scrolling, or diagram execution. The 0.4.1 checks and exact artifact sizes are recorded in [CHANGELOG.md](CHANGELOG.md).

| Property | Configuration / measurement |
| :--- | :--- |
| Application size | Depends on architecture and packaging; CI publishes release archives for each build |
| Compiler | `-O`, cross-module optimization, linker dead stripping, stripped Mach-O |
| Resources | Lazy LZMA decompression off the UI queue; reused for later documents |
| Cache | Shared Rust SVG cache: at most 128 entries / 16 MiB; persistent disk cache |
| Zoom | 10%–500%; native WebKit page zoom on macOS, document zoom on Windows; trackpad magnification follows macOS conventions |

For the previous measured build, `-Osize` saved less than 1% of the entire app while reducing parser throughput in that run, so the speed-oriented flags are retained. No formatting or parser capabilities have been removed to reduce size.

### TOC navigation and installed copies

Click a heading in the Contents pane to scroll to it, including clicking the same selected row again after scrolling away. Local `file://` navigation tolerates WebKit history API restrictions and uses native Back/Forward history. If a fix appears absent, verify the version in **About mdvu**: `/Applications/mdvu.app` and `~/Applications/mdvu.app` can contain different builds. Launch the newly installed copy explicitly.

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

## Architecture

`mdvu` uses a unified cross-platform hybrid architecture:
* **Core (`src/core`)**: Markdown parser (`pulldown-cmark`), dialect pipeline, runtime loading/cache and C-ABI FFI. Windows embeds the LZMA engines; packaged macOS builds share one resource copy between CPU architectures.
* **Shared GUI / CLI Entry Point**: The same frontend executable opens the GUI or exports HTML/TOC through CLI flags (`-o`, `--stdout`, `--toc`) and stdin. The macOS app also ships the Rust shared library and resources; Windows links the core into `mdvu.exe`.
* **macOS (`src/macos`)**: Hand-crafted native AppKit host with WebKit hardware-accelerated viewport, multi-pane split coordinator, trackpad gesture engine, and static FFI bridge.
* **Windows (`src/windows`)**: Lightweight standalone Win32 binary powered by Microsoft Edge WebView2, DWM dark mode, atomic-save file watching, and `AttachConsole` terminal integration.

The repository has one source root and one test root:

```text
src/core/          Shared Rust renderer and C ABI
src/macos/         Swift, AppKit and WebKit host
src/windows/       Rust, Win32 and WebView2 host
assets/            Shared CSS, JavaScript and compressed runtimes
tests/fixtures/   Shared Markdown fixtures and local assets
tests/macos/      Swift and WebKit regression tests
tests/ui/         Browser checks used on both platforms
tests/snapshots/  Reference images
packaging/macos/   macOS metadata and icon
packaging/windows/ MSI metadata and Windows branding
scripts/           Reproducible build, release and regression checks
```

Git contains application sources, locked renderer assets, packaging, documentation, regression tests, shared fixtures and approved reference images. Downloaded competitor applications, comparison tools, raw measurements, recordings and profiles stay locally under ignored `test-results/`; they are not source or release inputs. `COMPARISON.md` retains the readable results and methodology.

Build output belongs in `.build/`, `target/` and `dist/`. A checkout can be named `C:\Sources\mdvu` or placed anywhere else; no nested checkout is required.

Run `python3 -m unittest discover -s tests -p 'test_*.py'` for repository, release, installer-authoring and runtime-integrity checks. Run `make check` and `make coverage` on macOS. `./build.sh check` also runs the visual reference checks (Pillow and an active desktop required). After `make app`, `python3 scripts/test-macos-system.py` opens every fixture in the native UI. On Windows, run `cargo test --workspace`, `./scripts/build-windows.ps1`, then `./scripts/test-windows-system.ps1` from an interactive user session. The UI runners save checks, timing, process samples and screenshots for every Markdown fixture, including nested runtime cases. For a clean Windows test machine, run `./scripts/test-windows-installer.ps1 -Msi <path>` from an elevated interactive PowerShell. It tests the full MSI UI in both scopes, using a disposable standard Windows account and a verified non-elevated token for the user installation; checks Finish, shortcut targets/launch, associations and installed rendering; then uninstalls each test installation. It refuses to overwrite an existing installation and removes the temporary account, profile and staged test files afterward. Logs stay under `test-results/installer-windows/`. The system runner's `-Msi <path> -Install` option only performs a silent machine installation and is not the two-scope regression test. `./scripts/coverage-windows.ps1` includes native unit tests and an instrumented GUI session; its timings are separate from release performance measurements.

The shared control scenarios cover every 10% zoom step from 10% to 500% and back, endpoint clamping, manual zoom input/reset, TOC and file-panel hide/show, Tree/List, outline expansion/collapse and reading-position preservation during reflow. Fullscreen entry, interaction and exit follow the primary scenarios. Each action records its duration and reader dimensions. CI's timer mode checks controls and content without claiming frame performance or exercising desktop fullscreen transitions; run the default interactive mode for those checks.

Interactive regression ceilings are 250 ms for cold scrolling and 500 ms for a cold frame, zoom or pane reflow. Control timings include acknowledgement and two animation frames. Render-frame p95 remains a diagnostic distribution: the cold stress scenario repeatedly changes zoom while diagrams are being generated. Fullscreen transition durations are reported separately because they include the operating system's animation. These ceilings do not imply a constant frame rate or a globally optimal implementation.

For detailed diagrams and component design, see [ARCHITECTURE.md](ARCHITECTURE.md).

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

## Publishing a release

From a clean `develop` branch with a successful CI run for its exact commit:

```sh
./build.sh publish         # Download and validate all six CI packages; preview only
./build.sh publish --yes   # Merge, tag, wait for tested publication; update Homebrew/site
```

Use `python3 scripts/set-version.py X.Y.Z` to update `version.txt`, `Info.plist`, both Rust package versions and `Cargo.lock` together, then update the matching `CHANGELOG.md` section before pushing the release candidate. CI checks that these versions agree. The release helper never replaces an existing tag or public release. Tag CI tests Linux, macOS and Windows, builds all six packages, verifies SHA-256, uploads to a draft, checks the uploaded set, then makes it public. A failed or incomplete upload stays a draft. `release-manifest.json` records the exact source commit, package sizes and hashes.

The helper then updates Homebrew from the published cask, refreshes the website download links, and increments the development minor version. If tagging manually, dispatch **Deploy MDVu website** after successful publication and update Homebrew using the published `mdvu.rb`. Website measurements name their own tested revision; they are not silently relabelled as measurements of a new release.
