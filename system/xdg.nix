{ pkgs, ... }:

{
  services.gvfs.enable = true;
  services.gnome.sushi.enable = true;

  # Expose Nautilus on the session D-Bus so xdg-desktop-portal-gnome's
  # FileChooser and org.freedesktop.FileManager1 activation work outside GNOME.
  services.dbus.packages = [ pkgs.nautilus ];

  # Right-click "Open in Ghostty" inside Nautilus (sets NAUTILUS_4_EXTENSION_DIR
  # outside GNOME and locks the terminal choice in dconf).
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "ghostty";
  };

  # External thumbnailers for Nautilus (videos/audio covers, PDFs, EPUB/MOBI).
  # System environment.pathsToLink exports /share/thumbnailers, whereas
  # home-manager profiles do not link share/thumbnailers by default.
  environment.systemPackages = with pkgs; [
    ffmpegthumbnailer
    papers
    gnome-epub-thumbnailer
  ];

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
