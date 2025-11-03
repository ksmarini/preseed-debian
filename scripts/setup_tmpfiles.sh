#!/bin/bash
# Harden /var/tmp, /dev/shm, /home, /var/log, /var/log/audit
# /tmp é gerenciado via systemd tmp.mount (não tocar aqui)
set -euo pipefail

LOG="/var/log/setup_tmpfiles.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] Hardened Mount Options — Iniciando..."
echo "=============================================="

# Função padrão para aplicar flags e validar
harden_mount() {
  local target="$1"
  local opts="$2"

  echo -e "\n--- Harden: ${target} ---"
  echo "[INFO] Flags desejadas: ${opts}"

  # Atualiza /etc/fstab para persistência
  if grep -qE "[[:space:]]${target}[[:space:]]" /etc/fstab; then
    sed -i -E \
      "s#(^[^ ]+[[:space:]]+${target//\//\\/}[[:space:]]+[^ ]+[[:space:]]+)([^ ]+)#\1${opts}#" \
      /etc/fstab
    echo "✔ fstab atualizado"
  else
    echo "[WARN] ${target} não encontrado no fstab"
    echo "⚠️ INSERINDO entrada manual!"
    echo "${target} fstab precisa revisão posterior!"
  fi

  # Tentativa de aplicar no runtime
  if mount -o "remount,${opts}" "${target}" 2>/dev/null; then
    echo "✔ Remount aplicado em ${target}"
  else
    echo "⚠️ Remount falhou. Aplicará no próximo reboot."
  fi
}

# Proteções CIS

harden_mount "/dev/shm" "nosuid,nodev,noexec"
chmod 1777 /dev/shm || true

harden_mount "/var/tmp" "nosuid,nodev,noexec"
chmod 1777 /var/tmp || true

harden_mount "/var" "nosuid,nodev"

harden_mount "/var/log" "nosuid,nodev,noexec"
chmod 750 /var/log || true

harden_mount "/var/log/audit" "nosuid,nodev,noexec"
chmod 750 /var/log/audit || true

# Proteção /home — SEM noexec
echo -e "\n--- Harden: /home (somente nosuid,nodev) ---"
harden_mount "/home" "nosuid,nodev"
chmod 755 /home || true

# Validação final
echo -e "\n=============================================="
echo "[INFO] Verificação pós-aplicação"
echo "=============================================="

fails=0
validate() {
  local tgt="$1"
  local must="$2"
  if findmnt -kn "${tgt}" | grep -Eq "(${must//,/|})"; then
    echo "✅ ${tgt} → OK (${must})"
  else
    echo "❌ ${tgt} → FALHA (${must})"
    ((fails++))
  fi
}

validate "/dev/shm" "nosuid,nodev,noexec"
validate "/var/tmp" "nosuid,nodev,noexec"
validate "/var" "nosuid,nodev"
validate "/var/log" "nosuid,nodev,noexec"
validate "/var/log/audit" "nosuid,nodev,noexec"
validate "/home" "nosuid,nodev"

echo -e "\n=============================================="
if [ "$fails" -eq 0 ]; then
  echo "[OK] Harden configs aplicadas com SUCESSO TOTAL ✅"
else
  echo "[WARN] Harden com ${fails} falhas ⚠️"
  echo "      Verifique fstab ou reinicie o sistema"
fi
echo "Log completo: $LOG"
echo "=============================================="
exit 0
