{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # CachyOS ships this kernel built with Clang and ThinLTO, tuned for znver4
  # (this machine is a Zen 4 part). The `release` branch of the kernel flake is
  # the revision its Hydra builds and pushes to the cache configured in
  # system/nix.nix, so this downloads rather than compiling a kernel locally.
  #
  # It comes from the flake's own nixpkgs, not this repo's, which is what makes
  # the cached builds match. The kernel package set is therefore the only thing
  # in this configuration evaluated against that revision.
  kernelPackages =
    inputs.nix-cachyos-kernel.legacyPackages.${pkgs.stdenv.hostPlatform.system}."linuxPackages-cachyos-latest-lto-zen4".extend
      (
        final: prev: {
          # nixos-hardware adds this out-of-tree module for the Zen temperature
          # sensors. Its Makefile passes -Wimplicit-fallthrough=3, which only GCC
          # accepts; this kernel is compiled with Clang, where the unknown
          # warning option fails the build under -Werror. The flag is a warning
          # level, so dropping it changes nothing but whether the module builds.
          zenpower = prev.zenpower.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace Makefile --replace-fail "-Wimplicit-fallthrough=3" ""
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
      # Boot counting consumes one entry per failed attempt, so the menu needs
      # room for `tries` bad entries plus a generation to fall back to.
      configurationLimit = 5;
      bootCounting = {
        enable = true;
        tries = 3;
      };
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
