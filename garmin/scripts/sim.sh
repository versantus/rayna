#!/bin/bash
# Starts the Connect IQ simulator (if needed) and runs the debug build on a device: garmin/scripts/sim.sh fr965
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SDKROOT="$HOME/Library/Application Support/Garmin/ConnectIQ"
SDK="${CIQ_SDK:-$(ls -d "$SDKROOT"/Sdks/* | tail -1)}"
DEVICE="${1:-fr965}"
[ -f "$HERE/bin/Rayna-$DEVICE.prg" ] || "$HERE/scripts/build.sh" "$DEVICE"
pgrep -f "ConnectIQ.app" >/dev/null || { open "$SDK/bin/ConnectIQ.app"; sleep 4; }
"$SDK/bin/monkeydo" "$HERE/bin/Rayna-$DEVICE.prg" "$DEVICE"
