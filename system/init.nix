{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./plymouth.nix
    ./network.nix
    ./ssh.nix
  ];

  system.stateVersion = "26.05";
}
