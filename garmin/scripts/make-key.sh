#!/bin/bash
# Makes a Connect IQ developer key outside the repo (never commit it). Keep a backup: the Connect IQ Store
# needs the SAME key for every future update of the app.
set -euo pipefail
DIR="$(dirname "${RAYNA_GARMIN_KEY:-$HOME/.config/rayna-garmin/developer_key.der}")"
mkdir -p "$DIR"; cd "$DIR"
[ -f developer_key.der ] && { echo "Key already exists: $DIR/developer_key.der"; exit 0; }
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
chmod 600 developer_key.*
echo "Made $DIR/developer_key.der"
