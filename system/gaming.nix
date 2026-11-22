{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{
  programs.steam = {
    enable = true;
    # Keep Maple Mono NF CN out of Steam's FHS font directory so CEF/Proton
    # never falls back to its 1.2em-wide CJK glyphs; Ghostty still gets it from
    # the host profile.
    fontPackages = lib.filter (p: (p.pname or "") != "MapleMono-NF-CN") config.fonts.packages;
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
