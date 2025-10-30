#!/bin/bash
set -euo pipefail
LOG="/var/log/pam_hardening.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] PAM hardening: iniciando..."

[ -f /etc/security_env.conf ] && . /etc/security_env.conf || true
PW_MINLEN="${PW_MINLEN:-12}"
PW_MINCLASS="${PW_MINCLASS:-3}"
PW_REMEMBER="${PW_REMEMBER:-5}"
FAILLOCK_DENY="${FAILLOCK_DENY:-5}"
FAILLOCK_UNLOCK_TIME="${FAILLOCK_UNLOCK_TIME:-900}"

PWQ="/etc/security/pwquality.conf"
COMMON_PASS="/etc/pam.d/common-password"
COMMON_AUTH="/etc/pam.d/common-auth"
COMMON_ACCOUNT="/etc/pam.d/common-account"

mkdir -p /etc/security
cat >"$PWQ" <<EOF
minlen = $PW_MINLEN
minclass = $PW_MINCLASS
dictcheck = 1
EOF

if ! grep -q "pam_pwhistory.so" "$COMMON_PASS"; then
  sed -i '/^password.*pam_unix.so/ s/$/ remember='"$PW_REMEMBER"'/' "$COMMON_PASS" || true
  echo "password  required  pam_pwhistory.so use_authtok remember=$PW_REMEMBER" >>"$COMMON_PASS"
fi

sed -i '/pam_faillock\.so/d' "$COMMON_AUTH" || true
sed -i '/pam_faillock\.so/d' "$COMMON_ACCOUNT" || true
grep -q "pam_faillock.so preauth" "$COMMON_AUTH" ||
  sed -i "/pam_unix.so/i auth required pam_faillock.so preauth silent deny=${FAILLOCK_DENY} unlock_time=${FAILLOCK_UNLOCK_TIME}" "$COMMON_AUTH"
grep -q "pam_faillock.so authfail" "$COMMON_AUTH" ||
  sed -i "/pam_unix.so/a auth [default=die] pam_faillock.so authfail deny=${FAILLOCK_DENY} unlock_time=${FAILLOCK_UNLOCK_TIME}" "$COMMON_AUTH"
grep -q "pam_faillock.so" "$COMMON_ACCOUNT" || echo "account required pam_faillock.so" >>"$COMMON_ACCOUNT"

echo "[OK] PAM hardening aplicado."
