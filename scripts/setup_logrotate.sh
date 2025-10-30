#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_logrotate.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] setup_logrotate: iniciando"
echo "=============================================="

ENV_FILE="/etc/security_env.conf"
if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
  echo "[INFO] Carregado: $ENV_FILE"
else
  echo "[WARN] $ENV_FILE não encontrado — usando valores padrão"
  JOURNAL_MAX_PERCENT="5%"
  JOURNAL_MAX_FILE="200M"
  JOURNAL_MAX_AGE="14day"
fi

# Fallbacks
JOURNAL_MAX_PERCENT="${JOURNAL_MAX_PERCENT:-5%}"
JOURNAL_MAX_FILE="${JOURNAL_MAX_FILE:-200M}"
JOURNAL_MAX_AGE="${JOURNAL_MAX_AGE:-14day}"

echo "[INFO] Configurando journald (limites CIS/Wazuh)"

mkdir -p /etc/systemd/journald.conf.d
cat >/etc/systemd/journald.conf.d/10-journal-size.conf <<EOF
[Journal]
SystemMaxUse=${JOURNAL_MAX_PERCENT}
SystemMaxFileSize=${JOURNAL_MAX_FILE}
MaxRetentionSec=${JOURNAL_MAX_AGE}
EOF

systemctl restart systemd-journald || {
  echo "[ERRO] Falha ao reiniciar journald"
  exit 1
}

echo "--- Validação ---"
echo -n "SystemMaxUse: " && grep -q "SystemMaxUse" /etc/systemd/journald.conf.d/10-journal-size.conf && echo "✅"
echo -n "SystemMaxFileSize: " && grep -q "SystemMaxFileSize" /etc/systemd/journald.conf.d/10-journal-size.conf && echo "✅"
echo -n "MaxRetentionSec: " && grep -q "MaxRetentionSec" /etc/systemd/journald.conf.d/10-journal-size.conf && echo "✅"

echo "=============================================="
echo "[OK] setup_logrotate concluído com sucesso!"
echo "Logs disponíveis em: $LOG"
echo "=============================================="
