#!/bin/bash
set -euo pipefail
LOG="/var/log/setup_logrotate.log"
exec > >(tee -a "$LOG") 2>&1

[ -f /etc/security_env.conf ] && . /etc/security_env.conf || {
  echo "[ERRO] /etc/security_env.conf ausente"
  exit 1
}

echo "[INFO] Ajustando journald para limitar uso"

# journald persistente com limites controlados
mkdir -p /etc/systemd/journald.conf.d
cat >/etc/systemd/journald.conf.d/99-hardening.conf <<EOF
[Journal]
Storage=persistent
SystemMaxUse=${JOURNAL_MAX_PERCENT}
SystemMaxFileSize=${JOURNAL_MAX_FILE}
MaxRetentionSec=${JOURNAL_MAX_AGE}
ForwardToSyslog=no
EOF

systemctl restart systemd-journald

echo "[INFO] Criando regras adicionais de logrotate (idempotente)"

# Exemplo genérico para /var/log/*.log
cat >/etc/logrotate.d/99-generic-hardening <<'EOF'
/var/log/*.log {
    weekly
    rotate 12
    size 50M
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
    sharedscripts
    postrotate
        /bin/systemctl kill -s HUP rsyslog.service 2>/dev/null || true
    endscript
}
EOF

# Wazuh agent logs
cat >/etc/logrotate.d/99-wazuh-agent <<'EOF'
/var/ossec/logs/ossec.log {
    daily
    rotate 14
    size 50M
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

# Zabbix agent logs (se existir)
if [ -d /var/log/zabbix ]; then
  cat >/etc/logrotate.d/99-zabbix-agent <<'EOF'
/var/log/zabbix/*.log {
    weekly
    rotate 8
    size 30M
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
fi

echo "[OK] Logrotate/journald configurados"
