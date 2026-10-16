#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
SWIFT_RELEASE_FLAGS=$(make -s print-release-flags)
swift build -c release --arch arm64 --scratch-path "$ROOT/.build/universal-arm" $SWIFT_RELEASE_FLAGS
swift build -c release --arch x86_64 --scratch-path "$ROOT/.build/universal-x86" $SWIFT_RELEASE_FLAGS
ARM_BIN_DIR=$(swift build -c release --arch arm64 --scratch-path "$ROOT/.build/universal-arm" --show-bin-path)
X86_BIN_DIR=$(swift build -c release --arch x86_64 --scratch-path "$ROOT/.build/universal-x86" --show-bin-path)
lipo -create \
    "$ARM_BIN_DIR/mdvu" \
    "$X86_BIN_DIR/mdvu" \
    -output "$ROOT/.build/mdvu-universal"

# Both core slices are mandatory: packaging must never silently fall back to a host-only dylib.
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo build --release -p mdvu-core --target aarch64-apple-darwin
cargo build --release -p mdvu-core --target x86_64-apple-darwin
lipo -create \
    "$ROOT/target/aarch64-apple-darwin/release/libmdvu_core.dylib" \
    "$ROOT/target/x86_64-apple-darwin/release/libmdvu_core.dylib" \
    -output "$ROOT/.build/libmdvu_core-universal.dylib"
DYLIB_PATH="$ROOT/.build/libmdvu_core-universal.dylib"
mkdir -p "$ROOT/target/swift-ir"
for output in "$ROOT"/*.bc; do
    if [ -f "$output" ]; then mv "$output" "$ROOT/target/swift-ir/"; fi
done

make package \
    BINARY="$ROOT/.build/mdvu-universal" \
    DYLIB="$DYLIB_PATH" \
    RESOURCE_BUNDLE="$ARM_BIN_DIR/mdvu_mdvu.bundle"
file "$ROOT/dist/mdvu.app/Contents/MacOS/mdvu"
