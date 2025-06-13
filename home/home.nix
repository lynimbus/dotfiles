{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ../modules/home
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
