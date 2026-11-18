#!/usr/bin/env bash
# Regenerate docs/overview/snapshot.json from the evaluated flake, check every
# language pack for completeness against en.json and the installed package set,
# and verify the Go native UI builds cleanly.
#
#   just overview
set -euo pipefail

cd "$(dirname "$0")/../.."

out=docs/overview/snapshot.json
i18n_dir=docs/overview/i18n
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- language packs -------------------------------------------------------
[ -f "$i18n_dir/en.json" ] || {
  echo "$i18n_dir/en.json is missing; it is the reference the other packs are checked against" >&2
  exit 1
}

for pack in "$i18n_dir"/*.json; do
  code=$(basename "$pack" .json)
  jq -e . "$pack" >/dev/null || {
    echo "$pack is not valid JSON" >&2
    exit 1
  }
  if [ "$code" != en ]; then
    missing=$(jq -r --slurpfile en "$i18n_dir/en.json" \
      '[($en[0] | paths(scalars) | join("."))] - [paths(scalars) | join(".")] | .[]' "$pack" |
      grep -v "^descriptions\\." || true)
    if [ -n "$missing" ]; then
      echo "$pack is missing keys that en.json has:" >&2
      printf "  %s\n" "$missing" >&2
      exit 1
    fi
  fi
done

# --- package data ---------------------------------------------------------
nix eval --json -f docs/overview/data.nix | jq . >"$tmp/snapshot.json"

jq -r ".sections[].items[].pname" "$tmp/snapshot.json" | sort >"$tmp/pkglist.txt"
for pack in "$i18n_dir"/*.json; do
  code=$(basename "$pack" .json)
  [ "$code" = en ] && continue
  jq -r '.descriptions // {} | keys[]' "$pack" | sort >"$tmp/have.txt"
  missing=$(comm -23 "$tmp/pkglist.txt" "$tmp/have.txt")
  if [ -n "$missing" ]; then
    echo "$pack has no description for:" >&2
    printf "  %s\n" "$missing" >&2
    echo "add them there: the flake installs a package this pack does not cover" >&2
    exit 1
  fi
done

mv -f "$tmp/snapshot.json" "$out"

total=$(jq -r '.total' "$out")
local_count=$(jq -r '.meta.localCount' "$out")
size=$(wc -c <"$out")
echo "wrote $out: $total packages ($local_count local), $size bytes"

(cd docs/overview && go build -o "$tmp/overview" .)
echo "ok: docs/overview builds cleanly with Go $(go version | awk '{print $3}')"
