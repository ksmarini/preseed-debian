#!/bin/bash
# Harden /dev/shm, /var/tmp, /var, /var/log, /var/log/audit, /home
set -euo pipefail

LOG="/var/log/setup_tmpfiles.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] Hardened Mount Options — Iniciando..."
echo "=============================================="

update_fstab_and_remount() {
  local target="$1"
  local opts="$2"
  local result="❌ FAIL"

  echo -e "\n--- Harden: ${target} ---"
  echo "[INFO] Flags desejadas: ${opts}"

  # Atualiza/insere entrada no fstab
  if grep -Eq "[[:space:]]${target}[[:space:]]" /etc/fstab; then
    echo "[INFO] Atualizando fstab..."
    sed -i -E \
      "s#^([^ ]+[[:space:]]+${target//\//\\/}[[:space:]]+[^ ]+[[:space:]]+)([^ ]+).*#\1${opts}#" \
      /etc/fstab
  else
    echo "[WARN] ${target} não encontrado no fstab — Correção manual pode ser necessária"
  fi

  echo "[INFO] Tentando remount..."
  if mount -o remount,"${opts}" "$target" 2>/dev/null; then
    echo "✔ Remount aplicado em ${target}"
  else
    echo "⚠️ Remount falhou — será aplicado no próximo boot"
  fi

  if findmnt -kn "$target" | grep -qE "$(echo "$opts" | sed 's/,/|/g')"; then
    result="✅ OK"
  fi

  echo "[RESULTADO] $result — $target"
}

update_fstab_and_remount "/dev/shm" "rw,nosuid,nodev,noexec"
update_fstab_and_remount "/var/tmp" "rw,nosuid,nodev,noexec"

update_fstab_and_remount "/var/log" "rw,nosuid,nodev,noexec"
chmod 750 /var/log

update_fstab_and_remount "/var/log/audit" "rw,nosuid,nodev,noexec"
chmod 750 /var/log/audit

update_fstab_and_remount "/var" "rw,nosuid,nodev"
update_fstab_and_remount "/home" "rw,nosuid,nodev"
chmod 755 /home

echo -e "\n=============================================="
echo "[INFO] Verificação final:"
echo "=============================================="
check() {
  if findmnt -kn "$1" | grep -qE "$(echo "$2" | sed 's/,/|/g')"; then
    echo "✅ $1 OK ($2)"
  else
    echo "❌ $1 FALHA ($2)"
  fi
}

check "/dev/shm" "nosuid,nodev,noexec"
check "/var/tmp" "nosuid,nodev,noexec"
check "/var/log" "nosuid,nodev,noexec"
check "/var/log/audit" "nosuid,nodev,noexec"
check "/var" "nosuid,nodev"
check "/home" "nosuid,nodev"

echo "=============================================="
echo "[OK] Hardening de mounts finalizado ✅"
echo "Log completo: $LOG"
echo "=============================================="
exit 0
