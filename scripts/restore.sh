#!/usr/bin/env bash
# restore.sh — restore a machine from the git repo (new device migration).
#
# Order (see docs/recovery.md):
#   1. environment check
#   2. git repo check
#   3. chezmoi check + preview diff
#   4. apply user configuration (chezmoi apply)
#   5. restore flatpaks        (inventory, additive)
#   6. restore homebrew        (inventory, additive)
#   7. create missing distroboxes + run their bootstrap scripts
#   8. install the inventory timer
#   9. final health check (doctor)
#
# Usage: ./scripts/restore.sh [--profile NAME] [--yes] [--skip-config]
#                             [--skip-flatpak] [--skip-brew] [--skip-distrobox]
#                             [--skip-timer]
set -euo pipefail

ATOMIC_WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ATOMIC_WS_ROOT
# shellcheck source=scripts/lib/common.sh
# shellcheck disable=SC1091
source "${ATOMIC_WS_ROOT}/scripts/lib/common.sh"

PROFILE="${WORKSTATION_PROFILE:-$(aw_profile)}"
SKIP_CONFIG=0
SKIP_FLATPAK=0
SKIP_BREW=0
SKIP_DOCKER=0
SKIP_TIMER=0
while [[ $# -gt 0 ]]; do
    case "$1" in
    --profile)
        PROFILE="${2:?--profile needs a value}"
        shift 2
        ;;
    --yes)
        export AW_ASSUME_YES=1
        shift
        ;;
    --skip-config)
        SKIP_CONFIG=1
        shift
        ;;
    --skip-flatpak)
        SKIP_FLATPAK=1
        shift
        ;;
    --skip-brew)
        SKIP_BREW=1
        shift
        ;;
    --skip-distrobox)
        SKIP_DOCKER=1
        shift
        ;;
    --skip-timer)
        SKIP_TIMER=1
        shift
        ;;
    *) aw_die "unknown option: $1" ;;
    esac
done
export WORKSTATION_PROFILE="$PROFILE"

aw_step "[1/9] environment check"
. /etc/os-release 2>/dev/null || true
aw_info "restoring profile '${PROFILE}' onto ${NAME:-unknown} ${VERSION_ID:-}"
if ! aw_have git; then aw_die "git is required (install it first)"; fi
if ! aw_have python3; then aw_die "python3 is required (install it first)"; fi

aw_step "[2/9] git repo check"
if ! aw_git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    aw_die "${ATOMIC_WS_ROOT} is not a git repository — clone it properly first"
fi
aw_info "branch: $(aw_git branch --show-current || echo '(detached)')"
[[ "$(aw_git_dirty)" == "1" ]] && aw_warn "repo has uncommitted changes (they stay untouched)"

aw_step "[3/9] chezmoi check"
if [[ $SKIP_CONFIG -eq 1 ]]; then
    aw_info "skipped (--skip-config)"
elif ! aw_have chezmoi; then
    aw_warn "chezmoi is not installed — skipping config apply"
    aw_info "  install: brew install chezmoi (or https://chezmoi.io/install), then re-run"
else
    CHEZMOI_SRC="${ATOMIC_WS_ROOT}/home/chezmoi"
    aw_info "preview of pending config changes (chezmoi diff):"
    chezmoi --source "$CHEZMOI_SRC" diff || true
    if aw_confirm "apply these user configurations now?"; then
        aw_step "[4/9] applying user configuration (chezmoi apply)"
        chezmoi --source "$CHEZMOI_SRC" apply
        aw_ok "user configuration applied"
    else
        aw_info "config apply skipped by user (run later: chezmoi --source $CHEZMOI_SRC apply)"
    fi
fi

aw_step "[5/9] restoring flatpaks (additive)"
if [[ $SKIP_FLATPAK -eq 1 ]]; then aw_info "skipped (--skip-flatpak)"; else
    "${ATOMIC_WS_ROOT}/apps/flatpak/restore.sh" "$PROFILE"
fi

aw_step "[6/9] restoring homebrew (additive)"
if [[ $SKIP_BREW -eq 1 ]]; then aw_info "skipped (--skip-brew)"; else
    "${ATOMIC_WS_ROOT}/apps/brew/restore.sh" "$PROFILE"
fi

aw_step "[7/9] restoring distroboxes (create missing + bootstrap)"
if [[ $SKIP_DOCKER -eq 1 ]]; then aw_info "skipped (--skip-distrobox)"; else
    "${ATOMIC_WS_ROOT}/containers/restore.sh" "$PROFILE"
fi

aw_step "[8/9] installing the inventory timer"
if [[ $SKIP_TIMER -eq 1 ]]; then aw_info "skipped (--skip-timer)"; else
    "${ATOMIC_WS_ROOT}/scripts/install-user-timer.sh" || aw_warn "timer install failed — start it manually later"
fi

aw_step "[9/9] health check"
"${ATOMIC_WS_ROOT}/scripts/doctor.sh" || true
aw_ok "restore finished — reboot (or log out) and pick the Sway session to test it"
