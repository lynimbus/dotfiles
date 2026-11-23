{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  luciolePkg = inputs.luciole.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  services.gvfs.enable = true;
  services.avahi.enable = true;

  # Expose Luciole on the session D-Bus so org.freedesktop.FileManager1
  # activation works across desktop sessions.
  services.dbus.packages = [ luciolePkg ];

  xdg.terminal-exec = {
    enable = true;
    package = pkgs.xdg-terminal-exec;
    settings.default = [ "com.mitchellh.ghostty.desktop" ];
  };

  xdg.portal = {
    xdgOpenUsePortal = true;
    extraPortals = [
      luciolePkg
      pkgs.xdg-desktop-portal-gtk
    ];
    # Both desktops use Luciole's file chooser first and fall back to GTK.
    # Each compositor's module keeps its own section, so mkForce overrides only
    # the FileChooser entry.
    config = {
      umbriel."org.freedesktop.impl.portal.FileChooser" = lib.mkForce "luciole;gtk";
      mango."org.freedesktop.impl.portal.FileChooser" = lib.mkForce "luciole;gtk";
    };
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
