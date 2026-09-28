#!/usr/bin/env bash
# Build stremio-linux-shell natively against Arch's distro WebKitGTK (run inside archlinux:latest, cwd = shell source).
set -eu
pacman -Syu --noconfirm --needed base-devel rust gtk4 libadwaita webkitgtk-6.0 mpv libepoxy gettext glib2 git >/dev/null
pacman -Q webkitgtk-6.0 gtk4
cargo build --release 2>&1 | tail -1
mkdir -p nativebin/schemas
cp target/release/stremio-linux-shell data/server.js nativebin/
cp data/com.stremio.Stremio.gschema.xml nativebin/schemas/
glib-compile-schemas nativebin/schemas
chmod -R a+rwX nativebin
