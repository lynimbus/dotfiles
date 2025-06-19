{
  config,
  pkgs,
  inputs,
  ...
}: {
  services.xserver = {
    enable = true;
    xkb = {
      layout = "cn";
      variant = "";
    };
  };

  services.displayManager.autoLogin = {
    enable = true;
    user = "lantianx";
  };
}
