{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.magpie;
in
{
  options.programs.magpie = {
    enable = lib.mkEnableOption "magpie";

    autostart.enable = lib.mkEnableOption "Automatically start magpie on login";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.magpie;
      defaultText = lib.literalExpression "pkgs.magpie";
      description = "The magpie package that provides share/applications/magpie.desktop.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.sessionVariables.MAGPIE_BUN = "${pkgs.bun}/bin/bun";

    # The app updates itself by replacing its own binary, which a store path
    # cannot take, so upgrades belong to the rebuild.
    home.activation.magpieAutoUpdateOff = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe cfg.package} update auto off ||
        echo "magpie: could not disable self-update; turn it off in Settings"
    '';

    xdg.configFile."autostart/magpie.desktop" = lib.mkIf cfg.autostart.enable {
      force = true;
      text = ''
        [Desktop Entry]
        Type=Application
        Name=magpie
        Exec="${cfg.package}/bin/magpie" tray
        Terminal=false
      '';
    };
  };
}
