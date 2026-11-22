{ pkgs, username, ... }:

{
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
}
