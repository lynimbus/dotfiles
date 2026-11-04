#!/usr/bin/env bash
# run_once — applied once per machine after `chezmoi apply`.
#
# Port of home/core.nix's xdg.mimeApps (main branch): strata is the default
# file manager for directory opens. xdg-mime merges into mimeapps.list
# instead of clobbering it, so desktop-session edits survive re-runs.

set -euo pipefail

if command -v xdg-mime >/dev/null 2>&1 && command -v strata >/dev/null 2>&1; then
    xdg-mime default io.github.lgse.Strata.desktop inode/directory
else
    echo "xdg-mime or strata not available — skipping directory-handler default" >&2
fi

# Enable the ported user units (hourly-chime). Idempotent.
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user enable --now hourly-chime.timer 2>/dev/null || \
        echo "hourly-chime.timer: enable failed (run after first graphical login)" >&2
fi
