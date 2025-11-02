#!/bin/bash
set -euo pipefail
LOG="/var/log/setup_tmpfiles.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] Harden mounts: /tmp, /var/tmp, /dev/shm, /home"

FSTAB="/etc/fstab"

ensure_tmpfs() {
  local path="$1" opts="$2"
  umount -R "$path" 2>/dev/null || true
  sed -i "\|[[:space:]]$path[[:space:]]|d" "$FSTAB"
  echo "tmpfs $path tmpfs $opts 0 0" >> "$FSTAB"
  mkdir -p "$path"
  mount "$path"
}

harden_disk_mount() {
  local path="$1" addopts="$2"
  # Ajusta linha existente no fstab para incluir opções de segurança
  if grep -qE "[[:space:]]$path[[:space:]]" "$FSTAB"; then
    awk -v p="$path" -v add="$addopts" '
      $2==p {
        # Coluna 4 = opções
        split($0,f," ")
        # se opções são "defaults" ou similares, acrescenta flags
        sub(/defaults/,"defaults," add,$4)
        # se já tiver opções, só garante que addopts estão presentes
        if ($4 !~ add) $4=$4","add
        print $1" "$2" "$3" "$4" "$5" "$6
        next
      }
      {print}
    ' OFS=" " "$FSTAB" > "${FSTAB}.tmp" && mv "${FSTAB}.tmp" "$FSTAB"
    mount -o remount,"$addopts" "$path" || true
  else
    echo "[WARN] $path não encontrado no fstab; mantendo como está."
  fi
}

# /tmp -> tmpfs
ensure_tmpfs "/tmp" "rw,nosuid,nodev,noexec,mode=1777"

# /var/tmp -> **disco**, apenas endurece flags
harden_disk_mount "/var/tmp" "nosuid,nodev,noexec,mode=1777"

# /dev/shm -> tmpfs
ensure_tmpfs "/dev/shm" "rw,nosuid,nodev,noexec,mode=1777"

# /home -> reforça flags
if grep -qE "[[:space:]]/home[[:space:]]" "$FSTAB"; then
  harden_disk_mount "/home" "nosuid,nodev"
fi

echo "[OK] Harden mounts concluído."