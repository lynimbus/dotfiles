{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    (inputs.import-tree ./nixos)
  ];

  nixpkgs.config.allowUnfree = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_lqx;
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.nr_hugepages" = 256;
    };
    loader = {
      timeout = 5;
      systemd-boot = {
        editor = false;
        enable = true;
        configurationLimit = 2;
      };
      efi.canTouchEfiVariables = true;
    };

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
  i18n.supportedLocales = [ "all" ];

  hardware.bluetooth.enable = true;

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

  services.dbus.implementation = "broker";

  users.users.lantianx = {
    isNormalUser = true;
    description = "lantianx";
    extraGroups = [
      "networkmanager"
      "wheel"
      "kvm"
      "adbusers"
    ];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    just
    nixfmt-rfc-style
    nixfmt-tree
    inputs.alejandra.defaultPackage."${system}"
    wineWowPackages.stable
    gemini-cli
  ];

  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  security.polkit.enable = true;

  services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
      trusted-users = [ "lantianx" ];
      download-buffer-size = 524288000;
      auto-optimise-store = true;
    };
  };
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    nerd-fonts.jetbrains-mono
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-configtool
      fcitx5-gtk
      kdePackages.fcitx5-qt
      fcitx5-material-color
      kdePackages.fcitx5-chinese-addons
      (fcitx5-rime.override {
        rimeDataPkgs =
          with pkgs.nur.repos.linyinfeng.rimePackages;
          withRimeDeps [
            rime-ice
          ];
      })
    ];
  };

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
