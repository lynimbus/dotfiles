{ inputs, pkgs, ... }:

{
  imports = [ inputs.magpie-flake.homeManagerModules.default ];

  programs.magpie = {
    enable = true;
    autostart.enable = true;
  };

  home.file.".local/bin/rtk".source = "${pkgs.rtk}/bin/rtk";
}
