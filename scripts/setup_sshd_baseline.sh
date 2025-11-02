#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_sshd_baseline.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] setup_sshd_baseline: iniciando"
echo "=============================================="

ENV="/etc/security_env.conf"
if [ -f "$ENV" ]; then
  . "$ENV"
  echo "[INFO] Variáveis carregadas de: $ENV"
else
  echo "[WARN] $ENV não encontrado. Perfil assumido: prod"
  PROFILE="prod"
fi

SSHD="/etc/ssh/sshd_config"

echo "[INFO] Configurando parâmetros SSH"

# Desabilita funcionalidades inseguras e ruídos
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD"
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' "$SSHD"
sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 300/' "$SSHD"
sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 2/' "$SSHD"
sed -i 's|^#\?AuthorizedKeysFile.*|AuthorizedKeysFile .ssh/authorized_keys|' "$SSHD"

# Hardening CIS
sed -i 's/^#\?UsePAM.*/UsePAM yes/' "$SSHD"
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD"
sed -i 's/^#\?GSSAPIAuthentication.*/GSSAPIAuthentication no/' "$SSHD"
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' "$SSHD"
sed -i 's/^#\?LoginGraceTime.*/LoginGraceTime 30/' "$SSHD"
sed -i 's/^#\?LogLevel.*/LogLevel VERBOSE/' "$SSHD"

if [ "${PROFILE:-prod}" = "dev" ]; then
  echo "[WARN] MODO DEV: PasswordAuthentication habilitado"
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD"
else
  echo "[INFO] MODO PROD: Somente chave SSH"
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD"
fi

# Banner CIS
echo "[INFO] Instalando banners CIS"
cat >/etc/issue <<EOF

AVISO LEGAL:
Acesso restrito. Toda atividade é monitorada.
Não há expectativa de privacidade.
Usuários não autorizados serão responsabilizados.

EOF

cp /etc/issue /etc/issue.net
sed -i 's/^#\?Banner.*/Banner \/etc\/issue.net/' "$SSHD"

echo "[INFO] Validando sintaxe do SSH..."
if ! sshd -t; then
  echo "[ERRO] Sintaxe inválida no sshd_config! Não reiniciando SSH."
  exit 3
fi

echo "[INFO] Reiniciando SSH..."
systemctl restart ssh || systemctl restart sshd || true

echo "=============================================="
echo "[OK] setup_sshd_baseline concluído com sucesso!"
echo "Logs em: $LOG"
echo "=============================================="

exit 0