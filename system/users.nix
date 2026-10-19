{
  pkgs,
  username,
  homeDirectory,
  ...
}:

{
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    home = homeDirectory;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = false;
}
