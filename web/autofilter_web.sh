#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
autofilter_web.sh - Baseline de respuestas "negativas" para evitar falsos positivos (gobuster/ffuf)

Qué hace:
  - Lanza N requests a rutas aleatorias que NO deberían existir
  - Mide status code, bytes (length), words y lines
  - Sugiere filtros para Gobuster y FFUF

Uso:
  autofilter_web.sh -u http://10.10.10.10
  autofilter_web.sh -u https://example.com:8443 -n 5
  autofilter_web.sh -u http://10.10.10.10 -k -o output

Opciones:
  -u URL        URL base (obligatorio). Ej: http://IP:PORT  o  https://host
  -n COUNT      Número de pruebas (default: 3)
  -k            Ignorar TLS (curl -k)
  -t SECONDS    Timeout por request (default: 8)
  -o OUTROOT    Carpeta raíz de salida (default: output)
  -p PATH       Ruta base (default: /)  (se añade a la URL base)
  -n0           (no existe)  -> no usar
  -d            Mostrar debug (imprime URLs aleatorias)
  -h            Ayuda

Salida:
  output/<host>_<port>/autofilter/<timestamp>_autofilter.md

Notas:
  - Esto es "safe": solo hace unas pocas peticiones GET.
  - Útil antes de lanzar gobuster/ffuf para elegir -b / --exclude-length / -fs, etc.
EOF
}

URL=""
COUNT=3
INSECURE=0
TIMEOUT=8
OUTROOT="output"
BASE_PATH="/"
DEBUG=0

while getopts ":u:n:kt:o:p:dh" opt; do
  case "$opt" in
    u) URL="$OPTARG" ;;
    n) COUNT="$OPTARG" ;;
    k) INSECURE=1 ;;
    t) TIMEOUT="$OPTARG" ;;
    o) OUTROOT="$OPTARG" ;;
    p) BASE_PATH="$OPTARG" ;;
    d) DEBUG=1 ;;
    h) usage; exit 0 ;;
    :) echo "[-] Falta argumento para -$OPTARG" >&2; exit 1 ;;
    \?) echo "[-] Opción inválida: -$OPTARG" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -z "$URL" ]] && { echo "[-] Debes indicar -u <URL>"; usage >&2; exit 1; }
[[ "$COUNT" =~ ^[0-9]+$ ]] && [[ "$COUNT" -ge 1 ]] || { echo "[-] -n COUNT debe ser un entero >= 1" >&2; exit 1; }
[[ "$TIMEOUT" =~ ^[0-9]+$ ]] && [[ "$TIMEOUT" -ge 1 ]] || { echo "[-] -t SECONDS debe ser un entero >= 1" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || { echo "[-] curl no está instalado" >&2; exit 1; }

# Normaliza BASE_PATH para que empiece y termine con /
[[ "$BASE_PATH" != /* ]] && BASE_PATH="/$BASE_PATH"
[[ "$BASE_PATH" != */ ]] && BASE_PATH="$BASE_PATH/"

# Extrae host/port para carpeta (simple, suficiente)
hostport="$(echo "$URL" | sed -E 's#^[a-zA-Z]+://##' | sed -E 's#/.*$##')"
host="$(echo "$hostport" | cut -d: -f1)"
port="$(echo "$hostport" | awk -F: '{print ($2=="" ? "default" : $2)}')"

TS="$(date +"%Y%m%d_%H%M%S")"
OUTDIR="${OUTROOT}/${host}_${port}/autofilter"
mkdir -p "$OUTDIR"
OUTFILE="${OUTDIR}/${TS}_autofilter.md"

CURL_COMMON=(-sS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT")
[[ $INSECURE -eq 1 ]] && CURL_COMMON+=(-k)

rand_path() {
  # pseudo-UUID sin depender de uuidgen
  # shellcheck disable=SC2016
  printf '%s-%s-%s-%s-%s' \
    "$(tr -dc 'a-f0-9' </dev/urandom | head -c 8)" \
    "$(tr -dc 'a-f0-9' </dev/urandom | head -c 4)" \
    "$(tr -dc 'a-f0-9' </dev/urandom | head -c 4)" \
    "$(tr -dc 'a-f0-9' </dev/urandom | head -c 4)" \
    "$(tr -dc 'a-f0-9' </dev/urandom | head -c 12)"
}

echo "[*] URL base:   $URL"
echo "[*] Base path:  $BASE_PATH"
echo "[*] Pruebas:    $COUNT"
echo "[*] Timeout:    ${TIMEOUT}s"
echo "[*] Output:     $OUTFILE"
[[ $INSECURE -eq 1 ]] && echo "[*] TLS:        insecure (-k)"
[[ $DEBUG -eq 1 ]] && echo "[*] Debug:      ON"

# Arrays para métricas
declare -a codes=()
declare -a sizes=()
declare -a words=()
declare -a lines=()
declare -a test_urls=()

# Función para medir body (para words/lines) y status/size
measure_one() {
  local full_url="$1"
  local tmp
  tmp="$(mktemp)"

  # Descargamos body a tmp, y sacamos status+size de curl
  # size_download = bytes del body
  local meta
  meta="$(curl "${CURL_COMMON[@]}" -o "$tmp" -w "%{http_code} %{size_download}\n" "$full_url" || true)"

  local code size
  code="$(awk '{print $1}' <<<"$meta")"
  size="$(awk '{print $2}' <<<"$meta")"

  # Si no hay respuesta, curl suele dar code vacío/000
  [[ -z "$code" ]] && code="000"
  [[ -z "$size" ]] && size="0"

  local w l
  # words/lines sobre el body
  w="$(wc -w <"$tmp" | tr -d ' ')"
  l="$(wc -l <"$tmp" | tr -d ' ')"

  rm -f "$tmp"

  codes+=("$code")
  sizes+=("$size")
  words+=("$w")
  lines+=("$l")
}

# Ejecutar pruebas
for ((i=1; i<=COUNT; i++)); do
  rp="$(rand_path)"
  full="${URL%/}${BASE_PATH}${rp}"
  test_urls+=("$full")
  [[ $DEBUG -eq 1 ]] && echo "[dbg] $full"
  measure_one "$full"
done

# Helpers: moda simple (valor más frecuente)
mode_of() {
  # stdin -> valores, devuelve el más frecuente (si empate, el primero)
  awk '
  {c[$0]++}
  END{
    max=0; best="";
    for (k in c) {
      if (c[k] > max) { max=c[k]; best=k }
    }
    print best
  }'
}

# Compute suggestions
code_mode="$(printf "%s\n" "${codes[@]}" | mode_of)"
size_mode="$(printf "%s\n" "${sizes[@]}" | mode_of)"
words_mode="$(printf "%s\n" "${words[@]}" | mode_of)"
lines_mode="$(printf "%s\n" "${lines[@]}" | mode_of)"

# Si el mode es 000 (timeouts), avisar
if [[ "$code_mode" == "000" ]]; then
  echo "[!] Muchas respuestas '000' (sin respuesta/timeout). Prueba a subir timeout (-t) o revisa conectividad/TLS."
fi

# Escribir reporte
{
  echo "# Web Autofilter Baseline"
  echo
  echo "- **Target:** \`$URL\`"
  echo "- **Base path:** \`$BASE_PATH\`"
  echo "- **Tests:** \`$COUNT\`"
  echo "- **Timeout:** \`${TIMEOUT}s\`"
  echo "- **Generated:** \`$TS\`"
  echo
  echo "## Test results (random non-existing paths)"
  echo
  echo "| # | Status | Bytes | Words | Lines | URL |"
  echo "|---:|:------:|------:|------:|------:|-----|"
  for ((i=0; i<COUNT; i++)); do
    echo "| $((i+1)) | ${codes[i]} | ${sizes[i]} | ${words[i]} | ${lines[i]} | \`${test_urls[i]}\` |"
  done
  echo
  echo "## Baseline (most frequent values)"
  echo
  echo "- **Status (mode):** \`$code_mode\`"
  echo "- **Bytes (mode):** \`$size_mode\`"
  echo "- **Words (mode):** \`$words_mode\`"
  echo "- **Lines (mode):** \`$lines_mode\`"
  echo
  echo "## Suggested filters"
  echo
  echo "### Gobuster"
  echo
  if [[ "$code_mode" != "000" ]]; then
    echo "- Si tu objetivo devuelve **siempre** este status para rutas inexistentes, blacklistea ese código:"
    echo "  - \`-b $code_mode\`  (en tu wrapper) o \`--status-codes-blacklist $code_mode\`"
  fi
  echo "- Si el status no es fiable (CDN/WAF/soft-404), filtra por longitud:"
  echo "  - \`--exclude-length $size_mode\`"
  echo
  echo "Ejemplo:"
  echo '```bash'
  echo "gobuster dir -u \"${URL%/}${BASE_PATH}\" -w <wordlist> --exclude-length $size_mode"
  echo '```'
  echo
  echo "### FFUF"
  echo
  echo "- Filtrado recomendado por tamaño:"
  echo "  - \`-fs $size_mode\`"
  echo "- Alternativas si el tamaño cambia:"
  echo "  - \`-fw $words_mode\` o \`-fl $lines_mode\`"
  if [[ "$code_mode" != "000" ]]; then
    echo "- También puedes filtrar por código:"
    echo "  - \`-fc $code_mode\`"
  fi
  echo
  echo "Ejemplo:"
  echo '```bash'
  echo "ffuf -u \"${URL%/}${BASE_PATH}FUZZ\" -w <wordlist> -fs $size_mode"
  echo '```'
  echo
  echo "## Notes"
  echo
  echo "- Si ves códigos mixtos (ej. 200/302 para no-existentes), prioriza **exclude-length** o **words/lines**."
  echo "- Si hay muchos \`000\`, sube timeout (\`-t\`) o prueba \`-k\` si es HTTPS con cert raro."
} > "$OUTFILE"

echo
echo "[✓] Baseline listo."
echo "[+] Report -> $OUTFILE"
echo
echo "[+] Baseline (mode): status=$code_mode bytes=$size_mode words=$words_mode lines=$lines_mode"
echo
echo "[+] Sugerencia rápida:"
if [[ "$code_mode" != "000" ]]; then
  echo "    - Gobuster: --exclude-length $size_mode   (o blacklist: $code_mode)"
else
  echo "    - Gobuster: --exclude-length $size_mode   (status no fiable: 000)"
fi
echo "    - FFUF:     -fs $size_mode"
