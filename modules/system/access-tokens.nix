{
  config,
  pkgs,
  lib,
  ...
}: {
  sops.age.keyFile = "/home/lantianx/dotfiles/secrets/keys.txt";
  sops.secrets.nixAccessTokens = {
    sopsFile = ../../secrets/secrets.yaml;
    path = "/run/secrets/nixAccessTokens";
    mode = "0440";
    group = config.users.groups.keys.name;
  };

  nix.extraOptions = ''
    !include /run/secrets/nixAccessTokens
  '';
}
