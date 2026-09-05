#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$ROOT"

usage() {
    cat <<'EOF'
Usage: ./build.sh [command]

Commands:
  app        Build an optimized app for this Mac (default)
  universal  Build an arm64+x86_64 app
  archive    Build a Universal app and versioned ZIP with SHA-256
  debug      Build the debug executable
  release    Build the optimized executable
  test       Run unit tests
  check      Run unit and visual regression tests
  install    Install a local optimized app into ~/Applications
  publish    Publish release from develop to GitHub and Homebrew (-y|--yes)
  clean      Remove build and distribution products

Signing overrides for app/universal/archive:
  SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"
  CODESIGN_OPTIONS="--options runtime --timestamp"
EOF
}

command=${1:-app}

case "$command" in
    app)       exec make app ;;
    universal) exec make universal ;;
    archive)   exec make archive ;;
    publish)
        shift
        exec "$ROOT/scripts/publish-release.sh" "$@"
        ;;
    debug)     exec make ;;
    release)   exec make release ;;
    test)      exec make test ;;
    check)     make test; exec make visual-test ;;
    install)   exec make install ;;
    clean)     exec make clean ;;
    help|-h|--help) usage ;;
    *)
        echo "Unknown command: $command" >&2
        usage >&2
        exit 2
        ;;
esac
