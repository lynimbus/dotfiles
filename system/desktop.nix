{ pkgs, username, ... }:

{
  programs.umbriel.enable = true;
  programs.mango.enable = true;

  programs.noctalia = {
    enable = true;
    # Home Manager manages the Noctalia package and configuration in home/desktop/noctalia.
    package = null;
    recommendedServices.enable = true;
  };

  services.displayManager.noctalia-greeter = {
    enable = true;
    passwordless-sync-users = [ username ];
    settings = {
      session.default = "Umbriel";
      user.default = username;
      appearance = {
        scheme = "Synced";
        theme_mode = "dark";
      };
      cursor = {
        theme = "Adwaita";
        size = 24;
        path = pkgs.adwaita-icon-theme;
      };
      keyboard.layout = "us";
    };
  };

  services.gnome.gnome-keyring.enable = true;

  # Installs qq itself (programs.linuxqq-wayland-fix.qq defaults to pkgs.qq),
  # so home/packages.nix does not list it.
  programs.linuxqq-wayland-fix.enable = true;
}
