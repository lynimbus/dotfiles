{ pkgs, ... }:

{
  services.gvfs.enable = true;

  # Installed once, for both desktops: the portal the file chooser points at,
  # and the file manager the inode/directory mimetype runs (see
  # defaults/file-chooser.nix and defaults/mimeapps.nix).
  environment.systemPackages = [ pkgs.strata-file-manager ];

  xdg.portal = {
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
      strata-portal
    ];
  };

  systemd.user.services.xdg-desktop-portal = {
    overrideStrategy = "asDropin";
    enableDefaultPath = false;
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
