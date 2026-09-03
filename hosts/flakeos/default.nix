{ inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/boot
    ../../modules/nixos/locale.nix
    ../../modules/nixos/desktop/niri.nix
    ../../modules/nixos/desktop/services.nix
    ../../modules/nixos/power.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/users.nix
    ../../modules/nixos/nix.nix
  ];

  system.stateVersion = "26.05";
}
