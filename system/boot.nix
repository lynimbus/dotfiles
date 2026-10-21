{
  lib,
  pkgs,
  ...
}:

let
  kernelPackages = pkgs.linuxPackages_latest.extend (
    final: prev:
    let
      kernelBuild = "${prev.kernel.dev}/lib/modules/${prev.kernel.modDirVersion}/build";
    in
    {
      zenpower = prev.zenpower.overrideAttrs (_: {
        installPhase = ''
          runHook preInstall
          make -C ${kernelBuild} M=$PWD \
            ${lib.escapeShellArgs final.kernelModuleMakeFlags} \
            modules_install INSTALL_MOD_PATH=$out INSTALL_MOD_STRIP=1 \
            INSTALL_MOD_DIR=kernel/drivers/hwmon/zenpower
          runHook postInstall
        '';
      });
    }
  );
in
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

  boot.kernelPackages = kernelPackages;

  boot.tmp.cleanOnBoot = true;
}
