#!/usr/bin/env bash
# capture.sh — dump installed Homebrew packages to a Brewfile
#
# Output: apps/brew/inventory/<profile>/Brewfile
#         apps/brew/inventory/<profile>/leaves.<profile>.txt
#
# Uses `brew bundle dump` (the workflow Bazzite documents) and post-processes
# it into a stable, sorted file so re-running capture never produces a
# meaningless diff. `brew bundle dump` includes auto-installed dependencies;
# `brew leaves` marks the formulae you actually requested, and those are
# annotated here — the inventory stays honest about what it contains.
#
# Skips cleanly (exit 0) when Homebrew is not installed.
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

# Group the dump into per-manager sections. `brew bundle dump` writes a
# description comment BEFORE the entry it describes, so splitting it with
# `grep '^brew ' | sort` (the obvious way) detaches every description into a
# floating comment block and drops flatpak/vscode entries into a "rest"
# bucket; apps/brew/normalize.py keeps comment blocks attached to their entry,
# groups by manager and sorts inside each group (LC_ALL=C -> byte-stable),
# and drops the flatpak bucket: apps/flatpak/inventory/<profile>.json is the
# only record of flatpak state.
python3 "${SCRIPT_DIR}/normalize.py" "${RAW}" "${LEAVES_RAW}" "${PROFILE}" >"${OUT}"

# leaves.<profile>.txt: exactly the formulae the user asked for
LC_ALL=C sort -o "${OUT_DIR}/leaves.${PROFILE}.txt" "${LEAVES_RAW}"

BREWS=$(grep -c '^brew ' "${OUT}" || true)
CASKS=$(grep -c '^cask ' "${OUT}" || true)
TAPS=$(grep -c '^tap ' "${OUT}" || true)
LEAVES=$(grep -c . "${OUT_DIR}/leaves.${PROFILE}.txt" || true)
aw_ok "brew inventory → ${OUT} (${TAPS} taps, ${BREWS} formulae, ${LEAVES} requested, ${CASKS} casks)"
