{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  home-manager,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../modules/nixos
  ];

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
    ];
    config = {
      allowUnfree = true;
    };
  };

  networking.hostName = "nixos";

  users.users.lantianx = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "keys"];
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "24.05";
}
