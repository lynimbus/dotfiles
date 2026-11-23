default:
    @just --list

switch:
    nh os switch .

# Make the new generation the boot default without activating it.
stage:
    nh os boot .

# Activate now without making it the boot default, so a reboot reverts.
try:
    nh os test .

build:
    nh os build .

update:
    #!/usr/bin/env bash
    . scripts/lib.sh
    github_token
    nix flake update

# Move the packages in pkgs/ that track an upstream release to that release's
# latest version. Each package declares its own nix-update flags in passthru.bump.
#   just bump            # every package that tracks a release
#   just bump pig kero   # just those
bump *pkgs:
    scripts/bump-packages.sh {{pkgs}}

# Format all Nix files with nixfmt-tree.
fmt:
    nix fmt

# Run flake checks (formatting, shellcheck, package invariants, overview tests, NixOS eval).
check:
    nix flake check

# Refresh the embedded fallback snapshot shipped inside the overview desktop app.
# Write to a temp file first so nix eval (which builds overview to inspect its
# outPath) never reads a half-truncated snapshot.json.
snapshot:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    nix eval --json -f pkgs/overview/data.nix | jq . > "$tmp"
    mv -f "$tmp" pkgs/overview/snapshot.json

# Generate a package with nix-init and land it in pkgs/ in this repo's shape;
# overlay.nix picks the file up automatically. version may be omitted.
#   just scaffold https://github.com/owner/repo 1.2.3
scaffold url version="":
    scripts/scaffold-package.sh "{{url}}" "{{version}}"

# Drive the memo commands through record, digest and search, both failure paths included.
memo-verify:
    bash home/programs/memo-verify.sh

# List the generations that `undo` can return to.
gens:
    nixos-rebuild list-generations

# Return to the previous generation and make it the boot default.
undo:
    nh os rollback

gc:
    sudo nix-collect-garbage -d --delete-older-than 3d
    nix store optimise
