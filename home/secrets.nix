{ config, ... }:

{
  sops.age.sshKeyPaths = [
    "${config.home.homeDirectory}/.ssh/id_ed25519"
    "${config.home.homeDirectory}/.ssh/id_ed25519_recovery"
  ];
  home.sessionVariables.SOPS_AGE_KEY_CMD = "ssh-to-age -private-key -i ${config.home.homeDirectory}/.ssh/id_ed25519";

  assertions = [
    {
      assertion = builtins.all (secret: !(builtins.elem secret.path config.sops.age.sshKeyPaths)) (
        builtins.attrValues config.sops.secrets
      );
      message = "sops-nix secrets must not overwrite SSH decryption keys.";
    }
  ];
}
