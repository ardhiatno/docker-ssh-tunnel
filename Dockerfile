# --- STAGE 1: Ambil autossh & ssh dari EPEL tanpa build ---
FROM registry.access.redhat.com/ubi9:latest AS builder

RUN dnf install -y \
      'https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm' \
    && dnf config-manager --set-enabled epel \
    && dnf install -y --setopt=install_weak_deps=False autossh openssh-clients \
    && dnf clean all

RUN mkdir -p /out/bin /out/lib

# Copy binaries
RUN cp /usr/bin/autossh /out/bin/ && cp /usr/bin/ssh /out/bin/

# Copy required shared libraries
RUN set -e; \
    for b in /out/bin/autossh /out/bin/ssh; do \
      ldd "$b" | awk '/=>/ {print $3} /^\\// {print $1}' | sort -u | while read lib; do \
        cp -v --parents "$lib" /out/lib/; \
      done; \
    done; \
    cp -v --parents /lib64/ld-linux-x86-64.so.2 /out/lib/

# --- STAGE 2: Runtime minimal ---
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

# Pasang sshd karena akan digunakan untuk login SSH (dibutuhkan untuk container-access)
RUN microdnf install -y openssh-server passwd && microdnf clean all

# Buat user non-root 'tunnel'
RUN useradd -m -s /bin/bash tunnel

# Direktori kerja dan SSH
WORKDIR /home/tunnel/.ssh
COPY sshd_config /home/tunnel/.ssh/sshd_config
RUN mkdir -p /home/tunnel/.ssh && \
chown tunnel:tunnel /home/tunnel/.ssh && \
touch /home/tunnel/.ssh/authorized_keys /home/tunnel/.ssh/id_rsa && \
chown -R tunnel:tunnel /home/tunnel && \
chmod 600 /home/tunnel/.ssh/sshd_config

# Salin autossh, ssh, dan dependensi dari builder
COPY --from=builder /out/bin/autossh /usr/bin/autossh
COPY --from=builder /out/bin/ssh /usr/bin/ssh
COPY --from=builder /out/lib/ /lib64/

# Salin entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment defaults (bisa override)
ENV AUTOSSH_GATETIME=0 \
    SSH_OPTIONS="-o ServerAliveInterval=30 -o ServerAliveCountMax=3"
USER tunnel
EXPOSE 2222

# Jalankan entrypoint (sshd sebagai root, autossh nanti dijalankan sebagai user tunnel)
CMD ["/entrypoint.sh"]

