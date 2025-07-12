{
  imports = [
    ./secrets.nix
    #./intel-drivers.nix
    ./amd-drivers.nix
    ./nvidia-drivers.nix
    #./optimus-prime-offload-mode.nix
    ./optimus-prime-sync-mode.nix
    ./gnome.nix
    #./hyprland.nix
    ./variables.nix
    ./windows-vm.nix
  ];
}
