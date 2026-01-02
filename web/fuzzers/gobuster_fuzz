#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
enum_dirs_gobuster.sh - Enumeración de directorios/archivos con Gobuster

Uso:
  enum_dirs_gobuster.sh -u http://10.10.10.10
  enum_dirs_gobuster.sh -u https://example.com -w /usr/share/wordlists/dirb/common.txt
  enum_dirs_gobuster.sh -u http://10.10.10.10:8080 -x php,txt,html -t 60
  enum_dirs_gobuster.sh -u http://10.10.10.10 -p /app/ -o output

Opciones:
  -u URL        URL base (obligatorio). Ej: http://IP:PORT o https://host
  -p PATH       Ruta base (default: /). Ej: /admin/ o /app/
  -w WORDLIST   Wordlist (default: /usr/share/wordlists/dirb/common.txt)
  -t THREADS    Hilos (default: 50)
  -x EXT        Extensiones separadas por coma (ej: php,txt,html). Default: none
  -s CODES      Status codes válidos (default: 200,204,301,302,307,308,401,403)
  -b CODES      Status codes a excluir (blacklist). Default: none
  -a AGENT      User-Agent (default: Mozilla/5.0)
  -H HEADER     Header extra (puede repetirse). Ej: -H "Host: vhost"
  -k            Ignorar TLS (equivale a -k en curl; en gobuster es --no-tls-validation)
  -o OUTROOT    Carpeta raíz de salida (default: output)
  -n            Dry-run (muestra comando, no ejecuta)
  -h            Ayuda

Salida:
  output/<host>_<port>/<timestamp>_gobuster_<path>.txt
EOF
}

URL=""
BASE_PATH="/"
WORDLIST="/usr/share/wordlists/dirb/common.txt"
THREADS="50"
EXTS=""
STATUS_OK="200,204,301,302,307,308,401,403"
STATUS_BAD=""
UA="Mozilla/5.0"
TLS_INSECURE=0
OUTROOT="output"
DRYRUN=0
declare -a HEADERS=()

while getopts ":u:p:w:t:x:s:b:a:H:ko:nh" opt; do
  case "$opt" in
    u) URL="$OPTARG" ;;
    p) BASE_PATH="$OPTARG" ;;
    w) WORDLIST="$OPTARG" ;;
    t) THREADS="$OPTARG" ;;
    x) EXTS="$OPTARG" ;;
    s) STATUS_OK="$OPTARG" ;;
    b) STATUS_BAD="$OPTARG" ;;
    a) UA="$OPTARG" ;;
    H) HEADERS+=("$OPTARG") ;;
    k) TLS_INSECURE=1 ;;
    o) OUTROOT="$OPTARG" ;;
    n) DRYRUN=1 ;;
    h) usage; exit 0 ;;
    :) echo "[-] Falta argumento para -$OPTARG" >&2; exit 1 ;;
    \?) echo "[-] Opción inválida: -$OPTARG" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -z "$URL" ]] && { echo "[-] Debes indicar -u <URL>"; usage >&2; exit 1; }

command -v gobuster >/dev/null 2>&1 || { echo "[-] gobuster no está instalado"; exit 1; }
[[ -f "$WORDLIST" ]] || { echo "[-] Wordlist no existe: $WORDLIST"; exit 1; }
[[ "$THREADS" =~ ^[0-9]+$ ]] || { echo "[-] THREADS debe ser numérico"; exit 1; }


[[ "$BASE_PATH" != /* ]] && BASE_PATH="/$BASE_PATH"
[[ "$BASE_PATH" != */ ]] && BASE_PATH="$BASE_PATH/"

run() {
  echo "[cmd] $*"
  [[ $DRYRUN -eq 0 ]] && "$@"
}


hostport="$(echo "$URL" | sed -E 's#^[a-zA-Z]+://##' | sed -E 's#/.*$##')"
host="$(echo "$hostport" | cut -d: -f1)"
port="$(echo "$hostport" | awk -F: '{print ($2=="" ? "default" : $2)}')"

TS="$(date +"%Y%m%d_%H%M%S")"
SAFE_PATH="$(echo "$BASE_PATH" | sed 's#/#_#g' | sed 's/^_//; s/_$//')"
[[ -z "$SAFE_PATH" ]] && SAFE_PATH="root"

OUTDIR="${OUTROOT}/${host}_${port}"
mkdir -p "$OUTDIR"

OUTFILE="${OUTDIR}/${TS}_gobuster_${SAFE_PATH}.txt"

echo "[*] URL:        $URL"
echo "[*] Base path:  $BASE_PATH"
echo "[*] Wordlist:   $WORDLIST"
echo "[*] Threads:    $THREADS"
[[ -n "$EXTS" ]] && echo "[*] Exts:       $EXTS"
echo "[*] Status ok:  $STATUS_OK"
[[ -n "$STATUS_BAD" ]] && echo "[*] Exclude:    $STATUS_BAD"
echo "[*] Output:     $OUTFILE"
[[ $DRYRUN -eq 1 ]] && echo "[*] Dry-run:    ON"


args=(dir
  -u "${URL%/}${BASE_PATH}"
  -w "$WORDLIST"
  -t "$THREADS"
  -a "$UA"
  --no-error
)


if [[ -n "$STATUS_BAD" ]]; then
  args+=(--status-codes-blacklist "$STATUS_BAD")
else

  args+=(--status-codes "$STATUS_OK")
  args+=(--status-codes-blacklist "")
fi



[[ -n "$STATUS_BAD" ]] && args+=(--status-codes-blacklist "$STATUS_BAD")
[[ -n "$EXTS" ]] && args+=(-x "$EXTS")
[[ $TLS_INSECURE -eq 1 ]] && args+=(--no-tls-validation)


for h in "${HEADERS[@]}"; do
  args+=(-H "$h")
done

echo
echo "[*] Ejecutando gobuster (se mostrará por pantalla y se guardará en archivo)..."
echo


if [[ $DRYRUN -eq 1 ]]; then
  echo "[cmd] gobuster ${args[*]} | tee \"$OUTFILE\""
else
  gobuster "${args[@]}" | tee "$OUTFILE"
fi

echo
echo "[✓] Hecho."
echo "[+] Results -> $OUTFILE"
