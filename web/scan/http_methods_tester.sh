#!/bin/bash

# Verificación básica
if [ -z "$1" ]; then
    echo "Uso: $0 https://target.com[/ruta]"
    exit 1
fi

TARGET="$1"
METHODS=("OPTIONS" "PUT" "DELETE" "TRACE")
TMPFILE="method_test_output.tmp"

echo "=============================================="
echo "[*] Probando métodos HTTP en: $TARGET"
echo "=============================================="
echo ""

for METHOD in "${METHODS[@]}"; do
    echo "[+] Método: $METHOD"

    # Petición con método actual
    RESPONSE=$(curl -sk -X "$METHOD" -o "$TMPFILE" -w "%{http_code}" "$TARGET")

    echo "    Código HTTP: $RESPONSE"

    # Si es OPTIONS, mostrar encabezado Allow
    if [[ "$METHOD" == "OPTIONS" ]]; then
        echo "    Encabezado Allow:"
        curl -sk -X OPTIONS -I "$TARGET" | grep -i "Allow:"
    fi

    echo ""
done

rm -f "$TMPFILE"

echo "=============================================="
echo "[*] Análisis finalizado."
echo "=============================================="
