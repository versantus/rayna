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
  <key>CFBundleShortVersionString</key><string>2.0</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSUserNotificationAlertStyle</key><string>alert</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Simple app icon: 💧 emoji on a blue gradient, rendered with a tiny Swift script (best effort).
TMP="$(mktemp -d)"
cat > "$TMP/icon.swift" <<'SWIFT'
import AppKit
let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let rect = NSRect(x: 0, y: 0, width: size, height: size)
NSBezierPath(roundedRect: rect.insetBy(dx: 80, dy: 80), xRadius: 180, yRadius: 180).addClip()
NSGradient(colors: [NSColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1),
                    NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1)])!.draw(in: rect, angle: -90)
let s = NSAttributedString(string: "💧", attributes: [.font: NSFont.systemFont(ofSize: 560)])
let sz = s.size()
s.draw(at: NSPoint(x: (size - sz.width) / 2, y: (size - sz.height) / 2))
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT
if swift "$TMP/icon.swift" "$TMP/icon.png" 2>/dev/null; then
  ISET="$TMP/AppIcon.iconset"; mkdir -p "$ISET"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon.png" --out "$ISET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$ISET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ISET" -o "$APP/Contents/Resources/AppIcon.icns" || echo "(icon skipped)"
else
  echo "(icon generation skipped)"
fi
rm -rf "$TMP"

codesign --force --deep -s - "$APP"
echo
echo "Built: $(pwd)/$APP"
echo "Install: drag it to /Applications (or: cp -R \"$APP\" /Applications/) and open it."
