{
  config,
  pkgs,
  inputs,
  ...
}: {
  boot = {
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
    kernelPatches = [
      {patch = "${inputs.linux-xanmod-bore}/0001-bore.patch";}
      {patch = "${inputs.linux-xanmod-bore}/0002-sched-fair-Prefer-full-idle-SMT-cores.patch";}
      {patch = "${inputs.linux-xanmod-bore}/0003-glitched-cfs.patch";}
      {patch = "${inputs.linux-xanmod-bore}/0004-glitched-eevdf-additions.patch";}
      {patch = "${inputs.linux-xanmod-bore}/0005-o3-optimization.patch";}
    ];
  };
}
