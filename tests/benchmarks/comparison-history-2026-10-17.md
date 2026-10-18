# Historical measurements — superseded comparison draft

Not the current competitor ranking. Old fixture syntax, SVG error classification and exploratory memory data have been superseded by COMPARISON.md. Native MDVu before/after tests retain their named revisions and protocol.

<!-- competitor-study-start -->
## Local competitor study — 17 October 2026

Status: in progress, local preview only. Renderer update `47356db` passed 37 macOS fixtures; 37 Windows fixtures also passed; the wider competitor study is paused. Fresh MDVu and competitor performance runs must be recorded before publishing a speed ranking. Marked 3 is skipped: the user declined a subscription-based trial.

### Historical competitor diagram output (73 original examples)

Identical examples were extracted unchanged from project fixtures. Each app was inspected in its rendered UI. Plain fenced code is **source**, not a rendered diagram. An SVG containing a PlantUML error panel is **error**, not success. These 73 selected examples do not prove conformance for every construct in a language.

| Application | Version | Rendered | Error | Source |
| --- | --- | ---: | ---: | ---: |
| Typora | 1.14.10 | 31 | 6 | 36 |
| Obsidian | 1.14.4 | 29 | 8 | 36 |
| MacDown 3000 | 3000.0.7 | 27 | 10 | 36 |
| MarkViewer | 1.8.15 | 30 | 7 | 36 |
| MD-Viewer | 1.2.1 | 0 | 0 | 73 |

MacDown: Mermaid 11.12.1; code highlighting, Mermaid and TeX enabled. MarkViewer: default live editor with the cursor moved out of fenced code, no plugins. MD-Viewer: stock app, no plugins. Typora uses Mermaid 11.13.0. Obsidian was checked in stock reading mode, with Mermaid allowed for the isolated fixture vault; its virtualized preview sections were scrolled into view. VS Code case checks remain incomplete.

The old MDVu count of 70/73 is withdrawn: several SVG diagnostic panels were incorrectly counted as diagrams. The current MDVu verification uses the expanded 114-example catalogue, checks SVG diagnostics and opens each example in its own native process. Its results are reported separately below; D071 includes an explicit fixture syntax correction, so the new count must not be treated as an identical-input ranking against this historical table.

The [machine-readable case catalogue](diagram-compatibility.json) retains original fixture paths, line numbers, diagram-source SHA-256 values, per-case status and local AX evidence filenames. Raw evidence is under `test-results/competitors/`.

<details>
<summary>Historical competitor outcomes on the 73 original examples</summary>

| Case | Engine / syntax | Original example | Typora | Obsidian | MacDown 3000 | MarkViewer | MD-Viewer |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D001 | mermaid / flowchart | [1.1 System at a Glance](../fixtures/test-light.md#L70) | rendered | rendered | rendered | rendered | source |
| D002 | mermaid / C4Context | [2.1 Stakeholder Context — C4](../fixtures/test-light.md#L108) | rendered | rendered | rendered | rendered | source |
| D003 | mermaid / requirementDiagram | [2.3 Requirement Relationships](../fixtures/test-light.md#L141) | error | error | error | error | source |
| D004 | mermaid / quadrantChart | [2.5 Quality Trade-off Quadrants](../fixtures/test-light.md#L183) | rendered | rendered | rendered | rendered | source |
| D005 | mermaid / C4Container | [3.1 Container View](../fixtures/test-light.md#L208) | rendered | rendered | rendered | rendered | source |
| D006 | mermaid / C4Component | [3.2 Component View](../fixtures/test-light.md#L233) | rendered | rendered | rendered | rendered | source |
| D007 | mermaid / architecture-beta | [3.3 Architecture Service Map](../fixtures/test-light.md#L257) | rendered | rendered | rendered | rendered | source |
| D008 | mermaid / erDiagram | [4.1 Content Data Model](../fixtures/test-light.md#L290) | rendered | rendered | rendered | rendered | source |
| D009 | mermaid / sankey | [4.3 Publication Data Flow](../fixtures/test-light.md#L361) | rendered | rendered | rendered | rendered | source |
| D010 | mermaid / sequenceDiagram | [4.4 Search and Read Sequence](../fixtures/test-light.md#L374) | rendered | rendered | rendered | rendered | source |
| D011 | mermaid / stateDiagram-v2 | [5.3 Security State Model](../fixtures/test-light.md#L445) | rendered | rendered | rendered | rendered | source |
| D012 | mermaid / ishikawa-beta | [5.4 Risk Analysis — Ishikawa](../fixtures/test-light.md#L462) | rendered | rendered | error | rendered | source |
| D013 | mermaid / C4Dynamic | [6.2 Dynamic Render Path — C4](../fixtures/test-light.md#L511) | rendered | rendered | rendered | rendered | source |
| D014 | mermaid / zenuml | [6.3 Alternative Interaction — ZenUML](../fixtures/test-light.md#L526) | rendered | error | error | error | source |
| D015 | mermaid / swimlane-beta | [6.4 Workflow Swimlanes](../fixtures/test-light.md#L542) | error | error | error | error | source |
| D016 | mermaid / C4Deployment | [7.1 Deployment View](../fixtures/test-light.md#L572) | rendered | rendered | rendered | rendered | source |
| D017 | mermaid / gantt | [7.2 Release Timeline](../fixtures/test-light.md#L596) | rendered | rendered | rendered | rendered | source |
| D018 | mermaid / gitGraph | [7.3 Git Release Flow](../fixtures/test-light.md#L615) | rendered | rendered | rendered | rendered | source |
| D019 | mermaid / stateDiagram | [8.1 Operational State Machine](../fixtures/test-light.md#L652) | rendered | rendered | rendered | rendered | source |
| D020 | mermaid / xychart | [8.3 Example Performance Trend](../fixtures/test-light.md#L675) | rendered | rendered | rendered | rendered | source |
| D021 | mermaid / radar-beta | [8.4 Capability Radar](../fixtures/test-light.md#L688) | rendered | rendered | rendered | rendered | source |
| D022 | mermaid / timeline | [9.2 Capability Roadmap](../fixtures/test-light.md#L719) | rendered | rendered | rendered | rendered | source |
| D023 | mermaid / kanban | [9.3 Delivery Portfolio](../fixtures/test-light.md#L734) | rendered | rendered | rendered | rendered | source |
| D024 | mermaid / mindmap | [9.4 Product Capability Tree](../fixtures/test-light.md#L750) | rendered | rendered | rendered | rendered | source |
| D025 | mermaid / treemap-beta | [9.5 Portfolio Treemap](../fixtures/test-light.md#L775) | rendered | rendered | rendered | rendered | source |
| D026 | mermaid / graph | [12.1 Legacy graph Alias](../fixtures/test-light.md#L1850) | rendered | rendered | rendered | rendered | source |
| D027 | mermaid / classDiagram | [12.3 Class Model](../fixtures/test-light.md#L1878) | rendered | rendered | rendered | rendered | source |
| D028 | mermaid / journey | [12.4 User Journey](../fixtures/test-light.md#L1903) | rendered | rendered | rendered | rendered | source |
| D029 | mermaid / pie | [12.5 Pie Chart](../fixtures/test-light.md#L1920) | rendered | rendered | rendered | rendered | source |
| D030 | mermaid / block-beta | [12.6 Block Diagram](../fixtures/test-light.md#L1932) | rendered | rendered | rendered | rendered | source |
| D031 | mermaid / packet | [12.7 Packet Diagram](../fixtures/test-light.md#L1943) | rendered | rendered | rendered | rendered | source |
| D032 | mermaid / eventmodeling | [12.8 Event Modeling](../fixtures/test-light.md#L1958) | error | error | error | error | source |
| D033 | mermaid / treeView-beta | [12.9 Tree View](../fixtures/test-light.md#L1971) | error | error | error | error | source |
| D034 | mermaid / venn-beta | [12.10 Venn Diagram](../fixtures/test-light.md#L1988) | rendered | rendered | error | rendered | source |
| D035 | mermaid / wardley-beta | [12.11 Wardley Map](../fixtures/test-light.md#L2004) | error | error | error | rendered | source |
| D036 | mermaid / cynefin-beta | [12.12 Cynefin View](../fixtures/test-light.md#L2024) | error | error | error | error | source |
| D037 | mermaid / zenuml | [12.23 ZenUML Advanced Control Flow](../fixtures/test-complete.md#L2573) | rendered | error | error | error | source |
| D038 | plantuml / @startuml | [13.1.1 Sequence Diagram](../fixtures/test-complete.md#L2622) | source | source | source | source | source |
| D039 | plantuml / @startuml | [13.1.2 Use Case Diagram](../fixtures/test-complete.md#L2652) | source | source | source | source | source |
| D040 | plantuml / @startuml | [13.1.3 Class Diagram](../fixtures/test-complete.md#L2673) | source | source | source | source | source |
| D041 | plantuml / @startuml | [13.1.4 Object Diagram](../fixtures/test-complete.md#L2697) | source | source | source | source | source |
| D042 | plantuml / @startuml | [13.1.5 Activity Diagram — Current Syntax](../fixtures/test-complete.md#L2719) | source | source | source | source | source |
| D043 | puml / @startuml | [13.1.6 Activity Diagram — Legacy Syntax Probe](../fixtures/test-complete.md#L2739) | source | source | source | source | source |
| D044 | plantuml / @startuml | [13.1.7 Component Diagram](../fixtures/test-complete.md#L2755) | source | source | source | source | source |
| D045 | plantuml / @startuml | [13.1.8 Deployment Diagram](../fixtures/test-complete.md#L2775) | source | source | source | source | source |
| D046 | plantuml / @startuml | [13.1.9 State Diagram](../fixtures/test-complete.md#L2795) | source | source | source | source | source |
| D047 | plantuml / @startuml | [13.1.10 Timing Diagram](../fixtures/test-complete.md#L2811) | source | source | source | source | source |
| D048 | plantuml / @startjson | [13.2.1 JSON Data](../fixtures/test-complete.md#L2835) | source | source | source | source | source |
| D049 | plantuml / @startyaml | [13.2.2 YAML Data](../fixtures/test-complete.md#L2850) | source | source | source | source | source |
| D050 | plantuml / @startebnf | [13.2.3 EBNF Diagram](../fixtures/test-complete.md#L2867) | source | source | source | source | source |
| D051 | plantuml / @startregex | [13.2.4 Regex Diagram](../fixtures/test-complete.md#L2879) | source | source | source | source | source |
| D052 | plantuml / @startnwdiag | [13.2.5 Network Diagram (nwdiag)](../fixtures/test-complete.md#L2889) | source | source | source | source | source |
| D053 | plantuml / @startsalt | [13.2.6 Salt Wireframe](../fixtures/test-complete.md#L2906) | source | source | source | source | source |
| D054 | plantuml / @startuml | [13.2.7 ArchiMate Diagram](../fixtures/test-complete.md#L2923) | source | source | source | source | source |
| D055 | plantuml / @startuml | [13.2.8 SDL Shapes](../fixtures/test-complete.md#L2935) | source | source | source | source | source |
| D056 | plantuml / @startditaa | [13.2.9 Ditaa Diagram](../fixtures/test-complete.md#L2953) | source | source | source | source | source |
| D057 | plantuml / @startgantt | [13.2.10 Gantt Diagram](../fixtures/test-complete.md#L2969) | source | source | source | source | source |
| D058 | plantuml / @startchronology | [13.2.11 Chronology Diagram](../fixtures/test-complete.md#L2981) | source | source | source | source | source |
| D059 | plantuml / @startmindmap | [13.2.12 MindMap Diagram](../fixtures/test-complete.md#L2992) | source | source | source | source | source |
| D060 | plantuml / @startwbs | [13.2.13 WBS Diagram](../fixtures/test-complete.md#L3012) | source | source | source | source | source |
| D061 | plantuml / @startmath | [13.2.14 Standalone AsciiMath](../fixtures/test-complete.md#L3032) | source | source | source | source | source |
| D062 | plantuml / @startlatex | [13.2.15 Standalone JLaTeXMath](../fixtures/test-complete.md#L3040) | source | source | source | source | source |
| D063 | plantuml / @startuml | [13.2.16 Information Engineering Diagram](../fixtures/test-complete.md#L3048) | source | source | source | source | source |
| D064 | plantuml / @startchen | [13.2.17 Chen ER Diagram](../fixtures/test-complete.md#L3067) | source | source | source | source | source |
| D065 | plantuml / @startchart | [13.2.18 Chart Diagram](../fixtures/test-complete.md#L3086) | source | source | source | source | source |
| D066 | plantuml / @startfiles | [13.2.19 Files Tree Diagram](../fixtures/test-complete.md#L3098) | source | source | source | source | source |
| D067 | plantuml / @startboard | [13.3.1 Board Diagram](../fixtures/test-complete.md#L3115) | source | source | source | source | source |
| D068 | plantuml / @startwire | [13.3.2 Wire Diagram](../fixtures/test-complete.md#L3128) | source | source | source | source | source |
| D069 | plantuml / @startuml | [13.4.1 Hyperlinks, Tooltips, Creole and Unicode](../fixtures/test-complete.md#L3141) | source | source | source | source | source |
| D070 | plantuml / @startuml | [13.4.2 Style and Handwritten Option](../fixtures/test-complete.md#L3163) | source | source | source | source | source |
| D071 | plantuml / @startuml | [13.4.3 Preprocessor and Standard Library Include](../fixtures/test-complete.md#L3180) | source | source | source | source | source |
| D072 | plantuml / @startuml | [13.4.4 Teoz Sequence Engine](../fixtures/test-complete.md#L3194) | source | source | source | source | source |
| D073 | zenuml / Viewer->Parser: | [DIA-010 — Standalone zenuml fence alias](../fixtures/test-complete.md#L6237) | source | source | source | source | source |
</details>

### MDVu renderer update: native macOS verification

Build `47356db`, Apple M1 / 8 GiB / macOS 27.0.1: **37/37 fixtures passed**. The five main documents exercised cold-render input, the full 10–500–10% zoom range, panels, outline and folder expansion, reflow and native fullscreen. The run initially repeated the control matrix on 23 files; the remaining 14 used the reduced rendering profile. Future runs use the shared five-document control policy by default. A separate rerun confirmed that the new policy still executes the full matrix on `test-onescreen.md`.

| Fixture | Warm scroll frame p95 | Maximum zoom control | Maximum fullscreen transition | Peak aggregate physical footprint |
| --- | ---: | ---: | ---: | ---: |
| test-heavy.md | 18 ms | 248 ms | 835 ms | 1270.5 MiB |
| test-complete.md | 17 ms | 180 ms | 700 ms | 1155.1 MiB |
| test-medium.md | 18 ms | 163 ms | 766 ms | 764.3 MiB |
| test-light.md | 18 ms | 118 ms | 667 ms | 742.3 MiB |
| test-onescreen.md | 18 ms | 129 ms | 725 ms | 613.3 MiB |

One isolated cold-cache native run per fixture; five scroll traversals, last four pooled within each file. Zoom durations include IPC, state application and two frames. Fullscreen includes the macOS animation. Memory is the peak across the entire cold-render/control scenario, including WebKit and the isolated renderer; it is not steady idle memory and must not be ranked against the exploratory competitor table.

[Per-fixture checks and metrics](runtime-update-2026-10-17.json) include runtime versions, compressed-asset hashes, native executable and Rust library hashes, fixture hashes and raw-evidence paths.

### MDVu renderer update: native Windows verification

Build `47356db`, Intel i7-7700K / Windows 10 IoT Enterprise / RDP: **37/37 fixtures passed**, no system-runner failures (117 checks). The original full matrix completed on every fixture; after syncing `d782557`, a separate `test-onescreen.md` run confirmed the representative control policy, also without failures. Source synchronization used a verified Git bundle and fast-forward merge; no GitHub push or site deployment was performed.

| Fixture | Warm scroll frame p95 | Maximum zoom control | Maximum fullscreen transition | Peak process-tree private bytes |
| --- | ---: | ---: | ---: | ---: |
| test-complete.md | 33.5 ms | 242.3 ms | 124.7 ms | 627.0 MiB |
| test-heavy.md | 31.9 ms | 269.6 ms | 125.7 ms | 908.6 MiB |
| test-light.md | 31.7 ms | 156.3 ms | 126.9 ms | 467.3 MiB |
| test-medium.md | 31.7 ms | 187.8 ms | 110.0 ms | 467.3 MiB |
| test-onescreen.md | 32.0 ms | 187.5 ms | 146.7 ms | 375.9 MiB |

RDP schedules display frames near 32 ms on this setup. These frame intervals are not input latency, and Windows private bytes are not directly comparable with macOS physical footprint. Raw UI reports, screenshots and process samples are saved in `test-results/runtime-update/windows/` and the transport archive. The temporary NAS test session and its transfer server were stopped after the reports arrived.

### Locally rebuilt distribution packages

Renderer revision `47356db`, source revision `d782557`. All four macOS packages were rebuilt locally with ARM and Intel slices; the two Windows packages were built on NAS. These candidates have not been published.

| Package | Bytes | MiB |
| --- | ---: | ---: |
| mdvu-0.5.0-windows-x86_64.msi | 5,013,504 | 4.78 |
| mdvu-0.5.0-windows-x86_64.zip | 4,548,568 | 4.34 |
| mdvu-0.5.0-macos-arm64.zip | 3,996,258 | 3.81 |
| mdvu-0.5.0-macos-universal.zip | 8,025,893 | 7.65 |
| mdvu-0.5.0-macos-x86_64.zip | 4,128,056 | 3.94 |
| mdvu-0.5.0-macos.dmg | 8,356,792 | 7.97 |

Compressed engine archives total 3,018,085 bytes (LZMA1 preset 9 extreme), up 295,734 bytes from the previous bundles. Runtime source, compressed sizes, exact versions and SHA-256 hashes are locked in `scripts/runtime-assets/manifest.json`; normal builds do not require npm.

### Exploratory memory measurements

Apple M1, 8 GiB, macOS 27.0.1. Three trials per file; median aggregate physical footprint over seconds 8–10, sampled every 200 ms, including app helpers and newly created WebKit services. MiB = 1,048,576 bytes. These are preliminary measurements with differing operations and output coverage; they are **not a ranking** and do not describe startup or all-diagrams-ready memory.

| Application / operation | light | medium | complete | heavy |
| --- | ---: | ---: | ---: | ---: |
| MD-Viewer — explicit file open; no diagram output | 386.6 MiB | 483.2 MiB | 614.3 MiB | 1099.1 MiB |
| Obsidian — external-save reload | 403.7 MiB | 408.4 MiB | 483.3 MiB | 1106.3 MiB |
| MacDown 3000 — external-save reload | 129.0 MiB | 155.1 MiB | 170.3 MiB | 322.4 MiB |

MacDown’s 10-second window may end before diagram work settles. The new MDVu native full-control run samples a different lifecycle; its peak must not be inserted into this table as a comparable idle value. Existing Obsidian first-updated-text measurements (112 / 217 / 241 / 645 ms for light / medium / complete / heavy) are save-to-marker plus two animation frames in an already-open preview, not process startup, file-open time or diagram completion. The exploratory scroll probe had too few samples and is excluded.

<!-- competitor-study-end -->

## What is measured

| Measurement | Meaning |
| --- | --- |
| Parser benchmark | Markdown processing in the Rust core; excludes browser layout, paint and diagram execution |
| CLI export | A separate process exports HTML, including the requested embedded assets; excludes displaying that HTML |
| First window / document ready | Native window detection and the browser's readiness callback; neither guarantees that every diagram has rendered |
| Cold frame / scrolling / zoom | Actual animation frames and control completion while diagrams are generated from an empty fixture cache |
| Full zoom range | Every 10% step from 10% to 500% and back, manual input, clamping and reset |
| Panels and fullscreen | TOC/navigator visibility, outline expansion, width changes, reading position, native fullscreen entry, interaction and exit |
| Process memory | App and browser processes sampled throughout the fixture, including the separate diagram renderer |

A control duration includes native IPC, application of the state and two animation frames. macOS fullscreen duration also includes the operating system's transition animation. These values are not hardware input latency. Windows measurements through RDP include its display scheduling. Compare before/after on the same machine, rather than ranking the two operating systems against each other.

macOS records physical footprint across the app and WebKit processes created during an isolated run. Windows records process-tree private bytes. The memory definitions differ; shared working-set sums would count shared pages more than once. A small executable does not imply a small GUI working set.

## Reproducing measurements

Build and run from an unlocked, interactive desktop. Avoid concurrent builds, browser launches and other benchmarks. The five documents listed in `tests/ui/control-fixtures.json` exercise the full native control matrix and fullscreen. Other fixtures verify content, rendering, error recovery and security; scrolling is sampled only when the document overflows its viewport. Use `--controls all` on macOS or `-ControlScope all` on Windows for an explicit exhaustive stress run.

Each fixture starts with an empty diagram cache (including repeated runs into the same output directory); the harness saves checks, screenshots, timings and process samples. Preserve the output directory and the source commit before testing another revision.

```sh
# macOS: native unit tests, release build, all Markdown fixtures
make test
make app
python3 scripts/test-macos-system.py --output test-results/macos-after

# Compare preserved before/after runs of the same native scenarios
python3 scripts/compare-ui-results.py test-results/macos-before/results.json test-results/macos-after/results.json --output test-results/macos-comparison.csv

# Parser processing only
make benchmark

# End-to-end CLI export, including process launch (not GUI rendering)
python3 scripts/bench-comparison.py
```

```powershell
# Windows: run in an interactive desktop session
cargo test --workspace
./scripts/build-windows.ps1
./scripts/test-windows-system.ps1 -Exe ./dist/windows/mdvu.exe -FixtureFilter '*.md' -Output ./test-results/windows-after
```

The default system-test mode uses real animation frames and tests native fullscreen after the primary controls. CI uses an explicit timer mode to verify content and controls on hosted runners; its synthetic frames are not a performance measurement and it skips desktop fullscreen transitions. Performance ceilings are regression limits, not a guarantee of immediate response or a fixed frame rate.

The original `scrollFrameP95Ms` records the first traversal after diagram generation. Fonts and skipped text can still require their first layout during that pass. Use `--warm-passes 5` on macOS or `-WarmPasses 5` on Windows to retain five separate frame arrays in `scrollWarmPasses`: the first-pass metric stays unchanged, and subsequent passes measure already visited content. Compare the same mode and fixture on both revisions; keep first-use spikes visible rather than averaging them into the warm passes.

Distribution sizes must be reported for a named commit and architecture. Measure the complete `.app`, not just its launcher: macOS ships the Swift executable, Rust library and resources. A universal bundle contains both architectures. Windows publishes a portable executable/archive and MSI; its writable WebView2 profile belongs in `%LOCALAPPDATA%`, outside `dist`.

## Recorded build: 0.5.0 / 40892c5 / 17 October 2026

These historical native results identify the measured revision independently of the latest published release. [CI run 39052275911](https://github.com/stpork/mdvu/actions/runs/39052275911) supplied the distribution packages below.

| Package | Bytes | MiB |
| --- | ---: | ---: |
| macOS Universal DMG | 7,773,160 | 7.41 |
| macOS ARM portable ZIP | 3,710,489 | 3.54 |
| macOS Universal portable ZIP | 7,417,369 | 7.07 |
| macOS Intel portable ZIP | 3,804,494 | 3.63 |
| Windows x64 MSI | 4,714,496 | 4.50 |
| Windows x64 portable ZIP | 4,293,241 | 4.09 |

The native ARM app bundle was 4,797,484 bytes (4.58 MiB); the Windows executable was 5,775,872 bytes (5.51 MiB), excluding its loader and system WebView2 runtime. These are different artifacts from the compressed installers.

37 fixtures per platform, 4,676 control checks per platform, zoom 10–500–10%, panels and native fullscreen were exercised. Five scroll traversals per fixture retained their frame arrays; the last four traversals provide the warm-scroll values below. Apple M1 / 8 GiB / macOS 27.0.1 and Intel i7-7700K / Windows 10 IoT Enterprise through RDP were used. Before: `b8b55f1`; after: `40892c5`.

| Recorded measurement | macOS before → after | Windows before → after |
| --- | ---: | ---: |
| Warm frame interval, pooled p95 | 18 → 19 ms | 32.2 → 32.2 ms |
| Warm frame interval, maximum | 25 → 22 ms | 62.8 → 62.8 ms |
| Maximum zoom control duration, all fixtures | 331 → 254 ms | 333 → 293.7 ms |

These results do not establish a universal speedup. macOS `test-complete.md` zoom maximum increased from 183 to 254 ms and peak footprint from 992.8 to 1,074.24 MiB. Windows `test-heavy.md` tail private bytes increased from 499.9 to 529.2 MiB. First-use layout and fullscreen transitions remain distinct from warm scrolling. The saved fixture data retains regressions as well as improvements.
