#!/bin/bash

# Verificacion
if [ -z "$1" ]; then
    echo "Uso: $0 https://objetivo.com"
    exit 1
fi

TARGET=$1
OUTDIR="sensitive_results_$(date +%s)"
mkdir -p "$OUTDIR"

# WP archivos comunes
COMMON_FILES=(
"wp-config.php"
    "wp-config.php~"
    "wp-config.bak"
    "wp-config.txt"
    "wp-config.old"
    "wp-config.php.save"
    "wp-config.php.swp"
    "wp-config.php.swo"
    ".env"                      # Laravel en plugin o API embebida
    ".git/config"               # Si WP está versionado
    ".htaccess"                 # Puede revelar reglas peligrosas

    "backup.zip"
    "backup.sql"
    "db.sql"
    "wp-backup.zip"
    "wp-db.sql"
    "wordpress.zip"
    "wordpress.tar.gz"
    "dump.sql"

    "readme.html"               # Identifica versión de WordPress
    "license.txt"               # Igual
    "xmlrpc.php"                # Objetivo común de DoS

    "wp-admin/setup-config.php"  # Si WP no está instalado
    "wp-admin/install.php"
    "wp-content/debug.log"       # Logging habilitado
    "wp-content/plugins/"        # Directorio abierto
    "wp-content/themes/"         # Directorio abierto

    "admin.php~"
    "login.php~"
    "users.txt"
    "credentials.txt"
)

echo "[*] Escaneando archivos sensibles en: $TARGET"
echo "[*] Resultados guardados en: $OUTDIR"
echo ""

for FILE in "${COMMON_FILES[@]}"; do
    URL="${TARGET}/${FILE}"
    STATUS=$(curl -sk -o "${OUTDIR}/tmpfile" -w "%{http_code}" "$URL")

    if [[ "$STATUS" == "200" ]]; then
        echo "[+] Encontrado: $FILE (200 OK)"
        mv "${OUTDIR}/tmpfile" "${OUTDIR}/$(echo "$FILE" | tr '/' '_')"
    elif [[ "$STATUS" == "403" ]]; then
        echo "[!] Posible acceso restringido: $FILE (403 Forbidden)"
    fi
done

rm -f "${OUTDIR}/tmpfile"
echo ""
echo "[*] Escaneo completado."
