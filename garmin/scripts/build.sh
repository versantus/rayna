#!/bin/bash
# Build Rayna for Garmin.
#   garmin/scripts/build.sh [device] [debug|release]   (default: fr965 debug)
#   garmin/scripts/build.sh all                         (every product in manifest.xml, debug .prg each)
# Needs the Connect IQ SDK (SDK Manager) and a developer key. The key lives OUTSIDE the repo:
#   RAYNA_GARMIN_KEY (default ~/.config/rayna-garmin/developer_key.der). Make one with scripts/make-key.sh.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SDKROOT="$HOME/Library/Application Support/Garmin/ConnectIQ"
SDK="${CIQ_SDK:-$SDKROOT/Sdks/$(sed -n 's/.*\/Sdks\/\([^\/]*\).*/\1/p' "$SDKROOT/current-sdk.cfg" | head -1)}"
[ -d "$SDK/bin" ] || SDK="$(ls -d "$SDKROOT"/Sdks/* | tail -1)"
MONKEYC="$SDK/bin/monkeyc"
KEY="${RAYNA_GARMIN_KEY:-$HOME/.config/rayna-garmin/developer_key.der}"
[ -f "$KEY" ] || { echo "No developer key at $KEY. Run garmin/scripts/make-key.sh"; exit 1; }
DEVICE="${1:-fr965}"; TYPE="${2:-debug}"
mkdir -p "$HERE/bin"
build() {
  local d="$1"
  if [ "$TYPE" = release ]; then
    "$MONKEYC" -e -f "$HERE/monkey.jungle" -o "$HERE/bin/Rayna.iq" -y "$KEY" -w -r
  else
    "$MONKEYC" -d "$d" -f "$HERE/monkey.jungle" -o "$HERE/bin/Rayna-$d.prg" -y "$KEY" -w
  fi
}
if [ "$DEVICE" = all ]; then
  for d in $(sed -n 's/.*<iq:product id="\([^"]*\)".*/\1/p' "$HERE/manifest.xml"); do echo "== $d"; build "$d"; done
else
  build "$DEVICE"
fi
echo "Built into $HERE/bin. Run in the simulator: garmin/scripts/sim.sh $DEVICE"
