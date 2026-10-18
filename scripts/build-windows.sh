#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

VERSION=$(tr -d '[:space:]' < version.txt)

echo "==> Building MDVu Windows ($VERSION)..."

# Determine target
TARGET=""
if [ -n "${CARGO_TARGET:-}" ]; then
    TARGET="$CARGO_TARGET"
elif [ "$(uname -s)" = "Darwin" ] || [ "$(uname -s)" = "Linux" ]; then
    if rustup target list 2>/dev/null | grep -q "x86_64-pc-windows-gnu (installed)" && command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
        TARGET="x86_64-pc-windows-gnu"
    elif rustup target list 2>/dev/null | grep -q "x86_64-pc-windows-msvc (installed)" && command -v cargo-xwin >/dev/null 2>&1; then
        TARGET="x86_64-pc-windows-msvc"
    else
        echo "Error: Cannot cross-compile Windows PE binaries on $(uname -s)." >&2
        echo "Required tools missing. Please either:" >&2
        echo "  1) Install MinGW-w64: rustup target add x86_64-pc-windows-gnu && brew install mingw-w64" >&2
        echo "  2) Or run on Windows using: .\\build.ps1 or build.cmd" >&2
        exit 1
    fi
fi

case "$TARGET" in
    ''|x86_64-pc-windows-gnu|x86_64-pc-windows-msvc) ;;
    *) echo "Error: Windows release packaging requires an x86_64 Windows target." >&2; exit 1 ;;
esac

if [ -n "$TARGET" ]; then
    echo "    Using cargo target: $TARGET"
    if [ "$TARGET" = "x86_64-pc-windows-msvc" ] && command -v cargo-xwin >/dev/null 2>&1; then
        cargo xwin build --release -p mdvu-windows --bin mdvu --target "$TARGET"
    else
        cargo build --release -p mdvu-windows --bin mdvu --target "$TARGET"
    fi
else
    cargo build --release -p mdvu-windows --bin mdvu
fi

DIST_DIR="$ROOT/dist/windows"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Package only the release just built, never an older target or debug binary.
EXE="$ROOT/target/${TARGET:+$TARGET/}release/mdvu.exe"

validate_pe() {
    file_path="$1"
    name="$2"
    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        echo "Error: $name executable not found!" >&2
        exit 1
    fi
    # Must be PE32 / PE32+ Windows binary
    if ! file -b "$file_path" | grep -q "PE32"; then
        echo "Error: $name ($file_path) is not a Windows PE executable:" >&2
        file "$file_path" >&2
        exit 1
    fi
}

validate_pe "$EXE" "mdvu.exe"

cp "$EXE" "$DIST_DIR/mdvu.exe"
echo "  [OK] Copied $(basename "$EXE") -> mdvu.exe ($(file -b "$DIST_DIR/mdvu.exe"))"

# Copy WebView2Loader.dll (required by GNU/MinGW target runtime)
LOADER_DLL=$(find "$(dirname "$EXE")/build" -name "WebView2Loader.dll" | grep -E "x64/WebView2Loader\.dll" | head -n 1)
[ -n "$LOADER_DLL" ] || { echo "Error: WebView2Loader.dll missing from this build." >&2; exit 1; }
cp "$LOADER_DLL" "$DIST_DIR/WebView2Loader.dll"
echo "  [OK] Copied $(basename "$LOADER_DLL") -> WebView2Loader.dll"

[ -f "README.md" ] && cp "README.md" "$DIST_DIR/README.txt"
[ -f "LICENSE" ] && cp "LICENSE" "$DIST_DIR/LICENSE.txt"

ZIP_PATH="$ROOT/dist/mdvu-$VERSION-windows-x86_64.zip"
mkdir -p "$ROOT/dist"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"

echo "==> Creating release archive: $ZIP_PATH"
if command -v zip >/dev/null 2>&1; then
    (cd "$DIST_DIR" && zip -r "$ZIP_PATH" ./* >/dev/null 2>&1)
else
    python3 - "$ZIP_PATH" "$DIST_DIR" <<'PY'
from pathlib import Path
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in Path(sys.argv[2]).iterdir():
        archive.write(path, path.name)
PY
fi

if command -v shasum >/dev/null 2>&1; then
    HASH=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
    HASH=$(sha256sum "$ZIP_PATH" | awk '{print $1}')
else
    HASH=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$ZIP_PATH")
fi

ZIP_BASENAME=$(basename "$ZIP_PATH")
echo "$HASH  $ZIP_BASENAME" > "$ZIP_PATH.sha256"

echo "==> Build complete!"
echo "    Archive: $ZIP_PATH"
echo "    SHA-256: $HASH"
