{ ... }:

{
  hardware.bluetooth.enable = true;

  zramSwap.enable = true;

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
