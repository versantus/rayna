#!/bin/bash
# Captures App Store screenshots from booted simulators. Usage: scripts/screenshots.sh <udid>:<folder> ...
set -uo pipefail
cd "$(dirname "$0")/.."
APP=build/Build/Products/Debug-iphonesimulator/Rayna.app
for pair in "$@"; do
  D=${pair%%:*}; S=${pair##*:}
  mkdir -p ../appstore/screenshots/$S
  xcrun simctl status_bar $D override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
  xcrun simctl install $D $APP
  # warm-up launch so the first capture has the full status bar / Dynamic Island
  xcrun simctl launch $D co.versantus.raynawater.ios >/dev/null; sleep 4
  n=1
  for spec in 6:0 2:0 10:0 4:1; do
    xcrun simctl terminate $D co.versantus.raynawater.ios >/dev/null 2>&1; sleep 3
    SIMCTL_CHILD_RAYNA_DEMO=${spec%%:*} SIMCTL_CHILD_RAYNA_SETTINGS=${spec##*:} xcrun simctl launch $D co.versantus.raynawater.ios >/dev/null
    # shot 3 = goal: catch the spin + confetti mid-celebration
    if [ "$n" = 3 ]; then sleep 3; else sleep 7; fi
    xcrun simctl io $D screenshot ../appstore/screenshots/$S/0$n.png >/dev/null 2>&1
    n=$((n+1))
  done
  # Phase A–C features: unlocks + journey, pod tank
  scripts/shot.sh $D ../appstore/screenshots/$S/05.png 7 RAYNA_DEMO=6 RAYNA_STREAK=30 RAYNA_SWAP=1
  scripts/shot.sh $D ../appstore/screenshots/$S/06.png 6 RAYNA_DEMO=6 RAYNA_STREAK=16 RAYNA_JOURNEY=1
  scripts/shot.sh $D ../appstore/screenshots/$S/07.png 6 RAYNA_DEMO=6 RAYNA_STREAK=14 RAYNA_POD=1
done
