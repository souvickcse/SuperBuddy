#!/usr/bin/env bash
# Builds a shareable copy of Spider Buddy: a universal (Apple Silicon + Intel)
# Release build, wrapped in both a .zip and a .dmg, with a note for whoever you send it to.
#
#   ./Tools/make_dist.sh
#
# Output lands in dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="SpiderBuddy"
VERSION="1.0"
DIST="dist"
APP="build/Build/Products/Release/${APP_NAME}.app"

echo "==> building universal Release (arm64 + x86_64)"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath build \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build | grep -E "error:|warning: .*deprecat|BUILD SUCCEEDED|BUILD FAILED" || true

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
cat > "$DIST/How to open Spider Buddy.txt" <<'TXT'
Spider Buddy - a tiny web-slinging hero who lives on your desktop.

REQUIREMENTS
  macOS 13 (Ventura) or newer. Works on Apple Silicon and Intel Macs.


FIRST LAUNCH - PLEASE READ THIS BIT
  This app is not from the App Store and is not signed with a paid Apple
  developer certificate, so macOS refuses to open it the first time and offers
  to "Move to Bin". It is not damaged and it is not malware - it is simply
  unsigned. Pick ONE of these three:

  A. The usual way (macOS 13 and later)
      1. Drag SpiderBuddy.app into your Applications folder.
      2. Double-click it. macOS blocks it - click "Done", NOT "Move to Bin".
      3. Open System Settings > Privacy & Security.
      4. Scroll down to the "Security" section near the bottom. There is now a
         line saying SpiderBuddy.app was blocked because it is not from an
         identified developer. Click "Open Anyway" and enter your password.
      5. Double-click the app again, then click "Open".

  B. The quick way (Terminal, one line)
       xattr -dr com.apple.quarantine /Applications/SpiderBuddy.app
     Then double-click the app. This only clears the "downloaded from the
     internet" flag - you are not turning off any security feature.

  C. Skip all of it - build it yourself
     With Xcode command line tools installed, open the SpiderBuddy project
     folder and run:   make run
     An app built on your own Mac is never quarantined, so it just opens.

  Note: "right-click > Open" was the old trick. Recent macOS versions removed
  it for downloaded apps, which is why it may not work for you any more.

  No installer, nothing to configure. To uninstall, delete SpiderBuddy.app.


WHAT IT IS
  A small Spider-Man style character who walks along the edges of your screen,
  crawls up the walls and across the top, jumps, shoots webs and swings around,
  rests (sometimes hanging upside down from the ceiling) and does superhero
  landings. Villains drop in every minute or two for a fight.

  * Click him            - he does a little dance
  * Drag him and let go  - he flails, falls and does a superhero landing
  * The spider icon in the menu bar is the whole interface:
      Summon a villain!, Dance, Jump, Web-zip to the ceiling / a wall,
      Rest upside-down, Buddy size, Display (pick which screen he lives on),
      Pause / Resume, Quit.

  He floats above the Dock and menu bar, but every click that is not aimed at
  him goes straight through to whatever is underneath, so he never gets in
  your way.


PRIVACY
  No network access, no analytics, no accounts. The app only draws on your
  screen and reads nothing.

Built from source in the SpiderBuddy project (see README.md). Original
procedurally drawn artwork; an unofficial fan project, not affiliated with
Marvel.
TXT

FOLDER="Spider Buddy ${VERSION}"

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
cp -R "$APP" "$STAGE/$FOLDER/"
cp "$DIST/How to open Spider Buddy.txt" "$STAGE/$FOLDER/"
ditto -c -k --keepParent "$STAGE/$FOLDER" "$DIST/${APP_NAME}-${VERSION}-universal-macOS.zip"
rm -rf "$STAGE"

echo "==> building disk image"
STAGE=".build/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
cp "$DIST/How to open Spider Buddy.txt" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
# makehybrid writes the image directly; `hdiutil create -srcfolder` needs to
# attach a disk device, which not every environment allows
hdiutil makehybrid -quiet -hfs -hfs-volume-name "Spider Buddy" \
  -o "$DIST/${APP_NAME}-${VERSION}-universal.dmg" -ov "$STAGE"
rm -rf "$STAGE"

echo "==> verifying"
MOUNT=".build/mnt"
rm -rf "$MOUNT"; mkdir -p "$MOUNT"
hdiutil attach -readonly -nobrowse -mountpoint "$PWD/$MOUNT" \
  "$DIST/${APP_NAME}-${VERSION}-universal.dmg" >/dev/null
test -x "$MOUNT/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" && echo "    app is inside the dmg and executable"
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
