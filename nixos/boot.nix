{ pkgs, ... }:
{
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
}
