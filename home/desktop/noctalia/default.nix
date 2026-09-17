{ config, ... }:

let
  repoPath = "${config.home.homeDirectory}/nixos/home/desktop/noctalia";
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  programs.noctalia.enable = true;

  xdg.configFile = {
    "noctalia/config.toml".source = mkSymlink "${repoPath}/config.toml";
    "noctalia/templates/gtk-3.0.css".source = mkSymlink "${repoPath}/templates/gtk-3.0.css";
    "noctalia/templates/gtk-4.0.css".source = mkSymlink "${repoPath}/templates/gtk-4.0.css";
  };
}
