{
  imports = [
    ./secrets.nix
    #./intel-drivers.nix
    ./amd-drivers.nix
    ./nvidia-drivers.nix
    ./nvidia-prime-drivers.nix
    ./gnome.nix
    #./hyprland.nix
    ./variables.nix
  ];
}
