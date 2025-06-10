{
  config,
  pkgs,
  lib,
  inputs,
  home-manager,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    ../../modules/system/grub.nix
    ../../modules/system/networking.nix
    ../../modules/system/environment.nix
    ../../modules/system/nvidia.nix
    ../../modules/system/fonts.nix
    ../../modules/system/rime.nix
    ../../modules/system/dae.nix
    ../../modules/system/localization.nix
    ../../modules/system/power.nix
    ../../modules/system/sound.nix
    ../../modules/system/kde.nix
    ../../modules/system/settings.nix
    ../../modules/system/access-tokens.nix
    ../../modules/system/cleaner.nix
    ../../modules/system/pkgs.nix
    ../../modules/system/steam.nix
  ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "nixos";

  users.users.lantianx = {
    isNormalUser = true;
    shell = pkgs.nushell;
    extraGroups = ["wheel" "networkmanager" "keys"];
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "24.05";
}
