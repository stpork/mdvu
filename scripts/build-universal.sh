#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
SWIFT_RELEASE_FLAGS=$(make -s print-release-flags)
swift build -c release --arch arm64 --scratch-path "$ROOT/.build/universal-arm" $SWIFT_RELEASE_FLAGS
swift build -c release --arch x86_64 --scratch-path "$ROOT/.build/universal-x86" $SWIFT_RELEASE_FLAGS
lipo -create \
    "$ROOT/.build/universal-arm/arm64-apple-macosx/release/mdvu" \
    "$ROOT/.build/universal-x86/x86_64-apple-macosx/release/mdvu" \
    -output "$ROOT/.build/mdvu-universal"

DYLIB_PATH="$ROOT/target/release/libmdvu_core.dylib"
if command -v rustup >/dev/null 2>&1 && rustup target list --installed | grep -q "x86_64-apple-darwin" && rustup target list --installed | grep -q "aarch64-apple-darwin"; then
    cargo build --release -p mdvu-core --target aarch64-apple-darwin
    cargo build --release -p mdvu-core --target x86_64-apple-darwin
    lipo -create \
        "$ROOT/target/aarch64-apple-darwin/release/libmdvu_core.dylib" \
        "$ROOT/target/x86_64-apple-darwin/release/libmdvu_core.dylib" \
        -output "$ROOT/.build/libmdvu_core-universal.dylib"
    DYLIB_PATH="$ROOT/.build/libmdvu_core-universal.dylib"
else
    cargo build --release -p mdvu-core
fi

make package \
    BINARY="$ROOT/.build/mdvu-universal" \
    DYLIB="$DYLIB_PATH" \
    RESOURCE_BUNDLE="$ROOT/.build/universal-arm/arm64-apple-macosx/release/mdvu_mdvu.bundle"
file "$ROOT/dist/mdvu.app/Contents/MacOS/mdvu"
