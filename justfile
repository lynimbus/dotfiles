default:
    @just --list

switch:
    nh os switch .

build:
    nh os build .

update:
    env NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix flake update

check:
    nix flake check --no-build

gc:
    sudo nix-collect-garbage -d --delete-older-than 14d
    nix store optimise
