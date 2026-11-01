#!/usr/bin/env bash
# capture.sh — scan this machine's flatpaks into apps/flatpak/inventory/<profile>.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/lib/common.sh
source "${SCRIPT_DIR}/../../scripts/lib/common.sh"

PROFILE="${1:-$(aw_profile)}"
OUT="${ATOMIC_WS_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}/apps/flatpak/inventory/${PROFILE}.json"

exec python3 "${SCRIPT_DIR}/inventory.py" capture --profile "${PROFILE}" --out "${OUT}"
