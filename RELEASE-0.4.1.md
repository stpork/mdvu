# mdvu 0.4.1 release preparation

Prepared 2026-09-15. Publication, release tags, merging into `main`, and Homebrew tap updates are not part of this preparation.

## Scope

- File-URL TOC navigation tolerates WebKit history API restrictions.
- Re-selecting a TOC row after manual scrolling returns to that heading; normal selection still supports keyboard navigation.
- Regression checks assert actual heading position for push/replace paths and a missing target.
- CI test expressions explicitly return a concrete value instead of JavaScript `undefined`; the macOS 14 async WebKit bridge could previously crash while unwrapping its result. The one-screen fixture now runs in any checkout.
- README, architecture, changelog, Info.plist, `version.txt`, CLI and About fallback versions are aligned with 0.4.1.

## Validation

- `make test`: 61 tests passed.
- Real UI: opened CHANGELOG.md in the installed 0.4.1 user copy, selected release 0.3.1 and observed that heading at the top of the document. Scroll-bar position moved from 0 to 0.5155602. After manual scrolling to 0.6456892, clicking the same selected row restored 0.5155602.
- `make archive`: arm64, x86_64, Universal ZIPs and Universal DMG built.
- Universal visual regression: both `test-complete.md` and `test-onescreen.md` (diagrams included) matched their existing references, normalized RMS 0.00000 each. No reference or tolerance changes.
- `codesign -v --deep --strict dist/mdvu.app`: passed (ad-hoc signature).
- All four SHA-256 sidecars verified; packaged executable reports `mdvu 0.4.1`.
- GitHub CI is tracked on [draft PR #1](https://github.com/stpork/mdvu/pull/1); use its latest check result for hosted-runner validation.

## Performance and size

Native arm64 parser benchmark on this Mac: five iterations after warmup, generated repetitions of `test-light.md`. Median times: 1 MiB **61.21 ms**, 5 MiB **304.81 ms**, 10 MiB **612.22 ms**, 25 MiB **1541.56 ms**. This measures parsing, not loading/rendering the DOM or diagram execution. No cross-machine or fixed-FPS guarantee is implied.

Retained `-O`, cross-module optimization, dead stripping, stripped executables, LZMA engines, WebView prewarming and shared SVG cache. No dependencies, parser features or diagram formats were removed. UI navigation does not reparse the document.

Local release artifacts:

| Artifact | Bytes |
|---|---:|
| arm64 ZIP | 3,115,062 |
| x86_64 ZIP | 3,146,620 |
| Universal ZIP | 3,432,993 |
| Universal DMG | 3,801,150 |

Universal app disk allocation: 4,272 KiB. Compressed resources are stored once in the Universal bundle. Signing and packaging metadata can change archive sizes in subsequent builds.

## Installed-copy caveat

The broken system copy at `/Applications/mdvu.app` was confirmed to contain the old JavaScript without the history exception guard. It belongs to root and could not be overwritten without administrative access. The verified 0.4.1 native build is installed at `/Users/C5370280/SAPDevelop/Applications/mdvu.app`. Opening the system copy will still run the old code until it is replaced. No administrator permissions or default file associations were changed.

## Remaining measurement limits

These checks do not prove zero leaks, a minimum possible binary size, or a fixed scrolling/zoom frame rate. WebKit uses auxiliary processes, runtime strings are retained for reuse, and NSCache limits are advisory. Release artifacts are locally signed; Developer ID signing/notarization is not established by these checks.
