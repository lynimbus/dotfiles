{ repoRoot, ... }:

{
  services.userborn.enable = true;
  system.etc.overlay = {
    enable = true;
    mutable = false;
  };

  environment.etc = {
    machine-id.text = "e6998c90f65f4d70b8e9671a651da49f";
    "tmpfiles.d/credstore.conf".text = "";
    "tmpfiles.d/tuned-profiles.conf".text = "";
    "nixos".source = repoRoot;
  };
}
