{ ... }:

{
  hardware.bluetooth.enable = true;

  zramSwap.enable = true;

  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/24224C5D224C3658";
    fsType = "ntfs3";
    options = [
      "uid=1000"
      "gid=100"
      "windows_names"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
    ];
  };

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/466A71B2AC3E8697";
    fsType = "ntfs3";
    options = [
      "uid=1000"
      "gid=100"
      "windows_names"
    ];
  };

  services.tuned = {
    enable = true;
    settings.dynamic_tuning = true;
    ppdSettings.main.battery_detection = true;
  };

  powerManagement.resumeCommands = ''
    echo -n "serio0" > /sys/bus/serio/drivers/atkbd/unbind 2>/dev/null || true
    echo -n "serio0" > /sys/bus/serio/drivers/atkbd/bind   2>/dev/null || true
  '';
}
