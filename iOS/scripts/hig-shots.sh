#!/bin/bash
# HIG review screenshots: scripts/hig-shots.sh <udid> <outdir>
D=$1; O=$2; mkdir -p "$O"; cd "$(dirname "$0")/.."
xcrun simctl status_bar $D override --time 9:41 --batteryState charged --batteryLevel 100 >/dev/null 2>&1
xcrun simctl install $D build/Build/Products/Debug-iphonesimulator/Rayna.app
xcrun simctl ui $D appearance light; xcrun simctl ui $D content_size large
scripts/shot.sh $D "$O/main-light.png" 6 RAYNA_DEMO=6 RAYNA_STREAK=30 RAYNA_SWAP=1
scripts/shot.sh $D "$O/settings-light.png" 4 RAYNA_DEMO=6 RAYNA_SETTINGS=1
scripts/shot.sh $D "$O/journey-light.png" 5 RAYNA_DEMO=6 RAYNA_STREAK=16 RAYNA_JOURNEY=1
xcrun simctl ui $D appearance dark
scripts/shot.sh $D "$O/main-dark.png" 6 RAYNA_DEMO=6 RAYNA_STREAK=30 RAYNA_SWAP=1
scripts/shot.sh $D "$O/pod-dark.png" 5 RAYNA_DEMO=6 RAYNA_POD=1
xcrun simctl ui $D appearance light; xcrun simctl ui $D content_size accessibility-extra-extra-extra-large
scripts/shot.sh $D "$O/main-axxxl.png" 6 RAYNA_DEMO=6 RAYNA_STREAK=30 RAYNA_SWAP=1
scripts/shot.sh $D "$O/settings-axxxl.png" 4 RAYNA_DEMO=6 RAYNA_SETTINGS=1
xcrun simctl ui $D content_size large
