#!/bin/bash
# Regenerates iOS/Rayna/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png from the shared Rayna drawing.
set -euo pipefail
cd "$(dirname "$0")/../.."
TMP="$(mktemp -d)"
cp iOS/scripts/make-icon.swift "$TMP/main.swift"
swiftc -O -o "$TMP/make-icon" "$TMP/main.swift" Sources/RaynaCore/RaynaView.swift
OUT=iOS/Rayna/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"$TMP/make-icon" "$OUT"
# App Store icons must have no alpha channel
sips -s format jpeg -s formatOptions 100 "$OUT" --out "$TMP/i.jpg" >/dev/null && sips -s format png "$TMP/i.jpg" --out "$OUT" >/dev/null
rm -rf "$TMP"
