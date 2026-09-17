{ ... }:
{
  imports = [
    ./core.nix
    ./packages/cli.nix
    ./packages/dev.nix
    ./packages/archive.nix
    ./packages/gui.nix
    ./programs/fish.nix
    ./programs/zed.nix
    ./programs/yazi.nix
    ./programs/jujutsu.nix
  ];
}
