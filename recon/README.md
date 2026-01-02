## Scripts incluidos

  - `nmap_full_ip.sh`: Escaneo completo de puertos (TCP) con Nmap, guarda resultados en formatos legibles

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

##  Uso Básico

./nmap_full_ip.sh -t 10.10.10.10
