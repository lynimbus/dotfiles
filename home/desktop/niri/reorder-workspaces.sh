#!/usr/bin/env bash
# Niri keeps a separate workspace index sequence per output, and picks the order
# it created them in. This puts them in the order niri-hardware.kdl declares, so
# a new workspace is one edit there and nothing here.
set -euo pipefail

# The script runs from ~/.config/niri, next to that file.
config="$(dirname "$(readlink -f "$0")")/niri-hardware.kdl"
[ -r "$config" ] || { echo "no $config to read the workspace order from" >&2; exit 1; }

index=0
while IFS= read -r workspace; do
  [ -n "$workspace" ] || continue
  index=$((index + 1))
  printf 'Moving workspace %s to index %s\n' "$workspace" "$index"
  niri msg action move-workspace-to-index "$index" --reference "$workspace"
done < <(sed -n 's/^workspace "\([^"]*\)".*/\1/p' "$config")
