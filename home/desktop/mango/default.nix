{
  config,
  inputs,
  repoRoot,
  ...
}:

let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;

  repoFile = path: mkSymlink "${repoRoot}/home/desktop/mango/${path}";

  linkFiles =
    dir: files:
    builtins.listToAttrs (
      map (file: {
        name = "mango/${file}";
        value.source = repoFile "${dir}/${file}";
      }) files
    );
in
{
  imports = [
    inputs.mangowm.hmModules.mango
  ];

  wayland.windowManager.mango.enable = true;

  xdg.configFile = {
    "mango/screenshot.sh".source = repoFile "screenshot.sh";

    "systemd/user/mango-session.target.wants/xdg-desktop-autostart.target".source =
      mkSymlink "/etc/systemd/user/xdg-desktop-autostart.target";
  }
  // linkFiles "conf" [
    "config.conf"
    "binds.conf"
    "rules.conf"
    "mango-hardware.conf"
  ];
}
