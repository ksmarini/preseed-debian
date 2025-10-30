#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_sysctl.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] setup_sysctl: iniciando"

SYSCTL_DIR="/etc/sysctl.d"
CONF="${SYSCTL_DIR}/99-hardening.conf"

mkdir -p "$SYSCTL_DIR"

cat >"$CONF" <<'EOF'
# ===== Kernel & Network Hardening (CIS) =====

# Proteções IPv4 / ICMP
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Anti-Redirect spoof
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Nunca enviar redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Reverse Path Filtering (Anti-spoofing)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Secure redirect = off
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Kernel pointers / debug
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1

# ASLR
kernel.randomize_va_space = 2

# Bloqueia ptrace entre usuários
kernel.yama.ptrace_scope = 2

# Desabilita kexec (bloqueia bypasses via reboot)
kernel.kexec_load_disabled = 1

# Desabilita BPF para não privilegiados
kernel.unprivileged_bpf_disabled = 1

# Core dumps restritos
fs.suid_dumpable = 0
EOF

# Aplica imediatamente
echo "[INFO] Aplicando sysctl --system"
sysctl --system

echo "[OK] setup_sysctl concluído!"
