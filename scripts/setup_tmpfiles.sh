#!/bin/bash
# Harden /tmp and /var/tmp using systemd mount units + fstab
set -euo pipefail

LOG="/var/log/setup_tmpfiles.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] setup_tmpfiles: iniciando"

# 1) Remover entradas antigas do fstab
sed -i '/[[:space:]]\/tmp[[:space:]]/d' /etc/fstab
sed -i '/[[:space:]]\/var\/tmp[[:space:]]/d' /etc/fstab

# 2) Escrever fstab desejado (tmpfs endurecido em /tmp + bind /var/tmp)
cat >>/etc/fstab <<'EOF'
tmpfs   /tmp      tmpfs  rw,nosuid,nodev,noexec,relatime,mode=1777  0  0
/tmp    /var/tmp  none   bind                                       0  0
EOF
echo "[INFO] fstab atualizado (tmpfs /tmp com noexec; bind /var/tmp)"

# 3) Garantir que o systemd NÃO monte /var/tmp como tmpfs
#    (algumas builds trazem var-tmp.mount que sobrescreve o fstab)
if systemctl list-unit-files | grep -q '^var-tmp\.mount'; then
  systemctl mask var-tmp.mount || true
  echo "[INFO] var-tmp.mount mascarado"
fi

# 4) Forçar unit local de /tmp com as opções corretas (tem precedência sobre vendor)
mkdir -p /etc/systemd/system
cat >/etc/systemd/system/tmp.mount <<'EOF'
[Unit]
Description=Temporary Directory (/tmp) hardened
Documentation=man:hier(7) man:tmpfs(5)
DefaultDependencies=no
Conflicts=umount.target
Before=local-fs.target umount.target

[Mount]
What=tmpfs
Where=/tmp
Type=tmpfs
Options=rw,nosuid,nodev,noexec,relatime,mode=1777

[Install]
WantedBy=local-fs.target
EOF
echo "[INFO] /etc/systemd/system/tmp.mount escrito (noexec,nodev,nosuid)"

# 5) Aplicar: desmonta qualquer montagem existente, recarrega units e remonta corretamente
systemctl daemon-reload

# Desmonta montagens antigas (podem existir múltiplas)
umount -R /var/tmp 2>/dev/null || true
umount -R /tmp 2>/dev/null || true

# Sobe /tmp via unit (com as opções corretas) e depois aplica fstab (bind /var/tmp)
systemctl enable --now tmp.mount
mount -a

echo "[INFO] Montagens atuais:"
mount | grep -E '/tmp|/var/tmp' || true

echo "[OK] setup_tmpfiles concluído"
exit 0
