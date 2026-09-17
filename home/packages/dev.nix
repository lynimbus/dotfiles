{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zig
    koka
    go
    android-tools
  ];
}
