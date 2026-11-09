{ ... }:

{
  # The module installs qq itself (programs.linuxqq-wayland-fix.qq defaults to
  # pkgs.qq), so home/packages.nix does not list it.
  programs.linuxqq-wayland-fix.enable = true;
}
