#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/packaging/Info.plist")
ARCHIVE="$ROOT/dist/mdv-${VERSION}-macos-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/mdv.app" "$ARCHIVE"
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
echo "$ARCHIVE"
cat "$ARCHIVE.sha256"
