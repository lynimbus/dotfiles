{
  config,
  pkgs,
  ...
}: {
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "cn";
    variant = "";
  };

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "lantianx";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  services.udev.packages = [pkgs.gnome-settings-daemon];

  environment.systemPackages = with pkgs; [
    gnomeExtensions.appindicator
  ];

  nixpkgs.overlays = [
    (final: prev: {
      gnome-console = prev.gnome-console.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ [
            ../assets/gnome/disable-gnome-console-close-window-prompt-48.0.1.patch
          ];
      });
      mpv = prev.mpv.override {
        scripts = [
          final.mpvScripts.inhibit-gnome
        ];
      };
    })
  ];
}
