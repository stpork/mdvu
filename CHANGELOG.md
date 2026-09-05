# Changelog

All notable changes to **mdvu** are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-09-05

### Added
- **Ultra-Fast Native Architecture**: Built with pure AppKit and WebKit. Zero Electron, zero Node runtime, zero telemetry, and 100% offline. Cold start in ~150 ms, first paint in ~300 ms, with an ultra-compact ~1.8 MB Universal app bundle (<1.2 MB single-architecture, 1.1 MB compressed).
- **Reference-Grade Markdown Engine**: Powered by Apple/GitHub's reference `cmark-gfm` with full CommonMark and GitHub Flavored Markdown support (tables, task lists, autolinks, and strikethrough).
- **Obsidian Ecosystem Support**: Native handling of Obsidian-style callouts (`[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!DANGER]`, etc.) and `[[wikilinks]]` with internal document and anchor resolution.
- **Standardized Zoom Subsystem**: Compound `[-][ 100% ][+]` toolbar control featuring:
  - Smooth, real-time continuous trackpad pinch (`.magnify`) and `⌘ + Mouse Wheel` sync.
  - Discrete 10% stepping with automatic snapping from fractional gesture levels.
  - Manual percentage input field bounded strictly between **10%** and **500%**.
  - Double-click to instantly reset zoom to 100% (`⌘0`).
  - Persistent window zoom across document reloads, navigation history, and link jumps.
- **Document Titlebar Quick-Open**: Click directly on the filename in the window title to summon an `NSOpenPanel` modal sheet to switch files or folders within the current window, while preserving macOS proxy icon dragging and `⌘-click` folder hierarchy popups.
- **Two-Finger Navigation & Content Panning**: Intelligent trackpad gesture routing—two-finger horizontal swipes navigate Back and Forward when history is available, and automatically transition to smooth horizontal panning when zoomed in (`> 105%`) over wide tables and code blocks.
- **Offline Mermaid 11.x Diagrams**: Embedded LZMA-compressed resource (609 KB decompressed on demand), rendered asynchronously to SVG with theme-aware SHA-256 disk caching for instant subsequent views.
- **In-Page Search (`⌘F`)**: Instant keyword search with live match counters, highlighting, and smooth cycling (`⌘G` / `⇧⌘G`).
- **Full Width Mode (`⇧⌘W`)**: One-key toggle between readable typographic measure (920px max-width) and fluid edge-to-edge layout.
- **Atomic File Watching**: Live automatic reload on document save, supporting atomic file replacements in Vim, Xcode, and VS Code while preserving scroll position.
- **Headless PNG Snapshot (`--snapshot`)**: Fast command-line renderer for automation and visual regression testing.
- **Homebrew Cask Distribution**: Prepared automated tap packaging for `stpork/homebrew-tap` (`Casks/mdvu.rb`).
