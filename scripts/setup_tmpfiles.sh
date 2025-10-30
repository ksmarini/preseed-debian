#!/bin/bash
# Hardened temporary directories — FINAL
set -euo pipefail

LOG="/var/log/setup_tmpfiles.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] setup_tmpfiles: iniciando"

# =========================================================
# Remove entradas antigas de /tmp e /var/tmp do fstab
# =========================================================
sed -i '/[[:space:]]\/tmp[[:space:]]/d' /etc/fstab
sed -i '/[[:space:]]\/var\/tmp[[:space:]]/d' /etc/fstab

# Reescreve com opções seguras
cat >>/etc/fstab <<EOF
tmpfs /tmp tmpfs rw,nosuid,nodev,noexec,relatime,mode=1777 0 0
/tmp /var/tmp none bind 0 0
EOF

echo "[INFO] /etc/fstab atualizado com noexec,nodev,nosuid"

# =========================================================
# Override do systemd para /tmp — prevalece sobre tudo
# =========================================================
mkdir -p /etc/systemd/system/tmp.mount.d
cat >/etc/systemd/system/tmp.mount.d/override.conf <<EOF
[Mount]
What=tmpfs
Where=/tmp
Type=tmpfs
Options=rw,nosuid,nodev,noexec,relatime,mode=1777
EOF

echo "[INFO] tmp.mount configurado via override com segurança reforçada"

# =========================================================
# Monta novamente com as opções corretas
# =========================================================
umount -R /tmp 2>/dev/null || true
systemctl daemon-reload
systemctl restart tmp.mount || true
mount -a

echo "[INFO] Montagens aplicadas:"
mount | grep /tmp || true
mount | grep /var/tmp || true

echo "[OK] setup_tmpfiles concluído com sucesso!"
exit 0
