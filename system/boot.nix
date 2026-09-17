{ pkgs, ... }:

{
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
    "vga=current"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
  ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.tmp.cleanOnBoot = true;
}
