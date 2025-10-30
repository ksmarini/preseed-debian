#!/bin/bash
set -euo pipefail
LOG="/var/log/setup_wazuh.log"
exec > >(tee -a "$LOG") 2>&1

[ -f /etc/security_env.conf ] && . /etc/security_env.conf || {
  echo "[ERRO] /etc/security_env.conf ausente"
  exit 1
}

echo "[INFO] Iniciando setup_wazuh.sh"

# Se já existir o agente, só reconfigura manager e reinicia.
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q '^wazuh-agent'; then
  echo "[INFO] wazuh-agent já instalado. Ajustando manager..."
else
  echo "[INFO] Instalando wazuh-agent (se repositório já estiver configurado)"
  # Se o repositório não estiver configurado ainda, este apt falhará silenciosamente (ok).
  apt-get update -y || true
  apt-get install -y wazuh-agent || true
fi

CONF="/var/ossec/etc/ossec.conf"
if [ -f "$CONF" ]; then
  # Ajusta o <address> do manager (idempotente)
  if grep -q "<address>" "$CONF"; then
    sed -i "s#<address>.*</address>#<address>${WAZUH_MANAGER_IP}</address>#g" "$CONF"
  else
    # insere dentro de <client>...</client>
    sed -i "s#</client>#  <address>${WAZUH_MANAGER_IP}</address>\n</client>#g" "$CONF"
  fi
  systemctl enable --now wazuh-agent
  systemctl restart wazuh-agent
  echo "[OK] wazuh-agent configurado para manager ${WAZUH_MANAGER_IP}"
else
  echo "[WARN] $CONF não encontrado. Verifique repositório/instalação do Wazuh e reexecute."
fi
