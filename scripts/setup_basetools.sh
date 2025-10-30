#!/bin/bash
# setup_basetools.sh — Pós-instalação: ferramentas e perfil de usuário
set -euo pipefail
LOG="/var/log/setup_basetools.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] setup_basetools: iniciando"

USUARIO="${USUARIO:-marini}"

if id -u "$USUARIO" >/dev/null 2>&1; then
  HOME_USER="$(getent passwd "$USUARIO" | cut -d: -f6)"
  CONFIGURE_USER=true
else
  HOME_USER="/home/${USUARIO}"
  CONFIGURE_USER=false
fi

log_step() { echo -e "\n--- $1 ---"; }

append_if_not_exists() {
  local marker="$1" content="$2" file="$3" owner="${4:-root:root}"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -qF "$marker" "$file"; then
    printf "\n%s\n%s\n" "$marker" "$content" >>"$file"
    chown "$owner" "$file"
  fi
}

get_vimrc_content() {
  cat <<'EOF'
syntax on
set encoding=utf8 showmatch ts=4 sts=4 sw=4 autoindent smartindent smarttab expandtab
set number relativenumber cursorline history=5000 foldmethod=syntax foldlevel=99
nnoremap <space> za
EOF
}

get_eza_and_aliases_config() {
  cat <<'EOF'
# =============================================================================
# EZA + ALIASES (apenas shell interativa)
# =============================================================================
# A flag de ícone ($ICON_STYLE) e as opções base ($EZA_BASE_OPTS) são adicionadas diretamente.
alias ls="eza $ICON_STYLE $EZA_BASE_OPTS"
alias ll="eza -lh --git $ICON_STYLE $EZA_BASE_OPTS"
alias la="eza -a $ICON_STYLE $EZA_BASE_OPTS"
alias lla="eza -lha --git $ICON_STYLE $EZA_BASE_OPTS"
alias lt="eza -l --sort=modified --reverse $ICON_STYLE $EZA_BASE_OPTS"
alias lS="eza -lS --reverse $ICON_STYLE $EZA_BASE_OPTS"
alias ltree="eza -T $ICON_STYLE $EZA_BASE_OPTS"
alias ltree3="eza -T --level=3 $ICON_STYLE $EZA_BASE_OPTS"
alias lsd="eza -lD $ICON_STYLE $EZA_BASE_OPTS"
alias lsr="eza -R $ICON_STYLE $EZA_BASE_OPTS"

# Aliases com filtros não precisam de todas as opções base (ex: --header).
readonly EZA_IGNORE_PATTERN="node_modules|dist|build|target|__pycache__|*.log|*.lock"
alias lsi="eza $ICON_STYLE -I '$EZA_IGNORE_PATTERN'"
alias lli="eza -lh --git $ICON_STYLE -I '$EZA_IGNORE_PATTERN'"
alias lsg='eza -lh --git-status=modified $ICON_STYLE'

# --- Outros aliases ---
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -c'
alias cat='batcat'
alias bat='batcat'
alias fd='fdfind'

# --- Aliases com GRC (Generic Colouriser) ---
alias journalctl='grc journalctl'
alias tail='grc tail'
alias ping='grc ping'
alias ps='grc ps'
alias dig='grc dig'
alias nmap='grc nmap'
alias ss='grc ss'
EOF
}

get_root_ps1() {
  cat <<'EOF'
readonly RED="\[\e[1;31m\]"; readonly NC="\[\e[0m\]"
PS1="${RED}┌─[\u@\h]─[\w]\n└─> # ${NC}"
EOF
}

get_user_profile_boot() {
  cat <<'EOF'
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi
if command -v fastfetch &>/dev/null; then fastfetch; fi
EOF
}

log_step "Instalando pacotes extras úteis (sem duplicar preseed)"
PACKAGES_TO_INSTALL=(
  fzf man-db atop sysstat hwinfo ncdu btop iotop nmap tcpdump whois
  bind9-dnsutils traceroute bmon fastfetch tmux grc bat eza ripgrep
  silversearcher-ag fd-find fonts-cascadia-code fonts-firacode
)
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES_TO_INSTALL[@]}"

command -v batcat >/dev/null && ln -sf /usr/bin/batcat /usr/local/bin/bat
command -v fdfind >/dev/null && ln -sf /usr/bin/fdfind /usr/local/bin/fd

log_step "Configurando Vim globalmente"
sed -i -e 's/"syntax on/syntax on/' -e 's/"set background=dark/set background=dark/' /etc/vim/vimrc || true

log_step "Aplicando perfil do root"
echo "$(get_vimrc_content)" >/root/.vimrc
ROOT_BASH_CFG="$(get_eza_and_aliases_config)
$(get_root_ps1)"
append_if_not_exists "# PERFIL_ROOT" "$ROOT_BASH_CFG" "/root/.bashrc"

if [ "$CONFIGURE_USER" = true ]; then
  log_step "Applying profile for user"
  echo "$(get_vimrc_content)" >"$HOME_USER/.vimrc"
  chown "$USUARIO:$USUARIO" "$HOME_USER/.vimrc"
  append_if_not_exists "# PERFIL_USUARIO" "$(get_eza_and_aliases_config)" "$HOME_USER/.bashrc" "$USUARIO:$USUARIO"
  append_if_not_exists "# CONFIGURAÇÕES_DE_PERFIL" "$(get_user_profile_boot)" "$HOME_USER/.bash_profile" "$USUARIO:$USUARIO"
fi

echo "[OK] setup_basetools concluído com sucesso!"
