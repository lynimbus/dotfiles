{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./nixos
  ];

  boot = {
    loader = {
      timeout = 0;
      systemd-boot = {
        editor = false;
        enable = true;
        configurationLimit = 3;
      };
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.linuxPackages_lqx;

    kernelParams = [
      "nowatchdog"
      "quiet"
      "splash"
      "vga=current"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    consoleLogLevel = 0;
    initrd.verbose = false;
  };

  services.power-profiles-daemon.enable = false;
  services.tlp.enable = false;
  services.tuned.enable = true;

  networking.hostName = "nixos";

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];

  services.printing.enable = true;

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

  users.users.lantianx = {
    isNormalUser = true;
    description = "lantianx";
    extraGroups = ["networkmanager" "wheel" "kvm" "adbusers"];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;

  programs.adb.enable = true;

  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    nixfmt-rfc-style
    inputs.alejandra.defaultPackage."${system}"
    android-tools
    payload-dumper-go
    just
    clang
    lua
    python314
  ];

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      substituters = [
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://cache.garnix.io"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
      trusted-users = ["lantianx"];
      download-buffer-size = 524288000;
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1w";
    };
  };
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    fira-code
    fira-code-symbols
    sarasa-gothic
  ];

  services.dae = {
    enable = true;
    package = inputs.daeuniverse.packages.x86_64-linux.dae-unstable;
    configFile = "/etc/dae/config.dae";
    disableTxChecksumIpGeneric = false;
    assets = with pkgs; [
      v2ray-geoip
      v2ray-domain-list-community
    ];
    openFirewall = {
      enable = true;
      port = 12345;
    };
  };

  # services.daed = {
  #   enable = true;
  #   openFirewall = {
  #     enable = true;
  #     port = 12345;
  #   };
  # };

  system.stateVersion = "25.05";
}
