#!/usr/bin/env bash
# restore.sh — additively restore flatpaks from apps/flatpak/inventory/<profile>.json
#
# Restores the profile given as $1, WORKSTATION_PROFILE, or the hostname.
# Additive only unless --prune is passed (see below). Never uninstalls apps
# that exist on this machine but not in the inventory.
#
# Usage: restore.sh [profile] [--prune] [--dry-run] [--yes]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/lib/common.sh
source "${SCRIPT_DIR}/../../scripts/lib/common.sh"

PROFILE=""
PRUNE=0
DRY=0
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
    --prune) PRUNE=1 ;;
    --dry-run) DRY=1 ;;
    --yes) ASSUME_YES=1 ;;
    -*) aw_die "unknown option: $arg (usage: restore.sh [profile] [--prune] [--dry-run] [--yes])" ;;
    *)
        [[ -n "$PROFILE" ]] && aw_die "only one profile argument allowed"
        PROFILE="$arg"
        ;;
    esac
done
PROFILE="${PROFILE:-$(aw_profile)}"

ROOT="${ATOMIC_WS_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
INV="${ROOT}/apps/flatpak/inventory/${PROFILE}.json"

if [[ ! -f "$INV" ]]; then
    aw_warn "no flatpak inventory for profile '${PROFILE}' ($INV)"
    aw_info "create one on the machine you want to mirror, then commit it:"
    aw_info "    ./scripts/inventory.sh capture   # on the source machine"
    exit 0
fi
aw_info "restoring flatpaks from $INV"

ARGS=(--profile "${PROFILE}" --file "${INV}")
[[ $PRUNE -eq 1 ]] && ARGS+=(--prune)
[[ $DRY -eq 1 ]] && ARGS+=(--dry-run)
[[ $ASSUME_YES -eq 1 ]] && ARGS+=(--yes)

exec python3 "${SCRIPT_DIR}/inventory.py" restore "${ARGS[@]}"
