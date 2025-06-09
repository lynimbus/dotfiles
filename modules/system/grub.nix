{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    efibootmgr
    os-prober
  ];

  boot.loader = {
    systemd-boot.enable = false;
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      useOSProber = true;
      efiInstallAsRemovable = false;
      configurationLimit = 3;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
}
