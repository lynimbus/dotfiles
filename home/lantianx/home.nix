{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/home/programs.nix
    ../../modules/home/pkgs.nix
    ../../modules/home/fish.nix
    ../../modules/home/git.nix
    ../../modules/home/rime.nix
    ../../modules/home/kitty.nix
    ../../modules/home/ssh.nix
  ];

  home.username = "lantianx";
  home.homeDirectory = "/home/lantianx";

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "zh_CN.UTF-8";
  };

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
}
