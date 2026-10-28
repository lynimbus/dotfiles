{ hostname, ... }:

{
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  networking.networkmanager.settings.keyfile.path =
    "/var/lib/nixos/networkmanager/system-connections";

  networking.resolvconf.enable = false;
  environment.etc."resolv.conf".source = "/run/NetworkManager/resolv.conf";

  networking.wireless = {
    scanOnLowSignal = false;
    extraConfig = "# D-Bus";
  };
}
