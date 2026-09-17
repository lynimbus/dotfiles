{ config, pkgs, ... }:

let
  repoPath = "${config.home.homeDirectory}/nixos/home/desktop/niri";
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.packages = with pkgs; [
    xwayland-satellite
    # 截图标注
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
  };

  systemd.user.services.niri-polkit-agent = {
    Unit = {
      Description = "PolicyKit authentication agent for niri";
      After = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
    };
    Install.WantedBy = [ "niri.service" ];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };
}
