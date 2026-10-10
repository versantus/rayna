#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Rayna"

APP="Rayna.app"
rm -rf "$APP"
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
  <key>CFBundleShortVersionString</key><string>2.2.0</string>
  <key>CFBundleVersion</key><string>6</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSUserNotificationAlertStyle</key><string>alert</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Rayna's Higgsfield art: SwiftPM resource bundle (frame animations + band stills), menu-bar glyph, app icon (icon B).
BINDIR="$(dirname "$BIN")"
cp -R "$BINDIR/Rayna_RaynaCore.bundle" "$APP/Contents/Resources/"
cp assets/MenuGlyph.png assets/MenuGlyph@2x.png "$APP/Contents/Resources/"

TMP="$(mktemp -d)"
ISET="$TMP/AppIcon.iconset"; mkdir -p "$ISET"
for s in 16 32 128 256 512; do
  sips -z $s $s assets/AppIcon-macOS-1024.png --out "$ISET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) assets/AppIcon-macOS-1024.png --out "$ISET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ISET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"

codesign --force --deep -s - "$APP"
echo
echo "Built: $(pwd)/$APP"
echo "Install: drag it to /Applications (or: cp -R \"$APP\" /Applications/) and open it."
