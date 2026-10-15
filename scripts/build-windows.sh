#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

VERSION=$(cat version.txt 2>/dev/null || echo "0.5.0")
VERSION=$(echo "$VERSION" | tr -d '[:space:]')

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

# Locate compiled .exe binary (only true Windows PE executable)
EXE=""
for candidate in \
    ${TARGET:+"$ROOT/target/$TARGET/release/mdvu.exe"} \
    "$ROOT/target/x86_64-pc-windows-gnu/release/mdvu.exe" \
    "$ROOT/target/x86_64-pc-windows-msvc/release/mdvu.exe" \
    "$ROOT/target/release/mdvu.exe" \
    "$ROOT/target/debug/mdvu.exe"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
        EXE="$candidate"
        break
    fi
done

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

[ -f "README.md" ] && cp "README.md" "$DIST_DIR/README.txt"
[ -f "LICENSE" ] && cp "LICENSE" "$DIST_DIR/LICENSE.txt"

ZIP_PATH="$ROOT/dist/mdvu-$VERSION-windows-x86_64.zip"
mkdir -p "$ROOT/dist"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"

echo "==> Creating release archive: $ZIP_PATH"
if command -v zip >/dev/null 2>&1; then
    (cd "$DIST_DIR" && zip -r "$ZIP_PATH" ./* >/dev/null 2>&1)
else
    python3 -c "import zipfile, glob, os; z = zipfile.ZipFile('$ZIP_PATH', 'w', zipfile.ZIP_DEFLATED); [z.write(f, os.path.basename(f)) for f in glob.glob('$DIST_DIR/*')]; z.close()"
fi

if command -v shasum >/dev/null 2>&1; then
    HASH=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
    HASH=$(sha256sum "$ZIP_PATH" | awk '{print $1}')
else
    HASH=$(python3 -c "import hashlib; print(hashlib.sha256(open('$ZIP_PATH', 'rb').read()).hexdigest())")
fi

ZIP_BASENAME=$(basename "$ZIP_PATH")
echo "$HASH  $ZIP_BASENAME" > "$ZIP_PATH.sha256"

echo "==> Build complete!"
echo "    Archive: $ZIP_PATH"
echo "    SHA-256: $HASH"
