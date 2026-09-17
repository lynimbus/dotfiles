#!/usr/bin/env bash
set -euo pipefail

# Niri keeps a separate workspace index sequence on each output.
case "$(hostname)" in
  nixos)
    workspace_order=(
      "1terminal:1"
      "2browser:2"
      "3chat:3"
      "4entertainment:4"
      "5utility:5"
      "0other:6"
    )
    ;;
  *)
    printf 'No workspace order configured for host %s\n' "$(hostname)" >&2
    exit 0
    ;;
esac

for entry in "${workspace_order[@]}"; do
  workspace="${entry%%:*}"
  index="${entry##*:}"
  printf 'Moving workspace %s to index %s\n' "$workspace" "$index"
  niri msg action move-workspace-to-index "$index" --reference "$workspace"
done
