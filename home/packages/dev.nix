{ pkgs, ... }:

{
  home.packages = with pkgs; [
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
