{
  pkgs,
  inputs,
  ...
}: let
  myPkgs = import pkgs.path {
    overlays = [inputs.mac-style-plymouth.overlays.default];
    system = pkgs.system;
  };
in {
  boot.plymouth = {
    enable = true;
    theme = "mac-style";
    themePackages = [myPkgs.mac-style-plymouth];
  };
}
