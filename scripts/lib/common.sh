#!/usr/bin/env bash
# common.sh — shared helpers for atomic-workstation scripts.
# Sourced (not executed) by every entry point in scripts/.

# ── logging ────────────────────────────────────────────────────────────────
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    _aw_ok_col=$'\e[32m' _aw_warn_col=$'\e[33m' _aw_err_col=$'\e[31m' _aw_info_col=$'\e[36m' _aw_off=$'\e[0m'
else
    _aw_ok_col="" _aw_warn_col="" _aw_err_col="" _aw_info_col="" _aw_off=""
fi

aw_ok() { printf '%s[OK]%s    %s\n' "$_aw_ok_col" "$_aw_off" "$*" >&2; }
aw_warn() { printf '%s[WARN]%s  %s\n' "$_aw_warn_col" "$_aw_off" "$*" >&2; }
aw_error() { printf '%s[FAIL]%s  %s\n' "$_aw_err_col" "$_aw_off" "$*" >&2; }
aw_info() { printf '%s[INFO]%s  %s\n' "$_aw_info_col" "$_aw_off" "$*" >&2; }
aw_step() { printf '%s==> %s%s\n' "$_aw_info_col" "$_aw_off" "$*" >&2; }

aw_die() {
    aw_error "$@"
    exit 1
}

# ── repo / profile resolution ─────────────────────────────────────────────
# ATOMIC_WS_ROOT: repo root (set by the caller via its own BASH_SOURCE walk).
# WORKSTATION_PROFILE: machine identity for inventory files
#   (default: hostname; override with the env var for e.g. "laptop"/"desktop"
#   on machines that share a hostname, or to test).
aw_profile() {
    printf '%s' "${WORKSTATION_PROFILE:-$(hostname)}"
}

aw_inventory_dirs() {
    # Every git-tracked inventory location, one per line (used by sync.sh).
    printf '%s\n' \
        "${ATOMIC_WS_ROOT}/apps/flatpak/inventory" \
        "${ATOMIC_WS_ROOT}/apps/brew/inventory" \
        "${ATOMIC_WS_ROOT}/containers/inventory"
}

# ── command presence ──────────────────────────────────────────────────────
aw_have() { command -v "$1" >/dev/null 2>&1; }

# ── git helpers (safe: never mutate, never reset) ─────────────────────────
aw_git() { git -C "${ATOMIC_WS_ROOT}" "$@"; }

aw_git_dirty() {
    # Prints 0/1: whether the repo has ANY uncommitted change.
    [[ -n "$(aw_git status --porcelain 2>/dev/null)" ]] && printf 1 || printf 0
}

aw_git_in_merge() {
    # Prints 0/1: whether a merge/rebase is in progress (auto-sync must stop).
    local gd
    # --absolute-git-dir: the plain --git-dir form returns a path relative to
    # the repository root, which breaks when the script runs from any other
    # CWD (e.g. from systemd). It also works inside git worktrees.
    gd="$(aw_git rev-parse --absolute-git-dir 2>/dev/null)" || return 0
    [[ -e "$gd/MERGE_HEAD" || -d "$gd/rebase-merge" || -d "$gd/rebase-apply" ]] &&
        printf 1 || printf 0
}

# ── confirmations ─────────────────────────────────────────────────────────
# Non-destructive ask: default no, accepts y/yes.
aw_confirm() {
    local prompt="$1" answer
    if [[ "${AW_ASSUME_YES:-0}" == "1" ]]; then
        return 0
    fi
    read -r -p "$prompt [y/N] " answer <&2 || answer=""
    case "${answer:-n}" in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
    esac
}

# Destructive ask (prune/uninstall): the user must type the full word "yes".
aw_confirm_destructive() {
    local prompt="$1" answer
    if [[ "${AW_ASSUME_YES:-0}" == "1" ]]; then
        aw_warn "AW_ASSUME_YES=1 skips the destructive confirmation — refusing to auto-confirm a delete."
        return 1
    fi
    read -r -p "$prompt Type 'yes' to confirm: " answer <&2 || answer=""
    [[ "${answer:-}" == "yes" ]]
}
