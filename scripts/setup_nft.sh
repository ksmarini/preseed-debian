#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_nft.log"
exec > >(tee -a "$LOG") 2>&1

echo -e "\n=============== setup_nft.sh ==============="
echo "[INFO] Início - $(date)"

# ===== Variáveis de segurança =====
if [[ -f /etc/security_env.conf ]]; then
  echo "[INFO] Carregando variáveis de segurança..."
  # shellcheck disable=SC1091
  source /etc/security_env.conf
  echo "[INFO] Variáveis carregadas com sucesso."
else
  echo "[ERRO] /etc/security_env.conf não encontrado!"
  exit 1
fi

# ===== Validação =====
check_var() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    echo "[ERRO] Variável não definida: $var_name"
    exit 2
  fi
  echo "[INFO] OK: $var_name=${!var_name}"
}

check_var "ADMIN_WORKSTATION_IPS"
check_var "VPN_NETS"
check_var "ZABBIX_SERVER_IPS"
check_var "WAZUH_MANAGER_IP"

# ===== Conversão para formato nft =====
echo "[INFO] Convertendo listas para nftables..."

listify() {
  echo "$1" | sed 's/ *, */,/g'
}

ADMIN_SET=$(listify "$ADMIN_WORKSTATION_IPS")
VPN_SET=$(listify "$VPN_NETS")
ZBX_SET=$(listify "$ZABBIX_SERVER_IPS")

echo "[DEBUG] ADMIN_SET = ${ADMIN_SET}"
echo "[DEBUG] VPN_SET = ${VPN_SET}"
echo "[DEBUG] ZBX_SET = ${ZBX_SET}"

# ===== Geração do arquivo nft =====
echo "[INFO] Criando /etc/nftables.conf ..."
cat >/etc/nftables.conf <<EOF
flush ruleset

define PORT_SSH        = ${PORT_SSH}
define PORT_DNS        = ${PORT_DNS}
define PORT_HTTP       = ${PORT_HTTP}
define PORT_HTTPS      = ${PORT_HTTPS}
define PORT_NTP        = ${PORT_NTP}
define PORT_WZ_DATA    = ${PORT_WAZUH_DATA}
define PORT_WZ_CTRL    = ${PORT_WAZUH_CTRL}
define PORT_ZBX_SRV    = ${PORT_ZBX_SERVER}
define PORT_ZBX_AGENT  = ${PORT_ZBX_AGENT}
define WAZUH_MGR       = ${WAZUH_MANAGER_IP}

table inet filter {

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

    ip protocol icmp accept
    meta l4proto ipv6-icmp accept

    tcp dport \$PORT_SSH ip saddr @admin_allow accept
    tcp dport \$PORT_SSH ip saddr @vpn_allow accept

$([ "$PROFILE" = "dev" ] && echo '    # DEV: SSH com senha permitido')
$([ "$PROFILE" = "prod" ] && echo '    # PROD: somente chave SSH')

$([ "$EXPOSE_HTTP_INBOUND" = "true" ] && echo "    tcp dport \$PORT_HTTP accept")
$([ "$EXPOSE_HTTPS_INBOUND" = "true" ] && echo "    tcp dport \$PORT_HTTPS accept")
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy drop;

    oif "lo" accept
    ct state established,related accept

$([ "$ALLOW_OUTBOUND_DNS" = "true" ] && echo "    udp dport \$PORT_DNS accept
    tcp dport \$PORT_DNS accept")

$([ "$ALLOW_OUTBOUND_WEB" = "true" ] && echo "    tcp dport { \$PORT_HTTP, \$PORT_HTTPS } accept")

$([ "$ALLOW_OUTBOUND_NTP" = "true" ] && echo "    udp dport \$PORT_NTP accept")

    tcp dport { \$PORT_WZ_DATA, \$PORT_WZ_CTRL } ip daddr \$WAZUH_MGR accept
    tcp dport \$PORT_ZBX_SRV ip daddr @zbx_allow accept

    ip protocol icmp accept
    meta l4proto ipv6-icmp accept
  }
}
EOF

# ===== Validação e aplicação =====
echo "[INFO] Validando sintaxe..."
nft -c -f /etc/nftables.conf &&
  echo "[OK] Sintaxe nft válida" ||
  {
    echo "[ERRO] nft inválido!"
    exit 3
  }

echo "[INFO] Aplicando regras..."
nft -f /etc/nftables.conf

echo "[INFO] Habilitando nftables..."
systemctl enable --now nftables

echo "[OK] setup_nft finalizado com sucesso ✅"
echo "==============================================="
exit 0
