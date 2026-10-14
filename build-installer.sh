#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

APP="$HOME/Library/Caches/TheBrighteningBuild/The Brightening.app"
DIST="$ROOT/dist"
INSTALLER_SOURCE="$ROOT/Installer"

# Everything that goes into the package is staged in a private temporary
# folder, which the trap below removes however the script exits.
WORK="$(mktemp -d /tmp/the-brightening-installer.XXXXXX)"
PAYLOAD="$WORK/root"
SCRIPTS="$WORK/scripts"

COMPONENT_PKG="$WORK/component.pkg"
UNSIGNED_PKG="$WORK/The Brightening.pkg"
DISTRIBUTION="$WORK/distribution.xml"

APP_SIGN_IDENTITY="${THE_BRIGHTENING_SIGN_IDENTITY:-}"
INSTALLER_IDENTITY="${THE_BRIGHTENING_INSTALLER_IDENTITY:-}"
NOTARY_PROFILE="${THE_BRIGHTENING_NOTARY_PROFILE:-}"

trap 'rm -rf "$WORK"' EXIT

rm -rf "$DIST"
mkdir -p "$DIST"
mkdir -p "$PAYLOAD/Applications"
mkdir -p "$SCRIPTS"

"$ROOT/build.sh"

# The version lives in build.sh only. Reading it back from the finished app
# keeps the installer name and package version from drifting out of step.
VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist")"
# No spaces in the file name. GitHub turns spaces in release assets into
# dots, which would make the README and the checksum file disagree with the
# name people actually download.
FINAL_PKG="$DIST/The-Brightening-${VERSION}.pkg"

codesign \
    --verify \
    --deep \
    --strict \
    --verbose=4 \
    "$APP"

ditto \
    --norsrc \
    "$APP" \
    "$PAYLOAD/Applications/The Brightening.app"

cp "$INSTALLER_SOURCE/preinstall" "$SCRIPTS/preinstall"
cp "$INSTALLER_SOURCE/postinstall" "$SCRIPTS/postinstall"

# The preinstall script runs this helper to ask a running copy to quit, so
# the app gets to restore the display before its files are replaced.
xcrun swiftc \
    -O \
    -target arm64-apple-macos13.0 \
    -framework AppKit \
    "$INSTALLER_SOURCE/QuitRunningApp.swift" \
    -o "$SCRIPTS/quit-the-brightening"

chmod 755 \
    "$SCRIPTS/preinstall" \
    "$SCRIPTS/postinstall" \
    "$SCRIPTS/quit-the-brightening"

# Notarization checks every executable in the package, including this
# helper, so it needs the same Developer ID signature as the app.
if [[ -n "$APP_SIGN_IDENTITY" && "$APP_SIGN_IDENTITY" != "-" ]]; then
    codesign \
        --force \
        --options runtime \
        --timestamp \
        --identifier "com.abhikroy.thebrightening.quit-helper" \
        --sign "$APP_SIGN_IDENTITY" \
        "$SCRIPTS/quit-the-brightening"

    codesign \
        --verify \
        --strict \
        --verbose=4 \
        "$SCRIPTS/quit-the-brightening"
elif [[ -n "$NOTARY_PROFILE" ]]; then
    echo "Notarization requires THE_BRIGHTENING_SIGN_IDENTITY."
    exit 1
fi

# Installing to / with the payload holding Applications puts the app in
# /Applications. Recommended ownership makes the files root owned there.
pkgbuild \
    --root "$PAYLOAD" \
    --scripts "$SCRIPTS" \
    --identifier "com.abhikroy.thebrightening.pkg" \
    --version "$VERSION" \
    --install-location "/" \
    --ownership recommended \
    "$COMPONENT_PKG"

# A bare component package shows the file name as its title and offers fewer
# steps. Wrapping it in a distribution gives the installer window a readable
# title, a welcome step, and the Go Back button on every step after the first.
sed "s/VERSION_PLACEHOLDER/$VERSION/g" \
    "$INSTALLER_SOURCE/distribution.xml" > "$DISTRIBUTION"

productbuild \
    --distribution "$DISTRIBUTION" \
    --resources "$INSTALLER_SOURCE/Resources" \
    --package-path "$WORK" \
    "$UNSIGNED_PKG"

# A package is signed with a Developer ID Installer certificate, which is a
# different certificate from the one that signs the app.
if [[ -n "$INSTALLER_IDENTITY" ]]; then
    productsign \
        --sign "$INSTALLER_IDENTITY" \
        "$UNSIGNED_PKG" \
        "$FINAL_PKG"

    pkgutil \
        --check-signature \
        "$FINAL_PKG"
else
    cp "$UNSIGNED_PKG" "$FINAL_PKG"

    echo
    echo "Installer is unsigned."
    echo "Set THE_BRIGHTENING_INSTALLER_IDENTITY for a public release."
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
    if [[ -z "$INSTALLER_IDENTITY" ]]; then
        echo "Notarization requires a signed installer."
        exit 1
    fi

    xcrun notarytool submit \
        "$FINAL_PKG" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    # Stapling attaches the notarization ticket to the file, so Gatekeeper
    # can check it on a Mac that is offline.
    xcrun stapler staple "$FINAL_PKG"
    xcrun stapler validate "$FINAL_PKG"

    spctl \
        --assess \
        --type install \
        --verbose=4 \
        "$FINAL_PKG"
fi

# Published beside the package so a download can be checked before it is
# opened. Written from inside dist so the file holds bare names, which is what
# shasum -c expects when both files sit in the same folder.
(cd "$DIST" && shasum -a 256 "$(basename "$FINAL_PKG")" > SHA256SUMS.txt)

echo
echo "Installer:"
echo "$FINAL_PKG"
echo
echo "Checksums:"
cat "$DIST/SHA256SUMS.txt"
