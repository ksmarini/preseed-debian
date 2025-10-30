#!/bin/bash
set -euo pipefail
LOG="/var/log/hardening.log"
exec > >(tee -a "$LOG") 2>&1

[ -f /etc/security_env.conf ] || {
  echo "[ERRO] /etc/security_env.conf ausente"
  exit 1
}

echo "[INFO] Hardening geral iniciado"

# ===== SSH =====
SSHD="/etc/ssh/sshd_config"

sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD"
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' "$SSHD"
sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 300/' "$SSHD"
sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 2/' "$SSHD"

systemctl restart ssh || true

# ===== Config. de permissões globais =====
PROFILE="/etc/profile"
grep -q "umask 027" "$PROFILE" || echo "umask 027" >>"$PROFILE"

systemctl disable avahi-daemon 2>/dev/null || true
systemctl disable cups 2>/dev/null || true

echo "[OK] Hardening concluído com sucesso!"
