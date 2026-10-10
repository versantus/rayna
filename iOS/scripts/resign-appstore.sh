#!/bin/bash
# Re-signs the exported App Store IPA with the full entitlements (App Group, iCloud, HealthKit, push).
# Needed because the team has no registered devices, so Xcode can't make the development profiles an archive normally uses.
set -e
cd /tmp && rm -rf ipa && mkdir ipa && cd ipa && unzip -q ~/RaynaBuilds/export/Rayna.ipa
ID="Apple Distribution: Versantus IT Services Ltd (F9MJXEKGAR)"
mkent(){
 security cms -D -i "$1/embedded.mobileprovision" > /tmp/prof.plist
 B=$(plutil -extract Entitlements.application-identifier raw /tmp/prof.plist)
 cat > /tmp/ent.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>application-identifier</key><string>$B</string>
<key>com.apple.developer.team-identifier</key><string>F9MJXEKGAR</string>
<key>beta-reports-active</key><true/><key>get-task-allow</key><false/>
<key>com.apple.security.application-groups</key><array><string>group.co.versantus.raynawater</string></array>
$2
</dict></plist>
EOF
 codesign -f -s "$ID" --entitlements /tmp/ent.plist "$1" 2>&1 | grep -v "replacing existing" || true; }
mkent Payload/Rayna.app/Watch/RaynaWatch.app/PlugIns/RaynaWatchWidget.appex
mkent Payload/Rayna.app/Watch/RaynaWatch.app
mkent Payload/Rayna.app/PlugIns/RaynaWidgetExtension.appex
shopt -s nullglob; for fw in Payload/Rayna.app/Frameworks/*; do codesign -f -s "$ID" "$fw"; done
mkent Payload/Rayna.app '<key>com.apple.developer.healthkit</key><true/><key>com.apple.developer.healthkit.access</key><array/><key>com.apple.developer.icloud-container-identifiers</key><array><string>iCloud.co.versantus.raynawater</string></array><key>com.apple.developer.icloud-services</key><array><string>CloudKit</string></array><key>com.apple.developer.icloud-container-environment</key><string>Production</string><key>aps-environment</key><string>production</string>'
codesign --verify --deep --strict Payload/Rayna.app && echo VERIFIED
rm -f ~/RaynaBuilds/Rayna-1.0.ipa && zip -qry ~/RaynaBuilds/Rayna-1.0.ipa Payload
ls -la ~/RaynaBuilds/Rayna-1.0.ipa
codesign -d --entitlements - --xml Payload/Rayna.app 2>/dev/null | plutil -p - | grep -E "icloud|health|aps|groups"
