#!/usr/bin/env bash
# Bootstrap script for the fedora-dev distrobox container.
# Run INSIDE the container (restore.sh does this automatically after creating
# it; you can also run it by hand):
#     distrobox enter fedora-dev
set -euo pipefail

echo "==> fedora-dev bootstrap: development toolchain"

# Base packages come from containers/distrobox.ini (additional_packages).

# Starship prompt (works in any shell, config comes from chezmoi)
if ! command -v starship >/dev/null 2>&1; then
    curl -sS https://starship.rs/install.sh | sh -s -- --yes ||
        echo "WARN: starship install failed — install it manually later" >&2
fi

command -v pipx >/dev/null 2>&1 || python3 -m pip install --user pipx 2>/dev/null || true

echo "==> fedora-dev bootstrap done"
