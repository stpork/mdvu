#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
OUT="$ROOT/target/coverage"
mkdir -p "$OUT"
for engine in rust swift; do
    MDVU_ENGINE="$engine" make test SWIFT_TEST_ARGS=--enable-code-coverage
    BIN_DIR=$(swift build --show-bin-path)
    cp "$BIN_DIR/codecov/default.profdata" "$OUT/swift-$engine.profdata"
done
xcrun llvm-profdata merge -sparse "$OUT/swift-rust.profdata" "$OUT/swift-swift.profdata" -o "$OUT/swift.profdata"
TEST_BINARY=$(find "$BIN_DIR" -path '*Tests.xctest/Contents/MacOS/*' -type f | head -n 1)
test -n "$TEST_BINARY"
xcrun llvm-cov export "$TEST_BINARY" -instr-profile="$OUT/swift.profdata" > "$OUT/swift.json"
