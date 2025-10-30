#!/bin/bash
set -euo pipefail
LOG="/var/log/setup_remote_logs.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] setup_remote_logs: iniciando"
[ -f /etc/security_env.conf ] && . /etc/security_env.conf || true

WAZUH_SYSLOG_IP="${WAZUH_MANAGER_IP:-192.168.100.132}"
WAZUH_SYSLOG_PORT="${PORT_WAZUH_SYSLOG:-514}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y || true
apt-get install -y rsyslog || true

# journald persistente + limites
mkdir -p /var/log/journal
sed -i 's/^#\?Storage=.*/Storage=persistent/' /etc/systemd/journald.conf
sed -i 's/^#\?SystemMaxUse=.*/SystemMaxUse='"${JOURNAL_MAX_PERCENT:-5%}"'/' /etc/systemd/journald.conf
sed -i 's/^#\?SystemMaxFileSize=.*/SystemMaxFileSize='"${JOURNAL_MAX_FILE:-200M}"'/' /etc/systemd/journald.conf
sed -i 's/^#\?MaxRetentionSec=.*/MaxRetentionSec='"${JOURNAL_MAX_AGE:-14day}"'/' /etc/systemd/journald.conf
systemctl restart systemd-journald

# input do journald
grep -q 'imjournal' /etc/rsyslog.conf || cat >>/etc/rsyslog.conf <<'EOF'

# == Input do journald ==
module(load="imjournal" StateFile="imjournal.state")
EOF

# forward para Wazuh
cat >/etc/rsyslog.d/99-remote.conf <<EOF
template(name="TmplRFC5424" type="string"
  string="<%pri%>1 %timegenerated% %hostname% %app-name% %procid% - - %msg%\n")
*.* @${WAZUH_SYSLOG_IP}:${WAZUH_SYSLOG_PORT};TmplRFC5424
EOF

systemctl enable rsyslog 2>/dev/null || true
systemctl restart rsyslog || true

echo "[OK] syslog remoto ativo em ${WAZUH_SYSLOG_IP}:${WAZUH_SYSLOG_PORT}/udp"
