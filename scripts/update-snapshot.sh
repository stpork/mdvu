#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BIN=${1:-"$ROOT/.build/debug/mdv"}
mkdir -p "$ROOT/Tests/Snapshots"
"$BIN" --theme light --snapshot "$ROOT/Tests/Snapshots/kitchen-sink.png" "$ROOT/Tests/Fixtures/kitchen-sink.md"
echo "Updated Tests/Snapshots/kitchen-sink.png"
