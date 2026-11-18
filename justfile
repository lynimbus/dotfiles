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
    . docs/lib.sh
    github_token
    nix flake update

# Move the packages in pkgs/ that track an upstream release to that release's
# latest version. The package file itself declares the version and hash
# literals and the nix-update flags it needs (passthru.bump), so nothing here
# knows which package needs what.
#   just bump            # every package that tracks a release
#   just bump pig kero   # just those
bump *pkgs:
    docs/bump-packages.sh {{pkgs}}

check:
    nix flake check

# Generate a package with nix-init and land it in pkgs/ in this repo's shape;
# overlay.nix picks the file up as it is. version may be omitted.
#   just scaffold https://github.com/owner/repo 1.2.3
scaffold url version="":
    docs/scaffold-package.sh "{{url}}" "{{version}}"

# Regenerate docs/overview/snapshot.json from the evaluated flake, validate the
# language packs, and verify the MyGo overview app compiles.
overview:
    docs/overview/build.sh

# Run mygo vet, snapshot parity checks, and the headless ui.NewTester suite
# for the overview desktop app. Run it after a configuration change.
overview-verify:
    docs/overview/verify.sh

# Build and launch the MyGo overview desktop app directly from source.
overview-run:
    nix run .#legacyPackages.x86_64-linux.overview

# Drive the memo commands through record, digest and search, both failure paths included
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
