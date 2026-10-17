#!/bin/bash
# App Store screenshots from a booted simulator, written to ../appstore/screenshots/<folder>.
# Usage: scripts/store-shots.sh phone <udid> <folder>    (iPhone or iPad: 01 main with badges and a scene, 02 low water,
#                                                         03 goal, 04 layout picker, 05 badges, 06 pod, 07 settings)
#        scripts/store-shots.sh watch <udid> <folder>    (01–04: one scene each at a different water level)
# Needs a signed Debug build (Xcode Run, or xcodebuild ... -derivedDataPath build -allowProvisioningUpdates build):
# an unsigned build has no iCloud entitlement and crashes at launch.
set -uo pipefail
cd "$(dirname "$0")/.."
KIND=$1; D=$2; OUT=../appstore/screenshots/$3
mkdir -p "$OUT"
xcrun simctl status_bar "$D" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1

if [ "$KIND" = watch ]; then
  APP=co.versantus.raynawater.ios.watchkitapp
  xcrun simctl install "$D" build/Build/Products/Debug-watchsimulator/RaynaWatch.app
  n=1
  for spec in 1500:surge 700:tide 1900:flood 2600:podWave; do
    xcrun simctl terminate "$D" $APP >/dev/null 2>&1; sleep 2
    SIMCTL_CHILD_RAYNA_DEMO_ML=${spec%%:*} SIMCTL_CHILD_RAYNA_DEMO_SCENE=${spec##*:} xcrun simctl launch "$D" $APP >/dev/null
    sleep 7
    xcrun simctl io "$D" screenshot "$OUT/0$n.png" >/dev/null 2>&1
    n=$((n+1))
  done
  exit 0
fi

xcrun simctl uninstall "$D" co.versantus.raynawater.ios 2>/dev/null
xcrun simctl install "$D" build/Build/Products/Debug-iphonesimulator/Rayna.app
xcrun simctl ui "$D" appearance light
# Warm-up launch so the first capture has the full status bar and Dynamic Island.
xcrun simctl launch "$D" co.versantus.raynawater.ios >/dev/null; sleep 5
B="RAYNA_BADGES=all RAYNA_BANNER=0"
scripts/shot.sh "$D" "$OUT/01.png" 8 RAYNA_DEMO=6 RAYNA_STREAK=30 $B
scripts/shot.sh "$D" "$OUT/02.png" 7 RAYNA_DEMO=2 RAYNA_STREAK=3
scripts/shot.sh "$D" "$OUT/03.png" 3 RAYNA_DEMO=10 RAYNA_STREAK=14      # catch the goal spin and confetti
scripts/shot.sh "$D" "$OUT/04.png" 8 RAYNA_DEMO=6 RAYNA_STREAK=30 $B RAYNA_LAYOUTS=1
scripts/shot.sh "$D" "$OUT/05.png" 7 RAYNA_DEMO=6 RAYNA_STREAK=30 $B RAYNA_JOURNEY=1
scripts/shot.sh "$D" "$OUT/06.png" 7 RAYNA_DEMO=6 RAYNA_STREAK=14 RAYNA_POD=1
scripts/shot.sh "$D" "$OUT/07.png" 5 RAYNA_DEMO=4 RAYNA_SETTINGS=1
