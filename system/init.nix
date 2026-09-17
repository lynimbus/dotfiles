{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./plymouth.nix
    ./network.nix
    ./ssh.nix
    ./locale.nix
    ./fonts.nix
    ./input-method.nix
    ./audio.nix
    ./hardware.nix
    ./users.nix
    ./nix.nix
    ./packages.nix
  ];

  system.stateVersion = "26.05";
}
