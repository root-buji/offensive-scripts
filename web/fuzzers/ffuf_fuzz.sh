#!/bin/bash

# Requiere obviamente ffuf
command -v ffuf >/dev/null 2>&1 || {
    echo >&2 "[-] FFUF no está instalado. Instálalo con 'sudo apt install ffuf'"; exit 1;
}

# input
prompt_input() {
    read -p "$1 [$2]: " input
    echo "${input:-$2}"
}

# MENÚ
while true; do
    clear
    echo "========= FFUF DirBuster Tool ========="
    echo "1) Fuzz de directorios y archivos"
    echo "2) Fuzz de subdominios (requiere DNS configurado)"
    echo "3) Salir"
    echo "=========================================="
    read -p "Elige una opción: " option

    case $option in
        1)
            TARGET=$(prompt_input "Introduce la URL objetivo (sin / al final)" "https://target.com")
            WORDLIST=$(prompt_input "Ruta a la wordlist" "/usr/share/wordlists/dirb/common.txt")
            EXTENSIONS=$(prompt_input "Extensiones (separadas por coma)" "php,html,bak")
            THREADS=$(prompt_input "Número de hilos (threads)" "40")
            OUTPUT="ffuf_dirs_$(date +%s).json"

            echo "[*] Ejecutando fuzzing de directorios..."
            ffuf -u "${TARGET}/FUZZ" -w "$WORDLIST" -e ".$EXTENSIONS" \
                -mc 200,204,301,302,403 -t "$THREADS" -o "$OUTPUT" -of json

            echo "[+] Resultados guardados en $OUTPUT"
            read -p "Presiona Enter para continuar..."
            ;;

        2)
            TARGET=$(prompt_input "Dominio base (ej: target.com)" "target.com")
            WORDLIST=$(prompt_input "Wordlist de subdominios" "/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt")
            OUTPUT="ffuf_subs_$(date +%s).json"

            echo "[*] Ejecutando fuzzing de subdominios..."
            ffuf -u "https://FUZZ.${TARGET}" -w "$WORDLIST" \
                -mc 200,204,301,302,403 -t 40 -o "$OUTPUT" -of json

            echo "[+] Resultados guardados en $OUTPUT"
            read -p "Presiona Enter para continuar..."
            ;;

        3)
            echo "[*] Saliendo..."
            exit 0
            ;;

        *)
            echo "[!] Opción inválida"
            read -p "Presiona Enter para continuar..."
            ;;
    esac
done
