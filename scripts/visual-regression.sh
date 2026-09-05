#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BIN=${1:-"$ROOT/.build/debug/mdvu"}
REFERENCE="$ROOT/Tests/Snapshots/kitchen-sink.png"
ACTUAL=$(mktemp -t mdvu-snapshot).png
trap 'rm -f "$ACTUAL"' EXIT
test -f "$REFERENCE" || { echo "Missing reference; run make update-snapshot" >&2; exit 1; }
caffeinate -u -t 2 || true
"$BIN" --theme light --snapshot "$ACTUAL" "$ROOT/Tests/Fixtures/kitchen-sink.md"
python3 "$ROOT/scripts/compare_snapshots.py" "$REFERENCE" "$ACTUAL"
echo "Visual regression passed"
