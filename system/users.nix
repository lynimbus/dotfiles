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

  security.sudo.wheelNeedsPassword = false;
}
