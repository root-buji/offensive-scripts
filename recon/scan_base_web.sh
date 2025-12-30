#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
scan_base_web.sh - Reconocimiento web automático (safe)

Uso:
  scan_base_web.sh -t 10.10.10.10
  scan_base_web.sh -t example.com -p 80,443,8080
  scan_base_web.sh -t 10.10.10.10 -n

Opciones:
  -t TARGET     IP o hostname objetivo (obligatorio)
  -p PORTS      Puertos web manuales (ej: 80,443,8080)
  -o OUTDIR     Carpeta raíz de salida (default: output)
  -n            Dry-run (muestra comandos, no ejecuta)
  -h            Ayuda

Requisitos:
  - curl
  - whatweb
EOF
}

TARGET=""
PORTS=""
OUTROOT="output"
DRYRUN=0

while getopts ":t:p:o:nh" opt; do
  case "$opt" in
    t) TARGET="$OPTARG" ;;
    p) PORTS="$OPTARG" ;;
    o) OUTROOT="$OPTARG" ;;
    n) DRYRUN=1 ;;
    h) usage; exit 0 ;;
    :) echo "[-] Falta argumento para -$OPTARG" >&2; exit 1 ;;
    \?) echo "[-] Opción inválida: -$OPTARG" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -z "$TARGET" ]] && { echo "[-] Debes indicar -t <target>"; usage; exit 1; }

command -v curl >/dev/null 2>&1 || { echo "[-] curl no está instalado"; exit 1; }
command -v whatweb >/dev/null 2>&1 || { echo "[-] whatweb no está instalado"; exit 1; }

run() {
  echo "[cmd] $*"
  [[ $DRYRUN -eq 0 ]] && "$@"
}

# Puertos web por defecto
[[ -z "$PORTS" ]] && PORTS="80,443,8080,8000,8443"

OUTDIR="${OUTROOT}/${TARGET}/web"
mkdir -p "$OUTDIR"

SUMMARY="${OUTDIR}/summary.md"
declare -a FOUND_URLS=()

echo "[*] Target: $TARGET"
echo "[*] Ports: $PORTS"
echo "[*] Output: $OUTDIR"
[[ $DRYRUN -eq 1 ]] && echo "[*] Dry-run: ON"

IFS=',' read -ra PORT_LIST <<< "$PORTS"

{
  echo "# Web Recon Summary - $TARGET"
  echo
} > "$SUMMARY"

# Devuelve 0 si el endpoint responde con algún status HTTP (incluye 30x/40x/50x)
probe() {
  local url="$1"
  curl -sk --connect-timeout 5 --max-time 8 -o /dev/null -w "%{http_code}" "$url"
}

handle_url() {
  local url="$1"
  local scheme="$2"
  local port="$3"

  local code
  code="$(probe "$url" || true)"

  # http_code "000" = no respuesta / fallo TLS / timeout
  if [[ "$code" == "000" ]]; then
    return 1
  fi

  local service_dir="${OUTDIR}/${scheme}_${port}"
  mkdir -p "$service_dir"

  echo "[+] $url responde (HTTP $code)"
  echo

  echo "[*] WhatWeb:"
  run whatweb "$url" | tee "${service_dir}/whatweb.txt"
  echo

  echo "[*] HTTP Headers:"
  run curl -sk -I "$url" | tee "${service_dir}/headers.txt"
  echo

  {
    echo "## $url"
    echo
    echo "- Status: \`$code\`"
    echo "- WhatWeb: \`${scheme}_${port}/whatweb.txt\`"
    echo "- Headers: \`${scheme}_${port}/headers.txt\`"
    echo
  } >> "$SUMMARY"

  FOUND_URLS+=("$url (HTTP $code)")
  return 0
}

for port in "${PORT_LIST[@]}"; do
  echo
  echo "[*] Probing puerto $port"

  # 1) Probar HTTP primero
  url="http://${TARGET}:${port}"
  echo "[*] Probing $url"
  if handle_url "$url" "http" "$port"; then
    # si http funciona, no probamos https en el mismo puerto
    continue
  fi

  # 2) Si HTTP no funciona, probar HTTPS
  url="https://${TARGET}:${port}"
  echo "[*] Probing $url"
  handle_url "$url" "https" "$port" || true
done

echo
echo "[✓] Web recon terminado"
echo "[+] Summary -> $SUMMARY"

if [[ ${#FOUND_URLS[@]} -gt 0 ]]; then
  echo
  echo "[+] Endpoints detectados:"
  for u in "${FOUND_URLS[@]}"; do
    echo "    - $u"
  done
else
  echo
  echo "[!] No se detectaron endpoints web en los puertos indicados."
fi
