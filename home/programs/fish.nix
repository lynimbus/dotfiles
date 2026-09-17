{ ... }:

{
  programs.fish = {
    enable = true;

    shellInit = ''
      set -gx EDITOR nvim
      set -gx VISUAL nvim
    '';

    interactiveShellInit = ''
      set -g fish_greeting ""
      fish_vi_key_bindings
    '';

    shellAliases = {
      la = "ls -a";
    };
  };
}
