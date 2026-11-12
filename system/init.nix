{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./boot-complete.nix
    ./plymouth.nix
    ./network.nix
    ./wireshark.nix
    ./ssh.nix
    ./locale.nix
    ./fonts.nix
    ./input-method.nix
    ./audio.nix
    ./hardware.nix
    ./users.nix
    ./secrets.nix
    ./nix.nix
    ./etc-overlay.nix
    ./envfs.nix
    ./nix-ld.nix
    ./comma.nix
    ./fhs-compat.nix
    ./packages.nix
    ./linuxqq-wayland-fix.nix
    ./desktop-niri.nix
    ./desktop-mango.nix
    ./xdg.nix
    ../defaults/terminal.nix
    ../defaults/file-chooser.nix
  ];

  system.stateVersion = "26.05";
}
