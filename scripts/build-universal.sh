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
make package \
    BINARY="$ROOT/.build/mdvu-universal" \
    RESOURCE_BUNDLE="$ROOT/.build/universal-arm/arm64-apple-macosx/release/mdvu_mdvu.bundle"
file "$ROOT/dist/mdvu.app/Contents/MacOS/mdvu"
