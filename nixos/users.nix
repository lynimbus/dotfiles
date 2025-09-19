{ pkgs, username, ... }:
{
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = false;
}
