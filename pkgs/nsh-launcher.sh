#!/bin/sh
# The `nsh` on PATH: runs the distribution built by pkgs/nsh.nix.
#
# The CLI finds its prebuilt runtimes through its own executable path
# (<dist>/bin/nsh -> <dist>/runtime/...), and `nsh component add` (the web and
# Android runtimes, added on first use) writes into that same root. The store
# cannot host that, so this script mirrors the distribution into a writable
# directory and runs the copy, refreshing it whenever the store path changes:
# nix stays the source of truth, and `nsh update` (which would silently replace
# the mirror) is undone by the next run.
#
# It also carries the environment an app's own Rust runner needs to build, which
# outside a dev shell is otherwise left to the user: PKG_CONFIG_PATH for the
# GTK/WebKit/GStreamer crates, gsettings schemas and the GStreamer plugin path
# for the binary, and a cargo/clang/pkg-config to build with.
set -eu

dist="@dist@"
home=${NSH_HOME:-$HOME/.nsh}

if [ ! -x "$home/bin/nsh" ] || [ "$(cat "$home/.nix-dist" 2>/dev/null || true)" != "$dist" ]; then
  if mkdir "$home.lock" 2>/dev/null; then
    tmp="$home.new.$$"
    rm -rf "$tmp"
    cp -a "$dist" "$tmp"
    # The store copy is read-only; the mirror must be writable.
    chmod -R u+w "$tmp"
    printf '%s\n' "$dist" >"$tmp/.nix-dist"
    if [ -e "$home" ]; then mv -f "$home" "$home.old.$$"; fi
    mv "$tmp" "$home"
    rm -rf "$home.old.$$"
    rmdir "$home.lock"
  else
    # Another nsh is refreshing the mirror; wait for it to finish.
    while [ -d "$home.lock" ]; do sleep 0.2; done
  fi
fi

# One captured value per line: each is a colon-separated list of store paths,
# so they cannot share a line.
caps="$(cat "@runnerEnv@")"
pc="$(printf '%s\n' "$caps" | sed -n 1p)"
schemas="$(printf '%s\n' "$caps" | sed -n 2p)"
gst="$(printf '%s\n' "$caps" | sed -n 3p)"
if [ -n "${PKG_CONFIG_PATH:-}" ]; then pc="$pc:$PKG_CONFIG_PATH"; fi
if [ -n "${XDG_DATA_DIRS:-}" ]; then schemas="$schemas:$XDG_DATA_DIRS"; fi
if [ -n "${GST_PLUGIN_SYSTEM_PATH_1_0:-}" ]; then gst="$gst:$GST_PLUGIN_SYSTEM_PATH_1_0"; fi
export PKG_CONFIG_PATH="$pc"
export XDG_DATA_DIRS="$schemas"
export GST_PLUGIN_SYSTEM_PATH_1_0="$gst"
export LIBCLANG_PATH="@libclang@"

# The runner build calls cargo, and QuickJS's C code needs a compiler. A
# rustup-managed toolchain (the one that can cross-compile for Android) stays
# ahead of the nixpkgs cargo at the end; pkg-config and clang go first, so the
# GTK .pc files and the clang bindgen needs are found whatever the shell holds.
export PATH="@toolPath@:${PATH:-}:@cargoPath@"

exec "$home/bin/nsh" "$@"
