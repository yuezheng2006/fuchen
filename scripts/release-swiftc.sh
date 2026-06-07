#!/usr/bin/env bash
# Build Burrow.app with swiftc. Signs + notarizes when CODESIGN_IDENTITY is set.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
SDK=$(xcrun --show-sdk-path)
BIN=build/manual/Burrow
APP=build/Burrow.app
ICNS=build/AppIcon.icns
ZIP="dist/Burrow-${VERSION}.zip"
DMG="dist/Burrow-${VERSION}.dmg"
STAGE=build/dmg-staging

echo "==> compiling Burrow ${VERSION}"
mkdir -p build/manual
swiftc -sdk "$SDK" -target arm64-apple-macos14.0 -O -whole-module-optimization \
  $(find Sources -name '*.swift') -o "$BIN" \
  -framework AppKit -framework SwiftUI -framework Charts \
  -framework CoreServices -framework Network -framework CoreGraphics -lsqlite3

echo "==> building AppIcon.icns"
chmod +x scripts/build-icon.sh
scripts/build-icon.sh >/dev/null

echo "==> packaging ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Burrow"
chmod +x "$APP/Contents/MacOS/Burrow"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Burrow' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier dev.caezium.Burrow' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Burrow' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$APP/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile AppIcon' "$APP/Contents/Info.plist"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

mkdir -p dist
rm -f "$ZIP"
echo "==> zipping ${ZIP}"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

rm -f "$DMG"
echo "==> creating ${DMG}"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Burrow ${VERSION}" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

if [[ -n "${CODESIGN_IDENTITY:-}" && -n "${APPLE_ID:-}" ]]; then
  chmod +x scripts/sign-and-notarize.sh
  scripts/sign-and-notarize.sh "$APP" "$DMG" "$ZIP"
fi

ZIP_SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
DMG_SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
echo
echo "Built Burrow ${VERSION}"
echo "  zip      : ${ZIP}"
echo "  zip sha  : ${ZIP_SHA}"
echo "  dmg      : ${DMG}"
echo "  dmg sha  : ${DMG_SHA}"
if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
  echo
  echo "Note: unsigned build — set CODESIGN_IDENTITY + Apple notarization env to ship Gatekeeper-clean."
  echo "See docs/SIGNING.md"
fi
