{ inputs, ... }:

{
  imports = [ inputs.magpie-flake.homeManagerModules.default ];

  programs.magpie = {
    enable = true;
    autostart.enable = true;
  };
}
