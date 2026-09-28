#!/usr/bin/env bash
# Disable only the document.startViewTransition call in Routes.tsx (beta.40 control build).
set -eu
file=src/router/Routes.tsx
sed -i "s/typeof document.startViewTransition === 'function'/false \&\& typeof document.startViewTransition === 'function'/" "$file"
test "$(grep -c "false && typeof document.startViewTransition === 'function'" "$file")" = 1
git diff --stat
