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
  ];

  system.stateVersion = "26.05";
}
