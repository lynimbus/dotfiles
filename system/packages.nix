{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    neovim
    curl
    wget
    git
  ];
}
