#!/usr/bin/env bash
# install-user-timer.sh — install the inventory scan timer as a systemd USER unit.
#
# Copies the units from system/systemd/user/ into ~/.config/systemd/user/
# (not a symlink: the repo may be absent on a fresh machine before restore),
# reloads the daemon and enables the timer. Re-runnable (idempotent).
#
# NO root required. The timer only captures (never pushes) — pushing is
# manual via ./scripts/sync.sh --push.
set -euo pipefail

ATOMIC_WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${ATOMIC_WS_ROOT}/scripts/lib/common.sh"

UNIT_DIR="${HOME}/.config/systemd/user"
UNITS=(atomic-workstation-inventory.service atomic-workstation-inventory.timer)

aw_step "installing systemd user units"
if ! command -v systemctl >/dev/null 2>&1; then
    aw_die "systemctl not found — this needs a systemd system (Bazzite has one)"
fi
if [[ "$(systemctl --user is-system-running 2>/dev/null)" == "offline" ]]; then
    aw_warn "the systemd user session is offline (no dbus?) — units are installed but the timer will not run until you log in graphically"
fi

mkdir -p "${UNIT_DIR}"
for unit in "${UNITS[@]}"; do
    if [[ -f "${UNIT_DIR}/${unit}" ]] && ! cmp -s "${ATOMIC_WS_ROOT}/system/systemd/user/${unit}" "${UNIT_DIR}/${unit}"; then
        aw_info "${unit} exists and differs — overwriting from the repo"
    fi
    install -m 0644 "${ATOMIC_WS_ROOT}/system/systemd/user/${unit}" "${UNIT_DIR}/${unit}"
    aw_ok "installed ${unit}"
done

systemctl --user daemon-reload
systemctl --user enable --now atomic-workstation-inventory.timer

# The service ExecStart points at ~/dotfiles — sanity-check that
if [[ ! -x "${HOME}/dotfiles/scripts/inventory.sh" ]]; then
    aw_warn "$HOME/dotfiles/scripts/inventory.sh not found — the service will fail until the repo is cloned to $HOME/dotfiles (or you adjust ExecStart in a unit override: systemctl --user edit atomic-workstation-inventory.service)"
fi

aw_ok "timer enabled (next runs: see $(systemctl --user list-timers atomic-workstation-inventory.timer))"
