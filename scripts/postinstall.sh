#!/bin/bash
# Execução pós-instalação: hardening integrado e validações finais
set -euo pipefail

LOG="/var/log/postinstall.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] Início do postinstall ($(date))"
echo "=============================================="

export DEBIAN_FRONTEND=noninteractive
ENV_FILE="/etc/security_env.conf"

# Carrega env se disponível
if [[ -f "$ENV_FILE" ]]; then
  . "$ENV_FILE"
  echo "[INFO] Variáveis carregadas de: $ENV_FILE"
else
  echo "[WARN] Variáveis globais NÃO encontradas"
fi

TOTAL_FAILS=0

run_step() {
  local desc="$1"
  local script="$2"

  echo
  echo "----------------------------------------------"
  echo "[STEP] $desc"
  echo "----------------------------------------------"

  if "$script"; then
    echo "✅ $desc — SUCESSO"
  else
    echo "❌ $desc — FALHA"
    ((TOTAL_FAILS++))
  fi
}

# Execução das rotinas de segurança
run_step "Base Tools" /usr/local/sbin/setup_basetools.sh
run_step "SSH Baseline" /usr/local/sbin/setup_sshd_baseline.sh
run_step "Sysctl Hardening" /usr/local/sbin/setup_sysctl.sh
run_step "Temp & Log Hardening" /usr/local/sbin/setup_tmpfiles.sh
run_step "Firewall (nftables)" /usr/local/sbin/setup_nft.sh
run_step "Boot silencioso (GRUB)" /usr/local/sbin/setup_grub_silent.sh

echo
echo "=============================================="
echo "[INFO] Validações adicionais"
echo "=============================================="

validate_mount() {
  local target="$1"
  local opts="$2"

  if findmnt -kn "$target" | grep -Eq "(${opts//,/|})"; then
    echo "✅ Mount OK: $target ($opts)"
  else
    echo "❌ Mount FAIL: $target ($opts)"
    ((TOTAL_FAILS++))
  fi
}

# Verificações importantes (CIS)
validate_mount "/tmp" "nosuid,nodev,noexec"
validate_mount "/dev/shm" "nosuid,nodev,noexec"
validate_mount "/var/tmp" "nosuid,nodev,noexec"
validate_mount "/var" "nosuid,nodev"
validate_mount "/var/log" "nosuid,nodev,noexec"
validate_mount "/var/log/audit" "nosuid,nodev,noexec"
validate_mount "/home" "nosuid,nodev"

echo
echo "=============================================="
echo "[INFO] Verificando firewall"
if systemctl is-enabled nftables >/dev/null 2>&1; then
  echo "✅ nftables habilitado"
else
  echo "❌ nftables NÃO habilitado"
  ((TOTAL_FAILS++))
fi

echo
echo "[INFO] Verificando SSH ativo"
if systemctl is-active ssh >/dev/null 2>&1; then
  echo "✅ SSH ativo"
else
  echo "❌ SSH NÃO está ativo"
  ((TOTAL_FAILS++))
fi

echo
echo "=============================================="
if [[ $TOTAL_FAILS -eq 0 ]]; then
  echo "[OK] Postinstall concluído com SUCESSO TOTAL ✅"
else
  echo "[WARN] Postinstall finalizado com ${TOTAL_FAILS} falhas ⚠️"
  echo "Verifique o log: $LOG"
fi
echo "=============================================="

# Remove execução automática futura
systemctl disable postinstall.service || true
echo "[INFO] Serviço postinstall.service desabilitado"

echo "=============================================="
echo "[INFO] Fim do postinstall ($(date))"
echo "=============================================="
exit $TOTAL_FAILS
