#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_grub_silent.log"
exec > >(tee -a "$LOG") 2>&1

GRUB_FILE="/etc/default/grub"

echo "[INFO] Configurando GRUB silencioso e rápido"

# Remove logo do Debian
if ! grep -q "GRUB_GFXPAYLOAD_LINUX" "$GRUB_FILE"; then
  echo 'GRUB_GFXPAYLOAD_LINUX=text' >>"$GRUB_FILE"
fi

# Oculta menu e zera timeout
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' "$GRUB_FILE"
sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' "$GRUB_FILE"

# Modo silencioso
sed -i 's/^\(GRUB_CMDLINE_LINUX=".*\)"/\1 quiet splash"/' "$GRUB_FILE" ||
  sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="quiet splash"/' "$GRUB_FILE"

echo "[INFO] Removendo mensagens do systemd no boot"
mkdir -p /etc/systemd/system.conf.d
cat >/etc/systemd/system.conf.d/hide-systemd-messages.conf <<EOF
[Manager]
ShowStatus=no
EOF

echo "[INFO] Atualizando GRUB"
update-grub

echo "[OK] Boot otimizado e silencioso"
exit 0
