{
  config,
  pkgs,
  ...
}: {
  services.dae = {
    enable = true;
    configFile = "/home/lantianx/workspace/config.dae";
    assets = with pkgs; [
      v2ray-geoip
      v2ray-domain-list-community
    ];
  };
}
