default:
    @just --list

switch:
    nh os switch .

build:
    nh os build .

boot:
    nh os boot .

update:
    env NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix flake update
    nix run .#update-pkgs
    nh os switch .

update-input input:
    env NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix flake update {{input}}

check:
    nix flake check --no-build

fmt:
    nix fmt

rollback:
    nh os rollback

generations:
    nh os info

diff:
    nh os build . --diff always

diff-gen a b:
    nvd diff /nix/var/nix/profiles/system-{{a}}-link /nix/var/nix/profiles/system-{{b}}-link

gc:
    sudo nix-collect-garbage -d --delete-older-than 14d
    nix store optimise
