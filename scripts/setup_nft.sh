#!/bin/bash
set -euo pipefail
LOG="/var/log/setup_nft.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] setup_nft: iniciado"

# Carrega variáveis globais
source /etc/security_env.conf

# Converte CSV para lista nft
to_nft_list() {
  local csv="$1"
  # Remove espaços extras, transforma CSV para formato "a, b, c"
  echo "$csv" | sed 's/ *, */,/g' | sed 's/,/, /g'
}

ADMIN_SET=$(to_nft_list "$ADMIN_WORKSTATION_IPS")
VPN_SET=$(to_nft_list "$VPN_NETS")
ZBX_SET=$(to_nft_list "$ZABBIX_SERVER_IPS")

cat >/etc/nftables.conf <<EOF
flush ruleset

# ===== Variáveis =====
define PORT_SSH         = ${PORT_SSH}
define PORT_DNS         = ${PORT_DNS}
define PORT_HTTP        = ${PORT_HTTP}
define PORT_HTTPS       = ${PORT_HTTPS}
define PORT_NTP         = ${PORT_NTP}
define PORT_WAZUH_DATA  = ${PORT_WAZUH_DATA}
define PORT_WAZUH_CTRL  = ${PORT_WAZUH_CTRL}
define PORT_ZBX_SERVER  = ${PORT_ZBX_SERVER}
define PORT_ZBX_AGENT   = ${PORT_ZBX_AGENT}
define WAZUH_MGR        = ${WAZUH_MANAGER_IP}

table inet filter {

  # ===== Admin local e VPN =====
  set admin_allow {
    type ipv4_addr
    elements = { ${ADMIN_SET} }
  }

  set vpn_allow {
    type ipv4_addr
    flags interval
    elements = { ${VPN_SET} }
  }

  set zbx_allow {
    type ipv4_addr
    elements = { ${ZBX_SET} }
  }

  chain input {
    type filter hook input priority 0; policy drop;

    iif "lo" accept
    ct state established,related accept

    ip protocol icmp accept comment "ICMPv4 essencial"
    meta l4proto ipv6-icmp accept comment "ICMPv6 essencial"

    tcp dport \$PORT_SSH ip saddr @admin_allow accept comment "SSH admin"
    tcp dport \$PORT_SSH ip saddr @vpn_allow   accept comment "SSH VPN"

    limit rate 5/second counter log prefix "DROP_INPUT: " level warn drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy drop;

    oif "lo" accept
    ct state established,related accept

    udp dport \$PORT_DNS  accept
    tcp dport \$PORT_DNS  accept

    tcp dport \$PORT_HTTP accept
    tcp dport \$PORT_HTTPS accept

    udp dport \$PORT_NTP accept

    tcp dport { \$PORT_WAZUH_DATA, \$PORT_WAZUH_CTRL } ip daddr \$WAZUH_MGR accept comment "Wazuh Manager"
    tcp dport \$PORT_ZBX_SERVER ip daddr @zbx_allow accept comment "Zabbix Server"

    ip protocol icmp accept comment "ICMPv4 essencial"
    meta l4proto ipv6-icmp accept comment "ICMPv6 essencial"

    limit rate 5/second counter log prefix "DROP_OUTPUT: " level warn drop
  }
}
EOF

echo "[INFO] Validando sintaxe nft..."
nft -c -f /etc/nftables.conf

echo "[INFO] Aplicando firewall..."
nft -f /etc/nftables.conf

systemctl enable --now nftables

echo "[OK] setup_nft concluído!"
