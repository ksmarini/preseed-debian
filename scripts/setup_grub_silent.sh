#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_grub_silent.log"
exec > >(tee -a "$LOG") 2>&1

GRUB_FILE="/etc/default/grub"
ENV_FILE="/etc/security_env.conf"

# Carrega variáveis caso existam
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1091
  source "$ENV_FILE"
  echo "[INFO] Variáveis carregadas de: $ENV_FILE"
else
  echo "[WARN] $ENV_FILE não encontrado — usando defaults seguros"
fi

echo "[INFO] Configurando GRUB com hardening (mensagens essenciais)"

# Modo texto para uso em servidor
grep -q "GRUB_GFXPAYLOAD_LINUX" "$GRUB_FILE" || echo 'GRUB_GFXPAYLOAD_LINUX=text' >>"$GRUB_FILE"

# Oculta menu e timeout zero
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' "$GRUB_FILE" || echo 'GRUB_TIMEOUT=0' >>"$GRUB_FILE"
sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' "$GRUB_FILE" || echo 'GRUB_TIMEOUT_STYLE=hidden' >>"$GRUB_FILE"

# Kernel Hardening CIS + Lockdown + auditoria preparada
CMDLINE=(
  "quiet"
  "loglevel=3"
  "systemd.show_status=false"
  "lockdown=integrity"
  "audit=1"
  "audit_backlog_limit=${AUDIT_BACKLOG:-32768}"
  "slab_nomerge"
  "slub_debug=P"
  "page_poison=1"
  "vsyscall=none"
  "pti=on"
  "spectre_v2=on"
)

if [[ "${DISABLE_IPV6:-no}" == "yes" ]]; then
  CMDLINE+=("ipv6.disable=1")
fi

CMDLINE_STR="${CMDLINE[*]}"

if grep -q '^GRUB_CMDLINE_LINUX=' "$GRUB_FILE"; then
  sed -ri "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${CMDLINE_STR}\"|" "$GRUB_FILE"
else
  echo "GRUB_CMDLINE_LINUX=\"${CMDLINE_STR}\"" >>"$GRUB_FILE"
fi

mkdir -p /etc/systemd/system.conf.d
cat >/etc/systemd/system.conf.d/hide-systemd-messages.conf <<'EOF'
[Manager]
ShowStatus=auto
EOF

echo "[INFO] Atualizando GRUB"
update-grub

echo "[OK] GRUB endurecido e preparado (lockdown=integrity, audit pronto). Reinicie para aplicar."
exit 0
