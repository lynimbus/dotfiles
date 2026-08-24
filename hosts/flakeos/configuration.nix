{
  config,
  pkgs,
  hostname,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = hostname;

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

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        (fcitx5-rime.override {
          rimeDataPkgs = [
            rime-ice
          ];
        })
      ];
    };
  };

  services = {
    desktopManager.plasma6.enable = true;
    displayManager.sddm.enable = true;
    displayManager.sddm.wayland.enable = true;
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users."lynimbus" = {
    isNormalUser = true;
    description = "lynimbus";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    # 登录 shell 换成 nushell。NixOS 会自动把它装进 systemPackages 并注册进 /etc/shells。
    # 当前会话仍是旧 shell，重新登录后生效。
    shell = pkgs.nushell;
  };

  # 让裸 `nix run nixpkgs#<pkg>` / `nix shell nixpkgs#...` 使用本 flake 锁定的 nixpkgs,
  # 而不是 nix 内置的 github:NixOS/nixpkgs master 映射。
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  # 内存压缩交换:22G 内存无 swap 文件时的安全网,平时几乎不占内存。
  zramSwap.enable = true;

  # 省去生成 NixOS 手册(man configuration.nix 等),加快 rebuild。
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
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [ "https://cache.nixos.org" ];
    # 系统层声明二进制缓存：flake.nix 的 nixConfig 只对 trusted-users 生效，
    # 而 trusted-users 只有 root，写在这里才对普通用户的 nix build 也生效。
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://deepseek-harness-nix.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CXWu8iE8f2b24L2pY="
      "deepseek-harness-nix.cachix.org-1:5NrkwLN9veNMhiINtU5ZeV4isXFhFsOwn6Ms7J1M+TA="
    ];
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
