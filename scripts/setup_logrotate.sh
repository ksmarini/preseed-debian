#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_journald.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] setup_journald: iniciando"
echo "=============================================="

ENV_FILE="/etc/security_env.conf"
if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
else
  JOURNAL_MAX_PERCENT="5%"
  JOURNAL_MAX_FILE="200M"
  JOURNAL_MAX_AGE="14day"
fi

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

echo "[OK] Journald configurado!"
echo "Logs disponíveis em: $LOG"
echo "=============================================="
exit 0