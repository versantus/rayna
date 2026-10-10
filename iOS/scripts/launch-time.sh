#!/bin/bash
# Measures cold launch -> first Rayna frame on a simulator (process start -> first frame, logged by the app).
# Usage: scripts/launch-time.sh <udid> [runs]
D=$1; N=${2:-3}
for i in $(seq 1 $N); do
  xcrun simctl terminate $D co.versantus.rayna.ios >/dev/null 2>&1; sleep 2
  OUT=$(mktemp)
  SIMCTL_CHILD_RAYNA_DEMO=6 xcrun simctl launch --console-pty $D co.versantus.rayna.ios >"$OUT" 2>&1 &
  P=$!
  for t in $(seq 1 60); do grep -q "firstAnimatedFrame" "$OUT" && break; sleep 0.5; done
  kill $P 2>/dev/null; grep "RaynaLaunch" "$OUT" | tr -d '\r'; rm -f "$OUT"
done
xcrun simctl terminate $D co.versantus.rayna.ios >/dev/null 2>&1
