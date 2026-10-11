{ pkgs, lib, ... }:

{
  programs.niri.enable = true;

  systemd.user.services.niri = {
    overrideStrategy = "asDropin";
    environment = {
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_DESKTOP = "niri";
    };
  };

  programs.niri.useNautilus = false;

  xdg.portal = {
    config.niri = {
      "org.freedesktop.impl.portal.FileChooser" = lib.mkForce "strata;gtk";
    };
    extraPortals = [ pkgs.strata-portal ];
  };

  environment.systemPackages = [ pkgs.strata-file-manager ];
}
