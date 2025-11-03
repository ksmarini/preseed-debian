#!/bin/bash
# Harden /tmp, /var/tmp, /dev/shm, /home, /var/log e /var/log/audit
set -euo pipefail

LOG="/var/log/setup_tmpfiles.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] Hardened Temp & Log FS — Iniciando..."
echo "=============================================="

# Aplica e valida flags no fstab + remount
harden_fstab() {
  local target="$1"
  local opts="$2"
  local result="❌ FAIL"

  echo -e "\n--- Harden: ${target} ---"
  echo "[INFO] Requerido: ${opts}"

  # Persistência
  sed -i -E \
    "s#^([^ ]+[[:space:]]+${target//\//\\/}[[:space:]]+[^ ]+[[:space:]]+)(.*)#\1${opts}#" \
    /etc/fstab

  # Aplicação imediata (se possível)
  if mount -o "remount,${opts}" "${target}" 2>/dev/null; then
    echo "✔ Remount aplicado em ${target}"
  else
    echo "⚠️ Remount falhou. Aplicará no próximo reboot."
  fi

  # Verificação do estado final
  if findmnt -kn "${target}" | grep -Eq "(${opts//,/|})"; then
    result="✅ OK"
  fi

  echo "[RESULTADO] ${target}: ${result}"
}

harden_fstab "/tmp" "nosuid,nodev,noexec,mode=1777"
chmod 1777 /tmp

harden_fstab "/dev/shm" "nosuid,nodev,noexec"

harden_fstab "/var/tmp" "nosuid,nodev,noexec"
chmod 1777 /var/tmp

harden_fstab "/var" "nosuid,nodev"

harden_fstab "/var/log" "nosuid,nodev,noexec"
chmod 750 /var/log

harden_fstab "/var/log/audit" "nosuid,nodev,noexec"
chmod 750 /var/log/audit

# Protegendo /home (sem noexec)
harden_fstab "/home" "nosuid,nodev"
chmod 750 /home

echo -e "\n=============================================="
echo "[INFO] Verificação Pós-Aplicação"
echo "=============================================="

fails=0

check() {
  local target="$1"
  local opts="$2"

  if findmnt -kn "${target}" | grep -Eq "(${opts//,/|})"; then
    echo "✅ ${target} → OK (${opts})"
  else
    echo "❌ ${target} → FALHA (${opts})"
    ((fails++))
  fi
}

check "/tmp" "nosuid,nodev,noexec"
check "/dev/shm" "nosuid,nodev,noexec"
check "/var/tmp" "nosuid,nodev,noexec"
check "/var" "nosuid,nodev"
check "/var/log" "nosuid,nodev,noexec"
check "/var/log/audit" "nosuid,nodev,noexec"
check "/home" "nosuid,nodev"

echo -e "\n=============================================="
if [ "$fails" -eq 0 ]; then
  echo "[OK] Hardened FS concluído com SUCESSO TOTAL! ✅"
else
  echo "[WARN] Hardened FS com ${fails} falhas. ⚠️"
  echo "       Revise /etc/fstab ou reinicie o sistema."
fi
echo "Log completo: $LOG"
echo "=============================================="
exit 0
