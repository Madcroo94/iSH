#!/bin/sh
# Phone lab control: sh /root/lab/bin/lab.sh start|stop|status|restart
LAB="${LAB:-$(cd "$(dirname "$0")/.." && pwd)}"
export LAB
. "$LAB/etc/node.conf"
LOG="$LAB/logs/lab.log"; mkdir -p "$LAB/logs" "$LAB/www"
running() { ps 2>/dev/null | grep -v grep | grep -Eq -- "$1"; }
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

if command -v busybox-extras >/dev/null 2>&1; then HTTPD="busybox-extras httpd"
else HTTPD="httpd"; fi

start() {
  running 'sshd:|/usr/sbin/sshd' || { /usr/sbin/sshd && log "started sshd"; }
  if [ -e /dev/location ] && ! running 'cat /dev/location'; then
    nohup cat /dev/location >/dev/null 2>&1 &
    log "started keep-alive"
  fi
  sh "$LAB/bin/health.sh" >/dev/null 2>&1
  running "httpd -p $HTTP_PORT" || { $HTTPD -p "$HTTP_PORT" -h "$LAB/www" && log "started httpd :$HTTP_PORT"; }
  if ! running "$LAB/bin/loop.sh"; then
    nohup sh "$LAB/bin/loop.sh" >/dev/null 2>&1 &
    log "started health loop"
  fi
}

stop() {
  # Never touches sshd or the keep-alive: stopping those would cut off remote access.
  for p in $(ps 2>/dev/null | grep -v grep | grep -e "httpd -p $HTTP_PORT" -e "$LAB/bin/loop.sh" | awk '{print $1}'); do
    kill "$p" 2>/dev/null
  done
  log "stopped httpd and health loop"
}

status() {
  for name in 'sshd:|/usr/sbin/sshd' "httpd -p $HTTP_PORT" 'cat /dev/location' "$LAB/bin/loop.sh"; do
    label="$(echo "$name" | sed 's/|.*//')"
    if running "$name"; then echo "up    $label"; else echo "down  $label"; fi
  done
  [ -f "$LAB/www/status.json" ] && cat "$LAB/www/status.json"
  return 0
}

case "$1" in
  start) start; status ;;
  stop) stop ;;
  restart) stop; sleep 1; start; status ;;
  status|"") status ;;
  *) echo "usage: lab.sh start|stop|status|restart"; exit 1 ;;
esac
