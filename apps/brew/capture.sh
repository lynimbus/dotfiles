#!/usr/bin/env bash
# `brew bundle dump` (the workflow Bazzite documents) includes auto-installed
# dependencies; `brew leaves` marks only the formulae the user requested, so the
# committed Brewfile is stabilised and sorted to avoid meaningless re-capture
# diffs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/lib/common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../scripts/lib/common.sh"

PROFILE="${1:-$(aw_profile)}"
ROOT="${ATOMIC_WS_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
OUT_DIR="${ROOT}/apps/brew/inventory/${PROFILE}"
OUT="${OUT_DIR}/Brewfile"

if ! aw_have brew; then
    aw_warn "Homebrew is not installed — skipping brew capture."
    aw_info "on Bazzite: ujust install-brew  |  elsewhere: https://brew.sh"
    exit 0
fi

aw_step "capturing Homebrew packages (profile: ${PROFILE})"
mkdir -p "${OUT_DIR}"
RAW="$(mktemp)"
LEAVES_RAW="$(mktemp)"
trap 'rm -f "${RAW}" "${LEAVES_RAW}"' EXIT

brew bundle dump --file "${RAW}" --force
brew leaves >"${LEAVES_RAW}" 2>/dev/null || : >"${LEAVES_RAW}"

# `brew bundle dump` writes a description comment BEFORE the entry it describes,
# so a plain `grep '^brew ' | sort` would detach every description into a
# floating block and bury foreign managers in a "rest" bucket. normalize.py
# keeps the blocks attached; flatpak state has one owner:
# apps/flatpak/inventory/<profile>.json.
python3 "${SCRIPT_DIR}/normalize.py" "${RAW}" "${LEAVES_RAW}" "${PROFILE}" >"${OUT}"

LC_ALL=C sort -o "${OUT_DIR}/leaves.${PROFILE}.txt" "${LEAVES_RAW}"

BREWS=$(grep -c '^brew ' "${OUT}" || true)
CASKS=$(grep -c '^cask ' "${OUT}" || true)
TAPS=$(grep -c '^tap ' "${OUT}" || true)
LEAVES=$(grep -c . "${OUT_DIR}/leaves.${PROFILE}.txt" || true)
aw_ok "brew inventory → ${OUT} (${TAPS} taps, ${BREWS} formulae, ${LEAVES} requested, ${CASKS} casks)"
