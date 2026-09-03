{
  pkgs,
  inputs,
  ...
}:

let
  myPkgs = import pkgs.path {
    overlays = [ inputs.mac-style-plymouth.overlays.default ];
    system = pkgs.system;
  };
in
{
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
}
