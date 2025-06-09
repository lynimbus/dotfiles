{
  config,
  pkgs,
  ...
}: {
  networking.networkmanager.enable = true;
  networking.wireless.userControlled.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  networking.firewall.enable = false;
}
