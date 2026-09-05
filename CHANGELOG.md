# Changelog

All notable changes to **mdvu** are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
