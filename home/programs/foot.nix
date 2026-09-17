{ pkgs, ... }:

{
  programs.foot = {
    enable = true;

    server.enable = true;

    settings = {
      main = {
        term = "foot";
        font = "Maple Mono NF CN:size=13";
        dpi-aware = "no";
        resize-keep-grid = "no";
        shell = "${pkgs.fish}/bin/fish --login";
      };

      colors-dark = {
        alpha = 0.93;
        # foot >= 1.26 + compositor 支持（niri 26.04 起）
        blur = true;
      };

      csd.preferred = "none";

      mouse.hide-when-typing = "yes";
    };
  };
}
