{ pkgs, username, ... }:

{
  users.users.${username} = {
    isNormalUser = true;
    description = "lynimbus";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = false;
}
