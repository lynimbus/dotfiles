{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    inputs.magpie-flake.packages.${pkgs.stdenv.hostPlatform.system}.magpie
    zig
    koka
    go
    android-tools
    payload-dumper-go
    python3
    nodejs
    nil
    nixd
  ];
}
