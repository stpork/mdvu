#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BIN=${1:-"$ROOT/.build/debug/mdvu"}
mkdir -p "$ROOT/Tests/Snapshots"
caffeinate -u -t 2 || true
"$BIN" --theme light --snapshot "$ROOT/Tests/Snapshots/kitchen-sink.png" "$ROOT/Tests/Fixtures/kitchen-sink.md"
echo "Updated Tests/Snapshots/kitchen-sink.png"
