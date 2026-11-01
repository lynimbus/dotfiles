#!/usr/bin/env bash
# bootstrap.sh — first-time initialization check for atomic-workstation (safe, read-only).
#
# Does NOT install anything, does NOT touch partitions, bootloaders or the
# booted image. It checks the environment, reports what is missing and what
# to do next. Safe to re-run any time.
set -euo pipefail

ATOMIC_WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ATOMIC_WS_ROOT
# shellcheck source=scripts/lib/common.sh
# shellcheck disable=SC1091
source "${ATOMIC_WS_ROOT}/scripts/lib/common.sh"

MISSING=0
step() { printf '\n%s\n' "$*"; }

step "== system =="
# shellcheck disable=SC1091
. /etc/os-release 2>/dev/null || true
printf 'OS:      %s %s\n' "${NAME:-unknown}" "${VERSION_ID:-}"
printf 'Kernel:  %s\n' "$(uname -r)"
if aw_have bootc; then
    aw_ok "bootc present (image-based system)"
    bootc status 2>/dev/null | sed -n '1,8p' | sed 's/^/    /' >&2 || aw_warn "bootc status failed (needs root: sudo bootc status)"
elif aw_have rpm-ostree; then
    aw_ok "rpm-ostree present (ostree-based system)"
else
    aw_warn "neither bootc nor rpm-ostree — this host is not atomic/image-based"
    aw_info "the repo still works: chezmoi + flatpak + brew + distrobox parts function on any Linux"
fi

step "== required tools =="
for tool in git python3 chezmoi; do
    if aw_have "$tool"; then
        ver="$("$tool" --version 2>/dev/null | head -1 | awk '{print $NF}')"
        aw_ok "$tool (${ver:-version unknown})"
    else
        MISSING=1
        aw_error "$tool is MISSING"
        case "$tool" in
        chezmoi) aw_info "  install: brew install chezmoi   (or: https://chezmoi.io/install)" ;;
        python3) aw_info "  install: your distro's python3 package (Bazzite ships it)" ;;
        git) aw_info "  install: your distro's git package" ;;
        esac
    fi
done

step "== optional tools (inventory sources) =="
for tool in flatpak brew distrobox; do
    if aw_have "$tool"; then
        aw_ok "$tool present"
    else
        aw_warn "$tool not installed — its capture/restore will be skipped"
    fi
done

step "== repo state =="
printf 'Repo:     %s\n' "$ATOMIC_WS_ROOT"
printf 'Profile:  %s\n' "$(aw_profile)"
printf 'Branch:   %s\n' "$(aw_git branch --show-current 2>/dev/null || echo "(detached)")"
if [[ "$(aw_git_dirty)" == "1" ]]; then
    aw_warn "uncommitted changes present — commit or stash before relying on sync"
fi

step "== next steps =="
cat <<'EOF'
1. (optional, image-based hosts only) build & boot the custom image:
       see docs/installation.md — GitHub Actions builds it on push to main
2. apply user configuration:
       chezmoi --source ~/dotfiles/home/chezmoi diff     # preview
       chezmoi --source ~/dotfiles/home/chezmoi apply
3. install the inventory timer (systemd user unit, no root):
       ~/dotfiles/scripts/install-user-timer.sh
4. capture what is installed on THIS machine:
       ~/dotfiles/scripts/inventory.sh capture
5. on a NEW machine, restore everything:
       ~/dotfiles/scripts/restore.sh
EOF

if [[ $MISSING -eq 1 ]]; then
    aw_error "required tools missing — fix the [FAIL] lines above first"
    exit 1
fi
aw_ok "bootstrap check complete"
