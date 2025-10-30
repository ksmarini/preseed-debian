#!/bin/bash
set -euo pipefail

STAMP="/var/lib/pam-hardening/password-changed"

if [ ! -f "$STAMP" ]; then
  mkdir -p /var/lib/pam-hardening
  touch "$STAMP"
  logger -p auth.notice "[PAM] Senha alterada - reboot agendado"
  shutdown -r +1 "Reiniciando para finalizar configuração de segurança..."
fi

exit 0
