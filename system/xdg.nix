{ inputs, pkgs, ... }:

let
  luciolePkg = inputs.luciole.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  services.gvfs.enable = true;
  services.avahi.enable = true;

  # Expose Luciole on the session D-Bus so org.freedesktop.FileManager1
  # activation works across desktop sessions.
  services.dbus.packages = [ luciolePkg ];

  xdg.portal = {
    xdgOpenUsePortal = true;
    extraPortals = [
      luciolePkg
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  systemd.user.services.xdg-desktop-portal = {
    overrideStrategy = "asDropin";
    enableDefaultPath = false;
    after = [
      "xdg-desktop-portal-gtk.service"
    ];
    wants = [
      "xdg-desktop-portal-gtk.service"
    ];
  };
}
