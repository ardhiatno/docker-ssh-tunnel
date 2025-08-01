# SSH Tunnel Container untuk Akses Backend via DBeaver/Navicat

## Tujuan

Menjalankan container berbasis UBI yang:

* Membuka **SSH server** (user non-root `tunnel`) hanya di `localhost:2222`.
* Menggunakan `autossh` untuk membuat **persistent SSH tunnel** dari container ke backend internal (misal database) tanpa mengekspos port database langsung.
* Aplikasi desktop seperti **DBeaver** / **Navicat** melakukan koneksi ke backend dengan:

  1. SSH ke container (`tunnel@localhost:2222`), lalu
  2. Dari container menggunakan tunnel internal yang sudah dipasang oleh `autossh`.

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
* `autossh` berjalan sebagai user non-root `tunnel` dan menjaga tunnel tetap hidup.
* Private key untuk `autossh` dan login SSH di-mount dari host, tidak pernah dikemas ke image.
* Cocok untuk penggunaan di Linux (bind ke localhost), aman tanpa publish port publik.

## Prasyarat

* Docker & Docker Compose (v2) terinstal.
* SSH key pair (`~/.ssh/id_rsa` dan `~/.ssh/id_rsa.pub`) tersedia.
* Backend internal (misal database) bisa diakses dari container melalui SSH target (`SSH_HOST`) dan port (`REMOTE_PORT`).

## Struktur file yang diperlukan

* `Dockerfile` (seperti disepakati sebelumnya)
* `entrypoint.sh` (menjalankan sshd + autossh sebagai user non-root)
* `docker-compose.yml`
* `Makefile`
* `tunnel_authorized_keys` berisi public key (`~/.ssh/id_rsa.pub`) untuk user `tunnel`

## Setup cepat

1. Salin public key ke file yang dipakai container sebagai authorized\_keys:

   ```bash
   cp ~/.ssh/id_rsa.pub ./tunnel_authorized_keys
   ```
2. Build dan jalankan container:

   ```bash
   make all
   ```
3. Cek log untuk memastikan tunnel terhubung:

   ```bash
   make logs
   ```
4. Tes SSH ke container:

   ```bash
   make ssh
   ```
5. Konfigurasi DBeaver / Navicat:

   * **SSH Host:** `localhost`
   * **SSH Port:** `2222`
   * **SSH User:** `tunnel`
   * **SSH Key:** private key yang sesuai (`~/.ssh/id_rsa`)
   * **Remote Host:** `127.0.0.1`
   * **Remote Port:** `5432` (atau sesuai `LOCAL_PORT`)
   * Connection akan melewati container lalu ke backend via tunnel.

## Environment variables (boleh override lewat docker-compose atau `-e`)

* `SSH_USER` : user di backend internal (untuk autossh target)
* `SSH_HOST` : hostname / IP backend internal yang reachable via SSH
* `SSH_PORT` : port SSH target backend (default `22`)
* `REMOTE_PORT` : port service internal (misal database) di backend
* `LOCAL_PORT` : port lokal di container yang dipakai autossh untuk forward
* `DISABLE_STRICT_HOST_KEY_CHECKING` : set `1` untuk dev (menonaktifkan verifikasi host key, *tidak disarankan* produksi)

## Contoh `docker-compose.yml` (disertakan)

```yaml
version: "3.8"

services:
  ssh-tunnel:
    build: .
    container_name: ssh-tunnel
    restart: unless-stopped
    ports:
      - "127.0.0.1:2222:2222"
    environment:
      SSH_USER: alice
      SSH_HOST: internal-db.example.local
      SSH_PORT: "22"
      REMOTE_PORT: "5432"
      LOCAL_PORT: "5432"
      # DISABLE_STRICT_HOST_KEY_CHECKING: "1"
    volumes:
      - ~/.ssh/id_rsa:/home/tunnel/.ssh/id_rsa:ro
      - ~/.ssh/id_rsa.pub:/home/tunnel/.ssh/authorized_keys:ro
```

## Commands via Makefile

* `make build` — build container
* `make up` — jalankan dengan docker-compose
* `make down` — hentikan
* `make restart` — restart
* `make logs` — lihat log
* `make ssh` — SSH ke container sebagai `tunnel`
* `make clean` — bersihkan image/volume/cache

## Keamanan & best practice

* `autossh` berjalan sebagai user `tunnel`, bukan root.
* `sshd` tetap dijalankan oleh root (dibutuhkan untuk binding dan manajemen sesi).
* Database tidak diekspos langsung; hanya lewat SSH ke container kemudian ke tunnel internal.
* Jangan letakkan private key di image—selalu mount.
* Di produksi: isi `/home/tunnel/.ssh/known_hosts` dengan fingerprint target internal agar verifikasi host berjalan, jangan gunakan `DISABLE_STRICT_HOST_KEY_CHECKING=1`.

## Troubleshooting

* Jika tunnel tidak hidup: cek log `make logs` dan pastikan `autossh` berhasil authenticate ke `SSH_HOST`.
* Jika tidak bisa SSH ke container: pastikan public key dimount ke `/home/tunnel/.ssh/authorized_keys` dan permission benar (`700` untuk `.ssh`, `600` untuk file\`).
* Cek apakah `autossh` benar bind ke `127.0.0.1:LOCAL_PORT` di dalam container dengan:

  ```sh
  docker exec -it ssh-tunnel netstat -tlnp
  ```

## Ekstensi yang bisa ditambahkan

* SSH config alias lokal untuk otomatisasi (`~/.ssh/config`)
* Reverse tunnel jika backend perlu mengakses sesuatu di host
* Monitoring / healthcheck script untuk restart jika tunnel mati
* Logging terpusat dari container
