#!/usr/bin/env bash
# inventory.sh — unified entry point for software inventory operations.
#
#   inventory.sh capture [profile]            scan this machine → inventory files
#   inventory.sh status  [profile]            diff this machine vs the repo
#   inventory.sh restore [profile] [--prune] [--dry-run]
#                                             install what the inventory lists
#   inventory.sh sync    [profile]            capture + report git state
#
# --prune applies to the FLATPAK restore only (removing apps that are not in
# the inventory); it always asks for an interactive confirmation, and
# --yes cannot bypass it. --dry-run never changes anything.
#
# The profile defaults to WORKSTATION_PROFILE, else the hostname.
set -euo pipefail

ATOMIC_WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ATOMIC_WS_ROOT
# shellcheck source=scripts/lib/common.sh
# shellcheck disable=SC1091
source "${ATOMIC_WS_ROOT}/scripts/lib/common.sh"

usage() {
    cat <<'EOF'
usage: ./scripts/inventory.sh <command> [profile] [flags]

commands:
  capture    scan flatpak/homebrew/distrobox → inventory files for this machine
  status     diff this machine against the committed inventory
  restore    install missing software from the inventory (additive)
  sync       capture, then show the git state of the inventory files

flags (restore):
  --prune    ALSO uninstall flatpaks not listed in the inventory
             (interactive "Type 'yes'" confirmation; never implicit)
  --dry-run  show what would happen, change nothing

environment:
  WORKSTATION_PROFILE   machine identity (default: hostname)
EOF
}

parse_args() {
    PROFILE_ARG=""
    PRUNE=0
    DRY=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --prune)
            PRUNE=1
            shift
            ;;
        --dry-run)
            DRY=1
            shift
            ;;
        -*) aw_die "unknown option: $1 (see --help)" ;;
        *)
            if [[ -n "$PROFILE_ARG" ]]; then
                aw_die "only one profile argument allowed (got '$PROFILE_ARG' and '$1')"
            fi
            PROFILE_ARG="$1"
            shift
            ;;
        esac
    done
}

cmd_capture() {
    local profile="${PROFILE_ARG:-$(aw_profile)}"
    aw_step "capturing software inventory (profile: ${profile})"
    "${ATOMIC_WS_ROOT}/apps/flatpak/capture.sh" "${profile}"
    "${ATOMIC_WS_ROOT}/apps/brew/capture.sh" "${profile}"
    "${ATOMIC_WS_ROOT}/containers/capture.sh" "${profile}"
    aw_ok "capture complete"
}

cmd_status() {
    local profile="${PROFILE_ARG:-$(aw_profile)}"
    aw_step "comparing this machine against the inventory (profile: ${profile})"

    # flatpak: full diff (missing + extra), exit 1 only on a corrupt file
    python3 "${ATOMIC_WS_ROOT}/apps/flatpak/inventory.py" status \
        --profile "${profile}" \
        --file "${ATOMIC_WS_ROOT}/apps/flatpak/inventory/${profile}.json" || true

    # brew: which Brewfile entries are not installed
    "${ATOMIC_WS_ROOT}/apps/brew/restore.sh" "${profile}" --dry-run || true

    # containers: declared in distrobox.ini but missing here
    if aw_have distrobox && [[ -f "${ATOMIC_WS_ROOT}/containers/distrobox.ini" ]]; then
        local existing
        existing="$(distrobox list --no-color 2>/dev/null |
            awk -F'|' 'NR>1 {gsub(/ /,"",$2); if ($2 != "") print $2}' || true)"
        while IFS= read -r section; do
            [[ -z "$section" ]] && continue
            if ! grep -qx "$section" <<<"$existing"; then
                aw_warn "container '$section' is declared in containers/distrobox.ini but missing here"
            fi
        done < <(grep -oE '^\[[^]]+\]' "${ATOMIC_WS_ROOT}/containers/distrobox.ini" | tr -d '[]')
        aw_ok "container check done"
    else
        aw_info "distrobox not available — container check skipped"
    fi
}

cmd_restore() {
    local profile="${PROFILE_ARG:-$(aw_profile)}"
    aw_step "restoring software from the inventory (profile: ${profile})"

    local -a flatpak_args=()
    [[ $PRUNE -eq 1 ]] && flatpak_args+=(--prune)
    [[ $DRY -eq 1 ]] && flatpak_args+=(--dry-run)

    # NOTE: plain "${flatpak_args[@]}" (no ':-') — the :- form would inject an
    # empty argument when no flags are given, which the parser reads as a
    # second profile.
    "${ATOMIC_WS_ROOT}/apps/flatpak/restore.sh" "${profile}" "${flatpak_args[@]}"
    # the --prune flag must never reach brew/containers (they have nothing to prune)
    if [[ $DRY -eq 1 ]]; then
        "${ATOMIC_WS_ROOT}/apps/brew/restore.sh" "${profile}" --dry-run
        "${ATOMIC_WS_ROOT}/containers/restore.sh" "${profile}" --dry-run
    else
        "${ATOMIC_WS_ROOT}/apps/brew/restore.sh" "${profile}"
        "${ATOMIC_WS_ROOT}/containers/restore.sh" "${profile}"
    fi
    aw_ok "restore complete"
}

cmd_sync() {
    cmd_capture
    aw_step "git state of inventory files"
    local -a changed=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        changed+=("${line:3}")
    done < <(aw_git status --porcelain -- \
        apps/flatpak/inventory apps/brew/inventory containers/inventory 2>/dev/null || true)

    if [[ ${#changed[@]} -eq 0 ]]; then
        aw_ok "inventory unchanged since the last commit (idempotent capture)"
        return 0
    fi
    aw_info "inventory changed on this machine:"
    for f in "${changed[@]}"; do
        aw_info "  $f"
    done
    aw_info "commit with: ./scripts/sync.sh --commit   (it only stages inventory files)"
    if [[ "$(aw_git_dirty)" == "1" ]]; then
        aw_warn "the repo also has OTHER uncommitted changes — sync never touches those"
    fi
}

cmd="${1:-}"
case "$cmd" in
capture | status | restore | sync)
    shift || true
    parse_args "$@"
    "cmd_${cmd}"
    ;;
-h | --help | help | "")
    usage
    ;;
*)
    usage
    aw_die "unknown command: $cmd"
    ;;
esac
