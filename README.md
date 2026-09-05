# mdvu

<p align="center">
  <strong>The ultra-fast, lightweight native Markdown viewer for macOS.</strong><br>
  Built with pure AppKit & WebKit. Zero Electron. Zero Node. Zero Telemetry. 100% Offline.
</p>

<p align="center">
  <a href="#installation"><img src="https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple" alt="macOS 13+"></a>
  <a href="#installation"><img src="https://img.shields.io/badge/version-0.2.0-emerald" alt="Version 0.2.0"></a>
  <a href="#performance-and-size"><img src="https://img.shields.io/badge/bundle_size-1.8_MB_Universal-brightgreen" alt="Bundle Size 1.8 MB Universal"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-purple" alt="License MIT"></a>
</p>

<p align="center">
  <img src="Tests/Snapshots/kitchen-sink.png" alt="mdvu screenshot" width="900" style="border-radius: 8px; box-shadow: 0 8px 30px rgba(0,0,0,0.12);">
</p>

---

## Why mdvu?

Modern Markdown tools often bundle 150+ MB of Chromium and Node.js runtimes just to display formatted text. **mdvu** takes the opposite approach:
* **Blazing Fast**: Window visible in ~150 ms, first WebKit content painted in ~300 ms.
* **Ultra-Compact**: **1.8 MB** Universal app bundle (`arm64` + `x86_64`), under **1.2 MB** for single-architecture slices, and **1.1 MB** compressed release archive.
* **Cmark-GFM Engine**: Uses Apple / Swift's reference `cmark-gfm` parser with full CommonMark and GitHub Flavored Markdown compliance.
* **Obsidian-Friendly**: First-class support for Obsidian callouts (`[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!DANGER]`) and internal `[[wikilinks]]`.
* **Offline Diagrams**: Bundled Mermaid 11.x (LZMA-compressed) renders diagrams asynchronously to SVG with theme-aware SHA-256 disk caching.
* **Standardized Zoom Engine**: Unified continuous and discrete zoom (`[-][ 100% ][+]`), with manual percentage input, 10%–500% boundary control, trackpad pinch sync, and 10% discrete stepping.
* **Titlebar Quick-Open**: Click the window title to instantly open a new document or folder, preserving macOS proxy icon drag and directory popups.

---

## Installation

### Homebrew (Recommended)

Install via Homebrew Cask:

```sh
brew install --cask stpork/tap/mdvu
```

Or install directly from the tap repository:

```sh
brew install --cask https://raw.githubusercontent.com/stpork/homebrew-tap/main/Casks/mdvu.rb
```

### Manual Download

1. Download the latest release from the [GitHub Releases](https://github.com/stpork/mdvu/releases) page (`.dmg` or `-universal.zip`).
2. Open the `.dmg` and drag `mdvu.app` into `/Applications`.
3. *(If prompted by Gatekeeper for ad-hoc releases)*:
   ```sh
   xattr -d com.apple.quarantine /Applications/mdvu.app
   ```
4. *(Optional)* Link the CLI binary:
   ```sh
   ln -s /Applications/mdvu.app/Contents/MacOS/mdvu /usr/local/bin/mdvu
   ```

### Build From Source

Requirements: macOS 13+, Swift 6 / Command Line Tools.

```sh
git clone https://github.com/stpork/mdvu.git
cd mdvu
make app
make install # Installs to /Applications/mdvu.app
```

---

## Usage

### Command Line Interface

```sh
# Open a single file
mdvu README.md

# Open multiple files in separate tabs/windows
mdvu ARCHITECTURE.md CHANGELOG.md

# Open a directory (browsing mode with file list sidebar)
mdvu ~/Documents/Notes

# Force light, dark, or system theme
mdvu --theme dark document.md

# Select markdown dialect (generic, github, or obsidian)
mdvu --dialect obsidian note.md

# Open directly in edge-to-edge Full Width mode
mdvu --full-width document.md

# Headless snapshot generation (render Markdown to PNG without opening a window)
mdvu --snapshot output.png README.md
```

### CLI Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `--theme <system\|light\|dark>` | Color theme for document and diagrams | `system` |
| `--dialect <generic\|github\|obsidian>` | Parser dialect profile | `github` |
| `--full-width` | Open in edge-to-edge full width mode | Saved preference |
| `--no-mermaid` | Disable Mermaid diagram rendering | Enabled |
| `--snapshot <file.png>` | Headless render to PNG image and exit | None |

---

## Features

### 🔍 Standardized Zoom Control `[-][ 100% ][+]`
* **Discrete 10% Stepping**: UI buttons and `⌘+` / `⌘-` step cleanly by 10% and snap to clean multiples (e.g. `114%` $\to$ `120%`).
* **Live Gesture Sync**: Smooth trackpad pinch (`.magnify`) and `⌘ + Wheel` update the percentage indicator continuously in real time.
* **Manual Entry & Boundaries**: Click the centered percentage field to type a custom value (e.g. `150`, `250%`), bounded between **10%** and **500%**.
* **Double-Click Reset**: Double-clicking the indicator resets the zoom level to 100% (`⌘0`).
* **Persistent Window Zoom**: Zoom level is preserved across Back/Forward navigation, link jumps, and file reloads.

### 📑 Document Titlebar Quick-Open
* Click the file name in the window titlebar to open the native `NSOpenPanel` sheet modal and switch files or folders in the current window.
* Full compatibility with macOS native window features: dragging the title moves the window, `⌘-click` reveals the Finder directory hierarchy, and the proxy icon can be dragged into Terminal or Mail.

### 📐 Readable Measure vs. Full Width
* **Readable Measure (Default)**: Constrains body text to 920px with optimal line length (~70–85 characters) for effortless reading.
* **Full Width (`⇧⌘W`)**: Expands text, code, tables, and diagrams edge-to-edge across wide monitors.

### 🧭 Navigation & Two-Finger Swipe
* **Two-Finger History Swipe**: Horizontal trackpad swipes navigate Back and Forward when history is available.
* **Zoom Pan-Priority**: When zoomed in (`> 105%`), two-finger gestures seamlessly pan overflowing tables, code blocks, and diagrams without triggering history jumps.

### 📊 Offline Mermaid Diagrams
* Mermaid 11.x is bundled locally as an LZMA-compressed resource (609 KB) and decompressed on-demand on the first encounter of an uncached diagram.
* Rendered SVGs are cached to `~/Library/Caches/com.mdvu.viewer/diagrams` by SHA-256 hash and color scheme, enabling instant subsequent views.

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘O` | Open File or Folder |
| `⌘W` | Close Window |
| `⌘F` | Find in Document |
| `⌘G` / `⇧⌘G` | Find Next / Find Previous |
| `⌘+` / `⌘=` | Zoom In (+10%) |
| `⌘-` | Zoom Out (-10%) |
| `⌘0` | Actual Size (100%) |
| `⇧⌘W` | Toggle Full Width / Readable Width |
| `⌘[` / `⌘←` | Navigate Back in History |
| `⌘]` / `⌘→` | Navigate Forward in History |
| `⌘R` | Reload Document |
| `⌘Q` | Quit mdvu |

---

## Architecture

`mdvu` is designed as an ultra-efficient single-process pipeline:
```
File on Disk / Watcher
        │
        ▼
MarkdownPipeline (Preprocessing: Callouts, Wikilinks)
        │
        ▼
cmark-gfm (C AST Parser, GFM Extensions, Safe Mode)
        │
        ▼
HTMLDocument Assembly (Theme, Highlighting, CSS)
        │
        ▼
WKWebView (AppKit Chrome + Hardware Accelerated Rendering)
        │
        ▼
Async DiagramRenderer (Mermaid SVG + SHA-256 Cache)
```
For technical details, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## License & Credits

* **Author**: Finn de Bear ([finndebear@gmail.com](mailto:finndebear@gmail.com))
* **License**: Released under the [MIT License](LICENSE).

### Third-Party Software
* [swift-cmark](https://github.com/swiftlang/swift-cmark) — BSD-2-Clause / MIT (c) John MacFarlane, GitHub, Apple.
* [Mermaid.js](https://github.com/mermaid-js/mermaid) — MIT (c) Knut Sveidqvist and Mermaid Contributors.
