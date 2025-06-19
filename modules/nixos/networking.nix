{
  config,
  pkgs,
  ...
}: {
  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;
  
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        EnableNetworkConfiguration = true;
      };
      Network = {
        EnableIPv6 = true;
      };
      Scan = {
        DisablePeriodicScan = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    overskride
    iwgtk
    impala
  ];
  
  networking.firewall.enable = false;
}
