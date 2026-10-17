{
  config,
  inputs,
  pkgs,
  ...
}:

let
  repoPath = "${config.home.homeDirectory}/nixos/home/desktop/niri";
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
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
    "niri/config.kdl".source = mkSymlink "${repoPath}/conf/config.kdl";
    "niri/keybindings.kdl".source = mkSymlink "${repoPath}/conf/keybindings.kdl";
    "niri/niri-hardware.kdl".source = mkSymlink "${repoPath}/conf/niri-hardware.kdl";
    "niri/noctalia-shell.kdl".source = mkSymlink "${repoPath}/conf/noctalia-shell.kdl";
    "niri/spawn-at-startup.kdl".source = mkSymlink "${repoPath}/conf/spawn-at-startup.kdl";
    "niri/windowrules.kdl".source = mkSymlink "${repoPath}/conf/windowrules.kdl";
    "niri/reorder-workspaces.sh".source = mkSymlink "${repoPath}/reorder-workspaces.sh";
    "niri/float-autoclose.sh".source = mkSymlink "${repoPath}/float-autoclose.sh";
  };

  systemd.user.services.niri-float-autoclose = {
    Unit = {
      Description = "Close floating Ghostty when it loses focus";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      ExecStart = "${pkgs.bash}/bin/bash %h/.config/niri/float-autoclose.sh";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  systemd.user.services.pyclipsync = {
    Unit = {
      Description = "Wayland <-> X11 clipboard sync (pyclipsync)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
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
