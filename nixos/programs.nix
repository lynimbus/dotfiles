{ pkgs, inputs, ... }:
{
  programs.fish.enable = true;

  programs.firefox.enable = true;

  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  security.polkit.enable = true;

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
