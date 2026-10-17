# Performance and distribution size

`mdvu` uses a shared Rust Markdown core, AppKit/WebKit on macOS and Win32/WebView2 on Windows. It embeds the offline diagram and math assets, but uses the system browser runtime. The distribution size therefore excludes WebKit/WebView2, their process memory and the writable browser profile.

There is no controlled benchmark of competing applications in this repository. Earlier tables claiming 15–35 ms interactive startup, 28–45 MB GUI memory, 10× lower memory use or competitors crashing were unsupported and have been removed. CLI parsing/export time is not document paint time or interactive startup time.

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

Build and run from an unlocked, interactive desktop. Avoid concurrent builds, browser launches and other benchmarks. Each fixture starts with an empty diagram cache (including repeated runs into the same output directory); the harness saves checks, screenshots, timings and process samples. Preserve the output directory and the source commit before testing another revision.

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

[Public measurements and downloadable fixture data](https://stpork.github.io/mdvu/#performance) identify the measured revision independently of the latest published release. [CI run 39052275911](https://github.com/stpork/mdvu/actions/runs/39052275911) supplied the distribution packages below.

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

These results do not establish a universal speedup. macOS `test-complete.md` zoom maximum increased from 183 to 254 ms and peak footprint from 992.8 to 1,074.24 MiB. Windows `test-heavy.md` tail private bytes increased from 499.9 to 529.2 MiB. First-use layout and fullscreen transitions remain distinct from warm scrolling. The full published data retains fixture-level regressions as well as improvements.
