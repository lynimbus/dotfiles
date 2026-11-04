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

# ── system layer ───────────────────────────────────────────────────
aw_step "system"
if aw_have bootc; then
    aw_ok "bootc available"
    if bootc status >/dev/null 2>&1; then
        aw_ok "bootc status readable"
        bootc status 2>/dev/null | grep -m1 'image:' | sed 's/^ *image: */[INFO]  booted image: /' >&2 || true
    else
        aw_warn "bootc status needs root — run: sudo bootc status"
    fi
elif aw_have rpm-ostree; then
    aw_ok "rpm-ostree host (atomic)"
else
    aw_warn "not a bootc/ostree host — system-layer features unavailable here (normal on NixOS/other)"
fi

# ── session layer ──────────────────────────────────────────────────
aw_step "niri session"
for binary in niri noctalia foot kero strata swaylock grim slurp wl-copy; do
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

# ── application layer ──────────────────────────────────────────────
aw_step "application sources"
if aw_have flatpak; then
    aw_ok "flatpak $(flatpak --version 2>/dev/null | head -1)"
    if flatpak remotes 2>/dev/null | grep -q flathub; then
        aw_ok "flathub remote configured"
    else
        aw_warn "flathub remote missing — flatpak install will need: flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/"
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

# ── distrobox ──────────────────────────────────────────────────────
aw_step "distrobox"
if aw_have distrobox; then
    aw_ok "distrobox $(distrobox --version 2>/dev/null | head -1)"
    aw_have podman && aw_ok "podman $(podman --version 2>/dev/null | awk '{print $2}')" || aw_warn "podman missing — distrobox needs a container manager"
else
    aw_warn "distrobox not installed"
fi

# ── chezmoi ────────────────────────────────────────────────────────
aw_step "chezmoi"
CHEZMOI_SRC="${ATOMIC_WS_ROOT}/home/chezmoi"
if aw_have chezmoi; then
    aw_ok "chezmoi $(chezmoi --version 2>/dev/null | awk '{print $NF}' | head -1)"
    if OUT="$(chezmoi --source "$CHEZMOI_SRC" diff 2>/dev/null)" && [[ -z "$OUT" ]]; then
        aw_ok "user config applied and in sync with the repo"
    else
        aw_warn "config drift — preview with: chezmoi --source $CHEZMOI_SRC diff"
    fi
else
    fail "chezmoi missing — required to manage user configuration (brew install chezmoi)"
fi

# ── timer ──────────────────────────────────────────────────────────
aw_step "systemd user timer"
if command -v systemctl >/dev/null 2>&1; then
    state="$(systemctl --user is-enabled atomic-workstation-inventory.timer 2>/dev/null || echo not-found)"
    case "$state" in
    enabled) aw_ok "timer enabled (hourly inventory capture)" ;;
    disabled) aw_warn "timer disabled — enable: ~/dotfiles/scripts/install-user-timer.sh" ;;
    *) aw_warn "timer unit $state (install: ~/dotfiles/scripts/install-user-timer.sh)" ;;
    esac
    if systemctl --user show atomic-workstation-inventory.service --property=Result --value 2>/dev/null | grep -qx failure; then
        aw_warn "last timer run FAILED — journalctl --user -u atomic-workstation-inventory.service"
    fi
else
    aw_warn "systemctl unavailable — cannot check the user timer"
fi

# ── git ────────────────────────────────────────────────────────────
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

# ── summary ────────────────────────────────────────────────────────
echo >&2
if [[ $FAILS -gt 0 ]]; then
    aw_error "doctor: ${FAILS} failure(s) — fix the [FAIL] lines above"
    exit 1
fi
aw_ok "doctor: no failures (warnings are informational)"
