#!/bin/sh
# Reruns health.sh every 60 s. Started by lab.sh.
LAB="${LAB:-$(cd "$(dirname "$0")/.." && pwd)}"
while true; do
  LAB="$LAB" sh "$LAB/bin/health.sh" >/dev/null 2>&1
  sleep "${HEALTH_INTERVAL:-60}"
done
