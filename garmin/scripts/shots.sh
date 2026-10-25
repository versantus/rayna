#!/bin/bash
# Simulator screenshots of every screen on each device: garmin/scripts/shots.sh [devices...] (default: fr965 fr955)
# Builds demo.jungle (seeded sample data, one screen per build), runs it in the Connect IQ simulator and
# captures the simulator window into garmin/bin/shots/<device>-<screen>.png.
# Needs: an UNLOCKED Mac screen, and Screen Recording permission for your terminal
# (System Settings > Privacy & Security > Screen & System Audio Recording).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SDKROOT="$HOME/Library/Application Support/Garmin/ConnectIQ"
SDK="${CIQ_SDK:-$(ls -d "$SDKROOT"/Sdks/* | tail -1)}"
KEY="${RAYNA_GARMIN_KEY:-$HOME/.config/rayna-garmin/developer_key.der}"
DEVICES=("$@"); [ $# -eq 0 ] && DEVICES=(fr965 fr955)
SCREENS=(glance main picker added goal waiting)
OUT="$HERE/bin/shots"; mkdir -p "$OUT" "$HERE/bin/demo"
pgrep -f "ConnectIQ.app" >/dev/null || { open "$SDK/bin/ConnectIQ.app"; sleep 5; }
for d in "${DEVICES[@]}"; do
  for s in "${SCREENS[@]}"; do
    echo "const DEMO_SCREEN = \"$s\";" > "$HERE/bin/demo/DemoScreen.mc"
    "$SDK/bin/monkeyc" -d "$d" -f "$HERE/demo.jungle" -o "$HERE/bin/demo/Rayna-demo.prg" -y "$KEY" -w >/dev/null
    pkill -f monkeydo || true
    "$SDK/bin/monkeydo" "$HERE/bin/demo/Rayna-demo.prg" "$d" >/dev/null 2>&1 &
    sleep 6
    WID="$(swift "$HERE/scripts/simwindow.swift")"
    screencapture -x -o -l "$WID" "$OUT/$d-$s.png" && echo "saved $OUT/$d-$s.png"
  done
done
pkill -f monkeydo || true
