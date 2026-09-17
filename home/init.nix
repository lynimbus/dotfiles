{ ... }:
{
  imports = [
    ./core.nix
    ./packages/cli.nix
    ./packages/dev.nix
    ./packages/archive.nix
    ./packages/gui.nix
  ];
}
