#!/bin/bash
set -euo pipefail
LOGFILE="/var/log/postinstall.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "--- [$(date)] INÍCIO postinstall ---"
export DEBIAN_FRONTEND=noninteractive

[ -f /etc/security_env.conf ] || {
  echo "[ERRO] /etc/security_env.conf faltando"
  exit 1
}

echo "===> Base tools"
/usr/local/sbin/setup_basetools.sh

echo "===> Sysctl Hardening"
/usr/local/sbin/setup_sysctl.sh

echo "===> Ajustando GRUB"
sed -i -E 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i -E 's/^#?GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
update-grub || true

echo "===> Setup TMP"
/usr/local/sbin/setup_tmpfiles.sh

echo "===> Setup logrotate"
/usr/local/sbin/setup_logrotate.sh

echo "===> Firewall"
/usr/local/sbin/setup_nft.sh

echo "--- [$(date)] Pós-instalação concluída com sucesso ---"
systemctl disable postinstall.service || true
