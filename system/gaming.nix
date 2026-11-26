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
    settings.general = {
      # enableRenice only grants CAP_SYS_NICE; renice defaults to 0 unless set.
      renice = 10;
      ioprio = 0;
      # Never drop CPU governor to powersave on hybrid iGPU+dGPU laptops.
      igpu_power_threshold = -1;
    };
  };

  # Load the kernel ntsync driver (built as a module on CachyOS kernels) so
  # Proton-CachyOS / Wine 10+ uses native NT synchronization primitives.
  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", MODE="0666"
  '';

  # Allow nvidia-powerd Dynamic Boost (115W -> up to 140W on RTX 4060 Laptop).
  hardware.nvidia.dynamicBoost.enable = true;

  # Virtual input devices for Steam Input / controller remapping on Wayland.
  hardware.uinput.enable = true;

  users.users.${username}.extraGroups = [ "gamemode" ];
}
