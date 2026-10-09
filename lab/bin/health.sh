#!/bin/sh
# Collects node health, writes www/status.json and www/index.html. Must stay fast on iSH.
LAB="${LAB:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$LAB/etc/node.conf"
WWW="$LAB/www"; mkdir -p "$WWW" "$LAB/logs"

# iSH's ps truncates names (sshd shows as "sshd: /usr/s d"), so match on args, not pgrep -x.
running() { ps 2>/dev/null | grep -v grep | grep -Eq -- "$1"; }
yn() { if "$@"; then echo up; else echo down; fi; }

now="$(date '+%Y-%m-%d %H:%M:%S')"
sshd="$(yn running 'sshd:|/usr/sbin/sshd')"
httpd="$(yn running "httpd -p $HTTP_PORT")"
keepalive="$(yn running 'cat /dev/location')"
uptime_s="$(cut -d. -f1 /proc/uptime 2>/dev/null)"; uptime_s="${uptime_s:-0}"
load="$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)"; load="${load:-?}"
mem_free_kb="$(awk '/MemAvailable|MemFree/ {print $2; exit}' /proc/meminfo 2>/dev/null)"
disk="$(df -h / 2>/dev/null | awk 'NR==2 {print $4 " free of " $2}')"

overall=ok
[ "$sshd" = up ] || overall=degraded
[ "$keepalive" = up ] || overall=degraded

cat > "$WWW/status.json.tmp" <<JSON
{"node":"$NODE_NAME","role":"$NODE_ROLE","time":"$now","overall":"$overall",
 "sshd":"$sshd","httpd":"$httpd","keepalive":"$keepalive",
 "uptime_s":$uptime_s,"load":"$load","mem_free_kb":"${mem_free_kb:-?}","disk":"$disk"}
JSON
mv "$WWW/status.json.tmp" "$WWW/status.json"

cat > "$WWW/index.html.tmp" <<HTML
<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width">
<meta http-equiv=refresh content=60><title>$NODE_NAME</title>
<style>body{font:16px system-ui;margin:2em;background:#111;color:#eee}td{padding:.2em 1em}
.up,.ok{color:#5d5}.down,.degraded{color:#e55}</style>
<h1>$NODE_NAME <small>($NODE_ROLE)</small></h1>
<p class=$overall>Overall: $overall &middot; $now</p>
<table>
<tr><td>sshd :$SSH_PORT<td class=$sshd>$sshd
<tr><td>httpd :$HTTP_PORT<td class=$httpd>$httpd
<tr><td>keep-alive<td class=$keepalive>$keepalive
<tr><td>uptime<td>${uptime_s}s
<tr><td>load<td>$load
<tr><td>mem free<td>${mem_free_kb:-?} kB
<tr><td>disk<td>$disk
</table><p><a href=status.json>status.json</a></p>
HTML
mv "$WWW/index.html.tmp" "$WWW/index.html"

echo "$now $overall sshd=$sshd httpd=$httpd keepalive=$keepalive" >> "$LAB/logs/health.log"
# keep the log small
tail -n 500 "$LAB/logs/health.log" > "$LAB/logs/health.log.tmp" && mv "$LAB/logs/health.log.tmp" "$LAB/logs/health.log"
echo "$overall"
