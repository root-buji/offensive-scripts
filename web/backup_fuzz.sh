#!/bin/bash

if [ -z "$1" ]; then
    echo "Uso: $0 https://objetivo.com"
    exit 1
fi

TARGET=$1
OUTDIR="backup_name_results_$(date +%s)"
mkdir -p "$OUTDIR"

BACKUP_NAMES=(
    "backup" "backup_site" "site_backup" "site"
    "www" "public" "public_html" "html"
    "old" "old_site" "old_web"
    "web" "website"
    "prod" "production" "dev" "test" "staging"
    "db" "database" "dump" "mysql"
    "wordpress" "wp" "wp_backup" "blog"
)

BACKUP_EXTENSIONS=(
    ".zip" ".tar" ".tar.gz" ".tgz" ".gz"
    ".7z" ".rar" ".sql" ".sql.gz" ".bak"
)

echo "[*] Buscando backups por nombre en: $TARGET"
echo "[*] Guardando en: $OUTDIR"
echo ""

for NAME in "${BACKUP_NAMES[@]}"; do
    for EXT in "${BACKUP_EXTENSIONS[@]}"; do
        FILE="${NAME}${EXT}"
        URL="${TARGET}/${FILE}"

        # 🔍 Verificar si el archivo existe
        STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "$URL")

        if [[ "$STATUS" == "200" ]]; then
            echo "[+] BACKUP ENCONTRADO: $FILE (200 OK)"
            curl -sk "$URL" -o "${OUTDIR}/${FILE}"
        elif [[ "$STATUS" == "403" ]]; then
            echo "[!] Existe pero protegido (403): $FILE"
        fi
    done
done

echo ""
if [ -z "$(ls -A "$OUTDIR")" ]; then
    echo "[*] No se encontraron backups descargables."
else
    echo "[*] Backups descargados:"
    ls -lh "$OUTDIR"
fi
