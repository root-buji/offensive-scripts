#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
nmap_full_ip.sh - Nmap automatizado contra un target (TCP full + enum + NSE safe + UDP opcional)

Uso:
  nmap_full_ip.sh -t 10.10.10.10
  nmap_full_ip.sh -t 10.10.10.10 -P
  sudo nmap_full_ip.sh -t 10.10.10.10 -O -U

Opciones:
  -t TARGET     IP o hostname objetivo (obligatorio)
  -o OUTDIR     Carpeta de salida (default: output)
  -T TIMING     Timing 0..5 o T0..T5 (default: T3)
  -r RATE       --min-rate para el scan TCP full (entero >0). Si no se indica, desactivado
  -P            Desactivar host discovery (-Pn) (trata el host como up)
  -O            Activar OS detection (-O) (normalmente requiere root para mejores resultados)
  -U            Activar UDP top ports (requiere root; puede tardar mucho)
  -n            Dry-run (muestra comandos, no ejecuta)
  -h            Ayuda

Salida:
  output/<target>/<timestamp>_tcp_full.*
  output/<target>/<timestamp>_tcp_services.*
  output/<target>/<timestamp>_tcp_nse_safe.*
  output/<target>/<timestamp>_udp_top.* (si -U)
  output/<target>/<timestamp>_summary.md
EOF
}

# ---- Defaults
TARGET=""
OUTROOT="output"
TIMING="T3"
MINRATE=""
DO_OS=0
DO_UDP=0
FORCE_PN=0
DRYRUN=0

# ---- Args
while getopts ":t:o:T:r:POUnh" opt; do
  case "$opt" in
    t) TARGET="$OPTARG" ;;
    o) OUTROOT="$OPTARG" ;;
    T) TIMING="$OPTARG" ;;
    r) MINRATE="$OPTARG" ;;
    P) FORCE_PN=1 ;;
    O) DO_OS=1 ;;
    U) DO_UDP=1 ;;
    n) DRYRUN=1 ;;
    h) usage; exit 0 ;;
    :) echo "[-] Falta argumento para -$OPTARG" >&2; exit 1 ;;
    \?) echo "[-] Opción inválida: -$OPTARG" >&2; usage >&2; exit 1 ;;
  esac
done

# ---- Sanity checks
if [[ -z "$TARGET" ]]; then
  echo "[-] Debes indicar -t <target>" >&2
  usage >&2
  exit 1
fi

# Normalizar TIMING: aceptar 0..5 o T0..T5
if [[ "$TIMING" =~ ^[0-5]$ ]]; then
  TIMING="T${TIMING}"
fi

if [[ ! "$TIMING" =~ ^T[0-5]$ ]]; then
  echo "[-] Timing inválido: $TIMING (usa 0..5 o T0..T5)" >&2
  exit 1
fi

if [[ -n "$MINRATE" ]]; then
  if [[ ! "$MINRATE" =~ ^[0-9]+$ ]] || [[ "$MINRATE" -le 0 ]]; then
    echo "[-] -r RATE debe ser un entero > 0" >&2
    exit 1
  fi
fi

command -v nmap >/dev/null 2>&1 || { echo "[-] nmap no está instalado" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
  [[ $DO_OS -eq 1 ]] && echo "[!] Aviso: -O sin root puede dar resultados incompletos"
  [[ $DO_UDP -eq 1 ]] && echo "[!] Aviso: -U normalmente requiere root"
fi

run() {
  echo "[cmd] $*"
  [[ $DRYRUN -eq 0 ]] && "$@"
}

# ---- Output paths
TS="$(date +"%Y%m%d_%H%M%S")"
OUTDIR="${OUTROOT}/${TARGET}"
mkdir -p "$OUTDIR"

TCP_FULL_BASE="${OUTDIR}/${TS}_tcp_full"
TCP_SERV_BASE="${OUTDIR}/${TS}_tcp_services"
TCP_NSE_BASE="${OUTDIR}/${TS}_tcp_nse_safe"
UDP_BASE="${OUTDIR}/${TS}_udp_top"
SUMMARY_MD="${OUTDIR}/${TS}_summary.md"

# ---- Echo config
echo "[*] Target: $TARGET"
echo "[*] Output: $OUTDIR"
echo "[*] Timing: -$TIMING"
[[ -n "$MINRATE" ]] && echo "[*] min-rate: $MINRATE"
[[ $FORCE_PN -eq 1 ]] && echo "[*] Host discovery: disabled (-Pn)"
[[ $DO_OS -eq 1 ]] && echo "[*] OS detection: ON (-O)"
[[ $DO_UDP -eq 1 ]] && echo "[*] UDP top ports: ON (--top-ports 100)"
[[ $DRYRUN -eq 1 ]] && echo "[*] Dry-run mode: ON"

PN_ARG=()
[[ $FORCE_PN -eq 1 ]] && PN_ARG=(-Pn)

MINRATE_ARG=()
[[ -n "$MINRATE" ]] && MINRATE_ARG=(--min-rate "$MINRATE")

OS_ARG=()
[[ $DO_OS -eq 1 ]] && OS_ARG=(-O)

# ---- 1) TCP full
echo
echo "[1/4] TCP full scan (-p-) para descubrir puertos..."
run nmap -sS -p- "-$TIMING" --reason \
  "${PN_ARG[@]}" "${MINRATE_ARG[@]}" \
  -oA "$TCP_FULL_BASE" "$TARGET"

# Robust port extraction from gnmap (avoid 'Host:' etc.)
OPEN_PORTS="$(
  grep -oE '[0-9]+/open' "${TCP_FULL_BASE}.gnmap" \
  | cut -d/ -f1 \
  | sort -n \
  | uniq \
  | paste -sd, - \
  || true
)"

if [[ -z "$OPEN_PORTS" ]]; then
  echo "[!] No se detectaron puertos TCP abiertos. Revisa filtrado/firewall o ajusta timing."
  {
    echo "# Nmap summary - $TARGET ($TS)"
    echo
    echo "- TCP open ports: none detected"
    echo "- Sugerencia: prueba -P (-Pn) si el host bloquea ping; baja el timing o ajusta rate"
  } > "$SUMMARY_MD"
  echo "[+] Summary -> $SUMMARY_MD"
  exit 0
fi

if ! [[ "$OPEN_PORTS" =~ ^[0-9,]+$ ]]; then
  echo "[-] Error parseando puertos desde gnmap: '$OPEN_PORTS'" >&2
  echo "[-] Revisa: ${TCP_FULL_BASE}.gnmap" >&2
  exit 1
fi

echo "[+] Puertos TCP abiertos: $OPEN_PORTS"

# ---- 2) Services/version enum
echo
echo "[2/4] Enumeración de servicios/versiones sobre puertos abiertos..."
run nmap -sS -sV -p "$OPEN_PORTS" "-$TIMING" --reason \
  "${PN_ARG[@]}" "${OS_ARG[@]}" \
  -oA "$TCP_SERV_BASE" "$TARGET"

# ---- 3) NSE safe
echo
echo "[3/4] NSE safe (scripts seguros) sobre puertos abiertos..."
run nmap -sS --script safe -p "$OPEN_PORTS" "-$TIMING" --reason \
  "${PN_ARG[@]}" \
  -oA "$TCP_NSE_BASE" "$TARGET"

# ---- 4) UDP optional
if [[ $DO_UDP -eq 1 ]]; then
  echo
  echo "[4/4] UDP top ports (100 por defecto)... (esto puede tardar bastante)"
  # UDP puede fallar/ser ruidoso -> no abortamos el script
  run nmap -sU --top-ports 100 "-$TIMING" --reason \
    "${PN_ARG[@]}" \
    -oA "$UDP_BASE" "$TARGET" || true
else
  echo
  echo "[4/4] UDP: saltado (usa -U si lo necesitas)"
fi

# ---- Summary
{
  echo "# Nmap summary - $TARGET ($TS)"
  echo
  echo "## TCP open ports"
  echo "\`$OPEN_PORTS\`"
  echo
  echo "## Options used"
  echo "- Timing: -$TIMING"
  [[ $FORCE_PN -eq 1 ]] && echo "- Host discovery: disabled (-Pn)"
  [[ -n "$MINRATE" ]] && echo "- --min-rate $MINRATE"
  [[ $DO_OS -eq 1 ]] && echo "- OS detection: -O"
  [[ $DO_UDP -eq 1 ]] && echo "- UDP: --top-ports 100"
  [[ $DRYRUN -eq 1 ]] && echo "- Dry-run enabled"
  echo
  echo "## Files"
  echo "- TCP full: ${TCP_FULL_BASE}.nmap / .gnmap / .xml"
  echo "- TCP services: ${TCP_SERV_BASE}.nmap / .gnmap / .xml"
  echo "- TCP NSE safe: ${TCP_NSE_BASE}.nmap / .gnmap / .xml"
  if [[ $DO_UDP -eq 1 ]]; then
    echo "- UDP top ports: ${UDP_BASE}.nmap / .gnmap / .xml"
  fi
} > "$SUMMARY_MD"

echo
echo "[✓] Hecho."
echo "[+] Summary -> $SUMMARY_MD"

