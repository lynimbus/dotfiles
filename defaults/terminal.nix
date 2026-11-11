# The terminal that a program gets when it asks for one through
# xdg-terminal-exec.
{ pkgs, ... }:

{
  xdg.terminal-exec = {
    enable = true;
    package = pkgs.xdg-terminal-exec;
    settings.default = [ "com.mitchellh.ghostty.desktop" ];
  };
}
