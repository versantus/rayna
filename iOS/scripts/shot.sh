#!/bin/bash
# One simulator screenshot with demo env. Usage: scripts/shot.sh <udid> <out.png> <wait-seconds> [KEY=VALUE ...]
# KEYs are passed to the app as env (RAYNA_DEMO, RAYNA_STREAK, RAYNA_SWAP, RAYNA_JOURNEY, RAYNA_UNLOCK, RAYNA_SHARE, RAYNA_POD...).
D=$1; OUT=$2; W=$3; shift 3
xcrun simctl terminate $D co.versantus.rayna.ios >/dev/null 2>&1; sleep 2
for kv in "$@"; do export "SIMCTL_CHILD_$kv"; done
xcrun simctl launch $D co.versantus.rayna.ios >/dev/null
sleep $W
xcrun simctl io $D screenshot "$OUT" >/dev/null 2>&1
