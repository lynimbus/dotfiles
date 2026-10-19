{ pkgs, repoRoot, ... }:

let
  screenshot = pkgs.writeShellScriptBin "screenshot" ''
    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.grim
        pkgs.slurp
        pkgs.satty
        pkgs.wl-clipboard
        pkgs.xdg-user-dirs
      ]
    }:''${PATH:-/run/current-system/sw/bin}"
    exec ${pkgs.bash}/bin/bash ${repoRoot}/home/desktop/screenshot.sh "$@"
  '';

  kbd-backlight = pkgs.writeShellScriptBin "kbd-backlight" ''
    exec ${pkgs.brightnessctl}/bin/brightnessctl --device=kbd_backlight set "''${1:-10%+}"
  '';
in
{
  home.packages = [
    screenshot
    kbd-backlight
  ];
}
