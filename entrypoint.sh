#!/bin/sh
set -e

# --- Siapkan sshd host keys jika belum ada ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -C "tunnel-user" -f ~/.ssh/id_ed25519
fi

# Tulis authorized_keys dari env (mendukung banyak key newline-separated)
if [ -n "$TUNNEL_AUTHORIZED_KEYS" ]; then
  echo "[info] TUNNEL_AUTHORIZED_KEYS provided, parsing keys..." >&2

  # Buat file authorized_keys
  printf "%s\n" "$TUNNEL_AUTHORIZED_KEYS" > /home/tunnel/.ssh/authorized_keys
  chown tunnel:tunnel /home/tunnel/.ssh/authorized_keys 2>/dev/null || true
  chmod 600 /home/tunnel/.ssh/authorized_keys

  # Hitung dan tampilkan fingerprint tiap key (tanpa menampilkan key penuh)
  echo "[info] Authorized keys fingerprints:" >&2
  key_count=0
  printf "%s\n" "$TUNNEL_AUTHORIZED_KEYS" | while IFS= read -r key; do
    # simpan sementara agar ssh-keygen bisa baca
    tmpfile=$(mktemp)
    printf "%s\n" "$key" > "$tmpfile"
    if fingerprint=$(/usr/bin/ssh-keygen -lf "$tmpfile" 2>/dev/null); then
      echo "  - $fingerprint" >&2
    else
      echo "  - [warn] failed to parse key: $(echo "$key" | cut -c1-40)..." >&2
    fi
    rm -f "$tmpfile"
    key_count=$((key_count + 1))
  done

  # Karena while dalam subshell tidak bisa mengubah var di parent, ulang hitung untuk log
  total=$(printf "%s\n" "$TUNNEL_AUTHORIZED_KEYS" | wc -l | tr -d ' ')
  echo "[info] Loaded ${total} authorized key(s)." >&2
else
  echo "[warn] TUNNEL_AUTHORIZED_KEYS is empty; no SSH login keys configured for user 'tunnel'." >&2
fi

# Jalankan sshd di foreground agar bisa SSH ke container
/usr/sbin/sshd -f /home/tunnel/.ssh/sshd_config -D -p 2222

