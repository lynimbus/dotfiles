#!/usr/bin/env bash
# Generate a package with nix-init and land it in pkgs/ in the shape the rest
# of this repo uses:
#
#   - version and the hashes (vendorHash, cargoHash, ...) become function
#     arguments with default values, and the literals in the body become
#     inherit of those arguments. docs/bump-packages.sh drives nix-update over
#     the file, and nix-update rewrites either form, but a parameter is what
#     makes the value overridable and shows that it belongs to the release tag.
#   - nix-update-script is dropped: bumping runs through nix-update --flake and
#     takes its extra flags from passthru.bump, which this script writes as
#     passthru.bump = [ ]; so a new package is bumpable with nix-update's
#     defaults. Delete that line for a package that does not follow an upstream
#     release (a wrapper, or one derived from another package). Empty
#     maintainers is dropped too: this repo does not maintain the field.
#   - finalAttrs is flattened into direct references, since version is a
#     parameter by then, and a changelog written as ${finalAttrs.src.tag}
#     becomes the same tag expression the fetch uses.
#   - the result is written to pkgs/<name>.nix. overlay.nix turns every file in
#     that directory into an attribute, so nothing else needs wiring.
#
# Usage:
#   docs/scaffold-package.sh https://github.com/owner/repo [version]
#
# The skeleton only guarantees that it evaluates and that a bump can rewrite
# it. The build phases and meta.description stay for whoever knows the project:
# nix-init has no installer to invent for anything that is not a compiled
# language, and leaves an empty skeleton there (magpie, a TypeScript app that
# runs its bundle with bun, is that case).
set -euo pipefail
# shellcheck source=docs/lib.sh
source "$(dirname "$0")/lib.sh"
cd "$repo_dir" || exit 1

url="${1:?usage: docs/scaffold-package.sh <url> [version]}"
version="${2:-}"

github_token

# The attribute name is the URL's last segment, lowercased, and must be a valid
# Nix identifier: it is the overlay attribute and the file name. pname comes
# from the project's own build metadata, which nix-init derives, so the two can
# differ.
name="$(basename "${url%/}")"
name="${name%.git}"
name="${name,,}"
if [[ ! "$name" =~ ^[a-z][a-z0-9_-]*$ ]]; then
  die "no valid attribute name in the URL's last segment: $name (place the file by hand instead)"
fi
if [[ -e "pkgs/$name.nix" ]]; then
  die "pkgs/$name.nix already exists, not overwriting"
fi

extra=()
if [[ -n "$version" ]]; then
  extra+=(-V "$version")
fi

work="$(mktemp -d)"
# The generated file is a draft, so no interactive choices are wanted; without a
# TTY (an agent or CI running this) nix-init's tag prompt reads EOF and exits,
# so always go --headless.
if ! nix-init --headless -u "$url" "${extra[@]}" "$work/package.nix"; then
  die "nix-init failed; the directory is kept at $work"
fi
pkg="$work/package.nix"

# ---- (1) turn nix-update-script into the bump declaration ----
# nix-init's only use of passthru is the update script, and this repo records the
# same knowledge in passthru.bump instead.
sed -i -e 's|^\([[:space:]]*\)updateScript = nix-update-script.*$|\1bump = [ ];|' \
  -e '/nix-update-script/d' "$pkg"

# ---- (2) version literal becomes a parameter default ----
# The body keeps a binding to it: a derivation without version ends up named
# after pname alone, which is not the file name nix-update looks for later.
ver="$(sed -n 's/^  version = "\([^"]*\)";$/\1/p' "$pkg")"
sed -i 's|^  version = "[^"]*";$|  inherit version;|' "$pkg"

# ---- (3) hash literals become parameter defaults, in place ----
# The generic name for a fetcher is hash, so sha256 folds into it; vendorHash and
# cargoHash (the kero shape) become parameters of their own. A name that appears
# twice only becomes a parameter once: the other occurrence inherits the same
# argument, which would collide on a differing value, so it is left for a human.
names=()
lines=()
nlines=0
while read -r attr value; do
  param="$attr"
  if [[ "$attr" == sha256 ]]; then
    param="hash"
  fi
  dup=0
  for n in "${names[@]}"; do
    if [[ "$n" == "$param" ]]; then
      dup=1
    fi
  done
  if ((dup)); then
    echo "warning: $param appears more than once; only the first became a parameter, merge the rest by hand" >&2
  else
    names+=("$param")
    lines+=("  $param ? \"$value\",")
    nlines=$((nlines + 1))
  fi
  sed -i "s|^\([[:space:]]*\)$attr = \"$value\";|\1inherit $param;|" "$pkg"
done < <(sed -n 's/^[[:space:]]*\(sha256\|[A-Za-z0-9_-]*[Hh]ash\) = "\(sha256-[^"]*\)";$/\1 \2/p' "$pkg")

# A sha256 literal left behind is a hole in the bump contract, because
# nix-update cannot rewrite what it does not recognise: fail here instead of
# leaving it quietly.
if grep -q '= "sha256-' "$pkg"; then
  echo "some sha256 literal did not become a parameter, fix it by hand:" >&2
  grep -n '= "sha256-' "$pkg" >&2
  echo "the file is kept at $work" >&2
  exit 1
fi

# ---- (4) flatten finalAttrs into direct references ----
sed -i 's/finalAttrs\.version/version/g' "$pkg"
tag_expr="$(sed -n -e 's/^[[:space:]]*tag = \(.*\);$/\1/p' -e 's/^[[:space:]]*rev = \(.*\);$/\1/p' "$pkg" | head -1)"
if [[ -n "$tag_expr" ]]; then
  bare="${tag_expr%\"}"
  bare="${bare#\"}"
  # A changelog reference is interpolation: a bare identifier (version) has to
  # be wrapped back into ${...}, while an expression that already interpolates
  # (v${version}) or a literal tag is used as it stands.
  ident_re="^[a-zA-Z_][a-zA-Z0-9_-]*$"
  if [[ "$bare" =~ $ident_re ]]; then
    bare="\${$bare}"
  fi
  sed -i "s|\${finalAttrs\.src\.tag}|$bare|g" "$pkg"
  # rev and tag hold the same value for fetchFromGitHub, and nix-init's
  # changelog template uses either reference, so both become the same
  # expression.
  sed -i "s|\${finalAttrs\.src\.rev}|$bare|g" "$pkg"
fi
sed -i -e 's/(finalAttrs: {/{/' -e '$s/^})$/}/' "$pkg"
if grep -q 'finalAttrs' "$pkg"; then
  echo "warning: finalAttrs is still referenced (a rev-shaped tag?), check $pkg by hand" >&2
fi

# ---- (5) drop empty maintainers ----
sed -i -E '/^[[:space:]]*maintainers = (with lib\.maintainers; )?\[ \];$/d' "$pkg"

# ---- (6) insert the parameter block after the tool arguments, before '}:' ----
{
  printf '  # The version and every hash below come from the same release tag:\n  # "just bump %s" (nix-update) rewrites these literals together.\n' "$name"
  if [[ -n "$ver" ]]; then
    echo "  version ? \"$ver\","
  fi
  if [[ "$nlines" -gt 0 ]]; then
    printf '%s\n' "${lines[@]}"
  fi
} > "$work/params"

awk -v params="$work/params" '
  BEGIN { while ((getline l < params) > 0) b[++n] = l; close(params) }
  /^}:$/ && !ins { for (i = 1; i <= n; i++) print b[i]; ins = 1 }
  { print }
' "$pkg" > "$work/styled.nix" && mv "$work/styled.nix" "$pkg"

# ---- (7) write the file where the overlay picks it up ----
# The lines just deleted leave runs of blank lines behind; collapse them.
cat -s "$pkg" > "$work/squeezed.nix" && mv "$work/squeezed.nix" "$pkg"

# Whatever the template offered as passthru ends up declaring the bump flags:
# inside the block it already has, or as an attribute of its own.
if grep -qE '^  passthru = \{$' "$pkg"; then
  grep -qE '^    bump = \[ \];$' "$pkg" ||
    sed -i -e '0,/^  passthru = {$/s//  passthru = {\n    bump = [ ];/' "$pkg"
else
  sed -i -e '0,/^  meta = {/s//  passthru.bump = [ ];\n\n  meta = {/' "$pkg"
fi

mv "$pkg" "pkgs/$name.nix"
rm -rf "$work"

echo
echo "wrote pkgs/$name.nix; overlay.nix picks it up as it is."
if grep -q 'description = "";' "pkgs/$name.nix"; then
  echo "warning: meta.description is empty, fill it in."
fi
echo "next:"
echo "  1. fill in the build phases; the skeleton only guarantees that it evaluates"
echo "  2. nix build .#legacyPackages.x86_64-linux.$name"
echo "  3. delete passthru.bump = [ ]; if the package does not follow a release"
