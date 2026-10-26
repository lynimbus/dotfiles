{ ... }:

{
  # qq 本体也由这个模块装（programs.linuxqq-wayland-fix.qq 默认取 pkgs.qq），
  # 所以 home/packages/gui.nix 里不再单独装。
  programs.linuxqq-wayland-fix.enable = true;
}
