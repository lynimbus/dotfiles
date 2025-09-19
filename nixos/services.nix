{ pkgs, inputs, ... }:
{
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = false;
  services.tuned.enable = true;

  services.printing.enable = true;

  services.dbus.implementation = "broker";

  services.openssh.enable = true;

  services.dae = {
    enable = true;
    package = inputs.daeuniverse.packages.x86_64-linux.dae-unstable;
    configFile = "/etc/dae/config.dae";
    disableTxChecksumIpGeneric = false;
    assets = with pkgs; [
      v2ray-geoip
      v2ray-domain-list-community
    ];
    openFirewall = {
      enable = true;
      port = 12345;
    };
  };
}
