#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
swift package --scratch-path "$ROOT/.build/universal-arm" clean
swift package --scratch-path "$ROOT/.build/universal-x86" clean
swift build -c release --arch arm64 --scratch-path "$ROOT/.build/universal-arm"
swift build -c release --arch x86_64 --scratch-path "$ROOT/.build/universal-x86"
lipo -create \
    "$ROOT/.build/universal-arm/arm64-apple-macosx/release/mdv" \
    "$ROOT/.build/universal-x86/x86_64-apple-macosx/release/mdv" \
    -output "$ROOT/.build/mdv-universal"
make package \
    BINARY="$ROOT/.build/mdv-universal" \
    RESOURCE_BUNDLE="$ROOT/.build/universal-arm/arm64-apple-macosx/release/mdv_mdv.bundle"
file "$ROOT/dist/mdv.app/Contents/MacOS/mdv"
