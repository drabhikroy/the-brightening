#!/bin/zsh
set -euo pipefail

umask 022

VERSION="1.0.0"
BUILD_NUMBER="1"

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"

# Without an explicit target, swiftc stamps the binary with the macOS version
# of the Mac doing the build, so Info.plist states that same major version.
# Saying 13.0 here while the binary needs a newer system would only make the
# failure show up as a confusing launch error instead of a clear message.
MIN_MACOS="$(sw_vers -productVersion | cut -d. -f1).0"

# The bundle is assembled outside the repository. If the repository sits in
# an iCloud synced folder, iCloud can attach extended attributes to files
# while codesign is reading them, and the signature then fails to verify.
STAGE="$HOME/Library/Caches/TheBrighteningBuild"
APP="$STAGE/The Brightening.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICONSET="$STAGE/AppIcon.iconset"

ZIP="$BUILD/The Brightening.zip"

rm -rf "$BUILD" "$STAGE"
mkdir -p "$BUILD" "$MACOS" "$RESOURCES" "$ICONSET"

# No optimizer flag and no explicit deployment target, on purpose. A build
# with both washed out the display on an XDR MacBook, while this plain build
# looks right. Test on the hardware before adding either one back. Built-in
# XDR panels only ship in Apple silicon Macs, so the build machine's own
# architecture is the right one.
xcrun swiftc \
    -warnings-as-errors \
    "$ROOT"/Sources/*.swift \
    -framework AppKit \
    -framework CoreGraphics \
    -framework Metal \
    -framework QuartzCore \
    -framework ServiceManagement \
    -o "$MACOS/TheBrightening"

# iconutil wants every size under the names an icon set uses, including the
# doubled Retina ones, so the PNG set in Assets is copied in under both.
for size in 16 32 128 256 512; do
    cp "$ROOT/Assets/png/AppIcon-$size.png" "$ICONSET/icon_${size}x${size}.png"
    cp "$ROOT/Assets/png/AppIcon-$((size * 2)).png" "$ICONSET/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>The Brightening</string>
    <key>CFBundleExecutable</key>
    <string>TheBrightening</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.abhikroy.thebrightening</string>
    <key>CFBundleName</key>
    <string>The Brightening</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 Abhik Roy</string>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS/Info.plist"

find "$APP" -name '._*' -delete
xattr -cr "$APP"

# With no identity set, the app is signed ad hoc. That is fine for running
# it on this Mac, but only a Developer ID signature can be notarized.
SIGN_IDENTITY="${THE_BRIGHTENING_SIGN_IDENTITY:--}"
ENTITLEMENTS="$ROOT/TheBrightening.entitlements"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign - "$APP"
else
    codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
fi

codesign --verify --deep --strict --verbose=4 "$APP"

ditto -c -k --norsrc --keepParent "$APP" "$ZIP"

echo
echo "Signed app:"
echo "$APP"
echo
echo "Archive:"
echo "$ZIP"
