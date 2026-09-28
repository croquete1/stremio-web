#!/usr/bin/env bash
# Diagnostic run for stremio-bugs#2815: start the Linux shell against a local web build.
# Usage: diag/run.sh <site-dir> <label> <flatpak|native>
set -u
SITE=$1
LABEL=$2
MODE=${3:-flatpak}
OUT=out/$LABEL
mkdir -p "$OUT"
cp diag/hook.js "$SITE/diag-hook.js"
grep -q diag-hook.js "$SITE/index.html" || sed -i 's#</body>#<script src="/diag-hook.js"></script></body>#' "$SITE/index.html"
grep -c 'diag-hook.js' "$SITE/index.html" > "$OUT/hook-injected.txt"

if [ "$MODE" = flatpak ]; then
    flatpak run --user --env=WEBKIT_DISABLE_DMABUF_RENDERER=1 --command=python3 com.stremio.Stremio.Devel -c "$(cat diag/probe.py)" 2>&1 | tail -1 > "$OUT/sandbox.txt"
    flatpak run --user --env=WEBKIT_DISABLE_DMABUF_RENDERER=1 --command=sh com.stremio.Stremio.Devel -c 'echo WEBKIT_DISABLE_DMABUF_RENDERER=$WEBKIT_DISABLE_DMABUF_RENDERER' >> "$OUT/sandbox.txt"
    flatpak --user info com.stremio.Stremio.Devel | grep -E 'Commit' | head -1 | sed 's/^ */shell /' >> "$OUT/sandbox.txt"
else
    docker run --rm stremio-native pacman -Q webkitgtk-6.0 gtk4 > "$OUT/sandbox.txt" 2>&1
    echo "WEBKIT_DISABLE_DMABUF_RENDERER=1 (docker -e)" >> "$OUT/sandbox.txt"
fi

node diag/server.mjs "$SITE" 18080 "$OUT/steps.log" &
SERVER=$!
sleep 2

sudo dmesg --clear || true
( while true; do echo "--- $(date +%T)"; ps -eo pid,ppid,stat,etimes,rss,comm,args | grep -iE 'WebKit|stremio|bwrap' | grep -v grep | cut -c1-200; sleep 5; done ) > "$OUT/procs.log" 2>&1 &
PS_LOOP=$!
START=$(date +%s)
if [ "$MODE" = flatpak ]; then
    timeout --preserve-status -s TERM 170 dbus-run-session -- xvfb-run -a -s "-screen 0 1920x1080x24" \
        flatpak run --user --env=WEBKIT_DISABLE_DMABUF_RENDERER=1 --env=RUST_LOG=info \
        com.stremio.Stremio.Devel --url http://127.0.0.1:18080/ > "$OUT/shell.stdout" 2> "$OUT/shell.stderr"
    STATUS=$?
else
    docker run --rm --network host --ipc host --shm-size 1g --security-opt seccomp=unconfined \
        -e WEBKIT_DISABLE_DMABUF_RENDERER=1 -e WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 -e RUST_LOG=info \
        -e SERVER_PATH=/opt/stremio/server.js -e GSETTINGS_SCHEMA_DIR=/opt/stremio/schemas \
        -v "$PWD/nativebin:/opt/stremio" stremio-native \
        timeout --preserve-status -s TERM 170 dbus-run-session -- xvfb-run -a -s "-screen 0 1920x1080x24" \
        /opt/stremio/stremio-linux-shell --url http://127.0.0.1:18080/ > "$OUT/shell.stdout" 2> "$OUT/shell.stderr"
    STATUS=$?
fi
END=$(date +%s)
kill $SERVER $PS_LOOP 2>/dev/null

sudo dmesg | grep -iE 'segfault|trap|general protection|webkit' > "$OUT/dmesg.txt" || true
CLICKS=$(grep -c ' CLICK ' "$OUT/steps.log" 2>/dev/null || echo 0)
DETAILS=$(grep -c 'hash=#/detail/' "$OUT/steps.log" 2>/dev/null || echo 0)
DONE=$(grep -c 'DONE clicks=' "$OUT/steps.log" 2>/dev/null || echo 0)
{
    echo "label=$LABEL mode=$MODE"
    cat "$OUT/sandbox.txt"
    cat out/web.txt 2>/dev/null
    echo "exit_status=$STATUS (143 = still alive at our 170 s timeout; 139 = SIGSEGV)"
    echo "runtime_seconds=$((END - START))"
    echo "clicks=$CLICKS details_seen=$DETAILS done=$DONE"
    echo "dmesg:"; cat "$OUT/dmesg.txt"
    echo "web process pids seen: $(grep -E 'WebKitWebProcess' "$OUT/procs.log" | awk '{print $1}' | sort -u | tr '\n' ' ')"
    echo "D-state samples: $(grep -E 'WebKitWebProcess' "$OUT/procs.log" | awk '$3 ~ /D/' | wc -l)"
    echo "last steps:"; tail -4 "$OUT/steps.log" 2>/dev/null
    echo "stderr tail:"; grep -vE 'DEBUG|DeprecationWarning|trace-deprecation' "$OUT/shell.stderr" | tail -8
} | tee "$OUT/summary.txt"
