#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BIN=${1:-"$ROOT/.build/debug/mdvu"}
mkdir -p "$ROOT/tests/snapshots"
caffeinate -u -t 2 || true
"$BIN" --theme light --snapshot "$ROOT/tests/snapshots/kitchen-sink.png" "$ROOT/tests/fixtures/test-complete.md"
echo "Updated tests/snapshots/kitchen-sink.png"
"$BIN" --theme light --snapshot "$ROOT/tests/snapshots/onescreen.png" "$ROOT/tests/fixtures/test-onescreen.md"
echo "Updated tests/snapshots/onescreen.png"
