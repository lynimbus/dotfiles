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

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.timeout = 0;

  boot.kernelPackages = pkgs.linuxPackages_zen;

  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "udev.log_priority=3"
    "rd.systemd.show_status=auto"
    "rd.udev.log_level=3"
    "acpi.ec_no_wakeup=1"
    "gpiolib_acpi.ignore_interrupt=AMDI0030:00:6"
  ];
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;

  boot.plymouth = {
    enable = true;
    theme = "rings";
    themePackages = with pkgs; [
      (adi1090x-plymouth-themes.override {
        selected_themes = ["rings"];
      })
    ];
  };

  services.power-profiles-daemon.enable = false;
  services.tlp.enable = true;

  networking.hostName = "nixos";

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";

  i18n.defaultLocale = "zh_CN.UTF-8";

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

  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "disable-ps2-wakeup";
      text = ''
        # Disable wakeup for PS/2 keyboard controller
        ACTION=="add", SUBSYSTEM=="serio", KERNEL=="serio0", ATTR{power/wakeup}="disabled"
      '';
      destination = "/etc/udev/rules.d/99-disable-keyboard-wakeup.rules";
    })
  ];

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    # pulse.enable = true;
    # jack.enable = true;
    # media-session.enable = true;
  };

  # services.xserver.libinput.enable = true;

  users.users.lantianx = {
    isNormalUser = true;
    description = "lantianx";
    extraGroups = ["networkmanager" "wheel" "kvm" "adbusers"];
  };

  security.sudo.wheelNeedsPassword = false;

  programs.adb.enable = true;

  programs.firefox.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  nixpkgs.config.allowUnfree = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.05"
  ];

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    inputs.alejandra.defaultPackage."${system}"
    android-tools
    payload-dumper-go
    git-repo
    ventoy-full
    ladspa-sdk
    just
  ];

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall.enable = false;

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
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    wqy_zenhei
    maple-mono.NF-CN-unhinted
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
