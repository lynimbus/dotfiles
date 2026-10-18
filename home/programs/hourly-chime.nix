{ pkgs, ... }:

let
  hourlyChime = pkgs.writeShellScript "hourly-chime" ''
    ${pkgs.libnotify}/bin/notify-send \
      --app-name=hourly-chime \
      --icon=clock \
      "整点报时" "$(${pkgs.coreutils}/bin/date +%H:%M)"
    exec ${pkgs.pipewire}/bin/pw-play \
      ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/complete.oga
  '';
in
{
  systemd.user.services.hourly-chime = {
    Unit.Description = "整点报时通知与提示音";
    Service = {
      Type = "oneshot";
      ExecStart = "${hourlyChime}";
    };
  };

  systemd.user.timers.hourly-chime = {
    Unit.Description = "每小时整点触发整点报时";
    Timer = {
      OnCalendar = "*-*-* 08..23:00:00";
      AccuracySec = "1s";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
