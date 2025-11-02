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

# IPv4 ICMP Protections
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.icmp_ratelimit = 100

# Anti Redirect / Anti Spoof
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# No Source Routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Reverse Path Filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Kernel Pointers / Debug
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1

# ASLR
kernel.randomize_va_space = 2

# ptrace restrictions
kernel.yama.ptrace_scope = 2

# Disable kexec
kernel.kexec_load_disabled = 1

# Disable unpriv BPF
kernel.unprivileged_bpf_disabled = 1

# Core dumps restricted
fs.suid_dumpable = 0

# Martian packets logging
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# SYN Cookies (Anti-SYN-Flood)
net.ipv4.tcp_syncookies = 1
EOF

echo "[INFO] Aplicando sysctl --system"
sysctl --system | sed 's/^/SYSCTL: /'

echo "[OK] setup_sysctl concluído!"
exit 0