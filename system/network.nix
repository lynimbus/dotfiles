{ hostname, ... }:

{
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  networking.networkmanager.settings.keyfile.path =
    "/var/lib/nixos/networkmanager/system-connections";

  # The DG-LAB App pairs with CoyoteCoder's built-in Socket V2 relay, and the
  # phone has to reach it over the LAN. The firewall drops it at INPUT
  # otherwise, which looks like a broken QR code in the panel.
  networking.firewall.allowedTCPPorts = [ 9999 ];

  networking.resolvconf.enable = false;
  environment.etc."resolv.conf".source = "/run/NetworkManager/resolv.conf";

  networking.wireless.scanOnLowSignal = false;
}
