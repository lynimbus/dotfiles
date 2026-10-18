{
  config,
  inputs,
  ...
}:

let
  repoPath = "${config.home.homeDirectory}/nixos/home/desktop/mango";
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  imports = [
    inputs.mangowm.hmModules.mango
  ];

  wayland.windowManager.mango.enable = true;

  xdg.configFile = {
    "mango/config.conf".source = mkSymlink "${repoPath}/conf/config.conf";
    "mango/binds.conf".source = mkSymlink "${repoPath}/conf/binds.conf";
    "mango/rules.conf".source = mkSymlink "${repoPath}/conf/rules.conf";
    "mango/mango-hardware.conf".source = mkSymlink "${repoPath}/conf/mango-hardware.conf";
    "mango/screenshot.sh".source = mkSymlink "${repoPath}/screenshot.sh";

    "systemd/user/mango-session.target.wants/xdg-desktop-autostart.target".source =
      config.lib.file.mkOutOfStoreSymlink "/etc/systemd/user/xdg-desktop-autostart.target";
  };
}
