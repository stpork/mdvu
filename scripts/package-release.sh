#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

VERSION=$(tr -d '[:space:]' < "$ROOT/version.txt")
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/packaging/macos/Info.plist")
[ "$BUNDLE_VERSION" = "$VERSION" ] || { echo "Version mismatch; run scripts/set-version.py before building." >&2; exit 1; }

DIST="$ROOT/dist"
mkdir -p "$DIST"

ARM_BIN_DIR=$(swift build -c release --arch arm64 --scratch-path "$ROOT/.build/universal-arm" --show-bin-path)
X86_BIN_DIR=$(swift build -c release --arch x86_64 --scratch-path "$ROOT/.build/universal-x86" --show-bin-path)
ARM_BIN="$ARM_BIN_DIR/mdvu"
X86_BIN="$X86_BIN_DIR/mdvu"
BUNDLE="$ARM_BIN_DIR/mdvu_mdvu.bundle"
for required in "$ARM_BIN" "$X86_BIN" "$BUNDLE" \
    "$DIST/mdvu.app/Contents/MacOS/mdvu" \
    "$ROOT/target/aarch64-apple-darwin/release/libmdvu_core.dylib" \
    "$ROOT/target/x86_64-apple-darwin/release/libmdvu_core.dylib"; do
    [ -e "$required" ] || { echo "Missing release input: $required; run make archive." >&2; exit 1; }
done

echo "==> Packaging arm64 release bundle..."
make package BUNDLE_ASSETS=1 APP="$DIST/mdvu-arm64.app" BINARY="$ARM_BIN" DYLIB="$ROOT/target/aarch64-apple-darwin/release/libmdvu_core.dylib" RESOURCE_BUNDLE="$BUNDLE"
ARM_ZIP="mdvu-${VERSION}-macos-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$DIST/mdvu-arm64.app" "$DIST/$ARM_ZIP"
(cd "$DIST" && shasum -a 256 "$ARM_ZIP" > "$ARM_ZIP.sha256")
rm -rf "$DIST/mdvu-arm64.app"

echo "==> Packaging x86_64 release bundle..."
make package BUNDLE_ASSETS=1 APP="$DIST/mdvu-x86_64.app" BINARY="$X86_BIN" DYLIB="$ROOT/target/x86_64-apple-darwin/release/libmdvu_core.dylib" RESOURCE_BUNDLE="$BUNDLE"
X86_ZIP="mdvu-${VERSION}-macos-x86_64.zip"
ditto -c -k --sequesterRsrc --keepParent "$DIST/mdvu-x86_64.app" "$DIST/$X86_ZIP"
(cd "$DIST" && shasum -a 256 "$X86_ZIP" > "$X86_ZIP.sha256")
rm -rf "$DIST/mdvu-x86_64.app"

echo "==> Packaging Universal release bundle..."
UNI_ZIP="mdvu-${VERSION}-macos-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$DIST/mdvu.app" "$DIST/$UNI_ZIP"
(cd "$DIST" && shasum -a 256 "$UNI_ZIP" > "$UNI_ZIP.sha256")

echo "==> Packaging DMG release bundle..."
DMG_NAME="mdvu-${VERSION}-macos.dmg"
DMG_PATH="$DIST/$DMG_NAME"
DMG_STAGE=$(mktemp -d /tmp/mdvu-dmg.XXXXXX)
trap 'rm -rf "$DMG_STAGE"' EXIT
ditto "$DIST/mdvu.app" "$DMG_STAGE/mdvu.app"
ln -s /Applications "$DMG_STAGE/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "mdvu" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGE"
(cd "$DIST" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")

UNI_SHA=$(awk '{print $1}' "$DIST/$UNI_ZIP.sha256")
sed -e "s/version \".*\"/version \"$VERSION\"/" \
    -e "s/sha256 \".*\"/sha256 \"$UNI_SHA\"/" \
    "$ROOT/packaging/homebrew/mdvu.rb.template" > "$DIST/mdvu.rb"

echo ""
echo "Release bundles created successfully for v$VERSION:"
ls -lh "$DIST"/mdvu-"$VERSION"-macos*
echo ""
echo "Homebrew Cask generated at $DIST/mdvu.rb"
