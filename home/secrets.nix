{
  config,
  inputs,
  sshKey,
  ...
}:

{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops.defaultSopsFile = ../secrets/pi-auth.json;
  sops.age.sshKeyPaths = [
    sshKey
    "${sshKey}_recovery"
  ];
  home.sessionVariables.SOPS_AGE_KEY_CMD = "ssh-to-age -private-key -i ${sshKey}";

  assertions = [
    {
      assertion = builtins.all (secret: !(builtins.elem secret.path config.sops.age.sshKeyPaths)) (
        builtins.attrValues config.sops.secrets
      );
      message = "sops-nix secrets must not overwrite SSH decryption keys.";
    }
  ];

  sops.secrets."pi-auth" = {
    format = "json";
    key = "";
    path = "${config.home.homeDirectory}/.pi/agent/auth.json";
    mode = "0600";
  };
}
