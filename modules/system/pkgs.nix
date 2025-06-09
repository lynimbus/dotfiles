{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    wget
    git
    neovim
    sops
  ];
}
