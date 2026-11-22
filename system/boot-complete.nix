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

    # Wait for a DRM GPU device and the greetd display manager before marking
    # this generation good; greetd runs Noctalia Greeter on tty1.
    for _ in $(seq 60); do
      if ls /dev/dri/card* > /dev/null 2>&1 \
        && [ "$(${pkgs.systemd}/bin/systemctl is-active greetd.service)" = active ]
      then
        exit 0
      fi

      sleep 1
    done

    echo "boot-complete check failed: no DRM card or greetd is not active" >&2
    ls -l /dev/dri >&2 || true
    ${pkgs.systemd}/bin/systemctl status greetd.service --no-pager >&2 || true
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
