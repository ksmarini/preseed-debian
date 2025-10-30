#!/bin/bash
# setup_basetools.sh — Perfil, terminal e utilitários
set -euo pipefail

LOG="/var/log/setup_basetools.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] setup_basetools: iniciado"

# ===== Identifica usuário comum criado pelo preseed =====
USUARIO="$(awk -F: '$3>=1000 && $1!="nobody" {print $1; exit}' /etc/passwd)"
HOME_USER="$(getent passwd "$USUARIO" | cut -d: -f6)"

log_step() { echo -e "\n--- $1 ---"; }

append_if_not_exists() {
  local marker="$1" content="$2" file="$3" owner="$4"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -qF "$marker" "$file"; then
    {
      echo "$marker"
      echo "$content"
    } >>"$file"
    chown "$owner" "$file" 2>/dev/null || true
  fi
}

# ===== Instala utilitários =====
log_step "Instalando pacotes extras"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  fzf man-db atop sysstat hwinfo ncdu btop iotop nmap tcpdump whois \
  bind9-dnsutils traceroute bmon fastfetch tmux grc bat eza ripgrep \
  silversearcher-ag fd-find fonts-cascadia-code fonts-firacode \
  >/dev/null

command -v batcat >/dev/null && ln -sf /usr/bin/batcat /usr/local/bin/bat
command -v fdfind >/dev/null && ln -sf /usr/bin/fdfind /usr/local/bin/fd

# ===== VIM =====
log_step "Configurando Vim"
cat >/etc/vim/vimrc.local <<"EOF"
syntax on
set background=dark
set number relativenumber cursorline foldmethod=syntax foldlevel=99
nnoremap <space> za
EOF

# ===== Tema Fastfetch PMRO para usuário comum =====
log_step "Configurando Fastfetch"
mkdir -p "$HOME_USER/.config/fastfetch"
cat >"$HOME_USER/.config/fastfetch/config.jsonc" <<"EOF"
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "builtin",
    "source": "debian",
    "padding": {
      "top": 1,
      "right": 2
    },
    "color": "blue"
  },
  "modules": [
    "os",
    "kernel",
    "cpu",
    "gpu",
    "memory",
    "disk",
    "localIP",
    "uptime"
  ],
  "display": {
    "separator": "  ",
    "keyColor": "green",
    "valueColor": "yellow"
  }
}
EOF
chown -R "$USUARIO:$USUARIO" "$HOME_USER/.config/fastfetch"

# ===== PS1 especial somente para root =====
log_step "Aplicando PS1 do root"
cat >>/root/.bashrc <<"EOF"
# PMRO ROOT PROMPT
RED="\[\e[1;33m\]"
NC="\[\e[0m\]"
PS1="${RED}┌─[\u@PMRO]─[\w]\n└─> # ${NC}"
EOF

# ===== Aliases EZA + GRC =====
log_step "Adicionando aliases para user e root"

ALIASES="$(
  cat <<"EOF"
# EZA Aliases
alias ls='eza --icons=always'
alias ll='eza -lh --git --icons=always'
alias la='eza -a --icons=always'
alias lla='eza -lha --git --icons=always'
alias lt='eza -l --sort=modified --reverse --icons=always'
alias lS='eza -lS --reverse --icons=always'
alias ltree='eza -T --icons=always'
alias ltree3='eza -T --level=3 --icons=always'

# GRC
alias journalctl='grc journalctl'
alias tail='grc tail'
alias ping='grc ping'
alias ps='grc ps'
alias dig='grc dig'
alias nmap='grc nmap'
alias ss='grc ss'
EOF
)"

append_if_not_exists \
  "# ALIASES_PMRO" "$ALIASES" "$HOME_USER/.bashrc" "$USUARIO:$USUARIO"

append_if_not_exists \
  "# ALIASES_PMRO" "$ALIASES" "/root/.bashrc" "root:root"

echo "[OK] setup_basetools concluído com sucesso!"
