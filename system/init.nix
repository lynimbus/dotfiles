{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./plymouth.nix
  ];

  system.stateVersion = "26.05";
}
