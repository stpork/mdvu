# Performance and compatibility comparison

**Measurements recorded 18 October 2026; verification updated 19 October 2026.** Apple M1, 8 GiB, macOS 27.0.1. Eight applications in the current series (seven in the earlier tables), the same five project fixtures, five diagram-free derivatives and the supported diagram catalogue. Marked was excluded from the earlier tables and is now part of the new protocol. These are macOS results; they are not Windows competitor measurements.

The strongest observed MDVu advantages here are its complete Universal app size and built-in diagram coverage. It is not fastest on every file or lowest in memory on every workload. Editors and knowledge bases have features beyond a dedicated viewer; the comparison concerns reading the tested documents with built-in renderers.

## New complete-traversal protocol · incomplete

Eight applications: MDVu, activated Typora, Obsidian, MacDown 3000, MarkViewer, MD Viewer, VS Code and activated Marked 3.2.21. One document per fresh process. Cold clears identified regenerable application caches; macOS filesystem cache remains. Warm follows a full cold traversal of the same file. No plugins or external rendering server. [Measurement protocol](#measurement-protocol).

**Qualified startup observations: 136 / 192; verified EOF: 135 / 192; handled: 136 / 192.** Calibration attempts and missing dependencies/session failures are retained with exclusion reasons, not mixed into this table. Earlier prepared-profile observations remain below under their original scope.

First readable body is timed from process birth using compositor frames before the first input/focus intervention. The two-node Mermaid control requires the actual visible SVG. Ranges preserve sparse-frame uncertainty. RAM is summed physical footprint, median in seconds 7–8 / peak in seconds 0–8, including helper processes. Detailed RAM cells show median at 8 s / first-8-s peak / full-pass peak. The last is diagnostic and includes later Accessibility overhead; it is not a clean startup-memory ranking. Earliest valid completed pair selected per app/file; later valid repeats retained separately. One selected observation per cell; no statistical ranking or universal speed claim.

Phases without a † marker reached their actual EOF through viewport-sized scroll steps, with recorded frames/OCR and end context. Reaching EOF does not mean every diagram rendered. Traversal wall time includes test cadence and checks; it is not render speed. Zoom and scrolling FPS are not measured. † means the untouched startup observation is qualified, but subsequent traversal was not confirmed by the adapter; its observed peak must not be described as a full-file peak.

### Measurement protocol

- Use unchanged project fixtures `test-light.md`, `test-medium.md`, `test-complete.md`, `test-heavy.md`, `test-onescreen.md`, their diagram-free common-content derivatives and the separate 73-case `test-diagrams.md` catalogue. One document in one fresh application process; remove restored extra tabs/windows before the next run.
- Cold means identified regenerable application caches are cleared while keeping activation, preferences and source files. It does not mean the OS filesystem cache was purged. Warm starts a new process after the same document's completed cold traversal, retaining application caches.
- Record the test window with ScreenCaptureKit and compare compositor timestamps against process birth. First readable content and first actually visible Mermaid are separate observations; ignore source panes, placeholders and error panels. Keep the first eight seconds untouched. Automation waits and screenshot-call duration do not count as rendering time.
- Sample main/helper physical footprint every 200 ms. Report the median in seconds 7–8 and the first-eight-second peak separately from the later full-pass peak. Shared OS service attribution remains approximate. Keep screen geometry, app version and input/binary hashes with the raw evidence.
- Traverse by overlapping viewport steps to the actual document end and verify the end context in captured frames. EOF proves traversal, not successful rendering of every diagram. Traversal wall time includes test cadence and is not a speed ranking. Zoom and scroll FPS are outside this competitor protocol.
- Count installed regular-file bytes plus symlink payload once, excluding mutable profiles and the system WebKit/WebView2 runtime. Report source-only, unsupported, failed and unconfirmed cases explicitly; do not estimate missing results.

`COMPARISON.md` keeps the results and definitions. Raw inventories, attempt logs and the original full protocol are preserved locally under ignored `test-results/benchmarks/`; recordings and installed competitor apps stay under `test-results/`. They are intentionally absent from a source checkout.

### Confirmed comparison at a glance

Light is the identical 91,722-byte common-content fixture with diagram fences removed. Cold / warm are separate fresh-process observations; RAM is the median in seconds 7–8 including helpers. Diagram counts describe the separate valid-source 73-case catalogue, not the entire languages or every competitor feature.

| Application | Universal app, MiB | Light cold / warm | First Mermaid cold / warm | Light RAM cold / warm, MiB | Drawn examples |
| --- | --- | --- | --- | --- | --- |
| MDVu | 7.02 | 1.55 s / 1.22 s | 1.57 s / 0.69 s | 150 / 145 | 73 / 73 |
| Typora | 44.53 | 1.58 s / 1.75 s | 2.11 s / 1.55 s | 303 / 298 | 29 / 73 |
| Obsidian | 527.28 | 1.76 s / 1.55 s | 1.57 s / 1.18 s | 472 / 473 | 28 / 73 |
| MacDown 3000 | 16.54 | 1.29 s / 0.80 s | 1.71 s / 1.36 s | 103 / 101 | 26 / 73 |
| MarkViewer | 58.15 | 1.91 s / 2.16 s | 1.84 s / 1.40 s | 344 / 347 | 29 / 73 |
| MD Viewer | 410.02 | 2.12 s / 2.21 s | Source displayed / Source displayed | 422 / 447 | 0 / 73 |
| VS Code | 1388.93 | 4.09 s / 3.00 s | 3.43 s / 3.00 s | 1267 / 1206 | 38 / 73 |
| Marked | 145.18 | 3.87 s / 3.65 s | 3.41 s / 3.39 s | 286 / 276 | 37 / 73 |

These are individual paired observations, not repeated-trial medians or a statistical speed ranking. MacDown opens the diagram-free Light faster and uses less memory than MDVu in these observations. MDVu is the smallest app here and renders every selected catalogue example; neither fact proves universal performance superiority.

### Application files

| Application | Version | Logical MiB, Universal |
| --- | --- | --- |
| MDVu | 0.5.0 | 7.02 |
| Typora | 1.14.10 | 44.53 |
| Obsidian | 1.14.4 | 527.28 |
| MacDown 3000 | 3000.0.7 | 16.54 |
| MarkViewer | 1.8.15 | 58.15 |
| MD Viewer | 1.2.1 | 410.02 |
| VS Code | 1.142.0 | 1388.93 |
| Marked | 3.2.21 | 145.18 |

Logical app files plus symlink payload counted once, excluding directory metadata, resource forks/xattrs, user profiles and system WebKit. Size inventory and previous counting corrections: `test-results/benchmarks/application-size-2026-10-18.json` (local evidence, excluded from Git). This correction is not an application optimization.

### Common content, diagram fences removed

| Application | File | Cold: first content | Cold RAM: 8 s / startup peak / full peak, MiB | Warm: first content | Warm RAM: 8 s / startup peak / full peak, MiB |
| --- | --- | --- | --- | --- | --- |
| MD Viewer | `common-test-light.md` | 2.12 s | 422 / 455 / 540 | 2.21 s | 447 / 488 / 509 |
| MD Viewer | `common-test-medium.md` | 2.05 s | 370 / 399 / 460 | 1.52 s | 369 / 401 / 447 |
| MD Viewer | `common-test-onescreen.md` | 1.96 s | 378 / 406 / 429 | 1.10 s | 337 / 422 / 422 |
| MDVu | `common-test-complete.md` | 2.31 s | 168 / 209 / 725 | 2.35 s | 168 / 210 / 627 |
| MDVu | `common-test-light.md` | 1.55 s | 150 / 186 / 419 | 1.22 s | 145 / 186 / 402 |
| MDVu | `common-test-medium.md` | 1.13 s | 149 / 185 / 372 | 0.77 s | 146 / 184 / 366 |
| MDVu | `common-test-onescreen.md` | 1.22 s | 104 / 160 / 160 | 0.67 s | 103 / 159 / 159 |
| MacDown 3000 | `common-test-complete.md` | Frame analysis pending | 188 / 188 / 260 | Frame analysis pending | 179 / 186 / 197† |
| MacDown 3000 | `common-test-light.md` | 1.29 s | 103 / 141 / 141 | 0.80 s | 101 / 141 / 141 |
| MacDown 3000 | `common-test-medium.md` | 1.69 s | 115 / 144 / 153 | 0.89 s | 121 / 163 / 167 |
| MacDown 3000 | `common-test-onescreen.md` | HTML source displayed | 95 / 112 / 112 | HTML source displayed | 94 / 113 / 113 |
| MarkViewer | `common-test-light.md` | 1.91 s | 344 / 633 / 636 | 2.16 s | 347 / 605 / 605 |
| MarkViewer | `common-test-medium.md` | 1.94 s | 385 / 828 / 828 | 1.90 s | 377 / 751 / 776 |
| MarkViewer | `common-test-onescreen.md` | HTML source displayed | 303 / 580 / 580 | HTML source displayed | 291 / 578 / 578 |
| Marked | `common-test-light.md` | 3.87 s | 286 / 444 / 444 | 3.65 s | 276 / 406 / 471 |
| Marked | `common-test-medium.md` | 3.65 s | 338 / 508 / 537 | 3.07 s | 336 / 459 / 496 |
| Marked | `common-test-onescreen.md` | 3.70 s | 277 / 416 / 454 | 3.37 s | 281 / 414 / 434 |
| Obsidian | `common-test-complete.md` | 1.94 s | 647 / 742 / 867 | 1.66 s | 583 / 666 / 804 |
| Obsidian | `common-test-light.md` | 1.76 s | 472 / 548 / 572 | 1.55 s | 473 / 548 / 555 |
| Obsidian | `common-test-medium.md` | 1.97 s | 456 / 480 / 526 | 1.22 s | 373 / 429 / 481 |
| Obsidian | `common-test-onescreen.md` | 1.49 s | 345 / 473 / 473 | 1.11 s | 354 / 470 / 470 |
| Typora | `common-test-complete.md` | 2.41 s | 420 / 565 / 801 | 2.57 s | 413 / 566 / 789 |
| Typora | `common-test-light.md` | 1.58 s | 303 / 457 / 517 | 1.75 s | 298 / 455 / 509 |
| Typora | `common-test-medium.md` | 1.92 s | 327 / 518 / 556 | 1.94 s | 327 / 517 / 558 |
| Typora | `common-test-onescreen.md` | HTML source displayed | 293 / 466 / 670 | HTML source displayed | 292 / 469 / 637 |
| VS Code | `common-test-light.md` | 4.09 s | 1267 / 1272 / 1327 | 3.00 s | 1206 / 1273 / 1273 |
| VS Code | `common-test-medium.md` | 3.38 s | 1324 / 1349 / 1349 | 2.73 s | 1212 / 1244 / 1333 |
| VS Code | `common-test-onescreen.md` | 3.20 s | 1262 / 1312 / 1321 | 2.89 s | 1245 / 1285 / 1285 |

### Original project fixtures

| Application | File | Cold: first content | Cold RAM: 8 s / startup peak / full peak, MiB | Warm: first content | Warm RAM: 8 s / startup peak / full peak, MiB |
| --- | --- | --- | --- | --- | --- |
| MD Viewer | `test-light.md` | 2.57 s | 443 / 476 / 566 | 1.53 s | 388 / 505 / 562 |
| MD Viewer | `test-medium.md` | 2.30 s | 409 / 438 / 543 | 1.76 s | 400 / 432 / 533 |
| MD Viewer | `test-onescreen.md` | 2.35 s | 386 / 414 / 515 | 1.25 s | 347 / 433 / 504 |
| MDVu | `test-light.md` | 1.16 s | 152 / 189 / 600 | 0.76 s | 162 / 203 / 420 |
| MDVu | `test-medium.md` | 1.42 s | 150 / 185 / 585 | 0.92 s | 166 / 209 / 406 |
| MDVu | `test-onescreen.md` | 1.37 s | 356 / 464 / 464 | 0.71 s | 113 / 181 / 181 |
| MacDown 3000 | `test-light.md` | 3.53 s | 167 / 193 / 227 | 3.17 s | 157 / 188 / 227 |
| MacDown 3000 | `test-medium.md` | 8.29 s | 130 / 135 / 245 | 0.94 s | 156 / 161 / 251 |
| MacDown 3000 | `test-onescreen.md` | HTML source displayed | 94 / 109 / 121 | HTML source displayed | 97 / 136 / 136 |
| MarkViewer | `test-light.md` | 2.37 s | 504 / 714 / 902 | 2.56 s | 490 / 713 / 899 |
| MarkViewer | `test-medium.md` | 3.32 s | 646 / 848 / 1119 | 2.99 s | 611 / 745 / 1071 |
| MarkViewer | `test-onescreen.md` | HTML source displayed | 336 / 562 / 562 | HTML source displayed | 357 / 634 / 634 |
| Marked | `test-light.md` | 3.79 s | 522 / 539 / 618 | 3.36 s | 580 / 612 / 612 |
| Marked | `test-medium.md` | 4.49 s | 484 / 533 / 645 | 4.03 s | 485 / 548 / 672 |
| Marked | `test-onescreen.md` | 4.08 s | 317 / 447 / 497 | 3.80 s | 318 / 424 / 482 |
| Obsidian | `test-light.md` | 1.87 s | 666 / 730 / 942 | 1.53 s | 683 / 758 / 974 |
| Obsidian | `test-medium.md` | 1.87 s | 656 / 671 / 856 | 1.39 s | 564 / 607 / 803 |
| Obsidian | `test-onescreen.md` | 1.46 s | 385 / 549 / 549 | 1.10 s | 397 / 535 / 553 |
| Typora | `test-light.md` | 1.63 s | 542 / 566 / 650 | 1.80 s | 548 / 573 / 692 |
| Typora | `test-medium.md` | 1.68 s | 552 / 588 / 690 | 2.22 s | 502 / 525 / 678 |
| Typora | `test-onescreen.md` | HTML source displayed | 322 / 478 / 598 | HTML source displayed | 311 / 487 / 667 |
| VS Code | `test-light.md` | 3.56 s | 1446 / 1504 / 1546 | 3.67 s | 1544 / 1597 / 1597 |
| VS Code | `test-medium.md` | 3.36 s | 1389 / 1442 / 1442 | 2.76 s | 1338 / 1411 / 1498 |
| VS Code | `test-onescreen.md` | 3.67 s | 1295 / 1344 / 1344 | 2.81 s | 1300 / 1335 / 1335 |

### First Mermaid, two nodes

| Application | File | Cold: first content | Cold RAM: 8 s / startup peak / full peak, MiB | Warm: first content | Warm RAM: 8 s / startup peak / full peak, MiB |
| --- | --- | --- | --- | --- | --- |
| MD Viewer | `diagram-control.md` | Source displayed | 298 / 325 / 325 | Source displayed | 269 / 321 / 321 |
| MDVu | `diagram-control.md` | 1.57 s | 102 / 267 / 267 | 0.69 s | 80 / 117 / 117 |
| MacDown 3000 | `diagram-control.md` | 1.71 s | 110 / 167 / 167 | 1.36 s | 110 / 168 / 168 |
| MarkViewer | `diagram-control.md` | 1.84 s | 245 / 437 / 437 | 1.40 s | 244 / 441 / 441 |
| Marked | `diagram-control.md` | 3.41 s | 201 / 271 / 316 | 3.39 s | 201 / 271 / 316 |
| Obsidian | `diagram-control.md` | 1.57 s | 238 / 294 / 294 | 1.18 s | 244 / 302 / 302 |
| Typora | `diagram-control.md` | 2.11 s | 223 / 335 / 335 | 1.55 s | 224 / 357 / 357 |
| VS Code | `diagram-control.md` | 3.43 s | 1200 / 1269 / 1269 | 3.00 s | 1178 / 1246 / 1246 |

### Complete 73-example document

| Application | File | Cold: first content | Cold RAM: 8 s / startup peak / full peak, MiB | Warm: first content | Warm RAM: 8 s / startup peak / full peak, MiB |
| --- | --- | --- | --- | --- | --- |
| MD Viewer | `test-diagrams.md` | 2.19 s | 365 / 393 / 447 | 1.22 s | 336 / 390 / 441 |
| MDVu | `test-diagrams.md` | 1.24 s | 172 / 431 / 916 | 0.72 s | 153 / 204 / 415 |
| MacDown 3000 | `test-diagrams.md` | 2.67 s | 157 / 183 / 203 | 1.66 s | 152 / 160 / 196 |
| MarkViewer | `test-diagrams.md` | 2.51 s | 454 / 699 / 797 | 2.45 s | 466 / 753 / 780 |
| Marked | `test-diagrams.md` | 4.04 s | 493 / 523 / 555 | 5.35 s | 421 / 549 / 561 |
| Obsidian | `test-diagrams.md` | 1.73 s | 527 / 554 / 919 | 1.32 s | 547 / 583 / 929 |
| Typora | `test-diagrams.md` | 1.38 s | 412 / 593 / 810 | 1.33 s | 427 / 606 / 765 |
| VS Code | `test-diagrams.md` | 3.33 s | 1395 / 1452 / 1508 | 2.74 s | 1384 / 1434 / 1472 |

All attempts, binary/source hashes, cache states, geometry, exclusions and memory windows: `test-results/benchmarks/full-pass-2026-10-18.json` (local evidence, excluded from Git). Raw videos, frames and step logs: `test-results/full-pass-20261018/`. Local recordings are not distributed.

## Current MDVu verification · 19 October 2026

[PR #2 CI on revision `7230777`](https://github.com/stpork/mdvu/actions/runs/39165392352) passed on macOS, Windows and Linux. This verification covers 90 Swift tests, 27 shared Rust unit tests plus 16 integration tests, 8 Windows host unit tests, 11 packaged CLI contract cases and 38/38 native fixtures per platform, including all 73 catalogue examples. Hosted native fixture runs use timer mode to verify correctness; they are not frame-rate or competitor measurements.

The regression changes preserve the macOS math runtime through error pages, separate decoded Windows filenames from URL fragments and synchronize native/Rust release versions. No rendering engine or permanent cache was added. The Windows executable changed from 6,075,392 to 6,078,464 bytes (+3,072 bytes) in that CI pair. These identities are separate from the earlier performance series below.

The subsequent MSI fix (`cd56a3e`) was tested natively on Windows NAS (Windows 10 build 19045). On 19 October, the revised harness repeated both interactive scopes using application revision `2143586`: Program Files under the elevated account, and LocalAppData under a separate temporary standard account. Each passed 19 installer assertions and all seven installed-GUI checks, including Finish, Start Menu/CLI launch, associations, Markdown/images/diagrams, and complete uninstall. The harness stages NAS's explicitly configured private Scoop WebView2 runtime for the temporary account; this dependency is not added to the application. These are installer correctness checks, not startup performance measurements. Raw MSI logs and reports stay locally under `test-results/installer-20261019/`.

### Release-size and visibility recheck · 19 October

[CI at `ddd8e59`](https://github.com/stpork/mdvu/actions/runs/39175259892) passed on macOS, Windows and Linux, including MSI installation in both scopes and native Heavy/catalogue visibility checks. A subsequent local AppKit regression test reproduced TOC width drift when resizing a window. Restricting split-view size adjustment to the reader fixes that drift; the local Swift suite passes 91 tests. Fullscreen auditing now waits for AppKit's completion callback, so the next zoom is not timed during the operating system's fullscreen animation.

On NAS, optimizing only the Windows host for size reduced the executable from **6,074,368 to 5,876,736 bytes** (5.79 to 5.60 MiB; −3.25%). The shared Rust processing core retains O3. Paired CLI runs below use the same original project fixtures, three alternating process pairs and 60 measured iterations per process; each cell is the median of the three reported medians. These timings cover Markdown processing with diagram placeholders, not browser layout or SVG generation.

| Fixture | Windows host O3 | Compact Windows host |
| --- | ---: | ---: |
| Light | 2.82 ms | 2.76 ms |
| Medium | 3.39 ms | 3.37 ms |
| Complete | 10.52 ms | 10.53 ms |
| Heavy | 23.17 ms | 23.16 ms |
| Onescreen | 1.30 ms | 1.23 ms |

Both Windows variants passed the six main native fixtures, cold UI interaction, full zoom range, navigation/panels and fullscreen. Individual UI timings still vary: Heavy's maximum zoom action was 326 → 292 ms, while its second scroll-pass p95 was 31.9 → 43.7 ms and peak tree private bytes 664 → 688 MiB. These single desktop observations do not establish a UI speed or memory improvement. RDP's approximately 32 ms display interval is not input latency. Moving the entire core to size optimization was rejected: roughly 3% smaller library files cost 19–31% in paired fixture processing.

The visibility audit visits each actual SVG before any zoom, then revisits in reverse to exercise DOM restoration. It opens enclosing `details` and corrects scroll targets displaced by deferred layout; merely intersecting a figure's padding does not prove its SVG is onscreen. The NAS baseline showed all 315 valid Heavy diagrams and all 73 catalogue examples before zoom. A 350-node Heavy flowchart took about 3.5 seconds to become visible; waiting for SVG generation is distinct from a cached SVG failing to mount. The subsequent regression probe reproduced visible 3.2/3.3 diagrams remaining pending on macOS for 30 seconds. Enter observers were discarding their notification after a second geometry read refined deferred layout. On Windows, document-root observers were clipped by the nested reader: after a reverse pass, 277 Heavy SVGs remained mounted. The shared fix trusts enter snapshots, roots observers at the actual reader and re-arms retention after mounting. No rendering-engine or application-cache limit was increased. Raw build identities, paired measurements, visibility geometry and native reports remain under local, ignored `test-results/performance-recheck-20261019/`; these are separate from the earlier competitor startup series.

[Verification of `5a528f7`](https://github.com/stpork/mdvu/actions/runs/39177235718) passed on macOS, Windows and Linux. Native desktop runs on the Mac and NAS passed all six main fixtures and forward/reverse visibility checks on 315 valid Heavy diagrams and all 73 catalogue examples before zoom. At the end of that visibility scenario, both platforms retained five Heavy SVGs and three catalogue SVGs, with none more than 2,000 px outside the reader; Windows previously retained 277 Heavy SVGs, including 270 that far outside it. This measures mounted DOM, not total process memory. NAS verification used a clean rebuild after discovering stale Cargo dependencies pointing into an older temporary source snapshot. The rebuilt Windows executable was 5,877,760 bytes; binary SHA-256 and source revision are retained with the local report.

Pre-merge regression coverage also checks fenced-language metadata, explicit automatic dialect selection, superseded Windows folder scans/auto-opens, and Enter/Shift+Enter after debounced find. These are correctness fixes, not new competitor speed measurements.

## Native performance observations · 18 October 2026

This is the earlier native MDVu validation, separate from the incomplete competitor study above and the later correctness fixes. Its binaries contain a later cache correction; the earlier comparative startup numbers are not claimed as post-correction measurements.

Replacing an existing SVG at the 128-entry/16 MiB cache boundary used to flush unrelated entries. The shared Rust insertion helper now removes the replaced entry before checking occupancy. The same helper serves disk reads and renderer writes; limits stay unchanged. A regression test checks replacement at both boundaries and eviction on actual overflow. The Universal app remains 7,364,248 bytes (7.02 MiB).

| Check | Result |
| --- | --- |
| Swift | 89 tests passed |
| Shared Rust on Mac | 27 unit + 16 integration tests passed; 4 Windows-host tests passed |
| macOS Universal release | arm64 + x86_64 app and core built; deep/strict ad-hoc signature verified |
| macOS current native UI | 38/38 fixtures passed; full controls on all five main fixtures; 3 warm scroll passes |
| Windows NAS native | MSVC release + workspace tests + CLI passed; 120/120 checks, 38/38 UI fixtures |
| Windows EXE | 6,074,368 bytes (5.79 MiB), excluding the system WebView2 runtime/profile |
| Catalogue | 73 diagrams; zero error panels on both native platforms |

The controls cover 10–500% zoom, invalid-input clamping, Home/End, search, TOC/folder hide/show, tree/list, expand/collapse with reflow, reading-position preservation and fullscreen enter/exit. The forced-render-all heavy probe also verifies idle renderer release.

| File | Mac warm scroll frame p95, ms | Windows RDP warm scroll frame p95, ms |
| --- | --- | --- |
| `test-light.md` | 18.0 | 60.8 |
| `test-medium.md` | 18.0 | 32.7 |
| `test-complete.md` | 29.0 | 36.7 |
| `test-heavy.md` | 18.0 | 40.3 |
| `test-onescreen.md` | 18.0 | 33.2 |

These are in-page frame intervals in the native verification run, not input latency or a competitor scrolling benchmark. RDP frame pacing and the different machines prevent a Mac-versus-Windows speed ranking. Control-action durations include settling checks; native macOS fullscreen additionally includes its OS animation.

The code is not proven maximally fast or minimal-memory. Cold rendering still produced isolated intervals up to 120 ms on Mac and 250.1 ms on Windows RDP. The forced eager render-all heavy audit peaked around 1,192 MiB summed Mac footprint; this includes WebKit services and test overhead and is not normal lazy-reading memory. The transitive `block 0.1.6` dependency emits a future-incompatibility warning when the Windows crate is tested on Mac. No warning suppression or dependency fork was added.

MSI install/uninstall was not repeated in this performance series. Its cache correction (`4983d8a`) is included in PR #2. The performance numbers remain tied to their original binaries; the website has not been deployed as part of this verification.

The historical baseline [GitHub CI](https://github.com/stpork/mdvu/actions/runs/39056053120) passed macOS, Windows and Linux on `8b6d006`. See the current verification section for the later tested revision. Verification data, binary identities and raw-log locations: `test-results/benchmarks/verification-2026-10-18.json` (local evidence, excluded from Git).

## Historical prepared-profile observations · superseded

The following tables and method describe the earlier seven-app series. Its warm file-open timings, cache state, package inventory and trial activation differ from the current single-document cold/warm protocol above. Do not combine these series or reuse the older values in the landing-page comparison.

### Results at a glance

| Application | Installed MiB, Universal | Launch → content¹ | Open light² | Open heavy² | RAM at 8 s, MiB³ | First Mermaid⁴ | Diagrams |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MDVu 0.5.0 | 7.02 | 1.07 s | 630 ms | 770 ms | 211 | 1.10 s | 73 / 73 |
| Typora 1.14.10 | 44.01 | Trial reminder | 1.06 s | 18.07 s | 479 | 1.59 s | 29 / 73 |
| Obsidian 1.14.4 | 527.28 | 2.41 s | 540 ms | 1.26 s | 576 | 550 ms | 28 / 73 |
| MacDown 3000 3000.0.7 | 16.54 | 2.59 s | 1.12 s | Not visible in 30.6 s | 142 | 1.29–1.44 s | 26 / 73 |
| MarkViewer 1.8.15 | 58.15 | 3.44–3.54 s | 2.38–2.56 s | 28.86–28.96 s | 321 | 900 ms | 29 / 73 |
| MD Viewer 1.2.1 | 410.02 | 3.17 s | 800 ms | 4.80 s | 342 | Source only | 0 / 73 |
| VS Code 1.142.0 | 1388.93 | 4.21 s | 1.11 s | 4.54 s | 1004 | 810 ms | 38 / 73 |

The historical Typora package below has the earlier executable hash and its original inventory. The activated current-series package is 44.53 MiB; the same version/build does not imply identical bytes.

1. Stopped app, prepared profile, same `common-test-light.md`; process birth → first readable body. OS disk cache was not flushed. This is process-cold, not first-ever installation. Typora's trial reminder blocks a comparable result; no subscription was activated and no click delay was subtracted.
2. Ready app → first readable document body, timed from actual file dispatch. Common light: 91,722 bytes; common heavy: 1,482,352 bytes. They retain the original text/HTML/math and remove only diagram fences. A heading appearing does not establish completion of every diagram or responsiveness of controls.
3. Median summed physical footprint during seconds 7–8 after actual dispatch, on common light. Includes browser/render/helper processes, not only the launcher. Sizes and RAM are different metrics. See attribution limits below.
4. First visible `Input → Output` graph in an unchanged copy of `tests/fixtures/runtime/mermaid-only.md`. This includes engine initialization and scheduling, not just layout. It is a two-node startup control, not evidence about complex diagram throughput. MD Viewer displays source.

MDVu warm light and first Mermaid use the middle observation of three fresh-process trials; other cells are single observations. Values rounded to approximately 10 ms below a second or 0.01 s above it; raw timestamps and frame intervals are retained. Where adjacent captured frames are at least 80 ms apart, the table shows that interval instead of a precise-looking point value. No p95, confidence intervals or general “× faster” claim are inferred from these observations.

#### MDVu opening optimizations · paired control

The original 1.57 s light result did not reproduce in the untouched saved app. It is not used as the optimization baseline. Before and after use the same fixture bytes and capture protocol in a new session. Three fresh processes for light/first Mermaid; one per other workload. No p95 or statistical significance is claimed. The complete evidence, hashes, excluded contaminated trial and every observation are in the paired series: `test-results/benchmarks/mdvu-opening-optimization-2026-10-18.json` (local evidence, excluded from Git).

| Input | Trials before / after | First visible content, ms | Peak process footprint in 8 s, MiB |
| --- | --- | --- | --- |
| common-test-light.md | 3 / 3 | 788 → 632 | 264.5 → 265.8 |
| common-test-medium.md | 1 / 1 | 612 → 596 | 249.8 → 235.8 |
| common-test-complete.md | 1 / 1 | 721 → 661 | 272.2 → 289.4 |
| common-test-heavy.md | 1 / 1 | 766 → 773 | 276.0 → 296.0 |
| common-test-onescreen.md | 1 / 1 | 638 → 714 | 213.3 → 213.6 |
| test-light.md | 1 / 1 | 767 → 839 | 225.7 → 248.7 |
| test-medium.md | 1 / 1 | 573 → 600 | 247.7 → 246.7 |
| test-complete.md | 1 / 1 | 888 → 702 | 252.9 → 292.1 |
| test-heavy.md | 1 / 1 | 762 → 654 | 281.8 → 278.9 |
| test-onescreen.md | 1 / 1 | 568 → 559 | 512.6 → 524.7 |
| test-diagrams.md | 1 / 1 | 702 → 709 | 544.9 → 479.0 |
| diagram-control.md | 3 / 3 | 1309 → 1104 | 372.1 → 317.5 |

Universal `.app`: **10,467,175 → 7,364,248 bytes (9.98 → 7.02 MiB, −29.6%)**. Compressed runtimes now have one shared resource copy instead of one per Mach-O architecture. Mermaid/PlantUML/KaTeX compressed bytes and supported syntax are unchanged.

Root causes and fixes:

- New macOS document tabs instantiate a native window and WKWebView; Obsidian keeps an existing web application alive. Light Markdown parsing takes approximately 1 ms; native window/WebKit startup and first layout dominate. Start the file render before constructing the window, including Finder opens, and pass the actual appearance so system-theme opens do not render the wrong theme and repeat work.
- The first Mermaid job previously waited for the worker page, decoded the bundle, wrapped it as an escaped JavaScript string, parsed the wrapper, then injected a second command. Decode concurrently with worker startup; supply the direct source and first job together. Both native workers use this path. Exported standalone HTML retains the escaped safe loader.
- Replace the decoder-only LZMA implementation and bound its history buffer by the manifest's actual output size, rather than a 64 MiB compression dictionary. No encoder or additional archive formats are linked. Five isolated decoder calls showed Mermaid median 156 → 89 ms, PlantUML 99 → 61 ms, with equal output bytes; these are component timings, not UI latency.
- Keep the on-demand worker and idle release. No permanent preloaded Mermaid worker, enlarged document cache, process-pool workaround or fixture-specific branch was added. Stale runtime callbacks are rejected by worker generation on Windows and view identity on Mac.

Fresh Obsidian controls were 335 ms for light (one observation) and 485 / 518 ms for first Mermaid (two). **Obsidian still wins these warm-open controls.** The optimization does not establish universal superiority. MDVu cold process-to-text was 867 → 1,067 ms in single observations; this regression/variation is retained rather than hidden. The following cache-cleared study uses a different explicit protocol.

Validation: 89 Swift tests, Rust unit/integration tests, CLI tests, renderer asset checks, Windows GNU cross-build, 73/73 supported native examples and all 114 candidates rechecked (100 rendered, 14 expected unsupported). Windows native performance has not been remeasured for these changes.

#### Opening all five fixtures

Every cell is dispatch → first readable document content (including frontmatter). Common-content and exact-original results are deliberately separate. The original fixtures contain syntax/HTML/math that some applications handle differently; returning raw diagram source is not successful diagram rendering. `test-onescreen` is especially dependent on embedded HTML/CSS. Typora and MarkViewer live editors and MacDown's preview expose HTML/base64 source in its first viewport. These cases have no comparable formatted-render time in the tested view.

#### Common content — only diagram fences removed

| File | Bytes | MDVu | Typora | Obsidian | MacDown 3000 | MarkViewer | MD Viewer | VS Code |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| common-test-light.md | 91722 | 630 ms | 1.06 s | 540 ms | 1.12 s | 2.38–2.56 s | 800 ms | 1.11 s |
| common-test-medium.md | 130584 | 600 ms | 1.32 s | 0.82–0.96 s | 910 ms | 1.71–1.87 s | 490 ms | 830 ms |
| common-test-complete.md | 196438 | 660 ms | 1.80 s | 0.77–0.90 s | 1.85 s | 4.96 s | 1.25 s | 2.19 s |
| common-test-heavy.md | 1482352 | 770 ms | 18.07 s | 1.26 s | Not visible in 30.6 s | 28.86–28.96 s | 4.80 s | 4.54 s |
| common-test-onescreen.md | 42505 | 710 ms | Source displayed | 0.61–0.76 s | Source displayed | Source displayed | 840 ms | 1.54 s |

#### Original fixtures — byte-for-byte copies

| File | Bytes | MDVu | Typora | Obsidian | MacDown 3000 | MarkViewer | MD Viewer | VS Code |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| test-light.md | 109717 | 840 ms | 1.49 s | 500 ms | 1.47 s | 2.92–3.09 s | 950 ms | 0.98–1.38 s |
| test-medium.md | 174416 | 600 ms | 1.59 s | 550 ms | 9.34 s | 3.49–3.62 s | 730 ms | 760 ms |
| test-complete.md | 228154 | 700 ms | 2.29 s | 700 ms | 2.37 s | 6.68–6.83 s | 1.37 s | 1.58 s |
| test-heavy.md | 1653057 | 650 ms | 18.10 s | 970 ms | Not visible in 30.2 s | Not visible in 30.6 s | 5.82–5.90 s | 5.33 s |
| test-onescreen.md | 45010 | 560 ms | Source displayed | 0.41–0.49 s | Source displayed | Source displayed | 640 ms | 750 ms |

“Not visible” is a bounded observation of the preview, not a crash claim. MacDown's source-editor pane is excluded from the paint detector. Some heavy records last 30 seconds; all memory peaks below still use the same first 8 seconds. Longer videos replace the initial 8-second pilots according to the documented selection rules, not according to which app looks best.

#### Memory for every workload

Each cell is **MiB at 8 seconds / peak MiB in the first 8 seconds** after actual dispatch. A still-loading preview can consume less memory; it is not a comparable successful-render advantage. Baseline windows/tabs may remain according to each application's native document behavior. This is the observed process footprint, not a single-document minimum.

#### Common content

| File | MDVu | Typora | Obsidian | MacDown 3000 | MarkViewer | MD Viewer | VS Code |
| --- | --- | --- | --- | --- | --- | --- | --- |
| common-test-light.md | 211 / 246 | 479 / 567 | 576 / 641 | 142 / 167 | 321 / 492 | 342 / 421 | 1004 / 1135 |
| common-test-medium.md | 214 / 236 | 527 / 609 | 384 / 428 | 162 / 184 | 339 / 708 | 337 / 388 | 1217 / 1285 |
| common-test-complete.md | 234 / 289 | 597 / 672 | 524 / 599 | 208 / 227 | 514 / 771 | 565 / 637 | 1158 / 1268 |
| common-test-heavy.md | 252 / 296 | 664 / 688 | 860 / 872 | 176 / 176 | 813 / 844 | 707 / 778 | 1886 / 1983 |
| common-test-onescreen.md | 168 / 214 | 472 / 575 | 337 / 420 | 142 / 168 | 287 / 500 | 284 / 355 | 1133 / 1216 |

#### Original fixtures

| File | MDVu | Typora | Obsidian | MacDown 3000 | MarkViewer | MD Viewer | VS Code |
| --- | --- | --- | --- | --- | --- | --- | --- |
| test-light.md | 211 / 249 | 640 / 660 | 652 / 703 | 204 / 211 | 590 / 645 | 378 / 469 | 1406 / 1513 |
| test-medium.md | 213 / 247 | 662 / 680 | 590 / 629 | 187 / 196 | 531 / 709 | 382 / 454 | 1371 / 1482 |
| test-complete.md | 235 / 292 | 684 / 684 | 751 / 779 | 268 / 270 | 665 / 683 | 594 / 675 | 1460 / 1495 |
| test-heavy.md | 266 / 279 | 673 / 697 | 953 / 956 | 165 / 165 | 829 / 839 | 981 / 1039 | 1773 / 1842 |
| test-onescreen.md | 205 / 525 | 495 / 571 | 371 / 471 | 147 / 167 | 326 / 615 | 290 / 367 | 1245 / 1326 |

#### Combined diagram catalogue

| File | MDVu | Typora | Obsidian | MacDown 3000 | MarkViewer | MD Viewer | VS Code |
| --- | --- | --- | --- | --- | --- | --- | --- |
| test-diagrams.md | 229 / 479 | 613 / 656 | 513 / 542 | 181 / 207 | 546 / 752 | 310 / 353 | 1351 / 1403 |

#### Built-in diagram support — all 73 examples

The same valid-source catalogue in both application-cache-cold and fresh-process-warm passes, with no extra plugins or diagram server. It selects **MDVu-supported** grammars/library views, not every rival-specific feature. Forty Mermaid examples include C4 and Mermaid ZenUML; 33 PlantUML/puml examples include C4-PlantUML and ArchiMate. Aliases and layout/style duplicates are excluded. D003 requirement fields are quoted explicitly, so syntax repair gives MDVu no advantage. Counts mean a drawn diagram, not complete language conformance or pixel-perfect fidelity.

| Application | Version | Rendered | Error | Source |
| --- | --- | --- | --- | --- |
| MDVu | 0.5.0 | 73 | 0 | 0 |
| Typora | 1.14.10 | 29 | 11 | 33 |
| Obsidian | 1.14.4 | 28 | 12 | 33 |
| MacDown 3000 | 3000.0.7 | 26 | 14 | 33 |
| MarkViewer | 1.8.15 | 29 | 11 | 33 |
| MD Viewer | 1.2.1 | 0 | 0 | 73 |
| VS Code | 1.142.0 | 38 | 2 | 33 |
| Marked | 3.2.21 | 37 | 3 | 33 |

Both phases agree for all 584 application/example outcomes. Evidence combines complete AX document contents where exposed with saved viewport frames and native OCR. **EOF alone is not counted as rendering success.** MDVu Timing D047 was visually verified in frame 0034 in both phases; its fine labels are below the OCR threshold. Typora jumps from D040 to near EOF during both walks, so intermediate cases are corroborated by the full AX tree, not asserted to have been continuously visible. Marked 3.2.21 uses Swiss preview: Mermaid ZenUML D014 and D075/D076 show errors; PlantUML remains source. MarkViewer uses live editor preview; its separate read-only HTML mode is not represented by these numbers.

Per-case cold/warm outcomes, binary hashes, AX nodes and saved-frame references: `test-results/benchmarks/diagram-comparison-2026-10-18.json` (local evidence, excluded from Git). Raw evidence stays in `test-results/full-pass-20261018/capture/`.

<details>
<summary>Every grammar/view and outcome</summary>

| ID | Example | MDVu | Typora | Obsidian | MacDown 3000 | MarkViewer | MD Viewer | VS Code | Marked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D001 | Mermaid / flowchart | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D002 | Mermaid / C4Context | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D003 | Mermaid / requirementDiagram | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D004 | Mermaid / quadrantChart | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D005 | Mermaid / C4Container | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D006 | Mermaid / C4Component | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D007 | Mermaid / architecture-beta | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D008 | Mermaid / erDiagram | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D009 | Mermaid / sankey | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D010 | Mermaid / sequenceDiagram | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D011 | Mermaid / stateDiagram-v2 | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D012 | Mermaid / ishikawa-beta | rendered | rendered | rendered | error | rendered | source | rendered | rendered |
| D013 | Mermaid / C4Dynamic | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D014 | Mermaid / zenuml | rendered | rendered | error | error | error | source | rendered | error |
| D015 | Mermaid / swimlane-beta | rendered | error | error | error | error | source | rendered | rendered |
| D016 | Mermaid / C4Deployment | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D017 | Mermaid / gantt | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D018 | Mermaid / gitGraph | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D020 | Mermaid / xychart | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D021 | Mermaid / radar-beta | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D022 | Mermaid / timeline | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D023 | Mermaid / kanban | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D024 | Mermaid / mindmap | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D025 | Mermaid / treemap-beta | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D027 | Mermaid / classDiagram | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D028 | Mermaid / journey | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D029 | Mermaid / pie | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D030 | Mermaid / block-beta | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D031 | Mermaid / packet | rendered | rendered | rendered | rendered | rendered | source | rendered | rendered |
| D032 | Mermaid / eventmodeling | rendered | error | error | error | error | source | rendered | rendered |
| D033 | Mermaid / treeView-beta | rendered | error | error | error | error | source | rendered | rendered |
| D034 | Mermaid / venn-beta | rendered | rendered | rendered | error | rendered | source | rendered | rendered |
| D035 | Mermaid / wardley-beta | rendered | error | error | error | rendered | source | rendered | rendered |
| D036 | Mermaid / cynefin-beta | rendered | error | error | error | error | source | rendered | rendered |
| D038 | PlantUML / Sequence Diagram | rendered | source | source | source | source | source | source | source |
| D039 | PlantUML / Use Case Diagram | rendered | source | source | source | source | source | source | source |
| D040 | PlantUML / Class Diagram | rendered | source | source | source | source | source | source | source |
| D041 | PlantUML / Object Diagram | rendered | source | source | source | source | source | source | source |
| D042 | PlantUML / Activity Diagram — Current Syntax | rendered | source | source | source | source | source | source | source |
| D043 | PlantUML / Activity Diagram — Legacy Syntax Probe | rendered | source | source | source | source | source | source | source |
| D044 | PlantUML / Component Diagram | rendered | source | source | source | source | source | source | source |
| D045 | PlantUML / Deployment Diagram | rendered | source | source | source | source | source | source | source |
| D046 | PlantUML / State Diagram | rendered | source | source | source | source | source | source | source |
| D047 | PlantUML / Timing Diagram | rendered | source | source | source | source | source | source | source |
| D048 | PlantUML / JSON Data | rendered | source | source | source | source | source | source | source |
| D049 | PlantUML / YAML Data | rendered | source | source | source | source | source | source | source |
| D050 | PlantUML / EBNF Diagram | rendered | source | source | source | source | source | source | source |
| D051 | PlantUML / Regex Diagram | rendered | source | source | source | source | source | source | source |
| D052 | PlantUML / Network Diagram (nwdiag) | rendered | source | source | source | source | source | source | source |
| D053 | PlantUML / Salt Wireframe | rendered | source | source | source | source | source | source | source |
| D054 | PlantUML / ArchiMate Diagram | rendered | source | source | source | source | source | source | source |
| D055 | PlantUML / SDL Shapes | rendered | source | source | source | source | source | source | source |
| D057 | PlantUML / Gantt Diagram | rendered | source | source | source | source | source | source | source |
| D059 | PlantUML / MindMap Diagram | rendered | source | source | source | source | source | source | source |
| D060 | PlantUML / WBS Diagram | rendered | source | source | source | source | source | source | source |
| D063 | PlantUML / Information Engineering Diagram | rendered | source | source | source | source | source | source | source |
| D065 | PlantUML / Chart Diagram | rendered | source | source | source | source | source | source | source |
| D075 | Mermaid / usecase-beta | rendered | error | error | error | error | source | error | error |
| D076 | Mermaid / agentflow-beta | rendered | error | error | error | error | source | error | error |
| D077 | Mermaid / railroad-beta | rendered | error | error | error | error | source | rendered | rendered |
| D078 | Mermaid / railroad-ebnf-beta | rendered | error | error | error | error | source | rendered | rendered |
| D079 | Mermaid / railroad-abnf-beta | rendered | error | error | error | error | source | rendered | rendered |
| D080 | Mermaid / railroad-peg-beta | rendered | error | error | error | error | source | rendered | rendered |
| D090 | PlantUML / DOT | rendered | source | source | source | source | source | source | source |
| D091 | PlantUML / PACKET | rendered | source | source | source | source | source | source | source |
| D100 | PlantUML / C4-PlantUML / Context | rendered | source | source | source | source | source | source | source |
| D101 | PlantUML / C4-PlantUML / Landscape | rendered | source | source | source | source | source | source | source |
| D102 | PlantUML / C4-PlantUML / Container | rendered | source | source | source | source | source | source | source |
| D103 | PlantUML / C4-PlantUML / Component | rendered | source | source | source | source | source | source | source |
| D104 | PlantUML / C4-PlantUML / Dynamic | rendered | source | source | source | source | source | source | source |
| D105 | PlantUML / C4-PlantUML / Deployment | rendered | source | source | source | source | source | source | source |
| D106 | PlantUML / C4-PlantUML / Sequence | rendered | source | source | source | source | source | source | source |
| D110 | PlantUML / ArchiMate / business, application and technology layers | rendered | source | source | source | source | source | source | source |

</details>

#### Measurement method and evidence

- ScreenCaptureKit records only test application window rectangles, with other pixels black, no audio/cursor. AVFoundation frame PTS and process birth share the mach host clock. Automation prepares/closes windows; its waits, screenshot calls and response times are outside the measured interval. `/usr/bin/open` dispatch time includes OS routing; Obsidian uses its official open URI, and VS Code cold launch uses its official CLI and prepared preview workspace.
- Offline Vision revision 1 accurate CPU recognition locates target document text (including visible frontmatter) in the rendered pane; first frames and failure/reference frames are visually reviewed. MacDown's raw source pane is excluded. The small Mermaid control requires both exact node labels; visible graph output is independently checked. Recording requests 60 Hz but actual frame spacing is retained; capture is not a hardware input-latency measurement. Writer dropped frames: zero in the selected recordings.
- Warm trials start a fresh process with a tiny baseline actually readable, then open the test file. Default native viewport/zoom and editor layouts are retained; window rectangles are in the JSON. A baseline may remain in a separate window or tab. MDVu uses a dedicated empty SVG cache for each prepared process. Disk caches, profiles and installed runtime assets are not purged. Cold trials start a stopped app with the same light derivative and prepared profile.
- Memory uses `proc_pid_rusage` every 200 ms: app, descendants and newly started WebKit XPC services after an isolated session baseline. Shared OS services cannot be perfectly attributed, and summed footprints may count shared pages. It excludes unrelated background apps. Fixed 7–8 s sampling is aligned to the actual file-dispatch timestamp, not capture/setup/tool time. No concurrent build or OCR analysis runs during recordings.
- Complete Universal installed size is the sum of regular-file lengths, not disk allocation or download size. Electron bundled by an app is included; macOS system WebKit and writable profiles/vaults are not. MDVu's separately measured ARM app is 4.90 MiB, but **9.98 MiB Universal** is used for the comparison. Versions, executable hashes and bundle sizes were rechecked unchanged after the recordings. The five source fixtures were rechecked unchanged.
- Failed/incomplete/source-only cases remain explicit. MarkViewer heavy processes did not exit after a normal Quit request and were terminated by their verified benchmark PID; this is not called a spontaneous crash. No paid trial was activated. Zoom, scrolling and fullscreen are outside this competitor study. These measurements do not demonstrate that controls remain responsive while a heading is visible.

All timings, footprints, input/build hashes, selected frame brackets and evidence hashes: `test-results/benchmarks/competitor-performance-2026-10-18.json` (local evidence, excluded from Git). Every diagram outcome: `test-results/benchmarks/diagram-comparison-2026-10-18.json` (local evidence, excluded from Git). [Clean input catalogue](tests/fixtures/test-diagrams.md). Raw local recordings, first-frame PNGs, compositor metadata and process samples: `test-results/comparison-20261018/`. Recordings have not been uploaded or copied into website assets.

## Verified MDVu diagram catalogue — 18 October 2026

The current [test-diagrams.md](tests/fixtures/test-diagrams.md) contains **73 supported grammar/view examples**. Its selection rule is one example per engine and distinct grammar or library view; Mermaid and PlantUML are separate source languages. Aliases, layout/style probes and repeated examples are not counted as additional types. This is a catalogue of MDVu-supported inputs, not an exhaustive list of features unique to other applications.

Before selection, 114 candidates were opened individually in fresh native MDVu processes with empty diagram caches: **100 rendered, 14 failed, zero unresolved/source-only results**. Each case has a native screenshot and SHA-256 evidence. SVG diagnostic panels are checked independently of the engine's success callback. All 114 screenshots were visually reviewed. The final combined 73-example document was rendered again: **73/73 rendered, zero errors**.

The clean catalogue excludes 25 duplicates/aliases, 14 unsupported cases and 2 utility/formatting probes. The full registry, canonical-case mappings and exclusions remain in diagram-catalogue.json: `test-results/benchmarks/diagram-catalogue.json` (local evidence, excluded from Git); actual native outcomes and evidence hashes are in mdvu-diagram-validation.json: `test-results/benchmarks/mdvu-diagram-validation.json` (local evidence, excluded from Git).

C4-PlantUML 2.14.0 and ArchiMate 3.2.2 are bundled offline. All C4 and ArchiMate candidates rendered, including nested includes and the ArchiMate element/icon overview. D071 originally passed an expression directly to an unquoted ArchiMate macro; the catalogue version computes that argument first. The five original fixtures remain unchanged. Canonical D003 additionally quotes requirement fields explicitly to remove a comparison syntax error. Standalone ZenUML fences now use the existing Mermaid engine, and DOT uses the existing shared Graphviz instance. No additional rendering engine was added. The PlantUML compressed asset grew by 44,410 bytes (43.37 KiB).

The removed failures below are engine limitations, not library download errors. The Java reference engine also accepts the added probe syntax; its results are retained in diagram-reference-validation.json: `test-results/benchmarks/diagram-reference-validation.json` (local evidence, excluded from Git). The [browser factory registry](https://github.com/plantuml/plantuml/blob/v1.2026.9/src/main/java/net/sourceforge/plantuml/teavm/js/PSystemBuilderJs.java) omits these factories. Adding C4/ArchiMate macros cannot add a missing compiled diagram engine.

| Removed case | Type / command | Reason |
| --- | --- | --- |
| D056 | `@startditaa` | Ditaa is not included in the bundled PlantUML JavaScript engine. |
| D058 | `@startchronology` | The chronology diagram factory is not registered in the browser build. |
| D061 | `@startmath` | The browser build has no PlantUML AsciiMath renderer. Ordinary MDVu LaTeX/math blocks use KaTeX separately. |
| D062 | `@startlatex` | The browser build has no PlantUML JLaTeXMath renderer. Ordinary MDVu LaTeX/math blocks use KaTeX separately. |
| D064 | `@startchen` | The Chen ER diagram factory is absent from the browser build. |
| D066 | `@startfiles` | The files-tree diagram factory is absent from the browser build. |
| D067 | `@startboard` | The board diagram factory is absent from the browser build. |
| D068 | `@startwire` | The wire diagram factory is absent from the browser build. |
| D092 | `@startflow` | The flow diagram factory is absent from the browser build. |
| D093 | `@starthcl` | The HCL diagram factory is absent from the browser build. |
| D094 | `@startbpm` | The BPM diagram factory is absent from the browser build. |
| D095 | `@startgit` | The git diagram factory is absent from the browser build. |
| D098 | `help types` | Service command help types: the browser build does not register HelpFactory. This is not a diagram family. |
| D099 | `listsprites` | Service command listsprites: the browser build does not register ListSpriteDiagramFactory. This is not a diagram family. |

Initial catalogue validation ran on macOS with 24 Rust unit + 16 integration tests and 88 Swift tests; SVG diagnostic/DOT adapter and locked runtime checks also passed. The subsequent native NAS run verified the same 73 examples on Windows. See Current MDVu verification above for the later tested revision and platform checks. These are correctness checks, not a performance ranking.

## Historical data

Earlier before/after native MDVu and distribution results: `test-results/benchmarks/comparison-history-2026-10-17.md` (local evidence, excluded from Git) retain their original revisions/protocol. Superseded competitor syntax/counts and exploratory memory samples in that archive are not the current comparison.
