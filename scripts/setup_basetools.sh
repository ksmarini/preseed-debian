#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_basetools.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] setup_basetools iniciado"

# Detecta usuário comum padrão criado na instalação
USUARIO="$(getent passwd | awk -F: '$3>=1000 && $3<60000 {print $1; exit}')"
HOME_USER="$(eval echo ~$USUARIO)"
echo "[INFO] Usuário alvo: $USUARIO (home: $HOME_USER)"

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================
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

# =============================================================================
# BLOCOS DE CONFIGURAÇÃO
# =============================================================================
get_vimrc() {
  cat <<'EOF'
syntax on
set encoding=utf8 showmatch ts=4 sts=4 sw=4 autoindent smartindent smarttab expandtab
set number relativenumber cursorline history=5000 foldmethod=syntax foldlevel=99
nnoremap <space> za
EOF
}

get_common_aliases() {
  cat <<'EOF'
# =============================================================================
# EZA + ALIASES (somente shell interativa)
# =============================================================================
case $- in
*i*)
  ICON_STYLE="--icons=always"
  EZA_BASE_OPTS="--group-directories-first --header --time-style=relative"

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

  readonly EZA_IGNORE="node_modules|dist|build|target|__pycache__|*.log|*.lock"
  alias lsi="eza $ICON_STYLE -I '$EZA_IGNORE'"
  alias lli="eza -lh --git $ICON_STYLE -I '$EZA_IGNORE'"
  alias lsg='eza -lh --git-status=modified $ICON_STYLE'

  alias journalctl='grc journalctl'
  alias tail='grc tail'
  alias ping='grc ping'
  alias ps='grc ps'
  alias dig='grc dig'
  alias nmap='grc nmap'
  alias ss='grc ss'
;;
esac
EOF
}

# Prompt root
get_root_ps1() {
  cat <<'EOF'
# PS1 especial root (alerta visual)
RED="\[\e[1;31m\]"
NC="\[\e[0m\]"
PS1="${RED}┌─[\u@\h]─[\w]\n└─> # ${NC}"
EOF
}

# Fastfetch apenas para usuário comum
get_fastfetch_user_cfg() {
  cat <<'EOF'
# Exec Fastfetch apenas em shells interativas
if [ -n "$PS1" ] && command -v fastfetch &>/dev/null; then
  fastfetch --config /etc/fastfetch/marini.json
fi
EOF
}

# =============================================================================
# INSTALAÇÃO DE PACOTES
# =============================================================================
log_step "Instalando ferramentas extras"
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  grc fzf fastfetch eza ripgrep fd-find bat tmux bmon \
  traceroute nmap ncdu btop iotop whois tcpdump
ln -sf /usr/bin/batcat /usr/local/bin/bat || true
ln -sf /usr/bin/fdfind /usr/local/bin/fd || true

# =============================================================================
# ROOT PROFILE
# =============================================================================
log_step "Aplicando perfil do root"
echo "$(get_vimrc)" >/root/.vimrc
append_if_not_exists "# ALIASES_COMUNS" "$(get_common_aliases)" "/root/.bashrc"
append_if_not_exists "# PS1_ROOT" "$(get_root_ps1)" "/root/.bashrc"

# =============================================================================
# USER PROFILE
# =============================================================================
if [ -n "$USUARIO" ] && id "$USUARIO" &>/dev/null; then
  log_step "Aplicando perfil do usuário $USUARIO"
  echo "$(get_vimrc)" >"$HOME_USER/.vimrc"
  chown "$USUARIO:$USUARIO" "$HOME_USER/.vimrc"

  append_if_not_exists "# ALIASES_COMUNS" "$(get_common_aliases)" "$HOME_USER/.bashrc" "$USUARIO:$USUARIO"
  append_if_not_exists "# FASTFETCH_USER" "$(get_fastfetch_user_cfg)" "$HOME_USER/.bashrc" "$USUARIO:$USUARIO"
else
  echo "[WARN] Usuário comum não encontrado!"
fi

echo "[OK] setup_basetools concluído com sucesso!"
