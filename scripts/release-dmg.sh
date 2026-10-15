#!/bin/bash
# Developer ID signed, hardened-runtime, notarised + stapled DMG for Rayna (macOS).
# Usage: scripts/release-dmg.sh   (env: IDENTITY, NOTARY_PROFILE, OUT_DIR)
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${IDENTITY:-Developer ID Application: Versantus IT Services Ltd (F9MJXEKGAR)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-rayna-notary}"
OUT_DIR="${OUT_DIR:-$HOME/RaynaBuilds}"
VERSION="2.2.0"; BUILD="6"
DMG="$OUT_DIR/Rayna-$VERSION-signed.dmg"

# 1. Release build: universal if possible, else arm64.
if swift build -c release --arch arm64 --arch x86_64; then
  BINDIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"; ARCHS="arm64 x86_64"
else
  echo "Universal build failed; falling back to arm64" >&2
  swift build -c release --arch arm64
  BINDIR="$(swift build -c release --arch arm64 --show-bin-path)"; ARCHS="arm64"
fi
BIN="$BINDIR/Rayna"

# 2. Assemble Rayna.app (same layout as build.sh).
STAGE="$(mktemp -d)"; APP="$STAGE/Rayna.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Rayna"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Rayna</string>
  <key>CFBundleDisplayName</key><string>Rayna</string>
  <key>CFBundleIdentifier</key><string>co.versantus.rayna</string>
  <key>CFBundleExecutable</key><string>Rayna</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSUserNotificationAlertStyle</key><string>alert</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
cp -R "$BINDIR/Rayna_RaynaCore.bundle" "$APP/Contents/Resources/"
cp assets/MenuGlyph.png assets/MenuGlyph@2x.png "$APP/Contents/Resources/"
ISET="$STAGE/AppIcon.iconset"; mkdir -p "$ISET"
for s in 16 32 128 256 512; do
  sips -z $s $s assets/AppIcon-macOS-1024.png --out "$ISET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) assets/AppIcon-macOS-1024.png --out "$ISET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ISET" -o "$APP/Contents/Resources/AppIcon.icns"; rm -rf "$ISET"
xattr -cr "$APP"

# 3. Sign inside-out (no --deep). No entitlements: no iCloud for this build.
SIGN=(codesign --force --options runtime --timestamp -s "$IDENTITY")
while IFS= read -r -d '' f; do
  if file "$f" | grep -q "Mach-O"; then "${SIGN[@]}" "$f"; fi
done < <(find "$APP/Contents/Resources" -type f -print0)
find "$APP/Contents" -depth \( -name "*.framework" -o -name "*.dylib" \) -print0 | xargs -0 -I{} "${SIGN[@]}" {} 2>/dev/null || true
"${SIGN[@]}" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/Rayna")"

# 4. DMG.
mkdir -p "$OUT_DIR"; rm -f "$DMG"
DMGSRC="$STAGE/dmg"; mkdir -p "$DMGSRC"
cp -R "$APP" "$DMGSRC/"; ln -s /Applications "$DMGSRC/Applications"
hdiutil create -volname Rayna -srcfolder "$DMGSRC" -ov -format UDZO "$DMG"
codesign --force --timestamp -s "$IDENTITY" "$DMG"

# 5. Notarise, staple, verify.
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -vvv -t install "$DMG"
MNT="$(mktemp -d)"; hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$DMG" >/dev/null
spctl -a -vvv "$MNT/Rayna.app" || true
hdiutil detach "$MNT" >/dev/null
rm -rf "$STAGE"
shasum -a 256 "$DMG"
echo "Done: $DMG ($ARCHS)"
