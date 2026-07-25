#!/usr/bin/env sh
# Dummy TLS certs so nginx can listen on :443 (main traffic is HTTP :80).
# Usage: sh scripts/server/generate_self_signed_certs.sh [/opt/klany/shared/certs]

set -eu

CERT_DIR="${1:-/opt/klany/shared/certs}"
CN="${CN:-31.31.201.32}"

mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout "$CERT_DIR/server.key" \
  -out "$CERT_DIR/server.crt" \
  -subj "/CN=${CN}/O=Klany/C=RU"

chmod 600 "$CERT_DIR/server.key"
echo "[certs] wrote $CERT_DIR/server.crt and server.key (CN=${CN})"
