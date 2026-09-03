{ pkgs, ... }:

{
  # 游戏套件（旧配置合入）
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    appimage = {
      enable = true;
      binfmt = true;
    };
    gamescope.enable = true;
    gamemode.enable = true;
  };

}
