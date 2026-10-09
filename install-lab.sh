#!/bin/sh
# Installs the phone lab (status page + health checks) into /root/lab. Run in iSH after setup-ssh.sh.
# Safe to re-run: scripts are updated, your node.conf is kept.
#   sh install-lab.sh             install or update, then start
#   sh install-lab.sh uninstall   stop and remove the lab (SSH is left alone)
# Optional env vars (used only when node.conf doesn't exist yet):
#   NODE_NAME=phone1  NODE_ROLE=base  NODE_IP=10.0.0.250  SSH_PORT=2222  HTTP_PORT=8080

set -e

SRC="$(cd "$(dirname "$0")" && pwd)/lab"
DEST="${DEST:-/root/lab}"
PROFILE="${PROFILE:-/root/.profile}"
MARK_BEGIN="# >>> phone-lab >>>"
MARK_END="# <<< phone-lab <<<"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*"; exit 1; }

remove_profile_block() {
  [ -f "$PROFILE" ] || return 0
  sed -i "/$MARK_BEGIN/,/$MARK_END/d" "$PROFILE"
}

if [ "$1" = "uninstall" ]; then
  [ -f "$DEST/bin/lab.sh" ] || die "No lab found at $DEST."
  sh "$DEST/bin/lab.sh" stop || true
  remove_profile_block
  rm -rf "$DEST"
  say "Lab removed. SSH and the keep-alive are untouched."
  exit 0
fi
[ -z "$1" ] || die "Usage: sh install-lab.sh [uninstall]"

[ -d "$SRC/bin" ] || die "Can't find $SRC. Run this from the cloned repo folder."
if [ -z "$SKIP_APK" ]; then
  [ "$(id -u)" = "0" ] || die "Run this as root (the default user in iSH)."
  command -v apk >/dev/null 2>&1 || die "apk not found. This script is for iSH / Alpine."
  if ! command -v busybox-extras >/dev/null 2>&1 && ! command -v httpd >/dev/null 2>&1; then
    say "Installing busybox-extras for the web server (slow on iSH, be patient)..."
    apk add busybox-extras
  fi
fi

# 1. Files. Scripts are always replaced; node.conf is only written once.
say "Installing lab into $DEST..."
mkdir -p "$DEST/bin" "$DEST/etc" "$DEST/www" "$DEST/logs" "$DEST/nodes"
cp "$SRC"/bin/*.sh "$DEST/bin/"
if [ ! -f "$DEST/etc/node.conf" ]; then
  cat > "$DEST/etc/node.conf" <<CONF
NODE_NAME=${NODE_NAME:-phone1}
NODE_ROLE=${NODE_ROLE:-base}
NODE_IP=${NODE_IP:-}
SSH_PORT=${SSH_PORT:-2222}
HTTP_PORT=${HTTP_PORT:-8080}
CONF
  say "Wrote $DEST/etc/node.conf (edit it to rename this node)."
else
  say "Kept existing $DEST/etc/node.conf."
fi
# Files copied over from Windows break with CRLF endings ("not found" errors).
sed -i 's/\r$//' "$DEST"/bin/*.sh "$DEST/etc/node.conf"
chmod +x "$DEST"/bin/*.sh

# 2. Auto-start every time iSH opens. Leaves the ish-lab sshd block alone.
if ! grep -qF "$MARK_BEGIN" "$PROFILE" 2>/dev/null; then
  say "Adding auto-start to $PROFILE..."
  printf '%s\n' "$MARK_BEGIN" "sh $DEST/bin/lab.sh start >/dev/null 2>&1" "$MARK_END" >> "$PROFILE"
fi

# 3. Start
. "$DEST/etc/node.conf"
if [ -z "$NO_START" ]; then
  say "Starting lab..."
  sh "$DEST/bin/lab.sh" start
fi

echo
say "Done. Status page on port $HTTP_PORT."
if [ -n "$NODE_IP" ]; then
  echo "    From your laptop:  http://$NODE_IP:$HTTP_PORT/"
else
  echo "    From your laptop:  http://<phone-ip>:$HTTP_PORT/   (IP: Settings > Wi-Fi > (i))"
fi
echo "    Control it:        sh $DEST/bin/lab.sh start|stop|status|restart"
