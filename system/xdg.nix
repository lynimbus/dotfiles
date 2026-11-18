{ pkgs, ... }:

{
  services.gvfs.enable = true;
  services.gnome.sushi.enable = true;

  # Expose Nautilus on the session D-Bus so xdg-desktop-portal-gnome's
  # FileChooser and org.freedesktop.FileManager1 activation work outside GNOME.
  services.dbus.packages = [ pkgs.nautilus ];

  xdg.portal = {
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
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
