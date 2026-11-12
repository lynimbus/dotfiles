{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.boot.loader.systemd-boot.bootCounting.enable;

  # A generation that reaches boot-complete.target gets marked good and its
  # boot counter removed. Everything in this file exists to make that depend on
  # the machine actually being usable.
  check = pkgs.writeShellScript "boot-complete-check" ''
    set -u

    # No display manager runs here, so no Wayland socket exists until someone
    # logs in at tty1. Waiting on a compositor would fail every boot. What a
    # broken boot actually lacks is a GPU device or a login prompt.
    for _ in $(seq 60); do
      if ls /dev/dri/card* > /dev/null 2>&1 \
        && [ "$(${pkgs.systemd}/bin/systemctl is-active getty@tty1.service)" = active ]
      then
        exit 0
      fi

      sleep 1
    done

    echo "boot-complete check failed: no DRM card or no login prompt" >&2
    ls -l /dev/dri >&2 || true
    ${pkgs.systemd}/bin/systemctl status getty@tty1.service --no-pager >&2 || true
    exit 1
  '';
in
{
  config = lib.mkIf cfg {
    systemd.services.boot-complete-check = {
      description = "Require a GPU device and a login prompt before blessing this generation";

      requiredBy = [ "boot-complete.target" ];
      before = [ "boot-complete.target" ];

      # Default dependencies would order this after multi-user.target, which is
      # ordered after boot-complete.target, so the check would never gate the
      # blessing. The retry loop covers the units that start in parallel.
      unitConfig.DefaultDependencies = false;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = check;
        TimeoutStartSec = "90s";
      };
    };
  };
}
