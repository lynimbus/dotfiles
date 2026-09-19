{ config, ... }:

{
  sops.defaultSopsFile = ../secrets/pi-auth.json;
  sops.age.sshKeyPaths = [
    "${config.home.homeDirectory}/.ssh/id_ed25519"
  ];
  home.sessionVariables.SOPS_AGE_KEY_CMD = "ssh-to-age -private-key -i ${config.home.homeDirectory}/.ssh/id_ed25519";

  sops.secrets."pi-auth" = {
    format = "json";
    key = "";
    path = "${config.home.homeDirectory}/.pi/agent/auth.json";
    mode = "0600";
  };
}
