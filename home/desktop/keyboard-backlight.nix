{ pkgs, ... }:

{
  # Both desktop keybinding files call this with a step. The device name and the
  # default step belong to the keyboard, not to either compositor's config.
  home.packages = [
    (pkgs.writeShellScriptBin "kbd-backlight" ''
      exec ${pkgs.brightnessctl}/bin/brightnessctl --device=kbd_backlight set "''${1:-10%+}"
    '')
  ];
}
