#!/usr/bin/env bash
# doctor.sh — health check for the atomic-workstation setup.
# Checks bootc, the session stack, app sources, chezmoi, the timer and git.
# Exit code: 0 = no failures, 1 = at least one [FAIL].
set -euo pipefail

ATOMIC_WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ATOMIC_WS_ROOT
# shellcheck source=scripts/lib/common.sh
# shellcheck disable=SC1091
source "${ATOMIC_WS_ROOT}/scripts/lib/common.sh"

FAILS=0
fail() {
    aw_error "$*"
    FAILS=$((FAILS + 1))
}

# The one check that needs root is `bootc status`, so the documented
# invocation is `sudo ./scripts/doctor.sh` (or `ujust atomic-ws-doctor` run
# with sudo). Root's HOME and root's `systemd --user` manager then make every
# USER-scoped check lie: chezmoi would diff against /root, and the timer would
# look permanently uninstalled. So when running as root under sudo, resolve the
# real login user once and run the user-owned checks through `aw_user`.
AW_RUN_USER="$(id -un)"
AW_RUN_HOME="${HOME}"
if [[ "${EUID}" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
    AW_RUN_USER="${SUDO_USER}"
    AW_RUN_HOME="$(getent passwd "${AW_RUN_USER}" 2>/dev/null | cut -d: -f6)"
    [[ -n "${AW_RUN_HOME}" ]] || AW_RUN_HOME="/home/${AW_RUN_USER}"
fi
AW_RUN_UID="$(id -u "${AW_RUN_USER}" 2>/dev/null || id -u)"
export AW_RUN_USER AW_RUN_HOME AW_RUN_UID

# aw_user — run a user-owned command in the login user's context. A no-op when
# we are already that user (the normal non-sudo case); under sudo it drops back
# to the user with a usable HOME, PATH and XDG_RUNTIME_DIR (what `systemctl
# --user` and `xdg-mime` need).
aw_user() {
    if [[ "${EUID}" -ne 0 ]]; then
        "$@"
    else
        runuser -u "${AW_RUN_USER}" -- env \
            HOME="${AW_RUN_HOME}" \
            PATH="${AW_RUN_HOME}/.local/bin:${AW_RUN_HOME}/bin:${PATH}" \
            XDG_RUNTIME_DIR="/run/user/${AW_RUN_UID}" \
            "$@"
    fi
}

aw_step "system"
if aw_have bootc; then
    aw_ok "bootc available"
    if bootc status >/dev/null 2>&1; then
        aw_ok "bootc status readable"
        # A bare `image:` (the map key) also matches a plain 'image:' grep and
        # prints an empty value; require a value on the same line.
        bootc status 2>/dev/null | grep -m1 -E '^ *image: .+' | sed 's/^ *image: */[INFO]  booted image: /' >&2 || true
    else
        aw_warn "bootc status needs root — run: sudo bootc status"
    fi
elif aw_have rpm-ostree; then
    aw_ok "rpm-ostree host (atomic)"
else
    aw_warn "not a bootc/ostree host — system-layer features unavailable here (normal on NixOS/other)"
fi

aw_step "niri session"
# grim + slurp + swappy + wl-copy make up the screenshot chain that the Print
# bind drives, so a missing swappy/wl-copy silently breaks annotation and a
# missing `screenshot` (~/.local/bin) breaks the bind itself. Check both here
# instead of only the capture tools.
for binary in niri noctalia foot kero strata swaylock grim slurp swappy wl-copy screenshot; do
    if aw_have "$binary"; then aw_ok "$binary"; else aw_warn "$binary not in PATH (comes with the custom image; KDE fallback session stays available)"; fi
done
if [[ -f /usr/share/wayland-sessions/niri.desktop ]]; then
    aw_ok "wayland session entry: /usr/share/wayland-sessions/niri.desktop (SDDM can offer niri)"
else
    aw_warn "no niri.desktop session entry — SDDM cannot offer niri until the custom image is installed"
fi
if [[ -f /usr/share/xdg-desktop-portal/portals/gnome.portal ]] || aw_have xdg-desktop-portal-gnome; then
    aw_ok "xdg-desktop-portal-gnome present (screen sharing)"
else
    aw_warn "xdg-desktop-portal-gnome missing — screenshots/screen-share may not work in niri"
fi

aw_step "application sources"
if aw_have flatpak; then
    aw_ok "flatpak $(flatpak --version 2>/dev/null | head -1)"
    if flatpak remotes 2>/dev/null | grep -q flathub; then
        aw_ok "flathub remote configured"
    else
        aw_warn "flathub remote missing — flatpak install will need: flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/"
    fi
    # The image bakes the host fcitx5 + rime. The flathub "Fcitx 5" app is a
    # self-contained daemon for hosts without one: it races for the fcitx5
    # D-Bus name and keeps its own rime data under ~/.var/app/<app-id>, so the
    # host dictionary never gets used. Match on the display name, not the app
    # id — flathub has shipped this app under more than one id.
    if flatpak list --app --columns=name 2>/dev/null | grep -qi 'fcitx'; then
        aw_warn "the Fcitx 5 flatpak conflicts with the image's host fcitx5 — remove it: flatpak uninstall $(flatpak list --app --columns=application,name 2>/dev/null | grep -i fcitx | cut -f1)"
    else
        aw_ok "no conflicting Fcitx 5 flatpak (host fcitx5 is used)"
    fi
else
    aw_warn "flatpak not installed (GUI apps source unavailable)"
fi
if aw_have brew; then
    aw_ok "homebrew $(brew --version 2>/dev/null | head -1 | awk '{print $2}')"
else
    aw_warn "homebrew not installed (CLI apps source unavailable; on Bazzite: ujust install-brew)"
fi
PROFILE="${WORKSTATION_PROFILE:-$(aw_profile)}"
FLATPAK_INV="${ATOMIC_WS_ROOT}/apps/flatpak/inventory/${PROFILE}.json"
BREWFILE="${ATOMIC_WS_ROOT}/apps/brew/inventory/${PROFILE}/Brewfile"
if [[ -f "$FLATPAK_INV" ]]; then aw_ok "flatpak inventory for '${PROFILE}' exists"; else aw_warn "no flatpak inventory for '${PROFILE}' — run: ./scripts/inventory.sh capture"; fi
if [[ -f "$BREWFILE" ]]; then aw_ok "Brewfile for '${PROFILE}' exists"; else aw_warn "no Brewfile for '${PROFILE}' — run: ./scripts/inventory.sh capture"; fi

aw_step "distrobox"
if aw_have distrobox; then
    aw_ok "distrobox $(distrobox --version 2>/dev/null | head -1)"
    if aw_have podman; then
        aw_ok "podman $(podman --version 2>/dev/null | awk '{print $2}')"
    else
        aw_warn "podman missing — distrobox needs a container manager"
    fi
else
    aw_warn "distrobox not installed"
fi

aw_step "chezmoi"
CHEZMOI_SRC="${ATOMIC_WS_ROOT}/home/chezmoi"
if aw_have chezmoi; then
    aw_ok "chezmoi $(chezmoi --version 2>/dev/null | awk '{print $NF}' | head -1)"
    if OUT="$(aw_user chezmoi --source "$CHEZMOI_SRC" diff 2>/dev/null)" && [[ -z "$OUT" ]]; then
        aw_ok "user config applied and in sync with the repo"
    else
        aw_warn "config drift — preview with: chezmoi --source $CHEZMOI_SRC diff"
    fi
else
    fail "chezmoi missing — required to manage user configuration (brew install chezmoi)"
fi

# xdg defaults (port of home/core.nix xdg.mimeApps)
# run_once_10-xdg-and-units.sh only runs once, and the usual install order
# (apply config on stock Bazzite → bootc switch → reboot) makes it run BEFORE
# strata exists. Re-checking here is the recovery path.
aw_step "xdg defaults"
if command -v xdg-mime >/dev/null 2>&1; then
    dir_handler="$(aw_user xdg-mime query default inode/directory 2>/dev/null || true)"
    if [[ "$dir_handler" == "io.github.lgse.Strata.desktop" ]]; then
        aw_ok "inode/directory → strata"
    else
        aw_warn "inode/directory → '${dir_handler:-unset}' — set it: xdg-mime default io.github.lgse.Strata.desktop inode/directory"
    fi
else
    aw_warn "xdg-mime missing — cannot check the file-manager default"
fi

aw_step "systemd user timer"
if command -v systemctl >/dev/null 2>&1; then
    # `systemctl is-enabled` prints the state ("not-found") to STDOUT and ALSO
    # exits non-zero, so `$(... || echo not-found)` yields the value twice
    # ("not-found\nnot-found"). Capture stdout first; substitute on failure.
    state="$(aw_user systemctl --user is-enabled atomic-workstation-inventory.timer 2>/dev/null)" || state="not-found"
    case "$state" in
    enabled) aw_ok "timer enabled (hourly inventory capture)" ;;
    disabled) aw_warn "timer disabled — enable: ~/dotfiles/scripts/install-user-timer.sh" ;;
    *) aw_warn "timer unit $state (install: ~/dotfiles/scripts/install-user-timer.sh)" ;;
    esac
    if aw_user systemctl --user show atomic-workstation-inventory.service --property=Result --value 2>/dev/null | grep -qx failure; then
        aw_warn "last timer run FAILED — journalctl --user -u atomic-workstation-inventory.service"
    fi
else
    aw_warn "systemctl unavailable — cannot check the user timer"
fi

aw_step "git"
if aw_git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    aw_ok "repo at ${ATOMIC_WS_ROOT}"
    if [[ "$(aw_git_dirty)" == "1" ]]; then
        aw_warn "uncommitted changes — run ./scripts/sync.sh --commit (or commit by hand)"
    else
        aw_ok "working tree clean"
    fi
    aw_git remote -v 2>/dev/null | head -2 | sed 's/^/[INFO]  /' >&2 || aw_warn "no remote configured"
else
    fail "not a git repo — clone it properly"
fi

echo >&2
if [[ $FAILS -gt 0 ]]; then
    aw_error "doctor: ${FAILS} failure(s) — fix the [FAIL] lines above"
    exit 1
fi
aw_ok "doctor: no failures (warnings are informational)"
