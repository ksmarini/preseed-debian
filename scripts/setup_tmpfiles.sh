#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_tmpfiles.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] Harden /tmp /var/tmp /dev/shm /home"
echo "=============================================="

FSTAB="/etc/fstab"

fix_mount() {
  local path="$1"
  local options="$2"
  echo "[INFO] Configurando $path ..."
  umount -R "$path" 2>/dev/null || true
  sed -i "\|$path|d" "$FSTAB"
  echo "tmpfs $path tmpfs $options 0 0" >> "$FSTAB"
  mount "$path" || { echo "[ERRO] Falha ao montar $path"; exit 1; }
}

# /tmp
fix_mount "/tmp" "rw,nosuid,nodev,noexec,mode=1777"

# /var/tmp como tmpfs separado
fix_mount "/var/tmp" "rw,nosuid,nodev,noexec,mode=1777"

# /dev/shm
fix_mount "/dev/shm" "rw,nosuid,nodev,noexec,mode=1777"

# /home com nosuid,nodev
if grep -q "[[:space:]]/home[[:space:]]" "$FSTAB"; then
  echo "[INFO] Reforçando /home em fstab"
  sed -i -E 's/(defaults|ext4\s+defaults)/&,nosuid,nodev/' "$FSTAB"
  mount -o remount,nosuid,nodev /home || echo "[WARN] Remount /home falhou"
fi

echo "=============================================="
echo "[OK] Hardened TempFS concluído!"
echo "Logs disponíveis em: $LOG"
echo "=============================================="
exit 0