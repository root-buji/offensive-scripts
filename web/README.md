# Web Pentesting Scripts

Automatizaciones ofensivas para reconocimiento, escaneo, fuzzing y detección de vectores en entornos web.

Organizado en dos categorías:

-  **Scan** – Detección de tecnologías, métodos HTTP, headers, servicios
-  **Fuzzers** – Descubrimiento de directorios, archivos, backups, subdominios y bypasses

---

## Tabla de Scripts

| Script                         | Categoría | Descripción breve |
|-------------------------------|-----------|--------------------|
| `scan_base_web.sh`            | Scan      | Probing automático por puertos web (80, 443, 8080...) con `curl` y `whatweb`. Guarda headers y tecnologías |
| `http_methods_tester.sh`      | Scan      | Detecta métodos HTTP peligrosos como `PUT`, `DELETE`, `TRACE`, posibles vectores RCE                       |
| `ffuf_fuzz.sh`                | Fuzzer    | Fuzzing de directorios y archivos con `ffuf`, permite definir wordlist, extensión y hilos |
| `gobuster_fuzz.sh`            | Fuzzer    | Alternativa a FFUF usando `gobuster`, ideal para entornos sin Go |
| `wp_fuzz.sh`                  | Fuzzer    | Fuzzing dirigido a rutas sensibles en WordPress (`wp-login.php`, backups, XML-RPC, etc.) |
| `backup_fuzz.sh`              | Fuzzer    | Busca archivos de backup comunes: `.bak`, `.zip`, `.tar.gz`, `.old` |
| `autofilter_web.sh`           | Fuzzer    | Filtra resultados de fuzzing para eliminar falsos positivos y organizar output útil |

---

## Requisitos

- `ffuf`, `gobuster`, `curl`, `whatweb`
- Wordlists (`SecLists`, `rockyou.txt`, etc.)

