default:
    @just --list

switch:
    nh os switch .

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

gc:
    sudo nix-collect-garbage -d --delete-older-than 3d
    nix store optimise
