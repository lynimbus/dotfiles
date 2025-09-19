{ pkgs, ... }:
{
  users.users.lantianx = {
    isNormalUser = true;
    description = "lantianx";
    extraGroups = [
      "networkmanager"
      "wheel"
      "kvm"
      "adbusers"
    ];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = false;
}
