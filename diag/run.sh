#!/usr/bin/env bash
# Diagnostic run for stremio-bugs#2815: start the Linux shell Flatpak against a local web build.
# Usage: diag/run.sh <site-dir> <label>
set -u
SITE=$1
LABEL=$2
OUT=out/$LABEL
mkdir -p "$OUT"
cp diag/hook.js "$SITE/diag-hook.js"
sed -i 's#</body>#<script src="/diag-hook.js"></script></body>#' "$SITE/index.html"
grep -c 'diag-hook.js' "$SITE/index.html" > "$OUT/hook-injected.txt"

node diag/server.mjs "$SITE" 18080 "$OUT/steps.log" &
SERVER=$!
sleep 2

sudo dmesg --clear || true
START=$(date +%s)
# The shell's startup URL is the local web build; software rendering under Xvfb.
timeout --preserve-status -s TERM 170 dbus-run-session -- xvfb-run -a -s "-screen 0 1920x1080x24" \
    flatpak run --user --env=WEBKIT_DISABLE_DMABUF_RENDERER=1 --env=RUST_LOG=info \
    com.stremio.Stremio.Devel --url http://127.0.0.1:18080/ > "$OUT/shell.stdout" 2> "$OUT/shell.stderr"
STATUS=$?
END=$(date +%s)
kill $SERVER 2>/dev/null

sudo dmesg | grep -iE 'segfault|trap|general protection|webkit' > "$OUT/dmesg.txt" || true
CLICKS=$(grep -c ' CLICK ' "$OUT/steps.log" 2>/dev/null || echo 0)
DETAILS=$(grep -c 'hash=#/detail/' "$OUT/steps.log" 2>/dev/null || echo 0)
DONE=$(grep -c 'DONE clicks=' "$OUT/steps.log" 2>/dev/null || echo 0)
{
    echo "label=$LABEL"
    echo "exit_status=$STATUS (143 = killed by our timeout after 170 s, i.e. still alive; 139 = SIGSEGV)"
    echo "runtime_seconds=$((END - START))"
    echo "clicks=$CLICKS details_seen=$DETAILS done=$DONE"
    echo "dmesg:"; cat "$OUT/dmesg.txt"
    echo "last steps:"; tail -5 "$OUT/steps.log" 2>/dev/null
} | tee "$OUT/summary.txt"
