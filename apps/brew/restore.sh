#!/usr/bin/env bash
# restore.sh — install Homebrew packages from apps/brew/inventory/<profile>/Brewfile
#
# --dry-run reports what WOULD be installed by comparing the Brewfile with
# `brew list` (no reliance on optional `brew bundle` flags).
# Skips with a warning when Homebrew or the Brewfile is missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/lib/common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../scripts/lib/common.sh"

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

ROOT="${ATOMIC_WS_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
BREWFILE="${ROOT}/apps/brew/inventory/${PROFILE}/Brewfile"

if ! aw_have brew; then
    aw_warn "Homebrew is not installed — skipping brew restore."
    aw_info "install it first (Bazzite: ujust install-brew), then re-run."
    exit 0
fi

if [[ ! -f "$BREWFILE" ]]; then
    aw_warn "no Brewfile for profile '${PROFILE}' (${BREWFILE}) — skipping."
    exit 0
fi

INSTALLED="$(mktemp)"
trap 'rm -f "$INSTALLED"' EXIT
brew list --formula 2>/dev/null >"$INSTALLED" || true
brew list --cask 2>/dev/null >>"$INSTALLED" || true

missing=()
while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    grep -qxF "$name" "$INSTALLED" || missing+=("$name")
done < <(sed -n -e 's/^brew[[:space:]]*"//p' -e 's/^cask[[:space:]]*"//p' "$BREWFILE" | sed -e 's/".*$//')

aw_step "restoring Homebrew packages from $BREWFILE"
if [[ ${#missing[@]} -eq 0 ]]; then
    aw_ok "all $(grep -cE '^(brew|cask) ' "$BREWFILE") entries already installed — nothing to do"
    exit 0
fi

if [[ $DRY -eq 1 ]]; then
    aw_info "would install ${#missing[@]} package(s):"
    printf '        %s\n' "${missing[@]}" >&2
    exit 0
fi

brew bundle --file "$BREWFILE"
aw_ok "brew restore complete (profile '${PROFILE}')"
