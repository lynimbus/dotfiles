{ config, ... }:

{
  sops.defaultSopsFile = ../secrets/pi-auth.json;
  sops.age.sshKeyPaths = [
    "${config.home.homeDirectory}/.ssh/id_ed25519"
    "${config.home.homeDirectory}/.ssh/id_ed25519_recovery"
  ];
  home.sessionVariables.SOPS_AGE_KEY_CMD = "ssh-to-age -private-key -i ${config.home.homeDirectory}/.ssh/id_ed25519";

  sops.secrets."ssh-id-ed25519" = {
    format = "binary";
    sopsFile = ../secrets/ssh-id_ed25519;
    path = "${config.home.homeDirectory}/.ssh/id_ed25519";
    mode = "0600";
  };

  sops.secrets."pi-auth" = {
    format = "json";
    key = "";
    path = "${config.home.homeDirectory}/.pi/agent/auth.json";
    mode = "0600";
  };
}
