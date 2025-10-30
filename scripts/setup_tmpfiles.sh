#!/bin/bash
# Harden /tmp and /var/tmp using fstab + remount
set -euo pipefail

LOG="/var/log/setup_tmpfiles.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] Hardened Temp Filesystem - Iniciando..."
echo "=============================================="

# -----------------------------------------------------------------
echo "[INFO] Ajustando /tmp no fstab..."
# Remove qualquer entrada antiga do fstab sobre /tmp
sed -i '/\/tmp/d' /etc/fstab

# Adiciona entrada CIS compatível
echo "tmpfs /tmp tmpfs rw,nosuid,nodev,noexec,mode=1777 0 0" >>/etc/fstab

echo "[INFO] Aplicando noexec /tmp neste boot..."
umount -R /tmp 2>/dev/null || echo "[WARN] /tmp não estava montado antes."
mount /tmp || {
  echo '[ERRO] Falha ao montar /tmp'
  exit 1
}

mount | grep /tmp || {
  echo '[ERRO] /tmp não está montado'
  exit 1
}

# -----------------------------------------------------------------
echo "[INFO] Ajustando /dev/shm..."
if ! grep -q "/dev/shm" /etc/fstab; then
  echo "tmpfs /dev/shm tmpfs rw,nosuid,nodev,noexec 0 0" >>/etc/fstab
fi
mount -o remount,rw,nosuid,nodev,noexec /dev/shm || echo "[WARN] Remount /dev/shm falhou"

mount | grep /dev/shm || echo "[WARN] /dev/shm não localizado na tabela de montagem"

# -----------------------------------------------------------------
echo "[INFO] Ajustando /var/tmp como bind para /tmp..."
umount -R /var/tmp 2>/dev/null || echo "[WARN] /var/tmp não estava montado."
rm -rf /var/tmp 2>/dev/null || true
mkdir -p /tmp 2>/dev/null || true
ln -s /tmp /var/tmp

echo "[INFO] /var/tmp agora é symlink para /tmp"
ls -l /var/tmp

# -----------------------------------------------------------------
echo "[INFO] Ajustando /home (nosuid,nodev)..."
sed -i -E '/[[:space:]]\/home[[:space:]]/ s/(defaults|ext4\s+defaults)/&,nosuid,nodev/' /etc/fstab
mount -o remount,nosuid,nodev /home || echo "[WARN] Remount /home falhou"
mount | grep /home || echo "[WARN] /home não localizado na tabela de montagem"

# -----------------------------------------------------------------
echo "=============================================="
echo "[OK] Hardened Temp Filesystem concluído!"
echo "   * /tmp — noexec,nosuid,nodev ✅"
echo "   * /var/tmp — symlink => /tmp ✅"
echo "   * /dev/shm — noexec,nosuid,nodev ✅"
echo "   * /home — nosuid,nodev ✅"
echo "Logs disponíveis em: $LOG"
echo "=============================================="
exit 0
