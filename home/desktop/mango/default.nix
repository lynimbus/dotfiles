{
  config,
  inputs,
  repoRoot,
  ...
}:

let
  repo = import ../../lib.nix { inherit config repoRoot; };
in
{
  imports = [
    inputs.mangowm.hmModules.mango
  ];

  wayland.windowManager.mango.enable = true;

  xdg.configFile = {
    # mango-session starts this target, which lives in /etc, so the
    # wants-symlink has to point outside the store.
    "systemd/user/mango-session.target.wants/xdg-desktop-autostart.target".source =
      config.lib.file.mkOutOfStoreSymlink "/etc/systemd/user/xdg-desktop-autostart.target";
  }
  // repo.liveFiles {
    from = "desktop/mango/conf";
    into = "mango";
    files = [
      "config.conf"
      "binds.conf"
      "rules.conf"
      "mango-hardware.conf"
    ];
  };
}
