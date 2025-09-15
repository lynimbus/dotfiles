switch:
  nixos-rebuild switch --flake . --sudo

debug:
  nixos-rebuild build --flake . --sudo --show-trace --verbose

check:
  nix flake check

up:
  nix flake update

update:
  nix flake update
  nixos-rebuild switch --flake . --sudo


# Update specific input
# usage: make upp i=home-manager
upp:
  nix flake update $(i)

history:
  nix profile history --profile /nix/var/nix/profiles/system

repl:
  nix repl -f flake:nixpkgs

clean:
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 1d
  sudo nix store gc --debug
  sudo nix-collect-garbage --delete-old
