{ pkgs, ... }:

{
  # Linux Kernel
  security.forcePageTableIsolation = true;
  # security.lockKernelModules = true;
  # security.protectKernelImage = true;
  security.unprivilegedUsernsClone = true;
  security.virtualisation.flushL1DataCache = "cond";
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_zen;
  boot.kernelParams = [ 
    "quiet"
    "splash"
    "loglevel=3"
    "rd.udev.log_priority=3"
    "systemd.show_status=auto"
    "fbcon=nodefer"
    "vt.global_cursor_default=0"
    "kernel.modules_disabled=1"
    "lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
    "usbcore.autosuspend=-1"
    "video4linux"
    "acpi_rev_override=5"
  ];
}
