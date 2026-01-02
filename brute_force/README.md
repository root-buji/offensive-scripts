Fuerza Bruta de Servicios

Contiene scripts para automatizar ataques de fuerza bruta sobre servicios comunes como SSH y SMB (Usados en labs de ECCPT para probar distintos wordlists rapidamente)

## Scripts

### `ssh_brute.sh`
- Usa `hydra` para probar combinaciones de usuarios y contraseñas

### `smb_brute.sh`
- Basado en `crackmapexec`

## Requisitos

- `hydra`
- `crackmapexec`
- Wordlists comunes (`rockyou.txt`, `userlists`, etc.)

---

## Ejemplo 

```bash
./ssh_brute.sh -t 192.168.1.5 -u user.txt -p rockyou.txt
