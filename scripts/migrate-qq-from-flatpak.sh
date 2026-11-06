#!/usr/bin/env bash
# migrate-qq-from-flatpak.sh — carry the Flatpak QQ profile over to the native build.
#
# QQ's Flatpak build (com.qq.QQ) keeps its profile inside the sandbox:
#
#   ${HOME}/.var/app/com.qq.QQ/config/QQ          (1.5 GB on the reference box)
#
# The native package (the payload this image ships) reads:
#
#   ${XDG_CONFIG_HOME:-$HOME/.config}/QQ
#
# so switching from the Flatpak to the native build silently loses local login
# state and message history unless the tree is copied across first.
#
# Usage: ./scripts/migrate-qq-from-flatpak.sh [--dry-run] [--force]
#                                             [--from DIR] [--to DIR] [--help]
#
#   --dry-run     print the resolved source/target, the file count and size
#                 (du -sh), copy nothing
#   --force       merge over a non-empty target (cp -a, no deletions on either
#                 side); re-runnable
#   --from DIR    source profile (default ${HOME}/.var/app/com.qq.QQ/config/QQ)
#   --to DIR      target profile (default ${XDG_CONFIG_HOME:-$HOME/.config}/QQ)
#   --help        this text
#
# Exit codes:
#   0  nothing to migrate (source missing/empty), or the copy succeeded,
#      or --dry-run / --help
#   1  the target is non-empty and --force was not given (nothing written)
#   2  bad usage (unknown flag, missing option value)
#
# Safety rules (enforced, not configurable):
#   * this is a COPY, never a move: the Flatpak tree is left exactly as it was
#     and stays the fallback until YOU uninstall the Flatpak
#   * nothing is ever deleted — not on the source side, not on the target side
#   * the script never runs flatpak; the uninstall hint is printed, not executed
set -euo pipefail

ATOMIC_WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ATOMIC_WS_ROOT
# shellcheck source=scripts/lib/common.sh
# shellcheck disable=SC1091
source "${ATOMIC_WS_ROOT}/scripts/lib/common.sh"

usage() {
    cat >&2 <<'EOF'
Usage: migrate-qq-from-flatpak.sh [--dry-run] [--force] [--from DIR] [--to DIR]

Copy the Flatpak QQ profile ($HOME/.var/app/com.qq.QQ/config/QQ) into the
location the native QQ build reads ($XDG_CONFIG_HOME/QQ, default ~/.config/QQ).

Options:
  --dry-run     show the resolved source/target, file count and size; copy nothing
  --force       merge over an existing non-empty target (cp -a; nothing deleted)
  --from DIR    source profile directory (default ~/.var/app/com.qq.QQ/config/QQ)
  --to DIR      target profile directory (default ${XDG_CONFIG_HOME:-~/.config}/QQ)
  --help        print this help

Exit codes: 0 = nothing to migrate or copy succeeded (also --dry-run/--help),
            1 = target non-empty and --force not given,
            2 = bad usage.
The Flatpak tree is never modified and is never removed by this script.
EOF
}

DRY_RUN=0
FORCE=0
FROM="${HOME}/.var/app/com.qq.QQ/config/QQ"
TO="${XDG_CONFIG_HOME:-${HOME}/.config}/QQ"

while [[ $# -gt 0 ]]; do
    case "$1" in
    --dry-run)
        DRY_RUN=1
        shift
        ;;
    --force)
        FORCE=1
        shift
        ;;
    --from)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
            aw_error "--from needs a directory"
            usage
            exit 2
        fi
        FROM="$2"
        shift 2
        ;;
    --from=*)
        FROM="${1#--from=}"
        [[ -n "$FROM" ]] || {
            aw_error "--from needs a directory"
            usage
            exit 2
        }
        shift
        ;;
    --to)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
            aw_error "--to needs a directory"
            usage
            exit 2
        fi
        TO="$2"
        shift 2
        ;;
    --to=*)
        TO="${1#--to=}"
        [[ -n "$TO" ]] || {
            aw_error "--to needs a directory"
            usage
            exit 2
        }
        shift
        ;;
    --help | -h)
        usage
        exit 0
        ;;
    -*)
        aw_error "unknown option: $1"
        usage
        exit 2
        ;;
    *)
        aw_error "unexpected argument: $1"
        usage
        exit 2
        ;;
    esac
done

# Trailing slashes would make the "is the target the source?" check lie.
FROM="${FROM%/}"
TO="${TO%/}"

aw_step "QQ profile migration (Flatpak -> native)"
aw_info "source: ${FROM}"
aw_info "target: ${TO}"

# An already-native machine (no Flatpak QQ, or an empty sandbox profile) is a
# perfectly normal state, not an error.
if [[ ! -d "$FROM" ]]; then
    aw_ok "nothing to migrate: no Flatpak QQ profile at ${FROM}"
    aw_info "this machine already looks native (or QQ never ran in the Flatpak)."
    exit 0
fi
if ! find "$FROM" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
    aw_ok "nothing to migrate: the Flatpak QQ profile at ${FROM} is empty"
    exit 0
fi

FILE_COUNT="$(find "$FROM" -type f 2>/dev/null | wc -l | tr -d ' ')"
SIZE="$(du -sh "$FROM" 2>/dev/null | cut -f1)"

# Refuse to copy a tree onto itself (would be a no-op at best, self-overwrite at
# worst). Same-path is a usage error, not a copy.
FROM_REAL="$(cd "$FROM" && pwd -P)"
if [[ -e "$TO" ]]; then
    TO_REAL="$(cd "$TO" && pwd -P)"
else
    TO_REAL="$TO"
fi
if [[ "$FROM_REAL" == "$TO_REAL" ]]; then
    aw_error "source and target are the same directory: ${FROM}"
    aw_info "pick a different --to; nothing was copied."
    exit 2
fi

if [[ "$DRY_RUN" == "1" ]]; then
    aw_ok "dry run: would copy ${FILE_COUNT} files (${SIZE})"
    aw_info "from: ${FROM}"
    aw_info "to:   ${TO}"
    if [[ -e "$TO" ]] && [[ -n "$(find "$TO" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        if [[ "$FORCE" == "1" ]]; then
            aw_info "target already exists and is non-empty — --force given, would merge over it"
        else
            aw_warn "target already exists and is non-empty — a real run would refuse (use --force)"
        fi
    fi
    aw_info "nothing was changed (dry run)."
    exit 0
fi

if [[ -e "$TO" ]] && [[ -n "$(find "$TO" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    if [[ "$FORCE" != "1" ]]; then
        aw_error "target already exists and is not empty: ${TO}"
        aw_info "the native QQ profile is already there, so this copy was refused and"
        aw_info "nothing was written to either side."
        aw_info "re-run with --force to merge the Flatpak profile over it:"
        aw_info "    $(basename "${BASH_SOURCE[0]}") --force"
        exit 1
    fi
    aw_warn "merging over the existing target: ${TO} (nothing is deleted)"
fi

# cp -a of the source DIRECTORY onto the target path: cp -a "$FROM" "$TO"
# would nest it as "$TO/QQ" when $TO already exists, so copy the contents of
# the source into the target directory instead. Contents-level copy keeps the
# operation additive and re-runnable; nothing on either side is removed.
mkdir -p "$TO"
cp -a "${FROM}/." "${TO}/"
aw_ok "copied ${FILE_COUNT} files (${SIZE}) into ${TO}"

aw_step "next steps"
cat >&2 <<EOF
  1. Quit QQ completely (both the Flatpak build and the native one) so no
     process is holding the copied profile open, then start the native QQ.
  2. The first login may ask for a QR scan: QQ re-binds the device when the
     client changes, so a fresh scan is expected — your message history and
     local account data are already in ${TO}.
  3. Once the native build is confirmed working, remove the fallback:
         flatpak uninstall com.qq.QQ
     (this script deliberately does NOT run flatpak; the Flatpak profile at
     ${FROM} is left untouched until you do it yourself.)
EOF

exit 0
