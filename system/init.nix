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
    ./ollama.nix
    ./users.nix
    ./nix.nix
    ./nix-ld.nix
    ./packages.nix
    ./linuxqq-wayland-fix.nix
    ./desktop-niri.nix
    ./desktop-mango.nix
    ./xdg.nix
    ./magisk.nix
  ];

  system.stateVersion = "26.05";
}
