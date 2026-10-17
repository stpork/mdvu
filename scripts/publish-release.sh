#!/bin/bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LIVE=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) LIVE=1 ;;
        -h|--help)
            cat <<'USAGE'
Usage: ./build.sh publish [-y|--yes]

Without --yes: validate all six packages from successful CI for the current
clean develop commit and preview publication. No tag or release is created.
With --yes: merge develop into main, push a new version tag, wait for CI to
build/test both platforms and publish all six packages, update Homebrew and
the website, then bump develop's minor version. Existing tags are never replaced.
USAGE
            exit 0 ;;
        *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
done
[ "$(git branch --show-current)" = develop ] || { echo "Release from develop." >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Commit or stash changes before releasing." >&2; exit 1; }
gh auth status >/dev/null
VERSION=$(tr -d '[:space:]' < version.txt)
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid version: $VERSION" >&2; exit 1; }
TAG="v$VERSION"
SOURCE_COMMIT=$(git rev-parse HEAD)
TEMP=$(mktemp -d /tmp/mdvu-release.XXXXXX)
trap 'rm -rf "$TEMP"' EXIT
awk -v ver="$VERSION" '$0 ~ "^## \\[" ver "\\]" {found=1;next} found && /^## \[/ {exit} found {print}' CHANGELOG.md > "$TEMP/notes.md"
[ -s "$TEMP/notes.md" ] || { echo "Missing CHANGELOG notes for $VERSION" >&2; exit 1; }
RUN=$(gh run list --repo stpork/mdvu --workflow ci.yml --commit "$SOURCE_COMMIT" --event push --status success --limit 1 --json databaseId --jq '.[0].databaseId // empty')
[ -n "$RUN" ] || { echo "Push develop and wait for successful CI on $SOURCE_COMMIT first." >&2; exit 1; }
gh run download "$RUN" --repo stpork/mdvu --name mdvu-macos-release --name mdvu-windows-x86_64 --dir "$TEMP/artifacts"
mkdir "$TEMP/packages"
cp "$TEMP/artifacts/mdvu-macos-release/"* "$TEMP/packages/"
cp "$TEMP/artifacts/mdvu-windows-x86_64/"*.zip* "$TEMP/artifacts/mdvu-windows-x86_64/"*.msi* "$TEMP/packages/"
python3 scripts/release-assets.py "$TEMP/packages" "$VERSION"
cat "$TEMP/notes.md"
echo "Validated all six packages from CI run $RUN for $SOURCE_COMMIT."
if [ "$LIVE" -eq 0 ]; then
    echo "Preview complete. Run ./build.sh publish --yes to publish $TAG through tag CI."
    exit 0
fi

git fetch origin main develop --tags
[ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ] || { echo "Local main must match origin/main." >&2; exit 1; }
git merge-base --is-ancestor main develop || { echo "Merge main into develop and rerun CI first." >&2; exit 1; }
if git show-ref --verify --quiet "refs/tags/$TAG"; then
    echo "$TAG already exists; use a new version." >&2; exit 1
fi
git switch main
git merge --no-ff develop -m "Release $TAG"
git tag -a "$TAG" -m "mdvu release $TAG"
git push --atomic origin main "$TAG"
RELEASE_HEAD=$(git rev-parse HEAD)
RUN=''
for attempt in {1..40}; do
    RUN=$(gh run list --repo stpork/mdvu --workflow ci.yml --branch "$TAG" --commit "$RELEASE_HEAD" --event push --limit 1 --json databaseId --jq '.[0].databaseId // empty')
    [ -n "$RUN" ] && break
    sleep 3
done
[ -n "$RUN" ] || { echo "Tag pushed; check GitHub Actions for publication progress." >&2; exit 1; }
gh run watch "$RUN" --repo stpork/mdvu --exit-status
[ "$(gh release view "$TAG" --repo stpork/mdvu --json isDraft --jq .isDraft)" = false ]

# Use the cask from the published build; its checksum must match that archive.
gh release download "$TAG" --repo stpork/mdvu --pattern mdvu.rb --dir "$TEMP/published"
gh repo clone stpork/homebrew-tap "$TEMP/tap"
mkdir -p "$TEMP/tap/Casks"
cp "$TEMP/published/mdvu.rb" "$TEMP/tap/Casks/mdvu.rb"
git -C "$TEMP/tap" add Casks/mdvu.rb
if ! git -C "$TEMP/tap" diff --cached --quiet; then
    git -C "$TEMP/tap" commit -m "Update mdvu to $TAG"
    git -C "$TEMP/tap" push
fi
gh workflow run 'Deploy MDVu website' --repo stpork/stpork.github.io

git switch develop
NEXT_VERSION=$(python3 -c 'import sys; a,b,_=map(int,sys.argv[1].split(".")); print(f"{a}.{b+1}.0")' "$VERSION")
printf '%s\n' "$NEXT_VERSION" > version.txt
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEXT_VERSION" packaging/macos/Info.plist
git add version.txt packaging/macos/Info.plist
git commit -m "chore: bump version to $NEXT_VERSION"
git push origin develop
echo "Published $TAG with all six packages. Website refresh requested; develop is $NEXT_VERSION."
