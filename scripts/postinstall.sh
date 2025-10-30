#!/bin/bash
# Orquestra pós-instalação (idempotente)
set -euo pipefail
LOG="/var/log/postinstall.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] postinstall: iniciando..."

export DEBIAN_FRONTEND=noninteractive
[ -f /etc/security_env.conf ] || {
  echo "[ERRO] /etc/security_env.conf faltando!"
  exit 1
}

chmod +x /usr/local/sbin/*.sh || true

echo "===> Base tools"
/usr/local/sbin/setup_basetools.sh || true

echo "===> Hardening inicial (SSH/banners/sysctl)"
/usr/local/sbin/hardening.sh || true

echo "===> Ajustando GRUB"
sed -i -E 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/g' /etc/default/grub
sed -i -E 's/^#?GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/g' /etc/default/grub
update-grub || true

echo "===> Tmpfiles seguro"
/usr/local/sbin/setup_tmpfiles.sh || true

echo "===> Logrotate"
/usr/local/sbin/setup_logrotate.sh || true

echo "===> Syslog remoto + journald persistente"
/usr/local/sbin/setup_remote_logs.sh || true

echo "===> Firewall (nftables)"
/usr/local/sbin/setup_nft.sh || true

systemctl restart ssh || true
touch /var/log/postinstall.done
systemctl disable postinstall.service || true

echo "[OK] postinstall concluído com sucesso!"
exit 0
