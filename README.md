# SSH Tunnel Container untuk Akses Backend via DBeaver/Navicat

## Tujuan

Menjalankan container berbasis UBI yang:

* Membuka **SSH server** (user non-root `tunnel`).
* Menggunakan `autossh` untuk membuat **persistent SSH tunnel** dari container ke backend internal (misal database) tanpa mengekspos port database langsung.
* Aplikasi desktop seperti **DBeaver** / **Navicat** melakukan koneksi ke backend dengan:

  1. SSH ke container (`tunnel@ip-host-container:2222`), lalu
  2. Dari container menggunakan tunnel internal.

## Diagram Arsitektur

```
        ┌────────────────────────────┐
        │  DBeaver / Navicat (Host)  │
        │  ────────────────────────  │
        │  Connect via SSH to        │
        │  localhost:2222            │
        └─────────────┬──────────────┘
                      │ SSH
                      │ (port 2222)
                      │
        ┌─────────────▼──────────────┐
        │   Docker Host / Container  │
        │   Name: ssh-tunnel         │
        │                            │
        │  ┌──────────────────────┐  │
        │  │  sshd (port 2222)    │  │
        │  │  user: tunnel        │  │
        │  └─────────┬────────────┘  │
        └────────────┼───────────────┘
                     │ SSH Tunnel (outbound)
                     │
        ┌────────────▼─────────────┐
        │  Internal Backend DB     │
        │  e.g. PostgreSQL:5432    │
        └──────────────────────────┘
```

## Fitur utama

* Hanya **SSH** yang diekspos ke host (`127.0.0.1:2222`), database internal tidak pernah langsung terbuka.
* `sshd` berjalan sebagai user non-root `tunnel` dan menjaga tunnel tetap hidup.
* Cocok untuk penggunaan di Linux (bind ke localhost), aman tanpa publish port publik.

## Prasyarat

* Docker & Docker Compose (v2) terinstal.
* Backend internal (misal database) bisa diakses dari container melalui SSH target (`TUNNEL_AUTHORIZED_KEYS`) dan port (`REMOTE_PORT`).

## Struktur file yang diperlukan

* `Dockerfile`
* `entrypoint.sh` (mengambil parameter dari ENV dan menjalankan sshd )
* `docker-compose.yml`
* `Makefile`

## Setup cepat
1. Build dan jalankan container:

   ```bash
   make all
   ```
2. Cek log untuk memastikan tunnel terhubung:

   ```bash
   make logs
   ```
3. Tes SSH ke container:

   ```bash
   make ssh
   ```
4. Konfigurasi DBeaver / Navicat:

   * **SSH Host:** `ip-host-container`
   * **SSH Port:** `2222`
   * **SSH User:** `tunnel`
   * **SSH Key:** private key yang sesuai (`~/.ssh/id_ed25519`)
   * **Remote Host:** `127.0.0.1`
   * **Remote Port:** `5432` (atau sesuai `LOCAL_PORT`)
   * Connection akan melewati container lalu ke backend via tunnel.

## Environment variables (boleh override lewat docker-compose atau `-e`)

* `TUNNEL_AUTHORIZED_KEYS` : Authorized public key yang diijinkan untuk ssh ke container ini

## Contoh `docker-compose.yml` (disertakan)

```yaml
services:
  ssh-tunnel:
    container_name: ssh-tunnel
    restart: always
    image: ssh-tunnel
    environment:
      TUNNEL_AUTHORIZED_KEYS: |
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIo21jeou1wdo12he12ho12heo1udho1uwo test1
    ports:
      - 2222:2222
    networks:
      - internal-universe
```

## Commands via Makefile

* `make build` — build container
* `make up` — jalankan dengan docker-compose
* `make down` — hentikan
* `make restart` — restart
* `make logs` — lihat log
* `make ssh` — SSH ke container sebagai `tunnel`
* `make clean` — bersihkan image/volume/cache