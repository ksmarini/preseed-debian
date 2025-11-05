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
TOTAL_FAILS=0

# Carrega variáveis globais se existirem
if [[ -f "$ENV_FILE" ]]; then
  . "$ENV_FILE"
  echo "[INFO] Variáveis carregadas de: $ENV_FILE"
else
  echo "[WARN] Variáveis globais NÃO encontradas — prosseguindo com defaults"
fi

run_step() {
  local desc="$1"
  local script="$2"

  echo
  echo "----------------------------------------------"
  echo "[STEP] ${desc}"
  echo "----------------------------------------------"

  if [[ -x "$script" ]]; then
    if "$script"; then
      echo "✅ ${desc} — SUCESSO"
    else
      echo "❌ ${desc} — FALHA"
      ((TOTAL_FAILS++))
    fi
  else
    echo "⚠️ Script não encontrado ou sem permissão de execução: $script"
    ((TOTAL_FAILS++))
  fi
}

# Ordem sequencial de hardening
run_step "Ferramentas base" /usr/local/sbin/setup_basetools.sh
run_step "Configuração SSH baseline" /usr/local/sbin/setup_sshd_baseline.sh
run_step "Hardening de sysctl" /usr/local/sbin/setup_sysctl.sh
run_step "Hardening de mounts" /usr/local/sbin/setup_tmpfiles.sh
run_step "Configuração Firewall" /usr/local/sbin/setup_nft.sh
run_step "Configuração do Journald" /usr/local/sbin/setup_journald.sh
run_step "Configuração GRUB" /usr/local/sbin/setup_grub_silent.sh

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

echo "✅ /tmp validado via tmp.mount (systemd)"

validate_mount "/dev/shm" "nosuid,nodev,noexec"
validate_mount "/var/tmp" "nosuid,nodev,noexec"
validate_mount "/var" "nosuid,nodev"
validate_mount "/var/log" "nosuid,nodev"
validate_mount "/var/log/audit" "nosuid,nodev"
validate_mount "/home" "nosuid,nodev"

echo
echo "=============================================="
echo "[INFO] Verificando serviços"
echo "=============================================="

check_service() {
  local svc="$1"
  if systemctl is-active "$svc" >/dev/null 2>&1; then
    echo "✅ $svc ativo"
  else
    echo "❌ $svc NÃO está ativo"
    ((TOTAL_FAILS++))
  fi
}

check_service nftables
check_service ssh

echo
echo "=============================================="
if [[ $TOTAL_FAILS -eq 0 ]]; then
  echo "[OK] Postinstall concluído com SUCESSO TOTAL ✅"
else
  echo "[WARN] Postinstall finalizado com ${TOTAL_FAILS} falhas ⚠️"
  echo "Revise o log: ${LOG}"
fi
echo "=============================================="

# Marca execução concluída e remove autoexec
touch /var/log/postinstall_done
systemctl disable postinstall.service || true

echo
echo "=============================================="
echo "[INFO] Fim do postinstall ($(date))"
echo "=============================================="
exit $TOTAL_FAILS
