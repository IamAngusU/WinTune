#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-./keys}"
mkdir -p "$OUT_DIR"
umask 077

openssl req -x509 -newkey rsa:3072 -sha256 -nodes \
  -keyout "$OUT_DIR/update-signing-private.pem" \
  -out "$OUT_DIR/update-signing-public.crt" \
  -days 3650 \
  -subj "/CN=WinTune Advisor Update Signing/"

openssl x509 -in "$OUT_DIR/update-signing-public.crt" -outform DER -out "$OUT_DIR/update-signing-public.cer"

echo "Private key: $OUT_DIR/update-signing-private.pem (KEEP SERVER-ONLY)"
echo "Public certificate: $OUT_DIR/update-signing-public.cer (copy to Client/Bootstrap/keys/)"
