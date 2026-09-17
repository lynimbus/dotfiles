{ ... }:

{
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set -g fish_greeting ""
      fish_vi_key_bindings
    '';

    shellAliases = {
      la = "ls -a";
      lla = "ls -la";
      c = "clear";
      z = "cd";
    };
  };
}
