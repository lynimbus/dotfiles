{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.kitty = lib.mkForce {
    enable = true;
    enableGitIntegration = true;
    shellIntegration.enableFishIntegration = true;
    font = {
      name = "Maple Mono NF CN";
      size = 12;
    };
    themeFile = "JetBrains_Darcula";
  };
}
