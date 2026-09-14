#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BIN=${1:-"$ROOT/.build/debug/mdvu"}
REF_COMPLETE="$ROOT/Tests/Snapshots/kitchen-sink.png"
REF_ONESCREEN="$ROOT/Tests/Snapshots/onescreen.png"
ACTUAL_COMPLETE=$(mktemp -t mdvu-complete).png
ACTUAL_ONESCREEN=$(mktemp -t mdvu-onescreen).png
trap 'rm -f "$ACTUAL_COMPLETE" "$ACTUAL_ONESCREEN"' EXIT

test -f "$REF_COMPLETE" || { echo "Missing reference $REF_COMPLETE; run make update-snapshot" >&2; exit 1; }
test -f "$REF_ONESCREEN" || { echo "Missing reference $REF_ONESCREEN; run make update-snapshot" >&2; exit 1; }

caffeinate -u -t 2 || true

echo "==> Testing test-complete.md snapshot..."
"$BIN" --theme light --snapshot "$ACTUAL_COMPLETE" "$ROOT/Tests/Fixtures/test-complete.md"
python3 "$ROOT/scripts/compare_snapshots.py" "$REF_COMPLETE" "$ACTUAL_COMPLETE"

echo "==> Testing test-onescreen.md snapshot (with diagrams)..."
"$BIN" --theme light --snapshot "$ACTUAL_ONESCREEN" "$ROOT/Tests/Fixtures/test-onescreen.md"
python3 "$ROOT/scripts/compare_snapshots.py" "$REF_ONESCREEN" "$ACTUAL_ONESCREEN"

echo "Visual regression passed for all fixtures"
