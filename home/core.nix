{ username, homeDirectory, ... }:

{
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "26.05";

  services.polkit-gnome.enable = true;

  systemd.user.services.polkit-gnome = {
    Unit.Requires = [ "dbus.service" ];
    Unit.After = [ "dbus.service" ];
    Service.Restart = "on-failure";
    Service.RestartSec = 2;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "io.github.lgse.Strata.desktop" ];
    };
  };
}
