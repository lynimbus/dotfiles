{ lib, pkgs, ... }:

{
  home.packages = [ pkgs.magpie ];

  systemd.user.sessionVariables.MAGPIE_BUN = "${pkgs.bun}/bin/bun";

  # The app updates itself by replacing its own binary, which a store path
  # cannot take, so upgrades belong to the rebuild.
  home.activation.magpieAutoUpdateOff = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe pkgs.magpie} update auto off ||
      echo "magpie: could not disable self-update; turn it off in Settings"
  '';

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
