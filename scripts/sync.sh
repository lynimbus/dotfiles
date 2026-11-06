#!/usr/bin/env bash
# sync.sh — capture this machine's software state and manage the git commit.
#
#   ./scripts/sync.sh              capture + show what changed
#   ./scripts/sync.sh --commit     capture + commit ONLY inventory files
#   ./scripts/sync.sh --push       capture + commit + push (manual opt-in)
#
# Safety rules (enforced, not configurable from env):
#   * only files under apps/*/inventory and containers/inventory are staged —
#     your other uncommitted work is never committed by this script
#   * --push is manual-only; the systemd timer NEVER pushes (AUTO_PUSH is
#     read only by the timer unit's ExecStart, defaulting to off)
#   * never resets, never force-pushes; on conflict the script stops and tells
#     you what to do
set -euo pipefail

ATOMIC_WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ATOMIC_WS_ROOT
# shellcheck source=scripts/lib/common.sh
source "${ATOMIC_WS_ROOT}/scripts/lib/common.sh"

DO_COMMIT=0
DO_PUSH=0
for arg in "$@"; do
    case "$arg" in
    --commit) DO_COMMIT=1 ;;
    --push)
        DO_COMMIT=1
        DO_PUSH=1
        ;;
    -*) aw_die "unknown option: $arg" ;;
    esac
done

PROFILE="${WORKSTATION_PROFILE:-$(aw_profile)}"

if [[ "$(aw_git_in_merge)" == "1" ]]; then
    aw_error "a merge or rebase is in progress in ${ATOMIC_WS_ROOT}"
    aw_info "finish it first:  git -C ${ATOMIC_WS_ROOT} status"
    aw_info "the inventory files you captured are safe on disk; nothing was committed."
    exit 1
fi

"${ATOMIC_WS_ROOT}/scripts/inventory.sh" capture "${PROFILE}"

aw_step "git state of the inventory"
INV_PATHS=(apps/flatpak/inventory apps/brew/inventory containers/inventory)
if ! CHANGED="$(aw_git status --porcelain -- "${INV_PATHS[@]}")" || [[ -z "$CHANGED" ]]; then
    aw_ok "inventory is up to date with the last commit — nothing to do"
    exit 0
fi
printf '%s\n' "$CHANGED" >&2

if [[ $DO_COMMIT -eq 0 ]]; then
    aw_info "not committing (use --commit, or commit by hand)"
    exit 0
fi

# Pathspec commit: other staged work is untouched; untracked inventory files need the explicit add first.
aw_git add -- "${INV_PATHS[@]}"
MSG="chore(inventory): capture ${PROFILE} @ $(date +%Y-%m-%dT%H:%M:%S%z)"
aw_git commit -m "$MSG" -- "${INV_PATHS[@]}" >/dev/null
aw_ok "committed inventory for '${PROFILE}'"

if [[ $DO_PUSH -eq 1 ]]; then
    if ! aw_git remote | grep -q .; then
        aw_warn "no git remote configured — skipping push"
        exit 0
    fi
    if ! aw_git pull --rebase --autostash; then
        aw_error "pull --rebase failed (conflict with the remote?)"
        aw_info "resolve manually:  git -C ${ATOMIC_WS_ROOT} rebase --continue / --abort"
        exit 1
    fi
    aw_git push
    aw_ok "pushed to $(aw_git remote get-url origin 2>/dev/null || echo remote)"
else
    aw_info "push skipped (default off — use --push)"
fi
