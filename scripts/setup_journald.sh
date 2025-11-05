#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_journald.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] setup_journald: iniciando"
echo "=============================================="

ENV_FILE="/etc/security_env.conf"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1091
  source "$ENV_FILE"
else
  echo "[WARN] Variáveis globais não encontradas, usando defaults seguros"
  JOURNAL_SYSTEMMAXUSE="5%"
  JOURNAL_SYSTEMMAXFILESIZE="200M"
  JOURNAL_MAXRETENTION="14day"
fi

mkdir -p /etc/systemd/journald.conf.d
mkdir -p /var/log/journal # Persistência habilitada (CIS)

cat >/etc/systemd/journald.conf.d/10-journal.conf <<EOF
[Journal]
Storage=persistent
SystemMaxUse=${JOURNAL_SYSTEMMAXUSE}
SystemMaxFileSize=${JOURNAL_SYSTEMMAXFILESIZE}
MaxRetentionSec=${JOURNAL_MAXRETENTION}
ForwardToSyslog=no
Compress=yes
Seal=yes
EOF

# Reaplica configurações
systemctl restart systemd-journald

# Verifica aplicabilidade
echo "[INFO] Verificando storage do journald..."
if journalctl --verify &>/dev/null; then
  echo "✅ Journald configurado corretamente"
else
  echo "⚠️ Aviso: Verificação do journald encontrou inconsistências"
fi

echo "=============================================="
echo "[OK] journald configurado com sucesso ✅"
echo "Logs disponíveis em: $LOG"
echo "=============================================="
exit 0
