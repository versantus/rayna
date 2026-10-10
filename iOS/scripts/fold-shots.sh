#!/bin/bash
# v1.1 layout shots. Usage: scripts/fold-shots.sh <udid> <outdir> [prefix]
D=$1; O=$2; X=${3:-}; mkdir -p "$O"; cd "$(dirname "$0")/.."
xcrun simctl status_bar $D override --time 9:41 --batteryState charged --batteryLevel 100 >/dev/null 2>&1
xcrun simctl uninstall $D co.versantus.raynawater.ios 2>/dev/null; xcrun simctl install $D build/Build/Products/Debug-iphonesimulator/Rayna.app
xcrun simctl ui $D appearance light; xcrun simctl ui $D content_size large
scripts/shot.sh $D "$O/${X}main-fact.png" 6 RAYNA_DEMO=6 RAYNA_STREAK=16 RAYNA_POD=card RAYNA_FACTS=12 RAYNA_FACT=11 RAYNA_KID=0
scripts/shot.sh $D "$O/${X}kid-mode.png" 6 RAYNA_DEMO=5 RAYNA_STREAK=15 RAYNA_KID=1 RAYNA_FACTS=12
scripts/shot.sh $D "$O/${X}journey-facts.png" 6 RAYNA_DEMO=6 RAYNA_STREAK=16 RAYNA_JOURNEY=1 RAYNA_FACTS=12 RAYNA_KID=0
scripts/shot.sh $D "$O/${X}settings.png" 5 RAYNA_DEMO=6 RAYNA_SETTINGS=1 RAYNA_KID=0
xcrun simctl ui $D appearance dark
scripts/shot.sh $D "$O/${X}main-dark.png" 6 RAYNA_DEMO=6 RAYNA_STREAK=16 RAYNA_POD=card RAYNA_KID=0
xcrun simctl ui $D appearance light
