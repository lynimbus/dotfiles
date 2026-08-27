{
  config,
  pkgs,
  hostname,
  inputs,
  ...
}:

let
  # mac-style plymouth 主题由 flake overlay 注入（旧配置同款用法）
  myPkgs = import pkgs.path {
    overlays = [ inputs.mac-style-plymouth.overlays.default ];
    system = pkgs.system;
  };
in
{
  imports = [
    ./hardware-configuration.nix
    # epireyn/niri-flake 的 NixOS module：niri 会话/portal/polkit/keyring/systemd
    # 接线 + 声明式配置校验。它会给 home-manager 注入 homeModules.config
    # （programs.niri.config|settings 生成 ~/.config/niri/config.kdl）。
    # niri 包本体 = pkgs.niri-glass（下方 overlay 把 liquid-glass 补丁
    # 覆盖到 niri-flake 的 niri-stable 之上）。
    inputs.niri-flake.nixosModules.niri
  ];

  boot.loader = {
    timeout = 5;
    systemd-boot = {
      enable = true;
      # 关掉 boot 菜单里的编辑（防物理接触改内核参数）
      editor = false;
      # boot 菜单只保留最近 3 个条目
      configurationLimit = 3;
    };
    efi.canTouchEfiVariables = true;
  };

  # 静默启动 + 关看门狗（旧配置沿用）
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

  # mac-style 开机动画（配上面的 quiet/splash）
  boot.plymouth = {
    enable = true;
    theme = "mac-style";
    themePackages = [ myPkgs.mac-style-plymouth ];
  };

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

  # 中文字体 + 等宽 Nerd Font（旧配置合入，中文渲染必需）
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
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

  # niri：niri-flake 模块 + liquid-glass 补丁包（glassOverlay 定义在 flake.nix）。
  # 启用后 SDDM 会出现 niri 会话；登录界面默认进 niri，Plasma 保留兜底。
  # 配置本体（programs.niri.config）在 home/flakeos.nix，构建期校验。
  programs.niri = {
    enable = true;
    package = pkgs.niri-glass;
  };

  services = {
    desktopManager.plasma6.enable = true;
    displayManager.sddm.enable = true;
    displayManager.sddm.wayland.enable = true;
    # 默认会话切到 niri-glass（KDE 的会话名是 plasma，这里两者都在 SDDM 列表里）
    displayManager.defaultSession = "niri";
  };

  # dbus-broker（旧配置沿用，消息总线更快）
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

  # 翼龙15Pro (GM5HG0A) 固件怪癖：s2idle 挂起期间 8042 会收到假键盘中断，
  # 上游 spurious_8042 quirk 目前只覆盖同系的 GM5HG7A，本机仍需 workaround。
  # 现象：用内置键盘唤醒时 IRQ1 顺带清掉了控制器状态；用其他方式
  # （电源键/合盖/USB 键鼠）唤醒后 PS/2 键盘留在坏状态，atkbd 不再上报事件。
  # 方案：恢复后强制重新绑定 atkbd = 向键盘发 0xFF 复位指令重同步，
  # 该症状的社区通用解（/sys/bus/serio/drivers/atkbd/ unbind+bind）。
  # serio0 即 i8042 的 PNP0303 键盘口（本机无 PS/2 AUX 口）。
  powerManagement.resumeCommands = ''
    echo -n "serio0" > /sys/bus/serio/drivers/atkbd/unbind 2>/dev/null || true
    echo -n "serio0" > /sys/bus/serio/drivers/atkbd/bind   2>/dev/null || true
  '';

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

  # wheel 组 sudo 免密（旧配置沿用）
  security.sudo.wheelNeedsPassword = false;

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
    xwayland-satellite
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # 清华镜像优先（内容与密钥同 cache.nixos.org，国内提速），官方兜底。
    substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
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
    # 下载缓冲加大（旧配置沿用，大包下载更快）
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
