{
  inputs,
  ...
}:
{
  imports = [
    (inputs.import-tree ./nixos)
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
