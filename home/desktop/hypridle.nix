{ pkgs, ... }:

{
  home.packages = [ pkgs.playerctl ];

  services.hypridle = {
    enable = true;

    settings = {
      general = {
        lock_cmd = "noctalia msg session lock";
        before_sleep_cmd = "noctalia msg session lock";
        # niri 自己提供 org.freedesktop.ScreenSaver，hypridle 不能再抢
        ignore_dbus_inhibit = true;
      };

      listener = [
        {
          timeout = 360;
          condition_cmd = "! playerctl -a status 2>/dev/null | grep -q '^Playing$'";
          condition_retry = 30;
          on-timeout = "niri msg action power-off-monitors";
          on-resume = "niri msg action power-on-monitors";
        }
        {
          timeout = 1200;
          condition_cmd = "! playerctl -a status 2>/dev/null | grep -q '^Playing$'";
          condition_retry = 30;
          on-timeout = "noctalia msg session lock";
        }
      ];
    };
  };
}
