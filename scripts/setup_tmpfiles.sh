#!/bin/bash
# Hardened temporary directories
set -euo pipefail

LOG="/var/log/setup_tmpfiles.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] setup_tmpfiles: iniciando"

# =========================================================
# Remove entradas antigas de /tmp e /var/tmp do fstab
# =========================================================
sed -i '/[[:space:]]\/tmp[[:space:]]/d' /etc/fstab
sed -i '/[[:space:]]\/var\/tmp[[:space:]]/d' /etc/fstab

# =========================================================
# Nova configuração endurecida
# =========================================================
cat >>/etc/fstab <<EOF
tmpfs /tmp tmpfs rw,nosuid,nodev,noexec,relatime,mode=1777 0 0
/tmp /var/tmp none bind 0 0
EOF

echo "[INFO] fstab atualizado"

# =========================================================
# Impede systemd tmp.mount de sobrescrever fstab
# =========================================================
systemctl mask tmp.mount 2>/dev/null || true
echo "[INFO] tmp.mount mascareado"

# =========================================================
# Recarrega
# =========================================================
umount -R /tmp 2>/dev/null || true
mount -a

echo "[INFO] setup_tmpfiles concluído com sucesso!"
exit 0
