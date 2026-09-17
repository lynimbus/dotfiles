{ inputs, pkgs, ... }:

{
  boot.plymouth = {
    enable = true;
    theme = "mac-style";
    themePackages = [ inputs.mac-style-plymouth.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  };
}
