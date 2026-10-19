{
  config,
  inputs,
  pkgs,
  repoRoot,
  ...
}:

let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;

  repoFile = path: mkSymlink "${repoRoot}/home/desktop/niri/${path}";

  linkFiles =
    dir: files:
    builtins.listToAttrs (
      map (file: {
        name = "niri/${file}";
        value.source = repoFile "${dir}/${file}";
      }) files
    );
in
{
  home.packages = with pkgs; [
    xwayland-satellite
    slurp
    grim
    satty
    wl-clipboard
    xdg-user-dirs
  ];

  xdg.configFile = {
    "niri/reorder-workspaces.sh".source = repoFile "reorder-workspaces.sh";
  }
  // linkFiles "conf" [
    "config.kdl"
    "keybindings.kdl"
    "niri-hardware.kdl"
    "noctalia-shell.kdl"
    "spawn-at-startup.kdl"
    "windowrules.kdl"
  ];

  systemd.user.services.pyclipsync = {
    Unit = {
      Description = "Wayland <-> X11 clipboard sync (pyclipsync)";
      After = [ "niri.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "niri.service" ];
    Service = {
      ExecStart = "${
        inputs.pyclipsync.packages.${pkgs.stdenv.hostPlatform.system}.pyclipsync
      }/bin/pyclipsync";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 5;
    };
  };
}
