#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

VERSION=$(cat version.txt 2>/dev/null || echo "0.5.0")
VERSION=$(echo "$VERSION" | tr -d '[:space:]')

echo "==> Building MDVu Windows ($VERSION)..."

# Build with cargo
if [ -n "${CARGO_TARGET:-}" ]; then
    cargo build --release -p mdvu-windows -p mdvu-cli --target "$CARGO_TARGET"
else
    # Check if native Windows or cross-compilation target is available
    if [ "$(uname -s)" = "Darwin" ] || [ "$(uname -s)" = "Linux" ]; then
        if rustup target list 2>/dev/null | grep -q "x86_64-pc-windows-msvc (installed)"; then
            cargo build --release -p mdvu-windows -p mdvu-cli --target x86_64-pc-windows-msvc 2>/dev/null || cargo build --release -p mdvu-windows -p mdvu-cli || true
        else
            cargo build --release -p mdvu-windows -p mdvu-cli || true
        fi
    else
        cargo build --release -p mdvu-windows -p mdvu-cli
    fi
fi

DIST_DIR="$ROOT/dist/windows"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

EXE=""
for candidate in \
    "$ROOT/target/x86_64-pc-windows-msvc/release/mdvu-windows.exe" \
    "$ROOT/target/x86_64-pc-windows-gnu/release/mdvu-windows.exe" \
    "$ROOT/target/release/mdvu-windows.exe" \
    "$ROOT/target/release/mdvu-windows" \
    "$ROOT/target/debug/mdvu-windows.exe" \
    "$ROOT/target/debug/mdvu-windows"; do
    if [ -f "$candidate" ]; then
        EXE="$candidate"
        break
    fi
done

CLI=""
for candidate in \
    "$ROOT/target/x86_64-pc-windows-msvc/release/mdvu-cli.exe" \
    "$ROOT/target/x86_64-pc-windows-gnu/release/mdvu-cli.exe" \
    "$ROOT/target/release/mdvu-cli.exe" \
    "$ROOT/target/release/mdvu-cli" \
    "$ROOT/target/debug/mdvu-cli.exe" \
    "$ROOT/target/debug/mdvu-cli"; do
    if [ -f "$candidate" ]; then
        CLI="$candidate"
        break
    fi
done

if [ -n "$EXE" ]; then
    cp "$EXE" "$DIST_DIR/mdvu.exe"
    echo "  [OK] Copied $(basename "$EXE") -> mdvu.exe"
else
    echo "  [INFO] mdvu-windows.exe will be built on Windows host or via MSVC toolchain"
fi

if [ -n "$CLI" ]; then
    cp "$CLI" "$DIST_DIR/mdvu-cli.exe"
    echo "  [OK] Copied $(basename "$CLI") -> mdvu-cli.exe"
fi

[ -f "README.md" ] && cp "README.md" "$DIST_DIR/README.txt"
[ -f "LICENSE" ] && cp "LICENSE" "$DIST_DIR/LICENSE.txt"

ZIP_PATH="$ROOT/dist/mdvu-$VERSION-windows-x86_64.zip"
mkdir -p "$ROOT/dist"

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
