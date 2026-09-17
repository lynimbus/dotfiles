{ pkgs, ... }:

{
  xdg.terminal-exec = {
    enable = true;
    package = pkgs.xdg-terminal-exec;
    settings = {
      niri = [
        "com.mitchellh.ghostty.desktop"
      ];
      default = [
        "com.mitchellh.ghostty.desktop"
      ];
    };
  };

  xdg.portal = {
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  systemd.user.services.xdg-desktop-portal = {
    overrideStrategy = "asDropin";
    after = [
      "xdg-desktop-portal-gtk.service"
      "xdg-desktop-portal-gnome.service"
    ];
    wants = [
      "xdg-desktop-portal-gtk.service"
      "xdg-desktop-portal-gnome.service"
    ];
  };
}
