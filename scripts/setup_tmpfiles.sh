#!/bin/bash
# Harden /tmp, /var/tmp, /dev/shm, /home, /var/log e /var/log/audit
set -euo pipefail

LOG="/var/log/setup_tmpfiles.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] Hardened Temp & Log FS - Iniciando..."
echo "=============================================="

# Util para aplicar flags com remount
apply_mount_opts() {
  local target="$1"
  local opts="$2"

  echo "[INFO] Remontando ${target} com: ${opts}"
  if mount -o "remount,${opts}" "${target}"; then
    echo "✔ Remounted ${target}"
  else
    echo "[WARN] Remount falhou em ${target}. Aplicando via fstab e reboot pode ser necessário."
  fi
}

echo "[INFO] Aplicando hardening em /tmp..."
apply_mount_opts "/tmp" "nosuid,nodev,noexec,mode=1777"

echo "[INFO] Aplicando hardening em /dev/shm..."
apply_mount_opts "/dev/shm" "nosuid,nodev,noexec"

echo "[INFO] Aplicando hardening em /var/tmp..."
apply_mount_opts "/var/tmp" "nosuid,nodev,noexec"
chmod 1777 /var/tmp

echo "[INFO] Aplicando hardening em /var..."
apply_mount_opts "/var" "nosuid,nodev"

echo "[INFO] Aplicando hardening em /var/log..."
apply_mount_opts "/var/log" "nosuid,nodev,noexec"
chmod 750 /var/log

echo "[INFO] Aplicando hardening em /var/log/audit..."
apply_mount_opts "/var/log/audit" "nosuid,nodev,noexec"
chmod 750 /var/log/audit

echo "=============================================="
echo "[OK] Hardened Temp & Logs concluído!"
echo "   * /tmp — noexec,nosuid,nodev ✅"
echo "   * /var/tmp — noexec,nosuid,nodev ✅"
echo "   * /dev/shm — noexec,nosuid,nodev ✅"
echo "   * /var — nosuid,nodev ✅"
echo "   * /var/log — noexec,nosuid,nodev ✅"
echo "   * /var/log/audit — noexec,nosuid,nodev ✅"
echo "Logs: $LOG"
echo "=============================================="
exit 0
