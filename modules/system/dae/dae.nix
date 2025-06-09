{
  config,
  pkgs,
  ...
}: {
  services.dae = {
    enable = true;
    configFile = "/home/lantianx/dotfiles/modules/system/dae/config.dae";
    assets = with pkgs; [
      v2ray-geoip
      v2ray-domain-list-community
    ];
  };
}
