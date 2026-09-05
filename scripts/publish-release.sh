#!/bin/bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

AUTO_APPROVE=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) AUTO_APPROVE=1 ;;
        -h|--help)
            cat <<'USAGE'
Usage: ./build.sh publish [-y|--yes]

Modes:
  ./build.sh publish          Dry run: runs tests, compiles all release bundles
                             (arm64, x86_64, universal, dmg), verifies checksums,
                             and displays preview without pushing or uploading.
  ./build.sh publish -y       Full release: tests, builds, commits on develop,
                             merges into main, tags, pushes upstream to GitHub,
                             uploads GitHub release assets, updates stpork/homebrew-tap,
                             and bumps version Y-counter on develop.
USAGE
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            echo "Run './build.sh publish --help' for usage." >&2
            exit 2
            ;;
    esac
done

echo "=================================================="
if [ "$AUTO_APPROVE" -eq 1 ]; then
    echo "       mdvu Release Publication (LIVE MODE)       "
else
    echo "       mdvu Release Publication (DRY RUN)         "
fi
echo "=================================================="

# 1. Branch validation
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "develop" ]; then
    echo "ERROR: Release publication must be initiated from the 'develop' branch." >&2
    echo "Current branch: '$CURRENT_BRANCH'" >&2
    exit 1
fi

# 2. Check tools
if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: 'gh' (GitHub CLI) is required but not installed." >&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: 'gh' is not authenticated. Run 'gh auth login' first." >&2
    exit 1
fi

# 3. Read and validate current version format X.Y.Z
if [ ! -f "$ROOT/version.txt" ]; then
    echo "ERROR: version.txt not found in project root." >&2
    exit 1
fi
VERSION=$(tr -d '[:space:]' < "$ROOT/version.txt")

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: version.txt must follow semantic version format X.Y.Z (e.g. 0.2.0). Found: '$VERSION'" >&2
    exit 1
fi

TAG="v$VERSION"
echo "Target Version: $VERSION"
echo "Target Tag:     $TAG"

# 4. Extract release notes from CHANGELOG.md
NOTES_FILE=$(mktemp /tmp/mdvu-notes.XXXXXX)
awk -v ver="$VERSION" '
  $0 ~ "^## \\[" ver "\\]" { found=1; next }
  found && /^## \[/ { exit }
  found { print }
' "$ROOT/CHANGELOG.md" > "$NOTES_FILE"

if [ ! -s "$NOTES_FILE" ]; then
    echo "ERROR: No release notes found for version '$VERSION' in CHANGELOG.md" >&2
    echo "Please add a '## [$VERSION]' section to CHANGELOG.md before releasing." >&2
    rm -f "$NOTES_FILE"
    exit 1
fi

echo ""
echo "--- Release Notes from CHANGELOG.md ($TAG) ---"
cat "$NOTES_FILE"
echo "--------------------------------------------------"
echo ""

# 5. Run test suite
echo "==> Step 1/4: Running automated test suite..."
make test

# 6. Build release bundles (arm64, x86_64, universal, dmg)
echo "==> Step 2/4: Compiling and packaging release bundles..."
make archive

DIST="$ROOT/dist"
ARM_ZIP="$DIST/mdvu-${VERSION}-macos-arm64.zip"
X86_ZIP="$DIST/mdvu-${VERSION}-macos-x86_64.zip"
UNI_ZIP="$DIST/mdvu-${VERSION}-macos-universal.zip"
DMG_FILE="$DIST/mdvu-${VERSION}-macos.dmg"

for required_file in "$ARM_ZIP" "$X86_ZIP" "$UNI_ZIP" "$DMG_FILE"; do
    if [ ! -f "$required_file" ]; then
        echo "ERROR: Expected release artifact '$required_file' was not generated." >&2
        rm -f "$NOTES_FILE"
        exit 1
    fi
done

echo "==> Step 3/4: Verifying bundle integrity and checksums..."
ls -lh "$ARM_ZIP" "$X86_ZIP" "$UNI_ZIP" "$DMG_FILE"
echo ""

# Calculate next version by always bumping Y (minor): X.(Y+1).0
bump_y_counter() {
    local v="$1"
    if [[ "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        local maj="${BASH_REMATCH[1]}"
        local min="${BASH_REMATCH[2]}"
        echo "$maj.$((min + 1)).0"
    else
        echo "ERROR: Invalid version format for bump: $v" >&2
        exit 1
    fi
}
NEXT_VERSION=$(bump_y_counter "$VERSION")

# If this is DRY RUN mode, stop here and show preview
if [ "$AUTO_APPROVE" -ne 1 ]; then
    rm -f "$NOTES_FILE"
    echo "=================================================="
    echo "           DRY RUN COMPLETED SUCCESSFULLY         "
    echo "=================================================="
    echo "All tests passed and release bundles were generated:"
    echo "  - arm64 zip:     $ARM_ZIP"
    echo "  - x86_64 zip:    $X86_ZIP"
    echo "  - universal zip: $UNI_ZIP"
    echo "  - dmg:           $DMG_FILE"
    echo "  - Homebrew Cask: $DIST/mdvu.rb"
    echo ""
    echo "In LIVE mode (-y | --yes), the following actions will be executed:"
    echo "  1. Stage and commit pending develop branch changes ('chore(release): prepare $TAG')"
    echo "  2. Switch to 'main', merge 'develop' (--no-ff), and create git tag '$TAG'"
    echo "  3. Push 'main', 'develop', and '$TAG' to https://github.com/stpork/mdvu.git"
    echo "  4. Create GitHub Release '$TAG' with release notes and upload all 4 bundles + sha256"
    echo "  5. Clone and update 'stpork/homebrew-tap' (Casks/mdvu.rb), run brew audit, commit & push"
    echo "  6. Switch back to 'develop', bump version to '$NEXT_VERSION', commit and push to remote"
    echo ""
    echo "To execute publication, re-run with:"
    echo "    ./build.sh publish -y"
    echo "=================================================="
    exit 0
fi

# =======================================================
# LIVE PUBLICATION (when -y or --yes was provided)
# =======================================================
echo "==> Step 4/4: Executing Live Publication..."

# 1. Commit pending changes on develop
echo "--> Finalizing commit on develop branch..."
if ! git diff-index --quiet HEAD --; then
    git add -A
    git commit -m "chore(release): prepare $TAG"
fi

# 2. Merge develop into main and create tag
echo "--> Merging develop into main and creating tag $TAG..."
git checkout main
git merge --no-ff develop -m "Release $TAG"
git tag -d "$TAG" 2>/dev/null || true
git tag -a "$TAG" -m "mdvu release $TAG"

# 3. Push to upstream repository
echo "--> Pushing branches and tags to https://github.com/stpork/mdvu..."
REMOTE_URL="https://github.com/stpork/mdvu.git"
git remote add origin "$REMOTE_URL" 2>/dev/null || git remote set-url origin "$REMOTE_URL"
git push origin main
git push origin develop
git push origin "$TAG"

# 4. Create/update GitHub Release and upload assets
echo "--> Creating GitHub Release $TAG and uploading bundle assets..."
if gh release view "$TAG" --repo stpork/mdvu >/dev/null 2>&1; then
    echo "Release $TAG already exists on GitHub. Updating release notes..."
    gh release edit "$TAG" --repo stpork/mdvu --title "mdvu $TAG" --notes-file "$NOTES_FILE"
else
    gh release create "$TAG" \
        --repo stpork/mdvu \
        --title "mdvu $TAG" \
        --notes-file "$NOTES_FILE"
fi

gh release upload "$TAG" \
    --repo stpork/mdvu \
    --clobber \
    "$ARM_ZIP" "$ARM_ZIP.sha256" \
    "$X86_ZIP" "$X86_ZIP.sha256" \
    "$UNI_ZIP" "$UNI_ZIP.sha256" \
    "$DMG_FILE" "$DMG_FILE.sha256"

rm -f "$NOTES_FILE"

# 5. Update Homebrew tap
echo "--> Updating Homebrew tap stpork/homebrew-tap..."
TAP_DIR=$(mktemp -d /tmp/stpork-tap.XXXXXX)
if ! gh repo clone stpork/homebrew-tap "$TAP_DIR" 2>/dev/null; then
    git clone https://github.com/stpork/homebrew-tap.git "$TAP_DIR" || true
fi

cd "$TAP_DIR"
mkdir -p Casks
cp "$DIST/mdvu.rb" Casks/mdvu.rb

if command -v brew >/dev/null 2>&1; then
    echo "Running brew audit..."
    brew audit --cask Casks/mdvu.rb 2>&1 || true
fi

git add Casks/mdvu.rb
if ! git diff-index --quiet HEAD --; then
    git commit -m "Update mdvu to $TAG"
    git branch -M main 2>/dev/null || true
    git push -u origin main
    echo "Homebrew tap updated successfully."
else
    echo "Homebrew tap formula already up-to-date."
fi
rm -rf "$TAP_DIR"

cd "$ROOT"

# 6. Switch back to develop and bump Y-counter
echo "--> Switching back to develop and bumping version counter to v$NEXT_VERSION..."
git checkout develop
echo "$NEXT_VERSION" > "$ROOT/version.txt"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEXT_VERSION" "$ROOT/packaging/Info.plist" 2>/dev/null || true

git add "$ROOT/version.txt" "$ROOT/packaging/Info.plist"
git commit -m "chore: bump version to $NEXT_VERSION"
git push origin develop

echo ""
echo "=================================================="
echo "      mdvu $TAG published successfully!           "
echo "      develop branch bumped to v$NEXT_VERSION     "
echo "=================================================="
