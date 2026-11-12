#!/usr/bin/env bash
# Render docs/overview.html: evaluate the flake, inline the icons the apps ship,
# and drop the result into the page template together with the language packs.
#
#   just overview
#
# The page is generated because every fact on it already exists in the
# configuration. Editing the HTML to add a package would be a second copy that
# goes stale; evaluating the flake is the only source of truth.
set -euo pipefail

cd "$(dirname "$0")/../.."

out=docs/overview.html
i18n_dir=docs/overview/i18n
template=docs/overview/shell.html
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

[ -f "$template" ] || {
  echo "$template is missing; it holds the markup and the logic of the page" >&2
  exit 1
}

# --- language packs -------------------------------------------------------
# One JSON file per language, named <code>.json. English is the reference: every
# other pack must carry the same keys, and must describe every package the flake
# installs, or the page would fall back to English mid-view.
[ -f "$i18n_dir/en.json" ] || {
  echo "$i18n_dir/en.json is missing; it is the reference the other packs are checked against" >&2
  exit 1
}

jq -s "." "$i18n_dir"/*.json >"$tmp/packs.json"

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

# The picker lists the packs in file-name order; each pack states its own
# display name so the page never invents one.
jq "{__languages: map({code: .__meta.code, name: .__meta.name})}" \
  "$tmp/packs.json" >"$tmp/languages.json"

# Assemble { en: {...}, zh: {...}, __languages: [...] } so the page needs only
# the one inline document.
jq -n --slurpfile langs "$tmp/languages.json" --slurpfile packs "$tmp/packs.json" \
  'reduce $packs[0][] as $pack ({};
     . + {($pack.__meta.code): ($pack | del(.__meta))})
   + {__languages: $langs[0].__languages}' /dev/null >"$tmp/i18n.json"

# --- package data ---------------------------------------------------------
nix eval --json -f docs/overview/data.nix >"$tmp/data.json"

jq -e 'has("__languages")' "$tmp/i18n.json" >/dev/null || {
  echo "the language packs produced no locale list" >&2
  exit 1
}

# Every installed package needs a description in each translated pack, or a card
# shows its labels in one language and its prose in another. English is exempt:
# the derivation's own meta.description is already English, and the pack only
# overrides the packages whose upstream metadata has none.
jq -r ".sections[].items[].pname" "$tmp/data.json" | sort >"$tmp/pkglist.txt"
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

# --- icons ----------------------------------------------------------------
# An icon lives in the store the derivation points at, which a page opened over
# file:// cannot reach, so each one is inlined as a data URI and the page stays
# a single file.
#
# The card draws an icon at 40px, so a bitmapped icon is resampled to 64px first:
# the 256px and 1024px originals add half a megabyte and change nothing on screen.
# An SVG is already resolution free and goes in untouched.
jq -r '[.sections[].items[].icon | select(. != null)] | unique | .[]' "$tmp/data.json" |
  while read -r path; do
    printf "%s\t%s\n" "$path" \
      "$(case $path in
        *.svg) printf 'image/svg+xml' ;;
        *) printf 'image/png' ;;
      esac)"
  done >"$tmp/icons.tsv"

: >"$tmp/map.jsonl"
while IFS=$'\t' read -r path mime; do
  [ -f "$path" ] || continue
  case $mime in
    image/png)
      # magick is in home.packages for the mimetype handling, so it is there to
      # call; a checkout without it still renders, only larger.
      if magick "$path" -resize 64x64 png:- >"$tmp/icon.png" 2>/dev/null; then
        payload=$(base64 -w0 "$tmp/icon.png")
      else
        payload=$(base64 -w0 "$path")
      fi
      ;;
    *) payload=$(base64 -w0 "$path") ;;
  esac
  jq -cn --arg k "$path" --arg v "data:$mime;base64,$payload" '{($k): $v}' >>"$tmp/map.jsonl"
done <"$tmp/icons.tsv"

jq -s 'reduce .[] as $o ({}; . + $o)' "$tmp/map.jsonl" >"$tmp/map.json" 2>/dev/null ||
  echo "{}" >"$tmp/map.json"

jq --slurpfile icons "$tmp/map.json" \
  '.sections |= map(.items |= map(if .icon then .icon = ($icons[0][.icon] // null) else . end))' \
  "$tmp/data.json" >"$tmp/final.json"

# --- assemble -------------------------------------------------------------
# The JSON goes in as-is; sed would read a "&" in a description as a back
# reference, so the substitution is done by python.
python3 - "$tmp/final.json" "$tmp/i18n.json" "$template" "$out" <<'PY'
import json
import os
import sys

data_path, i18n_path, template_path, out_path = sys.argv[1:5]
payload = {
    "__DATA__": open(data_path).read().strip(),
    "__I18N__": open(i18n_path).read().strip(),
}
template = open(template_path).read()
for placeholder, value in payload.items():
    if placeholder not in template:
        sys.exit(f"{template_path} has no {placeholder} placeholder")
    template = template.replace(placeholder, value)
open(out_path, "w").write(template)

final = json.loads(payload["__DATA__"])
i18n = json.loads(payload["__I18N__"])
languages = [pack["code"] for pack in i18n["__languages"]]
print(
    f"wrote {out_path}: {final['total']} packages, languages {chr(44).join(languages)}, "
    f"{os.path.getsize(out_path)} bytes"
)
PY
