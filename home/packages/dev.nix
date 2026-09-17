{ pkgs, ... }:

{
  home.packages = with pkgs; [
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
