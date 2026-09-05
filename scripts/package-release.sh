#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if [ -f "$ROOT/version.txt" ]; then
    VERSION=$(tr -d '[:space:]' < "$ROOT/version.txt")
else
    VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/packaging/Info.plist")
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$ROOT/packaging/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$ROOT/packaging/Info.plist"

DIST="$ROOT/dist"
mkdir -p "$DIST"

ARM_BIN="$ROOT/.build/universal-arm/arm64-apple-macosx/release/mdvu"
X86_BIN="$ROOT/.build/universal-x86/x86_64-apple-macosx/release/mdvu"
BUNDLE="$ROOT/.build/universal-arm/arm64-apple-macosx/release/mdvu_mdvu.bundle"

echo "==> Packaging arm64 release bundle..."
if [ -f "$ARM_BIN" ]; then
    make package APP="$DIST/mdvu-arm64.app" BINARY="$ARM_BIN" RESOURCE_BUNDLE="$BUNDLE"
    ARM_ZIP="mdvu-${VERSION}-macos-arm64.zip"
    ditto -c -k --sequesterRsrc --keepParent "$DIST/mdvu-arm64.app" "$DIST/$ARM_ZIP"
    (cd "$DIST" && shasum -a 256 "$ARM_ZIP" > "$ARM_ZIP.sha256")
    rm -rf "$DIST/mdvu-arm64.app"
fi

echo "==> Packaging x86_64 release bundle..."
if [ -f "$X86_BIN" ]; then
    make package APP="$DIST/mdvu-x86_64.app" BINARY="$X86_BIN" RESOURCE_BUNDLE="$BUNDLE"
    X86_ZIP="mdvu-${VERSION}-macos-x86_64.zip"
    ditto -c -k --sequesterRsrc --keepParent "$DIST/mdvu-x86_64.app" "$DIST/$X86_ZIP"
    (cd "$DIST" && shasum -a 256 "$X86_ZIP" > "$X86_ZIP.sha256")
    rm -rf "$DIST/mdvu-x86_64.app"
fi

echo "==> Packaging Universal release bundle..."
UNI_ZIP="mdvu-${VERSION}-macos-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$DIST/mdvu.app" "$DIST/$UNI_ZIP"
(cd "$DIST" && shasum -a 256 "$UNI_ZIP" > "$UNI_ZIP.sha256")

echo "==> Packaging DMG release bundle..."
DMG_NAME="mdvu-${VERSION}-macos.dmg"
DMG_PATH="$DIST/$DMG_NAME"
DMG_STAGE=$(mktemp -d /tmp/mdvu-dmg.XXXXXX)
ditto "$DIST/mdvu.app" "$DMG_STAGE/mdvu.app"
ln -s /Applications "$DMG_STAGE/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "mdvu" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGE"
(cd "$DIST" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")

UNI_SHA=$(awk '{print $1}' "$DIST/$UNI_ZIP.sha256")
sed -e "s/version \".*\"/version \"$VERSION\"/" \
    -e "s/sha256 \".*\"/sha256 \"$UNI_SHA\"/" \
    "$ROOT/packaging/Casks/mdvu.rb.template" > "$DIST/mdvu.rb"

echo ""
echo "Release bundles created successfully for v$VERSION:"
ls -lh "$DIST"/mdvu-"$VERSION"-macos*
echo ""
echo "Homebrew Cask generated at $DIST/mdvu.rb"
