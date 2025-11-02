#!/bin/bash
set -euo pipefail

LOG="/var/log/postinstall.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] Início do postinstall"
echo "=============================================="

export DEBIAN_FRONTEND=noninteractive

# Carrega variáveis globais
if [ -f /etc/security_env.conf ]; then
  . /etc/security_env.conf
  echo "[INFO] Carregado: /etc/security_env.conf"
else
  echo "[ERRO] /etc/security_env.conf ausente!"
  exit 1
fi

# 1
echo "[1/6] Base Tools"
/usr/local/sbin/setup_basetools.sh
echo "[OK] Base Tools"
echo "----------------------------------------------"

# 2
echo "[2/6] SSH Baseline"
/usr/local/sbin/setup_sshd_baseline.sh
echo "[OK] SSH configurado"
echo "----------------------------------------------"

# 3
echo "[3/6] Sysctl Hardening"
/usr/local/sbin/setup_sysctl.sh
echo "[OK] Sysctl aplicado"
echo "----------------------------------------------"

# 4
echo "[4/6] Proteção TMP"
/usr/local/sbin/setup_tmpfiles.sh
echo "[OK] Proteção TMP aplicada"
echo "----------------------------------------------"

# 5
echo "[5/6] Logrotate & Journald"
/usr/local/sbin/setup_logrotate.sh
echo "[OK] Logrotate aplicado"
echo "----------------------------------------------"

# 6
echo "[6/6] Firewall (nftables)"
/usr/local/sbin/setup_nft.sh
echo "[OK] Firewall ativado"
echo "----------------------------------------------"

echo "=============================================="
echo "[OK] postinstall concluído com sucesso!"
echo "Logs em: $LOG"
echo "=============================================="

# Marca execução concluída para não repetir no próximo boot
echo "[INFO] Criando flag /var/log/postinstall_done"
touch /var/log/postinstall_done

echo "[INFO] Desabilitando postinstall.service"
systemctl disable postinstall.service || true

# Garante systemd atualizado
echo "[INFO] Reload do Daemon e SSH"
systemctl daemon-reload
systemctl restart ssh.service || true

echo "[OK] Pós-instalação finalizada corretamente"
exit 0