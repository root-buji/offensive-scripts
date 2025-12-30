# nmap_full_ip.sh

Script Bash para automatizar un escaneo **completo y ordenado con Nmap** contra un target, siguiendo un flujo típico de pentesting:

1. Descubrimiento de puertos TCP (`-p-`)
2. Enumeración de servicios y versiones
3. Ejecución de scripts NSE **safe**
4. Enumeración UDP opcional
5. Generación de un resumen en Markdown

Diseñado para **labs (HTB, PG, INE)** y **auditorías reales**, priorizando claridad, reutilización y outputs limpios.

---

## Características

- TCP full scan (`-p-`)
- Enumeración de servicios (`-sV`)
- Scripts NSE **safe** (no intrusivos)
- UDP top ports opcional
- Detección de OS opcional
- Soporte para `-Pn`
- `dry-run` para auditar comandos
- Outputs organizados por target y timestamp
- Summary automático en Markdown
- Compatible con Metasploit (XML)

---

##  Uso Básico

./nmap_full_ip.sh -t 10.10.10.10
