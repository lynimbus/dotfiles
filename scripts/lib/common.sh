#!/usr/bin/env bash
# common.sh — shared helpers for atomic-workstation scripts.
# Sourced (not executed) by every entry point in scripts/.

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

# ATOMIC_WS_ROOT: repo root (set by the caller via its own BASH_SOURCE walk).
# WORKSTATION_PROFILE: machine identity for inventory files
#   (default: hostname; override with the env var for e.g. "laptop"/"desktop"
#   on machines that share a hostname, or to test).
aw_profile() {
    printf '%s' "${WORKSTATION_PROFILE:-$(hostname)}"
}

# AW_DISABLE_CMDS: space-separated list of commands to pretend are missing.
# It exists because a PATH cannot hide a tool that lives in /usr/bin (shadowing
# an earlier PATH entry only makes `command -v` fall through to the real
# binary), and the test suite has to exercise the "tool absent" branches on a
# machine where the tools are genuinely installed. Unset in normal use.
aw_have() {
    local cmd="$1"
    local disabled
    for disabled in ${AW_DISABLE_CMDS:-}; do
        [[ "$cmd" == "$disabled" ]] && return 1
    done
    command -v "$cmd" >/dev/null 2>&1
}

aw_git() { git -C "${ATOMIC_WS_ROOT}" "$@"; }

aw_git_dirty() {
    [[ -n "$(aw_git status --porcelain 2>/dev/null)" ]] && printf 1 || printf 0
}

aw_git_in_merge() {
    local gd
    # --absolute-git-dir: the plain --git-dir form returns a path relative to
    # the repository root, which breaks when the script runs from any other
    # CWD (e.g. from systemd). It also works inside git worktrees.
    gd="$(aw_git rev-parse --absolute-git-dir 2>/dev/null)" || return 0
    [[ -e "$gd/MERGE_HEAD" || -d "$gd/rebase-merge" || -d "$gd/rebase-apply" ]] &&
        printf 1 || printf 0
}

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
