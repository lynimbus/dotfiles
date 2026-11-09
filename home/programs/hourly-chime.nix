{ pkgs, ... }:

let
  hourlyChime = pkgs.writeShellScript "hourly-chime" ''
    ${pkgs.libnotify}/bin/notify-send \
      --app-name=hourly-chime \
      --icon=clock \
      "Hourly chime" "$(${pkgs.coreutils}/bin/date +%H:%M)"
    exec ${pkgs.pipewire}/bin/pw-play \
      ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/complete.oga
  '';
in
{
  systemd.user.services.hourly-chime = {
    Unit.Description = "Hourly chime notification and sound";
    Service = {
      Type = "oneshot";
      ExecStart = "${hourlyChime}";
    };
  };

  systemd.user.timers.hourly-chime = {
    Unit.Description = "Fires the hourly chime at every full hour";
    Timer = {
      OnCalendar = "*-*-* 08..23:00:00";
      AccuracySec = "1s";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
