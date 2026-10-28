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
    hashedPasswordFile = "/var/lib/nixos/user-password-hash";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID7ZlQ/cZQv/nZO1tdGoaYX8yNUXHsPyzMrstAqdsA48"
    ];
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = false;
}
