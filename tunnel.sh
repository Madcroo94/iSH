#!/bin/sh
# Reverse tunnel fallback: lets the laptop reach iSH even when the network blocks it.
# Run on iSH after setup-ssh.sh:   sh tunnel.sh you@laptop-ip
# Then on the laptop:             ssh -p 2222 root@localhost

[ -n "$1" ] || { echo "Usage: sh tunnel.sh you@laptop-ip [port]"; exit 1; }
PORT="${2:-${PORT:-2222}}"

pgrep -x sshd >/dev/null 2>&1 || /usr/sbin/sshd

echo "Opening tunnel to $1. Leave this running."
echo "On the laptop run:  ssh -p $PORT root@localhost"
while true; do
  ssh -N \
    -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes \
    -R "$PORT:localhost:$PORT" "$1"
  echo "Tunnel dropped, reconnecting in 5s (Ctrl+C to stop)..."
  sleep 5
done
