{ inputs, ... }:
{
  imports = [
    inputs.kickstart-nixvim.homeManagerModules.default
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };
}
