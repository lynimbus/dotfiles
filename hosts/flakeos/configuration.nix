{
  pkgs,
  inputs,
  username,
  ...
}:

let
  myPkgs = import pkgs.path {
    overlays = [ inputs.mac-style-plymouth.overlays.default ];
    system = pkgs.system;
  };
in
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader = {
    timeout = 5;
    systemd-boot = {
      enable = true;
      editor = false;
      configurationLimit = 3;
    };
    efi.canTouchEfiVariables = true;
  };

  boot.kernelParams = [
    "nowatchdog"
    "quiet"
    "splash"
    "vga=current"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  boot.plymouth = {
    enable = true;
    theme = "mac-style";
    themePackages = [ myPkgs.mac-style-plymouth ];
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "flakeos";

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    fira-code
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        kdePackages.fcitx5-configtool
        fcitx5-gtk
        kdePackages.fcitx5-qt
        kdePackages.fcitx5-chinese-addons
        fcitx5-material-color
        (fcitx5-rime.override {
          rimeDataPkgs = [
            rime-ice
          ];
        })
      ];
    };
  };

  programs.niri = {
    enable = true;
    package = pkgs.niri-glass;
  };

  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.defaultSession = "niri";

  services.dbus.implementation = "broker";

  services.openssh.enable = true;

  hardware.bluetooth.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  services.libinput.enable = true;

  powerManagement.resumeCommands = ''
    echo -n "serio0" > /sys/bus/serio/drivers/atkbd/unbind 2>/dev/null || true
    echo -n "serio0" > /sys/bus/serio/drivers/atkbd/bind   2>/dev/null || true
  '';

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = "lynimbus";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.nushell;
  };

  security.sudo.wheelNeedsPassword = false;

  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  zramSwap.enable = true;

  documentation.nixos.enable = false;

  nixpkgs.config.allowUnfree = true;

  programs.nh = {
    enable = true;
    flake = "/home/lynimbus/dotfiles";
  };

  environment.systemPackages = with pkgs; [
    neovim
    curl
    wget
    git
    xwayland-satellite
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://deepseek-harness-nix.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CXWu8iE8f2b24L2pY="
      "deepseek-harness-nix.cachix.org-1:5NrkwLN9veNMhiINtU5ZeV4isXFhFsOwn6Ms7J1M+TA="
    ];
    download-buffer-size = 524288000;
    auto-optimise-store = true;
    warn-dirty = false;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "26.05";
}
