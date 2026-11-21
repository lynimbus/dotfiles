{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./boot-complete.nix
    ./plymouth.nix
    ./network.nix
    ./sing-box.nix
    ./docker.nix
    ./wireshark.nix
    ./ssh.nix
    ./locale.nix
    ./fonts.nix
    ./input-method.nix
    ./audio.nix
    ./hardware.nix
    ./users.nix
    ./password-guard.nix
    ./secrets.nix
    ./nix.nix
    ./etc-overlay.nix
    ./envfs.nix
    ./nix-ld.nix
    ./comma.nix
    ./fhs-compat.nix
    ./packages.nix
    ./linuxqq-wayland-fix.nix
    ./desktop-umbriel.nix
    ./desktop-mango.nix
    ./cherry-magpie.nix
    ./xdg.nix
    ../defaults/terminal.nix
    ../defaults/file-chooser.nix
  ];

  system.stateVersion = "26.05";
}
