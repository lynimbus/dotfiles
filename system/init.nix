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
    ./desktop-plasma.nix
    ./desktop-sddm.nix
    ./desktop-niri.nix
    ./xdg.nix
    ./version.nix
  ];

  system.stateVersion = "26.05";
}
