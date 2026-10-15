#!/bin/bash
# Build + export the Mac App Store package (Rayna.pkg) for the RaynaMac target.
# The archive is built unsigned, ad-hoc signed with the sandbox/iCloud entitlements,
# then re-signed by the export step (Apple Distribution + Mac App Store profile, created
# automatically). This avoids needing a registered Mac device for development signing.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${OUT:-$(cd .. && pwd)/builds}"
ARCHIVE="$OUT/RaynaMac.xcarchive"; EXPORT="$OUT/RaynaMac-export"
xcodegen generate
rm -rf "$ARCHIVE" "$EXPORT"
xcodebuild -project Rayna.xcodeproj -scheme RaynaMac -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" archive CODE_SIGNING_ALLOWED=NO
codesign --force -s - --options runtime --entitlements RaynaMac/RaynaMac.entitlements \
  "$ARCHIVE/Products/Applications/Rayna.app"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist RaynaMac/ExportOptions-MAS.plist \
  -exportPath "$EXPORT" -allowProvisioningUpdates
pkgutil --check-signature "$EXPORT/Rayna.pkg"
echo "Ready to upload: $EXPORT/Rayna.pkg"
