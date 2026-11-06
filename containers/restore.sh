#!/usr/bin/env bash
# restore.sh — create missing distrobox containers from containers/distrobox.ini
#
# Bootstrap scripts (containers/bootstrap/<name>.sh) run inside containers
# that were created by THIS invocation (skipped for already-existing ones).
# --dry-run only prints what would happen (no distrobox calls that mutate).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../scripts/lib/common.sh"

PROFILE=""
DRY=0
for arg in "$@"; do
    case "$arg" in
    --dry-run) DRY=1 ;;
    -*) aw_die "unknown option: $arg (usage: restore.sh [profile] [--dry-run])" ;;
    *)
        [[ -n "$PROFILE" ]] && aw_die "only one profile argument allowed"
        PROFILE="$arg"
        ;;
    esac
done
PROFILE="${PROFILE:-$(aw_profile)}"

ROOT="${ATOMIC_WS_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
INI="${ROOT}/containers/distrobox.ini"

if ! aw_have distrobox; then
    aw_warn "distrobox is not installed — skipping container restore."
    aw_info "on Bazzite it ships preinstalled; elsewhere: https://distrobox.it"
    exit 0
fi
if [[ ! -f "$INI" ]]; then
    aw_warn "no distrobox.ini found ($INI) — nothing to restore."
    exit 0
fi

ini_names() { grep -oE '^\[[^]]+\]' "$1" | tr -d '[]'; }
live_names() {
    distrobox list --no-color 2>/dev/null |
        awk -F'|' 'NR>1 {gsub(/ /,"",$2); if ($2 != "") print $2}' || true
}
contains() { grep -qxF "$2" <<<"$1"; }

BEFORE="$(live_names)"

if [[ $DRY -eq 1 ]]; then
    aw_step "dry run — containers declared in containers/distrobox.ini"
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        if contains "$BEFORE" "$name"; then
            aw_info "exists, would skip:    $name"
        elif [[ -f "${SCRIPT_DIR}/bootstrap/${name}.sh" ]]; then
            aw_info "would create:          $name  (+ bootstrap)"
        else
            aw_info "would create:          $name"
        fi
    done < <(ini_names "$INI")
    exit 0
fi

aw_step "creating missing distrobox containers (declared in containers/distrobox.ini)"
distrobox assemble create --file "$INI"

AFTER="$(live_names)"
while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if contains "$BEFORE" "$name"; then
        continue
    fi
    BOOTSTRAP="${SCRIPT_DIR}/bootstrap/${name}.sh"
    if [[ -f "$BOOTSTRAP" ]]; then
        aw_step "bootstrapping new container '$name'"
        if distrobox enter "$name" -- bash "$BOOTSTRAP"; then
            aw_ok "container '$name' bootstrapped"
        else
            aw_warn "bootstrap for '$name' failed — run it manually:"
            aw_info "    distrobox enter $name -- bash $BOOTSTRAP"
        fi
    fi
done <<<"$AFTER"

aw_ok "distrobox containers restored (profile '${PROFILE}')"
