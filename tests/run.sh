#!/bin/sh
# Offline tests for the lab scripts. Runs anywhere with a POSIX sh; no phone needed.
#   sh tests/run.sh
REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   $1"; }
bad()  { fail=$((fail+1)); echo "FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

for f in "$REPO"/*.sh "$REPO"/lab/bin/*.sh "$REPO"/tests/*.sh; do
  check "syntax $(basename "$f")" "sh -n '$f'"
done

# Fake ps: prints whatever is in $T/ps.out, the way iSH truncates sshd.
mkdir -p "$T/stub"
printf '#!/bin/sh\ncat "%s/ps.out"\n' "$T" > "$T/stub/ps"; chmod +x "$T/stub/ps"
PATH="$T/stub:$PATH"; export PATH

DEST="$T/root/lab"; PROFILE="$T/root/.profile"
mkdir -p "$T/root"; printf 'echo hi\n# >>> ish-lab sshd >>>\nx\n# <<< ish-lab sshd <<<\n' > "$PROFILE"
: > "$T/ps.out"

# Install
DEST="$DEST" PROFILE="$PROFILE" SKIP_APK=1 NO_START=1 NODE_NAME=phone2 NODE_ROLE=worker \
  sh "$REPO/install-lab.sh" >/dev/null 2>&1
check "install exits 0" "[ \$? -eq 0 ]"
check "scripts installed" "[ -x '$DEST/bin/lab.sh' ] && [ -x '$DEST/bin/health.sh' ] && [ -x '$DEST/bin/loop.sh' ]"
check "node.conf from env" "grep -q '^NODE_NAME=phone2$' '$DEST/etc/node.conf' && grep -q '^HTTP_PORT=8080$' '$DEST/etc/node.conf'"
check "profile block added" "[ \$(grep -c '>>> phone-lab >>>' '$PROFILE') -eq 1 ]"

# Re-run keeps node.conf, strips CRLF, doesn't duplicate the profile block
echo 'NODE_NAME=custom' >> "$DEST/etc/node.conf"
printf '#!/bin/sh\r\necho crlf\r\n' > "$DEST/bin/extra.sh"
DEST="$DEST" PROFILE="$PROFILE" SKIP_APK=1 NO_START=1 sh "$REPO/install-lab.sh" >/dev/null 2>&1
check "re-run keeps node.conf" "grep -q '^NODE_NAME=custom$' '$DEST/etc/node.conf'"
check "re-run strips CRLF" "! grep -q \"\$(printf '\r')\" '$DEST/bin/extra.sh'"
check "re-run no duplicate block" "[ \$(grep -c '>>> phone-lab >>>' '$PROFILE') -eq 1 ]"

# health.sh with everything down
out="$(sh "$DEST/bin/health.sh")"
check "health degraded when sshd down" "[ '$out' = degraded ]"
check "status.json valid JSON" "python3 -c 'import json,sys; json.load(open(sys.argv[1]))' '$DEST/www/status.json' 2>/dev/null || ! command -v python3 >/dev/null"
check "index.html written" "grep -q '<h1>custom' '$DEST/www/index.html'"

# health.sh with iSH-style truncated sshd, keep-alive, httpd up
cat > "$T/ps.out" <<PS
PID   USER     TIME  COMMAND
  101 root      0:00 sshd: /usr/s d
  102 root      0:00 cat /dev/location
  103 root      0:00 busybox-extras httpd -p 8080 -h $DEST/www
  104 root      0:00 sh $DEST/bin/loop.sh
PS
out="$(sh "$DEST/bin/health.sh")"
check "health ok with truncated sshd" "[ '$out' = ok ]"
check "status.json fields" "python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d[\"overall\"]==\"ok\" and d[\"httpd\"]==\"up\" and d[\"node\"]==\"custom\"' '$DEST/www/status.json' 2>/dev/null || ! command -v python3 >/dev/null"
check "health log written" "grep -q ' ok sshd=up' '$DEST/logs/health.log'"

st="$(sh "$DEST/bin/lab.sh" status)"
check "lab.sh status all up" "[ \$(echo \"\$st\" | grep -c '^up ') -eq 4 ]"
check "lab.sh status label" "echo \"\$st\" | grep -q '^up    sshd:$'"
check "lab.sh bad arg fails" "! sh '$DEST/bin/lab.sh' bogus >/dev/null"

# Uninstall: removes lab and only our profile block
: > "$T/ps.out"
DEST="$DEST" PROFILE="$PROFILE" sh "$REPO/install-lab.sh" uninstall >/dev/null 2>&1
check "uninstall removes lab" "[ ! -e '$DEST' ]"
check "uninstall removes block" "! grep -q 'phone-lab' '$PROFILE'"
check "uninstall keeps sshd block" "grep -q '>>> ish-lab sshd >>>' '$PROFILE' && grep -q '^echo hi$' '$PROFILE'"

echo; echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
