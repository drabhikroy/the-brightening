#!/bin/zsh
set -u

# Builds each repository folder given on the command line, runs it, and
# prints what the display is doing, so two builds can be compared as numbers
# instead of by eye. It changes no source files.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIAGNOSE="/tmp/brightening-diagnose"
APP="$HOME/Library/Caches/TheBrighteningBuild/The Brightening.app"

xcrun swiftc "$ROOT/Scripts/Diagnose.swift" -framework AppKit -o "$DIAGNOSE" || exit 1

# Quitting through the app, not killing it, so the app puts the display back
# before the next build starts. A killed copy would leave its boost in place
# and spoil the numbers for whichever build runs next.
quit_app() {
    osascript -e 'tell application "The Brightening" to quit' >/dev/null 2>&1
    sleep 2
}

for repo in "$@"; do
    echo
    echo "=== $repo ==="
    quit_app

    if ! (cd "$repo" && ./build.sh >/dev/null); then
        echo "build failed"
        continue
    fi

    echo "--- built for"
    xcrun vtool -show-build "$APP/Contents/MacOS/TheBrightening" | grep -E "platform|minos|sdk"

    echo "--- entitlements"
    codesign -d --entitlements - "$APP" 2>&1 | grep -v "^Executable"

    open "$APP"

    # Three readings a few seconds apart, because the extended range can move
    # while the system settles.
    for pass in 1 2 3; do
        sleep 4
        echo "--- display, reading $pass of 3"
        "$DIAGNOSE"
    done

    quit_app
    echo "--- display after quitting"
    "$DIAGNOSE"
done
