{ pkgs, ... }:

{
  home.packages = [ pkgs.magpie ];

  xdg.configFile."autostart/magpie.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=magpie
      Exec="${pkgs.magpie}/bin/magpie" tray
      Terminal=false
    '';
  };
}
