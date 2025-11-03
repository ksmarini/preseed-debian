#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_basetools.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] setup_basetools: iniciado"

# Detecta automaticamente o usuário comum
USUARIO="$(awk -F: '$3>=1000 && $1!~/^(nobody|systemd-|_)/ {print $1; exit}' /etc/passwd)"

if [ -z "$USUARIO" ]; then
  echo "[ERRO] Nenhum usuário comum detectado!"
  exit 1
fi

HOME_USER="$(getent passwd "$USUARIO" | cut -d: -f6)"

echo "[INFO] Usuário comum detectado: $USUARIO (home: $HOME_USER)"
mkdir -p "$HOME_USER"
chown "$USUARIO:$USUARIO" "$HOME_USER"

log_step() { echo -e "\n--- $1 ---"; }

# ======================
log_step "Instalando utilitários essenciais"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  fastfetch tmux grc bat eza ripgrep silversearcher-ag fd-find >/dev/null

command -v batcat >/dev/null && ln -sf /usr/bin/batcat /usr/local/bin/bat
command -v fdfind >/dev/null && ln -sf /usr/bin/fdfind /usr/local/bin/fd

# ======================
log_step "Fastfetch apenas para usuários comuns"
cat >/etc/profile.d/fastfetch.sh <<'EOF'
case $- in
  *i*)
    if [ "$EUID" -ne 0 ] && command -v fastfetch >/dev/null; then
      fastfetch
    fi
  ;;
esac
EOF
chmod 0644 /etc/profile.d/fastfetch.sh

# ======================
log_step "Configurando Vim globalmente"
cat >/etc/vim/vimrc.local <<"EOF"
syntax on
set background=dark
set number relativenumber cursorline foldmethod=syntax foldlevel=99
nnoremap <space> za
EOF

# ======================
log_step "Config fastfetch do usuário"
mkdir -p "$HOME_USER/.config/fastfetch"
cat >"$HOME_USER/.config/fastfetch/config.jsonc" <<"EOF"
{
  "logo": "debian",
  "modules": [
    "title", "separator",
    "os", "host", "kernel", "packages",
    "cpu", "memory", "uptime", "disk",
    "localip"
  ]
}
EOF
chown -R "$USUARIO:$USUARIO" "$HOME_USER/.config/fastfetch"

# ======================
log_step "Aliases globais para todos os usuários"
cat >/etc/profile.d/aliases_pmro.sh <<"EOF"
alias ls='eza --icons=always'
alias ll='eza -lh --git --icons=always'
alias la='eza -a --icons=always'
alias tail='grc tail'
alias ping='grc ping'
alias ps='grc ps'
alias dig='grc dig'
alias ss='grc ss'
alias journalctl='grc journalctl'
EOF
chmod 0644 /etc/profile.d/aliases_pmro.sh

# ======================
log_step "PS1 root com detecção de cor (sem fastfetch)"
cat >/etc/profile.d/pmro_root_ps1.sh <<"EOF"
if [ "$EUID" -eq 0 ]; then
  RED="\[\e[1;31m\]"
  NC="\[\e[0m\]"
  PS1="${RED}┌─[\u@\h]─[\w]\n└─> # ${NC}"
fi
EOF
chmod 0644 /etc/profile.d/pmro_root_ps1.sh

echo "[OK] setup_basetools concluído com sucesso!"
exit 0

