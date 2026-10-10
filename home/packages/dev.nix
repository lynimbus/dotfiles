{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    inputs.magpie-flake.packages.${pkgs.stdenv.hostPlatform.system}.magpie
    zig
    koka
    go
    android-tools
    python3
    nodejs
    nil
    nixd
  ];
}
