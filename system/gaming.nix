{
  pkgs,
  username,
  ...
}:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
    extraPackages = with pkgs; [
      gamemode
      gamescope
      mangohud
    ];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  # Virtual input devices for Steam Input / controller remapping on Wayland.
  hardware.uinput.enable = true;

  users.users.${username}.extraGroups = [ "gamemode" ];
}
