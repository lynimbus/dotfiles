{ pkgs, lib, ... }:

{
  programs.niri.enable = true;

  # Strata's self-written file chooser replaces the GNOME one, so the Nautilus
  # backend and its D-Bus activation are no longer wanted.
  programs.niri.useNautilus = false;

  xdg.portal = {
    config.niri = {
      # The niri module also sets this key, so override rather than merge.
      "org.freedesktop.impl.portal.FileChooser" = lib.mkForce "strata;gtk";
    };
    extraPortals = [ pkgs.strata-portal ];
  };

  # Makes Strata the D-Bus-activatable owner of org.freedesktop.FileManager1,
  # which is what browsers and GTK applications call to reveal a file. It is a
  # session-bus name, so the service file has to reach the session bus search
  # path through environment.pathsToLink rather than services.dbus.packages.
  environment.systemPackages = [ pkgs.strata-file-manager ];
}
