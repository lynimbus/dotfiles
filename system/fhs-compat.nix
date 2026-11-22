{ pkgs, ... }:

{
  # nix-ld covers a single ELF binary that expects the FHS interpreter. It does
  # not cover a program that ships its own complete root (an AppImage) or one
  # that dlopen()s a library by absolute path, so AppImage gets appimage-run.
  # steam-run is provided by programs.steam in system/gaming.nix.
  environment.systemPackages = with pkgs; [
    appimage-run
  ];
}
