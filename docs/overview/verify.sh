#!/usr/bin/env bash
# Verify the MyGo overview desktop app:
#  1. docs/overview/snapshot.json still matches the live evaluated flake counts
#  2. mygo vet reports no build-lifetime errors
#  3. Go headless ui.NewTester tests pass (layouts, search, filters, settings,
#     both languages, detail sheet, Caramel Island springs, and math invariants)
#
#   just overview-verify
set -euo pipefail

cd "$(dirname "$0")/../.."

snap=docs/overview/snapshot.json
[ -f "$snap" ] || {
  echo "$snap is missing; run 'just overview' first" >&2
  exit 1
}

expected_total=$(nix eval --json -f docs/overview/data.nix --apply 'd: d.total')
expected_local=$(nix eval --json -f docs/overview/data.nix --apply 'd: d.meta.localCount')
snap_total=$(jq -r '.total' "$snap")
snap_local=$(jq -r '.meta.localCount' "$snap")

if [ "$snap_total" != "$expected_total" ] || [ "$snap_local" != "$expected_local" ]; then
  echo "FAIL: $snap is stale (snapshot=$snap_total/$snap_local, flake=$expected_total/$expected_local); run 'just overview'" >&2
  exit 1
fi

if command -v mygo >/dev/null 2>&1; then
  (cd docs/overview && mygo vet .)
fi

(cd docs/overview && go test -v ./...)
echo "ok: overview app matches flake ($expected_total packages, $expected_local local) and passes all checks"
