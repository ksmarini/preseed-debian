#!/bin/bash
set -euo pipefail

LOG="/var/log/postinstall.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] Início do postinstall"
echo "=============================================="

export DEBIAN_FRONTEND=noninteractive

# Carrega variáveis globais de segurança
if [ -f /etc/security_env.conf ]; then
  . /etc/security_env.conf
  echo "[INFO] Carregado: /etc/security_env.conf"
else
  echo "[ERRO] /etc/security_env.conf ausente!"
  exit 1
fi

# -------------------------------------------------
echo "[1/6] Base Tools"
/usr/local/sbin/setup_basetools.sh
echo "[OK] Base Tools concluído"
echo "----------------------------------------------"

# -------------------------------------------------
echo "[2/6] Sysctl Hardening"
/usr/local/sbin/setup_sysctl.sh
echo "[OK] Sysctl aplicado"
echo "----------------------------------------------"

# -------------------------------------------------
echo "[3/6] GRUB Timeout"
sed -i -E 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i -E 's/^#?GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
update-grub || true
echo "[OK] GRUB atualizado"
echo "----------------------------------------------"

# -------------------------------------------------
echo "[4/6] Proteção de partições temporárias"
/usr/local/sbin/setup_tmpfiles.sh
echo "[OK] Partições endurecidas"
echo "----------------------------------------------"

# -------------------------------------------------
echo "[5/6] Logrotate & Journald"
/usr/local/sbin/setup_logrotate.sh
echo "[OK] Logrotate configurado"
echo "----------------------------------------------"

# -------------------------------------------------
echo "[6/6] Firewall (nftables)"
/usr/local/sbin/setup_nft.sh
echo "[OK] Firewall aplicado"
echo "----------------------------------------------"

echo "=============================================="
echo "[OK] Postinstall concluído com sucesso!"
echo "Logs disponíveis em: $LOG"
echo "=============================================="

systemctl disable postinstall.service || true
exit 0
