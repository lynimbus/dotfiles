{
  config,
  inputs,
  pkgs,
  repoRoot,
  ...
}:

let
  repo = import ../../lib.nix { inherit config repoRoot; };
in
{
  xdg.configFile = {
    "niri/reorder-workspaces.sh" = repo.liveFile "desktop/niri/reorder-workspaces.sh";
  }
  // repo.liveFiles {
    from = "desktop/niri/conf";
    into = "niri";
    files = [
      "config.kdl"
      "keybindings.kdl"
      "niri-hardware.kdl"
      "noctalia-shell.kdl"
      "spawn-at-startup.kdl"
      "windowrules.kdl"
    ];
  };

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
