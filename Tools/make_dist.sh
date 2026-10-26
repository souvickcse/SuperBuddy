#!/usr/bin/env bash
# Builds a shareable copy of Super Buddy: a universal (Apple Silicon + Intel)
# Release build, wrapped in both a .zip and a .dmg, with a note for whoever you send it to.
#
#   ./Tools/make_dist.sh
#
# Output lands in dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="SuperBuddy"
VERSION="1.1"
DIST="dist"
APP="build/Build/Products/Release/${APP_NAME}.app"

xcodegen generate

echo "==> building universal Release (arm64 + x86_64)"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath build \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build

test -d "$APP" || { echo "build produced no app"; exit 1; }

echo "==> checking binary"
lipo -info "$APP/Contents/MacOS/${APP_NAME}"
codesign --verify --deep --strict "$APP" && echo "    signature ok (ad-hoc)"
V=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
echo "    version $V"

# Optional: set SIGN_IDENTITY to a "Developer ID Application: ..." identity to
# produce a build that opens with no warning at all, and NOTARY_PROFILE to a
# stored notarytool profile to have it notarised and stapled.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

echo "==> staging $DIST/"
rm -rf "$DIST"
mkdir -p "$DIST"

# the note that goes out with it
cat > "$DIST/How to open Super Buddy.txt" <<'TXT'
Super Buddy - selectable superhero companions for your Mac desktop.

REQUIREMENTS
  macOS 13 (Ventura) or newer. Works on Apple Silicon and Intel Macs.


FIRST LAUNCH
  This app is ad-hoc signed and is not notarized with Apple. If macOS blocks
  the first launch, open System Settings > Privacy & Security, find the
  SuperBuddy entry and choose Open Anyway. Only approve an app you trust.

  To uninstall, delete SuperBuddy.app, or use brew uninstall --cask superbuddy
  if you installed it with Homebrew.


WHAT IT IS
  Four selectable desktop companions: Spider-Buddy, Pool-Buddy, Bat-Buddy and Smash-Buddy.
  Use the shield icon in the menu bar to choose a buddy and trigger actions.

  * Spider-Buddy: web swinging, wall crawling, jumps and superhero landings.
  * Pool-Buddy: katana sequences, pistol actions, swagger and dancing.
  * Bat-Buddy: Wingblades, grappling, gliding, Bat-Beacon bat camouflage, and a
    Buddy-Mobile that drives and climbs the side walls at high speed.
  * Smash-Buddy: heavy movement, super leaps, smashes, thunderclaps and roaring.
  * Each buddy has its own villain roster.
  * Click or drag your buddy, select size/display, pause, reset or quit from
    the menu bar. The Buddy-Mobile command starts a ride or brings it back.

  The overlay passes clicks through to other apps except over the buddy.


PRIVACY
  No network access, no analytics, no accounts. The app uses pointer position
  for interaction and does not capture your screen contents.

Built from source in the SuperBuddy project (see README.md). Original
procedurally drawn artwork; an unofficial fan project, not affiliated with
Marvel or DC.
TXT

FOLDER="Super Buddy ${VERSION}"

if [ "$SIGN_IDENTITY" != "-" ]; then
  echo "==> signing with $SIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --deep --strict "$APP" && echo "    signature ok"
else
  echo "==> ad-hoc signature (no Developer ID certificate set)"
fi

echo "==> zipping"
# keep the bundle intact (permissions + symlinks) - ditto, not zip
STAGE=".build/zip"
rm -rf "$STAGE"
mkdir -p "$STAGE/$FOLDER"
ditto --norsrc --noextattr "$APP" "$STAGE/$FOLDER/${APP_NAME}.app"
cp "$DIST/How to open Super Buddy.txt" "$STAGE/$FOLDER/"
ditto -c -k --keepParent "$STAGE/$FOLDER" "$DIST/${APP_NAME}-${VERSION}-universal-macOS.zip"
rm -rf "$STAGE"

echo "==> building disk image"
STAGE=".build/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto --norsrc --noextattr "$APP" "$STAGE/${APP_NAME}.app"
cp "$DIST/How to open Super Buddy.txt" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
# Use a compressed disk image so signed app metadata stays intact.
hdiutil create -format UDZO -volname "Super Buddy" \
  -srcfolder "$STAGE" -o "$DIST/${APP_NAME}-${VERSION}-universal.dmg" -ov
rm -rf "$STAGE"

echo "==> verifying"
MOUNT=".build/mnt"
rm -rf "$MOUNT"; mkdir -p "$MOUNT"
hdiutil attach -readonly -nobrowse -mountpoint "$PWD/$MOUNT" \
  "$DIST/${APP_NAME}-${VERSION}-universal.dmg" >/dev/null
test -x "$MOUNT/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" && echo "    app is inside the dmg and executable"
codesign --verify --deep --strict "$MOUNT/${APP_NAME}.app"
lipo -info "$MOUNT/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" | sed 's/^/    /'
hdiutil detach "$PWD/$MOUNT" >/dev/null
rm -rf "$MOUNT"

if [ -n "$NOTARY_PROFILE" ]; then
  echo "==> notarising (this can take a few minutes)"
  xcrun notarytool submit "$DIST/${APP_NAME}-${VERSION}-universal.dmg" \
    --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DIST/${APP_NAME}-${VERSION}-universal.dmg"
  echo "    notarised and stapled"
fi

echo "==> done"
ls -lh "$DIST"
echo
echo "Share either file. The .dmg is friendlier for non-technical people."
