{ pkgs, inputs, ... }:
{
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    just
    nixfmt-rfc-style
    nixfmt-tree
    inputs.alejandra.defaultPackage."${system}"
    wineWowPackages.stable
    gemini-cli
  ];
}
