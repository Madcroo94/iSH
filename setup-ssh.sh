#!/bin/sh
# One-shot SSH server setup for iSH (Alpine Linux on iOS).
# Safe to re-run. Usage:  sh setup-ssh.sh
# Optional env vars:
#   PORT=2222              port sshd listens on
#   PUBKEY="ssh-ed25519 ..."  public key to allow (skips the need for a password)
#   SKIP_PASSWORD=1        don't prompt for a root password

set -e

PORT="${PORT:-2222}"
CONF=/etc/ssh/sshd_config
PROFILE=/root/.profile
MARK_BEGIN="# >>> ish-lab sshd >>>"
MARK_END="# <<< ish-lab sshd <<<"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*"; exit 1; }

[ "$(id -u)" = "0" ] || die "Run this as root (the default user in iSH)."
command -v apk >/dev/null 2>&1 || die "apk not found. This script is for iSH / Alpine."

# 1. Install OpenSSH
if ! command -v /usr/sbin/sshd >/dev/null 2>&1; then
  say "Installing OpenSSH (this can take a minute on iSH)..."
  apk update
  apk add openssh
else
  say "OpenSSH already installed."
fi

# 2. Host keys
say "Generating host keys (only missing ones)..."
ssh-keygen -A

# 3. Config
if [ -f "$CONF" ] && [ ! -f "$CONF.orig" ]; then
  cp "$CONF" "$CONF.orig"
  say "Backed up original config to $CONF.orig"
fi
say "Writing $CONF (port $PORT)..."
cat > "$CONF" <<EOF
# Written by ish-lab setup-ssh.sh. Original is at $CONF.orig
Port $PORT
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
UseDNS no
PrintMotd no
Subsystem sftp internal-sftp
EOF

# 4. Public key (optional)
if [ -n "$PUBKEY" ]; then
  mkdir -p /root/.ssh
  touch /root/.ssh/authorized_keys
  if ! grep -qF "$PUBKEY" /root/.ssh/authorized_keys; then
    printf '%s\n' "$PUBKEY" >> /root/.ssh/authorized_keys
    say "Added your public key."
  fi
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/authorized_keys
fi

# 5. Root password
root_hash="$(grep '^root:' /etc/shadow 2>/dev/null | cut -d: -f2)"
case "$root_hash" in
  ""|"*"|"!"|"!!"|"!*") has_pw=0 ;;
  *) has_pw=1 ;;
esac
if [ "$has_pw" = "0" ] && [ -z "$SKIP_PASSWORD" ]; then
  say "Set a root password. You'll type this when you SSH in."
  passwd root
elif [ "$has_pw" = "1" ]; then
  say "Root password already set (run 'passwd' to change it)."
fi

# 6. Start sshd
say "Checking config..."
/usr/sbin/sshd -t || die "sshd config test failed (see error above)."
if pgrep -x sshd >/dev/null 2>&1; then
  say "Restarting sshd..."
  pkill -x sshd || true
  sleep 1
else
  say "Starting sshd..."
fi
/usr/sbin/sshd || die "sshd failed to start. Run '/usr/sbin/sshd -D -e' to see why."
sleep 1
pgrep -x sshd >/dev/null 2>&1 || die "sshd exited right away. Run '/usr/sbin/sshd -D -e' to see why."

# 7. Keep iSH alive in the background (needs Location permission for iSH)
if [ -e /dev/location ]; then
  if ! pgrep -f "cat /dev/location" >/dev/null 2>&1; then
    say "Starting background keep-alive (iOS will ask for Location access: choose Always)."
    nohup cat /dev/location > /dev/null 2>&1 &
  fi
else
  warn "/dev/location not found; keep the iSH app open so iOS doesn't pause it."
fi

# 8. Auto-start every time iSH opens
if ! grep -qF "$MARK_BEGIN" "$PROFILE" 2>/dev/null; then
  say "Adding auto-start to $PROFILE..."
  cat >> "$PROFILE" <<'EOF'
# >>> ish-lab sshd >>>
pgrep -x sshd >/dev/null 2>&1 || /usr/sbin/sshd
[ -e /dev/location ] && { pgrep -f "cat /dev/location" >/dev/null 2>&1 || (nohup cat /dev/location >/dev/null 2>&1 &); }
# <<< ish-lab sshd <<<
EOF
fi

# 9. Show how to connect
ip_addr=""
if command -v ip >/dev/null 2>&1; then
  ip_addr="$(ip -4 addr 2>/dev/null | awk '/inet / && $2 !~ /^127\./ {sub(/\/.*/, "", $2); print $2; exit}')"
fi
if [ -z "$ip_addr" ] && command -v ifconfig >/dev/null 2>&1; then
  ip_addr="$(ifconfig 2>/dev/null | awk '/inet / {for(i=1;i<=NF;i++) if($i ~ /^(addr:)?[0-9]+\./){a=$i; sub(/addr:/,"",a); if(a !~ /^127\./){print a; exit}}}')"
fi

echo
say "Done. sshd is running on port $PORT."
if [ -n "$ip_addr" ]; then
  echo "    From your laptop:  ssh -p $PORT root@$ip_addr"
else
  echo "    Find your phone's IP: Settings > Wi-Fi > (i) next to your network."
  echo "    From your laptop:  ssh -p $PORT root@<phone-ip>"
fi
echo
echo "    If it times out: same Wi-Fi (not guest), Settings > Privacy & Security >"
echo "    Local Network > iSH on, and keep iSH open. Still stuck? sh tunnel.sh you@laptop-ip"
