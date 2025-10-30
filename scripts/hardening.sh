#!/bin/bash
# Hardening base (CIS) — banners, SSH, sysctl, umask, serviços e preparação do PAM pós-login.
set -euo pipefail
LOG="/var/log/hardening.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] Iniciando hardening geral..."

# Carrega env
if [ -f /etc/security_env.conf ]; then
  . /etc/security_env.conf
else
  echo "[WARN] /etc/security_env.conf ausente; usando defaults."
fi

SSHD_PORT="${SSHD_PORT:-22}"
ALLOW_PASSWORD_SSH="${ALLOW_PASSWORD_SSH:-true}"

# ========== SSH ==========
echo "[INFO] SSH Hardening..."
SSHD="/etc/ssh/sshd_config"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD"
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' "$SSHD"
sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 300/' "$SSHD"
sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 2/' "$SSHD"
sed -i "s/^#\?Port.*/Port ${SSHD_PORT}/" "$SSHD"

if [ "$ALLOW_PASSWORD_SSH" = "true" ]; then
  grep -q '^[# ]*PasswordAuthentication' "$SSHD" &&
    sed -i 's/^[# ]*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD" ||
    echo "PasswordAuthentication yes" >>"$SSHD"
else
  grep -q '^[# ]*PasswordAuthentication' "$SSHD" &&
    sed -i 's/^[# ]*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD" ||
    echo "PasswordAuthentication no" >>"$SSHD"
fi

grep -q '^Banner ' "$SSHD" || echo "Banner /etc/issue.net" >>"$SSHD"
systemctl restart ssh || systemctl restart sshd || true

# ========== BANNERS ==========
echo "[INFO] Configurando banners..."
cat <<'EOF' >/etc/issue

ATENÇÃO: Sistema restrito. Todas as ações são monitoradas e registradas. Uso indevido é proibido.

EOF
cat <<'EOF' >/etc/issue.net

ATENÇÃO: Sistema restrito. Todas as ações são monitoradas e registradas. Uso indevido é proibido.

EOF
cat <<'EOF' >/etc/motd

ATENÇÃO: Uso não autorizado resultará em punições disciplinares e legais. Sistema monitorado.

EOF
chmod 644 /etc/issue /etc/issue.net /etc/motd

# ========== SYSCTL ==========
echo "[INFO] Aplicando proteções de Kernel/Rede..."
mkdir -p /etc/sysctl.d
cat >/etc/sysctl.d/99-hardening.conf <<'EOF'
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
fs.suid_dumpable = 0
kernel.unprivileged_bpf_disabled = 1
kernel.kexec_load_disabled = 1
EOF
sysctl --system || true

# ========== UMASK ==========
echo "[INFO] Ajustando umask..."
grep -qE '^[[:space:]]*umask[[:space:]]+027' /etc/profile || echo "umask 027" >>/etc/profile

# ========== SERVIÇOS ==========
echo "[INFO] Desabilitando serviços triviais..."
systemctl disable avahi-daemon 2>/dev/null || true
systemctl disable cups 2>/dev/null || true

# ========== PREPARO PAM PÓS-LOGIN ==========
# echo "[INFO] Preparando PAM hardening (após troca de senha)..."
# for PAM in /etc/pam.d/login /etc/pam.d/sshd; do
#   grep -q "/usr/local/sbin/firstlogin.sh" "$PAM" 2>/dev/null ||
#     echo "session optional pam_exec.so /usr/local/sbin/firstlogin.sh" >>"$PAM"
# done

# chage -d 0 marini || true
echo "[OK] Hardening aguardando troca de senha]"
