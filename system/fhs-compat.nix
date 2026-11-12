{ pkgs, ... }:

{
  # nix-ld covers a single ELF binary that expects the FHS interpreter. It does
  # not cover a program that ships its own complete root (an AppImage) or one
  # that dlopen()s a library by absolute path, so these two get a real sandbox
  # with /usr, /bin and /lib populated the traditional way.
  environment.systemPackages = with pkgs; [
    appimage-run
    steam-run-free
  ];
}
