#!/usr/bin/env bash
# run_once — applied once per machine after `chezmoi apply`.
#
# Port of home/core.nix's xdg.mimeApps (main branch): strata is the default
# file manager for directory opens. xdg-mime merges into mimeapps.list
# instead of clobbering it, so desktop-session edits survive re-runs.
#
# KNOWN TRAP: `chezmoi apply` may run before the custom image is booted (the
# usual order is clone repo → apply config → `bootc switch` → reboot). On that
# first pass strata does not exist yet, and chezmoi still records this script
# as done. The step is therefore re-checked by `scripts/doctor.sh`, which
# prints the one-liner to run after the switch if the handler is still unset.

set -euo pipefail

if command -v xdg-mime >/dev/null 2>&1 && command -v strata >/dev/null 2>&1; then
    xdg-mime default io.github.lgse.Strata.desktop inode/directory
else
    echo "xdg-mime or strata not available yet — after booting the custom image run:" >&2
    echo "    xdg-mime default io.github.lgse.Strata.desktop inode/directory" >&2
fi

# Enable the ported user units (hourly-chime). The unit files were just
# written by this apply, so the user manager has to re-read them first;
# enable --now is a no-op on an already-active timer.
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now hourly-chime.timer 2>/dev/null || \
        echo "hourly-chime.timer: enable failed (run after first graphical login)" >&2
fi
