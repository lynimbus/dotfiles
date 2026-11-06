#!/usr/bin/env bash
# capture.sh — record existing distrobox containers into
# containers/inventory/<profile>.json
#
# Container STATUS is deliberately NOT recorded: it changes on every boot and
# would pollute git diffs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../scripts/lib/common.sh"

PROFILE="${1:-$(aw_profile)}"
ROOT="${ATOMIC_WS_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
OUT="${ROOT}/containers/inventory/${PROFILE}.json"

if ! aw_have distrobox; then
    aw_warn "distrobox is not installed — skipping container capture."
    exit 0
fi

RAW="$(distrobox list --no-color 2>/dev/null || true)"

python3 - "$PROFILE" "$OUT" "$RAW" "${SCRIPT_DIR}/bootstrap" <<'PY_EOF'
import json
import os
import sys
from pathlib import Path

profile, out_path, raw, bootstrap_dir = sys.argv[1:5]

rows = []
for line in raw.splitlines():
    if not line.strip() or line.lstrip().startswith("ID "):
        continue
    parts = [p.strip() for p in line.split("|")]
    if len(parts) < 4 or not parts[1]:
        continue
    name, image = parts[1], parts[3]
    has_bootstrap = (Path(bootstrap_dir) / f"{name}.sh").is_file()
    rows.append(
        {
            "name": name,
            "image": image,
            "bootstrap": f"containers/bootstrap/{name}.sh" if has_bootstrap else None,
        }
    )
rows.sort(key=lambda r: r["name"])

inv = {"version": 1, "profile": profile, "containers": rows}
out = Path(out_path)
out.parent.mkdir(parents=True, exist_ok=True)
tmp = out.with_suffix(".json.tmp")
tmp.write_text(json.dumps(inv, indent=2, ensure_ascii=False) + "\n")
os.replace(tmp, out)
print(f"[OK]    distrobox inventory → {out_path} ({len(rows)} containers)", file=sys.stderr)
PY_EOF
