{ lib, pkgs, ... }:

let
  # Both desktops run the same file chooser. The sections are named per desktop
  # because each compositor's own module keeps one, and this merges into it
  # rather than replacing it; niri's module writes its own value there, hence
  # mkForce.
  fileChooser = {
    "org.freedesktop.impl.portal.FileChooser" = lib.mkForce "strata;gtk";
  };
in
{
  services.gvfs.enable = true;

  # Installed once, for both desktops: the portal the file chooser points at,
  # and the file manager that the inode/directory mimetype runs (see
  # home/core.nix).
  environment.systemPackages = [ pkgs.strata-file-manager ];

  xdg.terminal-exec = {
    enable = true;
    package = pkgs.xdg-terminal-exec;
    settings.default = [ "com.mitchellh.ghostty.desktop" ];
  };

  xdg.portal = {
    xdgOpenUsePortal = true;
    config = {
      niri = fileChooser;
      mango = fileChooser;
    };
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
