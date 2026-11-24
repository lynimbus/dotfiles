{ inputs, ... }:

{
  imports = [
    inputs.t3code-jj.homeModules.default
  ];

  programs.t3code-jj.enable = true;
}
