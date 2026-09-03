#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BIN=${1:-"$ROOT/.build/release/mdv"}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for MB in 1 5 10 25; do
    TARGET=$((MB * 1048576))
    OUT="$TMP/fixture-${MB}mb.md"
    awk -v target="$TARGET" '{ line[NR]=$0; bytes+=length($0)+1 } END { while (written < target) { for (i=1; i<=NR && written<target; i++) { print line[i]; written+=length(line[i])+1 } } }' "$ROOT/Tests/Fixtures/kitchen-sink.md" > "$OUT"
    "$BIN" --benchmark "$OUT"
done
