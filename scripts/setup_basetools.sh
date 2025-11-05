#!/bin/bash
set -euo pipefail

LOG="/var/log/setup_basetools.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo "[INFO] setup_basetools: iniciando"
echo "=============================================="

export DEBIAN_FRONTEND=noninteractive

# -------------------------------
# 1) Detectar o usuário padrão (sem debconf)
# -------------------------------
detect_user() {
  local u
  u="$(awk -F: '$3>=1000 && $1!="nobody"{print $1;exit}' /etc/passwd || true)"

  # Garantia absoluta
  [[ -z "$u" ]] && u="root"

  echo "$u"
}

DEFAULT_USER="$(detect_user)"
USER_HOME="$(getent passwd "$DEFAULT_USER" | cut -d: -f6)"

echo "[INFO] Usuário detectado: $DEFAULT_USER ($USER_HOME)"

# -------------------------------
# 2) Pacotes essenciais
# -------------------------------
apt-get update -qq
apt-get install -y \
  bash-completion \
  vim \
  eza \
  atop btop bmon iotop \
  bat fzf grc \
  sysstat hwinfo ncdu \
  jq unzip \
  curl wget ca-certificates \
  iproute2 net-tools lsof \
  fastfetch

# -------------------------------
# 3) Vim — sistema + usuário
# -------------------------------
get_vimrc_content() {
  cat <<'EOF'
syntax on
set encoding=utf8 showmatch
set tabstop=4 shiftwidth=4 softtabstop=4
set autoindent smartindent smarttab expandtab
set number relativenumber cursorline history=5000
set foldmethod=syntax foldlevel=99
nnoremap <space> za
EOF
}

mkdir -p /etc/vim
get_vimrc_content >/etc/vim/vimrc.local

mkdir -p "$USER_HOME/.vim/tmp" "$USER_HOME/.vim/undo"
get_vimrc_content >"$USER_HOME/.vimrc"
chown -R "$DEFAULT_USER:$DEFAULT_USER" "$USER_HOME/.vim" "$USER_HOME/.vimrc"

# -------------------------------
# 4) Bash — somente shell interativa
# -------------------------------
BASHRC_GLOBAL="/etc/bash.bashrc"
BLOCK_TAG="# ==== INTERACTIVE BLOCK ===="

if ! grep -q "$BLOCK_TAG" "$BASHRC_GLOBAL" 2>/dev/null; then
  cat >>"$BASHRC_GLOBAL" <<EOF

$BLOCK_TAG
case \$- in
  *i*)
    export EZA_BASE_OPTS="--group-directories-first --header --time-style=relative"
    ICON_STYLE="--icons=always"

    alias ls="eza \$ICON_STYLE \$EZA_BASE_OPTS"
    alias ll="eza -lh --git \$ICON_STYLE \$EZA_BASE_OPTS"
    alias la="eza -a \$ICON_STYLE \$EZA_BASE_OPTS"
    alias lt="eza -l --sort=modified --reverse \$ICON_STYLE \$EZA_BASE_OPTS"
    alias lS="eza -lS --reverse \$ICON_STYLE \$EZA_BASE_OPTS"
    alias ltree="eza -T \$ICON_STYLE \$EZA_BASE_OPTS"

    alias grep='grep --color=auto'
    alias diff='diff --color=auto'
    alias ip='ip -c'

    command -v batcat >/dev/null && alias cat='batcat'
    command -v fdfind >/dev/null && alias fd='fdfind'

    if command -v grc >/dev/null 2>&1; then
      alias journalctl='grc journalctl'
      alias tail='grc tail'
      alias head='grc head'
      alias ping='grc ping'
      alias ps='grc ps'
      alias dig='grc dig'
      alias ss='grc ss'
    fi

    PS1='\\u@\\h:\\w\\$ '
    export PS1
  ;;
esac
# ==== INTERACTIVE BLOCK (END) ====
EOF
fi

# -------------------------------
# 5) Fastfetch (login interativo)
# -------------------------------
if [[ ! -f "$USER_HOME/.bash_profile" ]] || ! grep -q "fastfetch" "$USER_HOME/.bash_profile"; then
  cat >>"$USER_HOME/.bash_profile" <<'EOF'
if [[ $- == *i* ]]; then
  command -v fastfetch >/dev/null 2>&1 && fastfetch
fi
EOF
  chown "$DEFAULT_USER:$DEFAULT_USER" "$USER_HOME/.bash_profile"
fi

echo "=============================================="
echo "[OK] setup_basetools concluído com SUCESSO ✅"
echo "Logs: $LOG"
echo "=============================================="
exit 0
